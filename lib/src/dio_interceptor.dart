import 'package:dio/dio.dart';

import 'endpoint_vault_client.dart';
import 'models/file_attachment.dart';
import 'services/formdata_extractor.dart';

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

  /// Whether to capture file attachments from FormData requests.
  final bool captureFileAttachments;

  /// Custom filter to determine if a request should be captured.
  final bool Function(RequestOptions request)? shouldCapture;

  /// Custom filter to determine if a request is critical.
  final bool Function(RequestOptions request)? isCritical;

  EndpointVaultInterceptor({
    this.onlyCritical = false,
    this.captureSuccessStats = true,
    this.captureFileAttachments = true,
    this.shouldCapture,
    this.isCritical,
  });

  final Map<RequestOptions, DateTime> _requestStartTimes = {};

  /// Stores extracted FormData during request lifecycle.
  /// Key is a unique identifier for the request.
  final Map<String, _PendingFormData> _pendingFormData = {};

  @override
  void onRequest(
      RequestOptions options, RequestInterceptorHandler handler) async {
    _requestStartTimes[options] = DateTime.now();

    // Check if we should extract FormData
    if (captureFileAttachments &&
        options.data is FormData &&
        _shouldCapture(options)) {
      try {
        await _extractAndReplaceFormData(options, handler);
        return;
      } catch (e) {
        // If extraction fails, continue with original request
        if (EndpointVault.instance.config.debug) {
          print('[EndpointVault] FormData extraction failed: $e');
        }
      }
    }

    handler.next(options);
  }

  /// Extract files from FormData and replace with fresh streams.
  Future<void> _extractAndReplaceFormData(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final formData = options.data as FormData;
    final extractor = EndpointVault.instance.formDataExtractor;

    if (extractor == null) {
      handler.next(options);
      return;
    }

    final result = await extractor.extract(formData);

    if (result != null) {
      // Store the extraction result for later use
      final requestId = _getRequestId(options);
      _pendingFormData[requestId] = _PendingFormData(
        result: result,
        requestOptions: options,
      );

      // Replace the original FormData with recreated one (fresh streams)
      options.data = result.recreatedFormData;

      if (EndpointVault.instance.config.debug) {
        print('[EndpointVault] Captured ${result.count} file attachments '
            'for ${options.method} ${options.uri}');
      }
    }

    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    final startTime = _requestStartTimes.remove(response.requestOptions);
    final duration =
        startTime != null ? DateTime.now().difference(startTime) : null;

    // Clean up stored files on success
    final requestId = _getRequestId(response.requestOptions);
    final pendingData = _pendingFormData.remove(requestId);
    if (pendingData != null) {
      _cleanupAttachments(pendingData.result.attachments);
    }

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
    final duration =
        startTime != null ? DateTime.now().difference(startTime) : null;

    // Get any captured FormData
    final requestId = _getRequestId(err.requestOptions);
    final pendingData = _pendingFormData.remove(requestId);

    // Check if we should capture this error
    if (_shouldCapture(err.requestOptions) &&
        _isCriticalRequest(err.requestOptions)) {
      EndpointVault.instance.captureFailure(
        method: err.requestOptions.method,
        url: _getFullUrl(err.requestOptions),
        statusCode: err.response?.statusCode,
        errorType: _getErrorType(err),
        errorMessage: err.message,
        requestHeaders: _headersToMap(err.requestOptions.headers),
        requestBody: _getRequestBodyForCapture(err.requestOptions, pendingData),
        responseHeaders: _headersToMap(err.response?.headers.map),
        responseBody: err.response?.data,
        duration: duration,
        extra: {
          'dioErrorType': err.type.toString(),
          if (err.requestOptions.extra.containsKey('ev_context'))
            'context': err.requestOptions.extra['ev_context'],
        },
        attachments: pendingData?.result.attachments,
        formFields: pendingData?.result.fields,
      );
    } else if (pendingData != null) {
      // If we're not capturing, clean up the attachment files
      _cleanupAttachments(pendingData.result.attachments);
    }

    handler.next(err);
  }

  /// Get request body, excluding FormData file content (already captured).
  dynamic _getRequestBodyForCapture(
    RequestOptions options,
    _PendingFormData? pendingData,
  ) {
    if (pendingData != null) {
      // For FormData, return the form fields only (files are in attachments)
      return {
        'type': 'FormData',
        'fields': pendingData.result.fields
            .map((e) => {'key': e.key, 'value': e.value})
            .toList(),
        'fileCount': pendingData.result.attachments.length,
      };
    }
    return options.data;
  }

  /// Clean up attachment files after successful request or when not capturing.
  void _cleanupAttachments(List<FileAttachment> attachments) {
    // Schedule cleanup asynchronously to not block the response
    Future.microtask(() async {
      try {
        final storage = EndpointVault.instance.attachmentStorage;
        if (storage != null) {
          await storage.deleteAll(attachments);
        }
      } catch (e) {
        if (EndpointVault.instance.config.debug) {
          print('[EndpointVault] Failed to cleanup attachments: $e');
        }
      }
    });
  }

  /// Generate a unique ID for a request to track pending FormData.
  String _getRequestId(RequestOptions options) {
    return '${options.hashCode}_${options.uri}_${options.method}';
  }

  bool _shouldCapture(RequestOptions options) {
    // Check for skip flag
    if (options.extra['ev_skip'] == true) {
      return false;
    }

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

/// Holds pending FormData extraction result during request lifecycle.
class _PendingFormData {
  final FormDataExtractionResult result;
  final RequestOptions requestOptions;

  _PendingFormData({
    required this.result,
    required this.requestOptions,
  });
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

  /// Skip file attachment capture for this request (still captures the request).
  Options skipAttachmentCapture() {
    return copyWith(
      extra: {
        ...?extra,
        'ev_skip_attachments': true,
      },
    );
  }
}
