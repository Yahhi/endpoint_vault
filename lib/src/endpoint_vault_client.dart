import 'dart:async';

import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'config.dart';
import 'models/captured_event.dart';
import 'models/event_package.dart';
import 'models/file_attachment.dart';
import 'models/pending_request.dart';
import 'models/server_response.dart';
import 'models/server_settings.dart';
import 'encryption/encryption_service.dart';
import 'redaction/redaction_rules.dart';
import 'services/formdata_extractor.dart';
import 'services/server_settings_service.dart';
import 'services/retry_manager.dart';
import 'storage/attachment_storage.dart';
import 'storage/local_event_storage.dart';

/// Main client for EndpointVault SDK.
///
/// Initialize once in your app's main() function:
///
/// ```dart
/// await EndpointVault.init(
///   apiKey: 'your-api-key',
///   encryptionKey: 'your-encryption-key',
/// );
/// ```
class EndpointVault {
  static EndpointVault? _instance;
  static EndpointVault get instance {
    if (_instance == null) {
      throw StateError(
        'EndpointVault not initialized. Call EndpointVault.init() first.',
      );
    }
    return _instance!;
  }

  final EndpointVaultConfig config;
  final EncryptionService _encryption;
  final RedactionService _redaction;
  final ServerSettingsService _settingsService;
  final RetryManager _retryManager;
  final LocalEventStorage _localStorage;
  final AttachmentStorage? _attachmentStorage;
  final FormDataExtractor? _formDataExtractor;
  final Dio _internalDio;
  final String _deviceId;

  bool _isInitialized = false;
  StreamController<CapturedEvent>? _eventStreamController;

  /// Stores replay success callbacks indexed by eventId.
  /// Called when a replay request succeeds to allow continuation of workflows
  /// like file uploads that depend on response data.
  final Map<String, Future<void> Function(Response response)> _replaySuccessCallbacks = {};

  EndpointVault._({
    required this.config,
    required EncryptionService encryption,
    required RedactionService redaction,
    required ServerSettingsService settingsService,
    required RetryManager retryManager,
    required LocalEventStorage localStorage,
    AttachmentStorage? attachmentStorage,
    FormDataExtractor? formDataExtractor,
    required Dio internalDio,
    required String deviceId,
  })  : _encryption = encryption,
        _redaction = redaction,
        _settingsService = settingsService,
        _retryManager = retryManager,
        _localStorage = localStorage,
        _attachmentStorage = attachmentStorage,
        _formDataExtractor = formDataExtractor,
        _internalDio = internalDio,
        _deviceId = deviceId;

  /// Current server settings.
  ServerSettings get serverSettings => _settingsService.settings;

  /// Whether local resend is enabled (from server settings).
  bool get localResendEnabled => _settingsService.localResendEnabled;

  /// Attachment storage service (null if file attachments disabled).
  AttachmentStorage? get attachmentStorage => _attachmentStorage;

  /// FormData extractor service (null if file attachments disabled).
  FormDataExtractor? get formDataExtractor => _formDataExtractor;

