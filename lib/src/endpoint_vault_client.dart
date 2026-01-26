import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'config.dart';
import 'models/captured_event.dart';
import 'encryption/encryption_service.dart';
import 'redaction/redaction_rules.dart';
import 'storage/offline_queue.dart';

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
  final OfflineQueue _offlineQueue;
  final Dio _internalDio;
  final String _deviceId;

  bool _isInitialized = false;
  StreamController<CapturedEvent>? _eventStreamController;

  EndpointVault._({
    required this.config,
    required EncryptionService encryption,
    required RedactionService redaction,
    required OfflineQueue offlineQueue,
    required Dio internalDio,
    required String deviceId,
  })  : _encryption = encryption,
        _redaction = redaction,
        _offlineQueue = offlineQueue,
        _internalDio = internalDio,
        _deviceId = deviceId;

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
    );

    // Initialize services
    final encryption = EncryptionService(encryptionKey);
    final redactionService = RedactionService(redaction);
    final offlineQueue = OfflineQueue(maxOfflineQueueSize);

    // Get or create device ID
    final prefs = await SharedPreferences.getInstance();
    var deviceId = prefs.getString('endpoint_vault_device_id');
    if (deviceId == null) {
      deviceId = const Uuid().v4();
      await prefs.setString('endpoint_vault_device_id', deviceId);
    }

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

    _instance = EndpointVault._(
      config: config,
      encryption: encryption,
      redaction: redactionService,
      offlineQueue: offlineQueue,
      internalDio: internalDio,
      deviceId: deviceId,
    );

    _instance!._isInitialized = true;

    // Process offline queue
    if (enableOfflineQueue) {
      await _instance!._processOfflineQueue();
    }

    if (debug) {
      print('[EndpointVault] Initialized successfully');
      print('[EndpointVault] Device ID: $deviceId');
      print('[EndpointVault] Environment: $environment');
    }

    return _instance!;
  }

  /// Capture a failed request event.
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
  }) async {
    final event = CapturedEvent(
      id: const Uuid().v4(),
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
    );

    await _sendEvent(event, encrypt: true);
  }

  /// Capture success stats (no payload, just metrics).
  Future<void> captureSuccess({
    required String method,
    required String url,
    required int statusCode,
    Duration? duration,
  }) async {
    if (!config.captureSuccessStats) return;

    final event = CapturedEvent(
      id: const Uuid().v4(),
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

    await _sendEvent(event, encrypt: false);
  }

  /// Send event to EndpointVault server.
  Future<void> _sendEvent(CapturedEvent event, {required bool encrypt}) async {
    try {
      Map<String, dynamic> payload = event.toJson();

      if (encrypt && event.requestBody != null) {
        payload['requestBody'] = _encryption.encrypt(
          jsonEncode(event.requestBody),
        );
        payload['encrypted'] = true;
      }

      if (encrypt && event.responseBody != null) {
        payload['responseBody'] = _encryption.encrypt(
          jsonEncode(event.responseBody),
        );
      }

      await _internalDio.post('/v1/events', data: payload);

      _eventStreamController?.add(event);

      if (config.debug) {
        print('[EndpointVault] Event captured: ${event.method} ${event.url}');
      }
    } catch (e) {
      if (config.debug) {
        print('[EndpointVault] Failed to send event: $e');
      }

      if (config.enableOfflineQueue) {
        await _offlineQueue.add(event);
        if (config.debug) {
          print('[EndpointVault] Event queued for later');
        }
      }
    }
  }

  /// Process queued events from offline storage.
  Future<void> _processOfflineQueue() async {
    final events = await _offlineQueue.getAll();
    if (events.isEmpty) return;

    if (config.debug) {
      print('[EndpointVault] Processing ${events.length} queued events');
    }

    for (final event in events) {
      try {
        await _sendEvent(event, encrypt: true);
        await _offlineQueue.remove(event.id);
      } catch (e) {
        // Keep in queue for next attempt
        break;
      }
    }
  }

  /// Stream of captured events (for debugging/monitoring).
  Stream<CapturedEvent> get eventStream {
    _eventStreamController ??= StreamController<CapturedEvent>.broadcast();
    return _eventStreamController!.stream;
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

  /// Dispose resources.
  void dispose() {
    _eventStreamController?.close();
    _internalDio.close();
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
