import 'package:dio/dio.dart';

import 'endpoint_vault_client.dart';

/// Dio interceptor for automatic request capture.
///
/// Add this interceptor to your Dio instance to automatically capture
/// failed requests and success statistics.
///
/// ```dart
/// final dio = Dio();
/// dio.interceptors.add(EndpointVaultInterceptor());
///
/// // Mark requests as critical with extra option
/// dio.get('/api/payment', options: Options(
///   extra: {'ev_critical': true},
/// ));
/// ```
class EndpointVaultInterceptor extends Interceptor {
  /// Only capture requests marked as critical.
  /// If false, captures all failed requests.
  final bool onlyCritical;

  /// Capture success stats for all requests (not just failures).
  final bool captureSuccessStats;

  /// Custom filter to determine if a request should be captured.
  final bool Function(RequestOptions request)? shouldCapture;

  /// Custom filter to determine if a request is critical.
  final bool Function(RequestOptions request)? isCritical;

  EndpointVaultInterceptor({
    this.onlyCritical = false,
    this.captureSuccessStats = true,
    this.shouldCapture,
    this.isCritical,
  });

  final Map<RequestOptions, DateTime> _requestStartTimes = {};

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    _requestStartTimes[options] = DateTime.now();
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    final startTime = _requestStartTimes.remove(response.requestOptions);
    final duration = startTime != null
        ? DateTime.now().difference(startTime)
        : null;

    // Capture success stats if enabled
    if (captureSuccessStats && _shouldCapture(response.requestOptions)) {
      EndpointVault.instance.captureSuccess(
        method: response.requestOptions.method,
        url: _getFullUrl(response.requestOptions),
        statusCode: response.statusCode ?? 200,
        duration: duration,
      );
    }

    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final startTime = _requestStartTimes.remove(err.requestOptions);
    final duration = startTime != null
        ? DateTime.now().difference(startTime)
        : null;

    // Check if we should capture this error
    if (_shouldCapture(err.requestOptions) && _isCriticalRequest(err.requestOptions)) {
      EndpointVault.instance.captureFailure(
        method: err.requestOptions.method,
        url: _getFullUrl(err.requestOptions),
        statusCode: err.response?.statusCode,
        errorType: _getErrorType(err),
        errorMessage: err.message,
        requestHeaders: _headersToMap(err.requestOptions.headers),
        requestBody: err.requestOptions.data,
        responseHeaders: _headersToMap(err.response?.headers.map),
        responseBody: err.response?.data,
        duration: duration,
        extra: {
          'dioErrorType': err.type.toString(),
          if (err.requestOptions.extra.containsKey('ev_context'))
            'context': err.requestOptions.extra['ev_context'],
        },
      );
    }

    handler.next(err);
  }

  bool _shouldCapture(RequestOptions options) {
    // Use custom filter if provided
    if (shouldCapture != null) {
      return shouldCapture!(options);
    }

    // Skip EndpointVault's own requests
    if (options.headers['X-API-Key'] != null &&
        options.uri.host.contains('endpoint')) {
      return false;
    }

    return true;
  }

  bool _isCriticalRequest(RequestOptions options) {
    // Use custom filter if provided
    if (isCritical != null) {
      return isCritical!(options);
    }

    // Check extra option
    if (options.extra['ev_critical'] == true) {
      return true;
    }

    // If onlyCritical is false, capture all failures
    if (!onlyCritical) {
      return true;
    }

    return false;
  }

  String _getFullUrl(RequestOptions options) {
    return options.uri.toString();
  }

  String _getErrorType(DioException err) {
    switch (err.type) {
      case DioExceptionType.connectionTimeout:
        return 'connection_timeout';
      case DioExceptionType.sendTimeout:
        return 'send_timeout';
      case DioExceptionType.receiveTimeout:
        return 'receive_timeout';
      case DioExceptionType.badCertificate:
        return 'bad_certificate';
      case DioExceptionType.badResponse:
        return 'bad_response';
      case DioExceptionType.cancel:
        return 'cancelled';
      case DioExceptionType.connectionError:
        return 'connection_error';
      case DioExceptionType.unknown:
        return 'unknown';
    }
  }

  Map<String, dynamic>? _headersToMap(Map<String, dynamic>? headers) {
    if (headers == null) return null;
    return Map<String, dynamic>.from(headers.map((key, value) {
      if (value is List) {
        return MapEntry(key, value.join(', '));
      }
      return MapEntry(key, value?.toString());
    }));
  }
}

/// Extension on [Options] for EndpointVault configuration.
extension EndpointVaultOptions on Options {
  /// Mark this request as critical for EndpointVault capture.
  Options critical({String? context}) {
    return copyWith(
      extra: {
        ...?extra,
        'ev_critical': true,
        if (context != null) 'ev_context': context,
      },
    );
  }

  /// Skip EndpointVault capture for this request.
  Options skipCapture() {
    return copyWith(
      extra: {
        ...?extra,
        'ev_skip': true,
      },
    );
  }
}