  /// Initialize EndpointVault SDK.
  ///
  /// Call this once in your app's main() function before using the SDK.
  static Future<EndpointVault> init({
    required String apiKey,
    required String encryptionKey,
    String? projectId,
    String serverUrl = 'https://api.endpoint.yahhi.me',
    String environment = 'production',
    String? appVersion,
    bool captureSuccessStats = true,
    bool enableOfflineQueue = true,
    int maxOfflineQueueSize = 100,
    RedactionConfig redaction = const RedactionConfig(),
    RetryConfig retry = const RetryConfig(),
    bool debug = false,
    bool captureFileAttachments = true,
    int maxAttachmentFileSize = 52428800,
    int maxTotalAttachmentSize = 104857600,
    int maxAttachmentsPerEvent = 10,
    String? attachmentStorageDir,
    Duration attachmentRetentionDuration = const Duration(days: 7),
  }) async {
    if (_instance != null && _instance!._isInitialized) {
      if (debug) {
        print('[EndpointVault] Already initialized, returning existing instance');
      }
      return _instance!;
    }

    final config = EndpointVaultConfig(
      apiKey: apiKey,
      encryptionKey: encryptionKey,
      projectId: projectId,
      serverUrl: serverUrl,
      environment: environment,
      appVersion: appVersion,
      captureSuccessStats: captureSuccessStats,
      enableOfflineQueue: enableOfflineQueue,
      maxOfflineQueueSize: maxOfflineQueueSize,
      redaction: redaction,
      retry: retry,
      debug: debug,
      captureFileAttachments: captureFileAttachments,
      maxAttachmentFileSize: maxAttachmentFileSize,
      maxTotalAttachmentSize: maxTotalAttachmentSize,
      maxAttachmentsPerEvent: maxAttachmentsPerEvent,
      attachmentStorageDir: attachmentStorageDir,
      attachmentRetentionDuration: attachmentRetentionDuration,
    );

    // Create internal Dio for API calls
    final internalDio = Dio(BaseOptions(
      baseUrl: serverUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: {
        'X-API-Key': apiKey,
        'Content-Type': 'application/json',
      },
    ));

    // Initialize services
    final encryption = EncryptionService(encryptionKey);
    final redactionService = RedactionService(redaction);
    final settingsService = ServerSettingsService(dio: internalDio, debug: debug);
    final retryManager = RetryManager(
      maxRetries: retry.maxRetries,
      baseDelay: retry.initialDelay,
      debug: debug,
    );
    final localStorage = LocalEventStorage(
      maxSize: maxOfflineQueueSize,
      debug: debug,
    );

    // Initialize attachment services if enabled
    AttachmentStorage? attachmentStorage;
    FormDataExtractor? formDataExtractor;

    if (captureFileAttachments) {
      attachmentStorage = AttachmentStorage(
        encryption: encryption,
        storageDir: attachmentStorageDir,
        debug: debug,
      );

      formDataExtractor = FormDataExtractor(
        storage: attachmentStorage,
        maxFileSize: maxAttachmentFileSize,
        maxTotalSize: maxTotalAttachmentSize,
        maxAttachments: maxAttachmentsPerEvent,
        debug: debug,
      );
    }

    // Get or create device ID
    final prefs = await SharedPreferences.getInstance();
    var deviceId = prefs.getString('endpoint_vault_device_id');
    if (deviceId == null) {
      deviceId = const Uuid().v4();
      await prefs.setString('endpoint_vault_device_id', deviceId);
    }

    _instance = EndpointVault._(
      config: config,
      encryption: encryption,
      redaction: redactionService,
      settingsService: settingsService,
      retryManager: retryManager,
      localStorage: localStorage,
      attachmentStorage: attachmentStorage,
      formDataExtractor: formDataExtractor,
      internalDio: internalDio,
      deviceId: deviceId,
    );

    // Set up retry executor
    _instance!._retryManager.setExecutor(_instance!._executeRetry);

    _instance!._isInitialized = true;

    // Fetch server settings
    await settingsService.fetchSettings();

    // Start processing pending retries
    if (enableOfflineQueue) {
      await retryManager.startProcessing();
    }

    // Schedule attachment cleanup
    if (captureFileAttachments) {
      _instance!._scheduleAttachmentCleanup();
    }

    if (debug) {
      print('[EndpointVault] Initialized successfully');
      print('[EndpointVault] Device ID: $deviceId');
      print('[EndpointVault] Environment: $environment');
      print('[EndpointVault] Local resend enabled: ${settingsService.localResendEnabled}');
      print('[EndpointVault] File attachments: ${captureFileAttachments ? "enabled" : "disabled"}');
    }

    return _instance!;
  }

