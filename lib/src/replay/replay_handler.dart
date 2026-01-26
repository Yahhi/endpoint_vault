import 'package:dio/dio.dart';

import '../endpoint_vault_client.dart';

/// Handler for device-side replay requests.
///
/// Use this to execute replay requests from the EndpointVault dashboard
/// when server-side replay isn't possible (e.g., short-lived auth tokens).
///
/// ```dart
/// // Check for pending replays periodically or on app resume
/// final replayHandler = ReplayHandler(dio);
/// await replayHandler.checkAndExecute();
/// ```
class ReplayHandler {
  final Dio dio;

  /// Callback to refresh authentication before replay.
  final Future<Map<String, String>?> Function()? refreshAuth;

  /// Callback when replay is requested.
  final void Function(ReplayRequest request)? onReplayRequested;

  /// Callback when replay completes.
  final void Function(ReplayRequest request, bool success)? onReplayComplete;

  ReplayHandler(
    this.dio, {
    this.refreshAuth,
    this.onReplayRequested,
    this.onReplayComplete,
  });

  /// Check for pending replay requests and execute them.
  Future<void> checkAndExecute() async {
    final request = await EndpointVault.instance.checkForReplayRequest();
    if (request == null) return;

    onReplayRequested?.call(request);

    try {
      // Refresh auth if needed
      Map<String, String>? authHeaders;
      if (refreshAuth != null) {
        authHeaders = await refreshAuth!();
      }

      // Build request options
      final options = Options(
        method: request.method,
        headers: {
          ...?request.headers,
          ...?authHeaders,
        },
      );

      // Execute the replay
      final response = await dio.request(
        request.url,
        data: request.body,
        options: options,
      );

      // Report success
      await EndpointVault.instance.reportReplayResult(
        replayId: request.id,
        success: true,
        statusCode: response.statusCode,
      );

      onReplayComplete?.call(request, true);
    } on DioException catch (e) {
      // Report failure
      await EndpointVault.instance.reportReplayResult(
        replayId: request.id,
        success: false,
        statusCode: e.response?.statusCode,
        errorMessage: e.message,
      );

      onReplayComplete?.call(request, false);
    } catch (e) {
      // Report failure
      await EndpointVault.instance.reportReplayResult(
        replayId: request.id,
        success: false,
        errorMessage: e.toString(),
      );

      onReplayComplete?.call(request, false);
    }
  }

  /// Execute a specific replay request manually.
  Future<Response> executeReplay(
    ReplayRequest request, {
    Map<String, String>? additionalHeaders,
  }) async {
    onReplayRequested?.call(request);

    try {
      final response = await dio.request(
        request.url,
        data: request.body,
        options: Options(
          method: request.method,
          headers: {
            ...?request.headers,
            ...?additionalHeaders,
          },
        ),
      );

      await EndpointVault.instance.reportReplayResult(
        replayId: request.id,
        success: true,
        statusCode: response.statusCode,
      );

      onReplayComplete?.call(request, true);
      return response;
    } catch (e) {
      if (e is DioException) {
        await EndpointVault.instance.reportReplayResult(
          replayId: request.id,
          success: false,
          statusCode: e.response?.statusCode,
          errorMessage: e.message,
        );
      } else {
        await EndpointVault.instance.reportReplayResult(
          replayId: request.id,
          success: false,
          errorMessage: e.toString(),
        );
      }

      onReplayComplete?.call(request, false);
      rethrow;
    }
  }
}
