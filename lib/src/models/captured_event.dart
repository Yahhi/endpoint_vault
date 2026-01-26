/// Represents a captured API event (failure or success).
class CapturedEvent {
  /// Unique event ID.
  final String id;

  /// Timestamp when the event was captured.
  final DateTime timestamp;

  /// HTTP method (GET, POST, PUT, DELETE, etc.).
  final String method;

  /// Full request URL.
  final String url;

  /// HTTP status code (null for network errors).
  final int? statusCode;

  /// Error type (e.g., 'connection_timeout', 'bad_response').
  final String? errorType;

  /// Error message.
  final String? errorMessage;

  /// Request headers (redacted).
  final Map<String, dynamic>? requestHeaders;

  /// Request body (redacted).
  final dynamic requestBody;

  /// Response headers.
  final Map<String, dynamic>? responseHeaders;

  /// Response body.
  final dynamic responseBody;

  /// Request duration in milliseconds.
  final int? durationMs;

  /// Environment (e.g., 'production', 'staging').
  final String? environment;

  /// App version.
  final String? appVersion;

  /// Device ID for replay coordination.
  final String? deviceId;

  /// Additional context/metadata.
  final Map<String, dynamic>? extra;

  /// Whether this is a success event (stats only).
  final bool isSuccess;

  CapturedEvent({
    required this.id,
    required this.timestamp,
    required this.method,
    required this.url,
    this.statusCode,
    this.errorType,
    this.errorMessage,
    this.requestHeaders,
    this.requestBody,
    this.responseHeaders,
    this.responseBody,
    this.durationMs,
    this.environment,
    this.appVersion,
    this.deviceId,
    this.extra,
    this.isSuccess = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'timestamp': timestamp.toIso8601String(),
      'method': method,
      'url': url,
      if (statusCode != null) 'statusCode': statusCode,
      if (errorType != null) 'errorType': errorType,
      if (errorMessage != null) 'errorMessage': errorMessage,
      if (requestHeaders != null) 'requestHeaders': requestHeaders,
      if (requestBody != null) 'requestBody': requestBody,
      if (responseHeaders != null) 'responseHeaders': responseHeaders,
      if (responseBody != null) 'responseBody': responseBody,
      if (durationMs != null) 'durationMs': durationMs,
      if (environment != null) 'environment': environment,
      if (appVersion != null) 'appVersion': appVersion,
      if (deviceId != null) 'deviceId': deviceId,
      if (extra != null) 'extra': extra,
      'isSuccess': isSuccess,
    };
  }

  factory CapturedEvent.fromJson(Map<String, dynamic> json) {
    return CapturedEvent(
      id: json['id'],
      timestamp: DateTime.parse(json['timestamp']),
      method: json['method'],
      url: json['url'],
      statusCode: json['statusCode'],
      errorType: json['errorType'],
      errorMessage: json['errorMessage'],
      requestHeaders: json['requestHeaders'],
      requestBody: json['requestBody'],
      responseHeaders: json['responseHeaders'],
      responseBody: json['responseBody'],
      durationMs: json['durationMs'],
      environment: json['environment'],
      appVersion: json['appVersion'],
      deviceId: json['deviceId'],
      extra: json['extra'],
      isSuccess: json['isSuccess'] ?? false,
    );
  }

  @override
  String toString() {
    return 'CapturedEvent(id: $id, method: $method, url: $url, statusCode: $statusCode)';
  }
}