  /// Schedule periodic cleanup of old attachment files.
  void _scheduleAttachmentCleanup() {
    // Run cleanup on init
    Future.microtask(() async {
      try {
        await _attachmentStorage?.cleanup(
          maxAge: config.attachmentRetentionDuration,
        );
      } catch (e) {
        if (config.debug) {
          print('[EndpointVault] Attachment cleanup failed: $e');
        }
      }
    });
  }

  /// Capture a failed request event.
  ///
  /// The [onReplaySuccess] callback is called when this request is successfully
  /// replayed (either via local resend or server-triggered replay). This is useful
  /// for workflows that depend on response data, such as:
  ///
  /// - Extracting file upload URLs from the response
  /// - Continuing multi-step operations after retry
  /// - Triggering dependent API calls
  ///
  /// Example usage for file upload workflows:
  /// ```dart
  /// EndpointVault.instance.captureFailure(
  ///   method: 'POST',
  ///   url: 'https://api.example.com/upload',
  ///   statusCode: 500,
  ///   errorType: 'server_error',
  ///   onReplaySuccess: (Response response) async {
  ///     // Extract upload URLs from the successful response
  ///     final uploadUrls = response.data['uploadUrls'] as List;
  ///     for (final url in uploadUrls) {
  ///       await uploadFileToUrl(url);
  ///     }
  ///   },
  /// );
  /// ```
  Future<void> captureFailure({
    required String method,
    required String url,
    required int? statusCode,
    String? errorType,
    String? errorMessage,
    Map<String, dynamic>? requestHeaders,
    dynamic requestBody,
    Map<String, dynamic>? responseHeaders,
    dynamic responseBody,
    Duration? duration,
    Map<String, dynamic>? extra,
    List<FileAttachment>? attachments,
    List<MapEntry<String, String>>? formFields,
    Future<void> Function(Response response)? onReplaySuccess,
  }) async {
    final eventId = const Uuid().v4();

    final eventData = EventData(
      eventId: eventId,
      timestamp: DateTime.now().toUtc(),
      method: method,
      url: url,
      statusCode: statusCode,
      errorType: errorType,
      errorMessage: errorMessage,
      requestHeaders: _redaction.redactHeaders(requestHeaders ?? {}),
      requestBody: _redaction.redactBody(requestBody),
      responseHeaders: responseHeaders,
      responseBody: responseBody,
      durationMs: duration?.inMilliseconds,
      environment: config.environment,
      appVersion: config.appVersion,
      deviceId: _deviceId,
      extra: extra,
      isSuccess: false,
      attachments: attachments,
      formFields: formFields,
    );

    // Store the replay success callback if provided
    if (onReplaySuccess != null) {
      _replaySuccessCallbacks[eventId] = onReplaySuccess;

      if (config.debug) {
        print('[EndpointVault] Stored replay success callback for event: $eventId');
      }
    }

    await _processEvent(eventData, isError: true);
  }

  /// Capture success stats (no payload, just metrics).
  Future<void> captureSuccess({
    required String method,
    required String url,
    required int statusCode,
    Duration? duration,
  }) async {
    if (!config.captureSuccessStats) return;

    final eventData = EventData(
      eventId: const Uuid().v4(),
      timestamp: DateTime.now().toUtc(),
      method: method,
      url: url,
      statusCode: statusCode,
      durationMs: duration?.inMilliseconds,
      environment: config.environment,
      appVersion: config.appVersion,
      deviceId: _deviceId,
      isSuccess: true,
    );

    await _processEvent(eventData, isError: false);
  }

  /// Process an event according to the new logic:
  /// - Success: send only statistical package
  /// - Error with normal status: send encrypted + statistical
  /// - If local resend enabled: also store unencrypted locally
  /// - If server unavailable: queue for retry
  Future<void> _processEvent(EventData eventData, {required bool isError}) async {
    final statisticalPackage = eventData.toStatisticalPackage();

    // For successful requests, only send stats
    if (!isError) {
      await _sendStatisticalPackage(statisticalPackage, eventData);
      return;
    }

    // For errors, prepare encrypted package
    final encryptedPackage = eventData.toEncryptedPackage(
      encryptFn: _encryption.encrypt,
    );

    // If local resend is enabled, store unencrypted data locally
    if (localResendEnabled) {
      final unencryptedPackage = eventData.toUnencryptedPackage();
      await _localStorage.store(unencryptedPackage);
    }

    // Try to send to server
    await _sendErrorPackages(
      statisticalPackage: statisticalPackage,
      encryptedPackage: encryptedPackage,
      eventData: eventData,
    );
  }

  /// Send only statistical package (for successful requests).
  Future<void> _sendStatisticalPackage(
    StatisticalPackage package,
    EventData eventData,
  ) async {
    try {
      final response = await _internalDio.post(
        '/v1/events/stats',
        data: package.toJson(),
      );

      final serverResponse = _parseResponse(response);
      await _handleRetryCommand(serverResponse, eventData, {PackageType.statistical});

      _notifyEventCaptured(eventData);

      if (config.debug) {
        print('[EndpointVault] Stats captured: ${eventData.method} ${eventData.url}');
      }
    } catch (e) {
      if (config.debug) {
        print('[EndpointVault] Failed to send stats: $e');
      }

      if (config.enableOfflineQueue) {
        await _queueForRetry(eventData, {PackageType.statistical});
      }
    }
  }

  /// Send error packages (encrypted + statistical).
  Future<void> _sendErrorPackages({
    required StatisticalPackage statisticalPackage,
    required EncryptedPackage encryptedPackage,
    required EventData eventData,
  }) async {
    try {
      // Send both encrypted and statistical data
      final payload = {
        'encrypted': encryptedPackage.toJson(),
        'stats': statisticalPackage.toJson(),
      };

      final response = await _internalDio.post(
        '/v1/events',
        data: payload,
      );

      final serverResponse = _parseResponse(response);
      await _handleRetryCommand(
        serverResponse,
        eventData,
        {PackageType.encrypted, PackageType.statistical},
      );

      // Upload attachments if present
      if (eventData.attachments != null && eventData.attachments!.isNotEmpty) {
        await _uploadAttachments(eventData.eventId, eventData.attachments!);
      }

      _notifyEventCaptured(eventData);

      if (config.debug) {
        print('[EndpointVault] Event captured: ${eventData.method} ${eventData.url}');
      }
    } catch (e) {
      if (config.debug) {
        print('[EndpointVault] Failed to send event: $e');
      }

      if (config.enableOfflineQueue) {
        await _queueForRetry(
          eventData,
          {PackageType.encrypted, PackageType.statistical},
        );
      }
    }
  }

  /// Upload attachments for an event.
  Future<void> _uploadAttachments(
    String eventId,
    List<FileAttachment> attachments,
  ) async {
    if (_attachmentStorage == null) return;

    for (final attachment in attachments) {
      try {
        // Read encrypted file data
        final encryptedData = await _attachmentStorage!.readEncryptedByPath(
          attachment.localPath,
        );

        // Upload to server
        await _internalDio.post(
          '/v1/events/attachments',
          data: {
            'eventId': eventId,
            'attachmentId': attachment.id,
            'fieldName': _encryption.encrypt(attachment.fieldName),
            'filename': _encryption.encrypt(attachment.filename),
            if (attachment.contentType != null)
              'contentType': _encryption.encrypt(attachment.contentType!),
            'sizeBytes': encryptedData.length,
            'checksumSha256': attachment.checksumSha256,
          },
        );

        // Upload the actual file data
        await _internalDio.post(
          '/v1/events/attachments/$eventId/${attachment.id}/data',
          data: encryptedData,
          options: Options(
            contentType: 'application/octet-stream',
          ),
        );

        // Delete local file after successful upload
        await _attachmentStorage!.deleteByPath(attachment.localPath);

        if (config.debug) {
          print('[EndpointVault] Attachment uploaded: ${attachment.id}');
        }
      } catch (e) {
        if (config.debug) {
          print('[EndpointVault] Failed to upload attachment ${attachment.id}: $e');
        }
        // Keep the file for retry
      }
    }
  }

  /// Queue an event for retry when server is unavailable.
  Future<void> _queueForRetry(
    EventData eventData,
    Set<PackageType> packagesToSend,
  ) async {
    final pendingRequest = PendingRequest(
      id: const Uuid().v4(),
      eventId: eventData.eventId,
      createdAt: DateTime.now(),
      statisticalPackage: eventData.toStatisticalPackage(),
      encryptedPackage: packagesToSend.contains(PackageType.encrypted)
          ? eventData.toEncryptedPackage(encryptFn: _encryption.encrypt)
          : null,
      unencryptedPackage: localResendEnabled ? eventData.toUnencryptedPackage() : null,
      packagesToSend: packagesToSend,
    );

    await _retryManager.addPendingRequest(pendingRequest);

    if (config.debug) {
      print('[EndpointVault] Event queued for retry: ${eventData.eventId}');
    }
  }

  /// Execute a retry for a pending request.
  Future<bool> _executeRetry(PendingRequest request) async {
    try {
      if (request.packagesToSend.contains(PackageType.encrypted) && request.encryptedPackage != null) {
        // Send error packages
        final payload = {
          'encrypted': request.encryptedPackage!.toJson(),
          if (request.statisticalPackage != null) 'stats': request.statisticalPackage!.toJson(),
        };

        final response = await _internalDio.post('/v1/events', data: payload);
        final serverResponse = _parseResponse(response);

        if (serverResponse.hasRetryCommand) {
          await _retryManager.handleRetryCommand(
            serverResponse.retryCommand!,
            request,
          );
          return false; // Will be retried with new parameters
        }

        // Upload any pending attachments
        final attachments = request.encryptedPackage!.attachments;
        if (attachments != null && attachments.isNotEmpty) {
          for (final attachment in attachments) {
            await _uploadAttachmentFromEncrypted(
              request.eventId,
              attachment,
            );
          }
        }

        return true;
      } else if (request.statisticalPackage != null) {
        // Send only stats
        final response = await _internalDio.post(
          '/v1/events/stats',
          data: request.statisticalPackage!.toJson(),
        );
        final serverResponse = _parseResponse(response);

        if (serverResponse.hasRetryCommand) {
          await _retryManager.handleRetryCommand(
            serverResponse.retryCommand!,
            request,
          );
          return false;
        }

        return true;
      }

      return true;
    } catch (e) {
      if (config.debug) {
        print('[EndpointVault] Retry failed: $e');
      }
      return false;
    }
  }

  /// Upload attachment from encrypted metadata (for retry).
  Future<void> _uploadAttachmentFromEncrypted(
    String eventId,
    EncryptedFileAttachment attachment,
  ) async {
    if (_attachmentStorage == null) return;

    try {
      // Check if file still exists
      if (!await _attachmentStorage!.existsByPath(attachment.localPath)) {
        if (config.debug) {
          print('[EndpointVault] Attachment file not found: ${attachment.id}');
        }
        return;
      }

      final encryptedData = await _attachmentStorage!.readEncryptedByPath(
        attachment.localPath,
      );

      await _internalDio.post(
        '/v1/events/attachments',
        data: {
          'eventId': eventId,
          'attachmentId': attachment.id,
          'fieldName': attachment.encryptedFieldName,
          'filename': attachment.encryptedFilename,
          if (attachment.encryptedContentType != null)
            'contentType': attachment.encryptedContentType,
          'sizeBytes': encryptedData.length,
          'checksumSha256': attachment.checksumSha256,
        },
      );

      await _internalDio.post(
        '/v1/events/attachments/$eventId/${attachment.id}/data',
        data: encryptedData,
        options: Options(
          contentType: 'application/octet-stream',
        ),
      );

      await _attachmentStorage!.deleteByPath(attachment.localPath);

      if (config.debug) {
        print('[EndpointVault] Attachment uploaded on retry: ${attachment.id}');
      }
    } catch (e) {
      if (config.debug) {
        print('[EndpointVault] Failed to upload attachment on retry: $e');
      }
    }
  }

  ServerResponse _parseResponse(Response response) {
    if (response.data is Map<String, dynamic>) {
      return ServerResponse.fromJson(response.data);
    }
    return const ServerResponse(success: true);
  }

  Future<void> _handleRetryCommand(
    ServerResponse response,
    EventData eventData,
    Set<PackageType> packagesToSend,
  ) async {
    if (!response.hasRetryCommand) return;

    final pendingRequest = PendingRequest(
      id: const Uuid().v4(),
      eventId: eventData.eventId,
      createdAt: DateTime.now(),
      retryId: response.retryCommand!.retryId,
      statisticalPackage: eventData.toStatisticalPackage(),
      encryptedPackage: packagesToSend.contains(PackageType.encrypted)
          ? eventData.toEncryptedPackage(encryptFn: _encryption.encrypt)
          : null,
      packagesToSend: packagesToSend,
    );

    await _retryManager.handleRetryCommand(
      response.retryCommand!,
      pendingRequest,
    );
  }

  void _notifyEventCaptured(EventData eventData) {
    if (_eventStreamController == null) return;

    // Convert to CapturedEvent for backward compatibility
    final event = CapturedEvent(
      id: eventData.eventId,
      timestamp: eventData.timestamp,
      method: eventData.method,
      url: eventData.url,
      statusCode: eventData.statusCode,
      errorType: eventData.errorType,
      errorMessage: eventData.errorMessage,
      requestHeaders: eventData.requestHeaders,
      requestBody: eventData.requestBody,
      responseHeaders: eventData.responseHeaders,
      responseBody: eventData.responseBody,
      durationMs: eventData.durationMs,
      environment: eventData.environment,
      appVersion: eventData.appVersion,
      deviceId: eventData.deviceId,
      extra: eventData.extra,
      isSuccess: eventData.isSuccess,
    );

    _eventStreamController!.add(event);
  }

  /// Stream of captured events (for debugging/monitoring).
  Stream<CapturedEvent> get eventStream {
    _eventStreamController ??= StreamController<CapturedEvent>.broadcast();
    return _eventStreamController!.stream;
  }

  /// Get locally stored event for replay (only available if local resend enabled).
  Future<UnencryptedPackage?> getLocalEvent(String eventId) async {
    if (!localResendEnabled) return null;
    return _localStorage.get(eventId);
  }

  /// Get all locally stored events.
  Future<List<UnencryptedPackage>> getLocalEvents() async {
    if (!localResendEnabled) return [];
    return _localStorage.getAll();
  }

  /// Remove a locally stored event after successful replay.
  Future<void> removeLocalEvent(String eventId) async {
    await _localStorage.remove(eventId);
  }

  /// Check if a replay request is pending for this device.
  Future<ReplayRequest?> checkForReplayRequest() async {
    try {
      final response = await _internalDio.get(
        '/v1/replay/pending',
        queryParameters: {'deviceId': _deviceId},
      );

      if (response.data != null && response.data['pending'] == true) {
        return ReplayRequest.fromJson(response.data['request']);
      }
    } catch (e) {
      if (config.debug) {
        print('[EndpointVault] Failed to check replay requests: $e');
      }
    }
    return null;
  }

  /// Report replay result back to server.
  Future<void> reportReplayResult({
    required String replayId,
    required bool success,
    int? statusCode,
    String? errorMessage,
  }) async {
    try {
      await _internalDio.post('/v1/replay/result', data: {
        'replayId': replayId,
        'deviceId': _deviceId,
        'success': success,
        'statusCode': statusCode,
        'errorMessage': errorMessage,
        'timestamp': DateTime.now().toUtc().toIso8601String(),
      });
    } catch (e) {
      if (config.debug) {
        print('[EndpointVault] Failed to report replay result: $e');
      }
    }
  }

  /// Execute a replay request using the stored local event data.
  ///
  /// This method:
  /// 1. Retrieves the original request data from local storage
  /// 2. Replays the request using the provided Dio instance
  /// 3. Reports the result to the EndpointVault server
  /// 4. Calls the [onReplaySuccess] callback if the replay succeeds
  ///
  /// The [dio] parameter should be your app's Dio instance (NOT EndpointVault's internal one)
  /// so that the replayed request goes through your normal interceptors and authentication.
  ///
  /// Returns `true` if the replay was successful, `false` otherwise.
  ///
  /// Example usage:
  /// ```dart
  /// // Check for pending replay requests
  /// final replayRequest = await EndpointVault.instance.checkForReplayRequest();
  /// if (replayRequest != null) {
  ///   final success = await EndpointVault.instance.executeReplay(
  ///     replayRequest: replayRequest,
  ///     dio: myAppDio,  // Your app's Dio instance
  ///   );
  ///   print('Replay ${success ? "succeeded" : "failed"}');
  /// }
  /// ```
  Future<bool> executeReplay({
    required ReplayRequest replayRequest,
    required Dio dio,
  }) async {
    try {
      // Get the original request data from local storage
      final localEvent = await getLocalEvent(replayRequest.eventId);
      if (localEvent == null) {
        if (config.debug) {
          print('[EndpointVault] Local event not found for replay: ${replayRequest.eventId}');
        }
        await reportReplayResult(
          replayId: replayRequest.id,
          success: false,
          errorMessage: 'Local event data not found',
        );
        return false;
      }

      // Prepare request options
      final options = Options(
        method: localEvent.method,
        headers: localEvent.requestHeaders?.map((k, v) => MapEntry(k, v.toString())),
        extra: {
          'ev_skip': true,  // Skip capturing this replay request
        },
      );

      // Execute the replay
      final response = await dio.request<dynamic>(
        localEvent.url,
        data: localEvent.requestBody,
        options: options,
      );

      // Report success to server
      await reportReplayResult(
        replayId: replayRequest.id,
        success: true,
        statusCode: response.statusCode,
      );

      // Remove the local event after successful replay
      await removeLocalEvent(replayRequest.eventId);

      // Call the stored replay success callback if available
      final callback = _replaySuccessCallbacks.remove(replayRequest.eventId);
      if (callback != null) {
        try {
          await callback(response);
          if (config.debug) {
            print('[EndpointVault] Replay success callback executed for event: ${replayRequest.eventId}');
          }
        } catch (e) {
          if (config.debug) {
            print('[EndpointVault] Replay success callback failed: $e');
          }
          // Don't fail the replay itself if callback fails
        }
      }

      if (config.debug) {
        print('[EndpointVault] Replay successful: ${replayRequest.method} ${replayRequest.url}');
      }

      return true;
    } on DioException catch (e) {
      // Report failure to server
      await reportReplayResult(
        replayId: replayRequest.id,
        success: false,
        statusCode: e.response?.statusCode,
        errorMessage: e.message,
      );

      if (config.debug) {
        print('[EndpointVault] Replay failed: ${e.message}');
      }

      return false;
    } catch (e) {
      // Report failure to server
      await reportReplayResult(
        replayId: replayRequest.id,
        success: false,
        errorMessage: e.toString(),
      );

      if (config.debug) {
        print('[EndpointVault] Replay failed: $e');
      }

      return false;
    }
  }

  /// Execute a replay using the original request data directly.
  ///
  /// Use this when you have the original request data available (e.g., from a local queue)
  /// and want to retry it with a callback on success.
  ///
  /// The [eventId] should match the ID used when capturing the failure.
  ///
  /// Example usage:
  /// ```dart
  /// // Get local event
  /// final event = await EndpointVault.instance.getLocalEvent(eventId);
  /// if (event != null) {
  ///   final success = await EndpointVault.instance.replayLocalEvent(
  ///     eventId: eventId,
  ///     dio: myAppDio,
  ///   );
  /// }
  /// ```
  Future<bool> replayLocalEvent({
    required String eventId,
    required Dio dio,
  }) async {
    final localEvent = await getLocalEvent(eventId);
    if (localEvent == null) {
      if (config.debug) {
        print('[EndpointVault] Local event not found: $eventId');
      }
      return false;
    }

    try {
      final options = Options(
        method: localEvent.method,
        headers: localEvent.requestHeaders?.map((k, v) => MapEntry(k, v.toString())),
        extra: {
          'ev_skip': true,  // Skip capturing this replay request
        },
      );

      final response = await dio.request<dynamic>(
        localEvent.url,
        data: localEvent.requestBody,
        options: options,
      );

      // Remove the local event after successful replay
      await removeLocalEvent(eventId);

      // Call the stored replay success callback if available
      final callback = _replaySuccessCallbacks.remove(eventId);
      if (callback != null) {
        try {
          await callback(response);
          if (config.debug) {
            print('[EndpointVault] Replay success callback executed for event: $eventId');
          }
        } catch (e) {
          if (config.debug) {
            print('[EndpointVault] Replay success callback failed: $e');
          }
        }
      }

      if (config.debug) {
        print('[EndpointVault] Local event replay successful: ${localEvent.method} ${localEvent.url}');
      }

      return true;
    } on DioException catch (e) {
      if (config.debug) {
        print('[EndpointVault] Local event replay failed: ${e.message}');
      }
      return false;
    } catch (e) {
      if (config.debug) {
        print('[EndpointVault] Local event replay failed: $e');
      }
      return false;
    }
  }

  /// Get the replay success callback for an event (if one was registered).
  ///
  /// This is useful if you want to manually execute the callback or check
  /// if a callback exists for a given event.
  Future<void> Function(Response response)? getReplaySuccessCallback(String eventId) {
    return _replaySuccessCallbacks[eventId];
  }

  /// Remove a replay success callback without executing it.
  ///
  /// Use this to clean up callbacks for events that will never be replayed.
  void removeReplaySuccessCallback(String eventId) {
    _replaySuccessCallbacks.remove(eventId);
  }

  /// Get the count of registered replay success callbacks.
  int get replaySuccessCallbackCount => _replaySuccessCallbacks.length;

  /// Refresh server settings.
  Future<void> refreshSettings() async {
    await _settingsService.fetchSettings();
  }

  /// Get pending retry count.
  Future<int> get pendingRetryCount => _retryManager.pendingCount;

  /// Get local event count.
  Future<int> get localEventCount => _localStorage.count;

  /// Get attachment storage usage in bytes.
  Future<int> get attachmentStorageBytes async {
    return await _attachmentStorage?.totalStorageBytes() ?? 0;
  }

  /// Run attachment cleanup manually.
  Future<int> cleanupAttachments({Duration? maxAge}) async {
    return await _attachmentStorage?.cleanup(
      maxAge: maxAge ?? config.attachmentRetentionDuration,
    ) ?? 0;
  }

  /// Dispose resources.
  void dispose() {
    _eventStreamController?.close();
    _retryManager.dispose();
    _localStorage.dispose();
    _internalDio.close();
    _replaySuccessCallbacks.clear();
  }
}

/// Replay request from EndpointVault server.
class ReplayRequest {
  final String id;
  final String eventId;
  final String method;
  final String url;
  final Map<String, dynamic>? headers;
  final dynamic body;
  final DateTime requestedAt;

  ReplayRequest({
    required this.id,
    required this.eventId,
    required this.method,
    required this.url,
    this.headers,
    this.body,
    required this.requestedAt,
  });

  factory ReplayRequest.fromJson(Map<String, dynamic> json) {
    return ReplayRequest(
      id: json['id'],
      eventId: json['eventId'],
      method: json['method'],
      url: json['url'],
      headers: json['headers'],
      body: json['body'],
      requestedAt: DateTime.parse(json['requestedAt']),
    );
  }
}
