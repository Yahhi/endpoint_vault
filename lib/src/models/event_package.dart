import 'dart:convert';

/// Statistical data package - minimal metrics only, no sensitive data.
class StatisticalPackage {
  final String eventId;
  final DateTime timestamp;
  final String method;
  final String url;
  final int? statusCode;
  final int? durationMs;
  final String? environment;
  final String? appVersion;
  final String? deviceId;
  final bool isSuccess;
  final String? errorType;

  const StatisticalPackage({
    required this.eventId,
    required this.timestamp,
    required this.method,
    required this.url,
    this.statusCode,
    this.durationMs,
    this.environment,
    this.appVersion,
    this.deviceId,
    this.isSuccess = false,
    this.errorType,
  });

  Map<String, dynamic> toJson() => {
        'eventId': eventId,
        'timestamp': timestamp.toIso8601String(),
        'method': method,
        'url': url,
        if (statusCode != null) 'statusCode': statusCode,
        if (durationMs != null) 'durationMs': durationMs,
        if (environment != null) 'environment': environment,
        if (appVersion != null) 'appVersion': appVersion,
        if (deviceId != null) 'deviceId': deviceId,
        'isSuccess': isSuccess,
        if (errorType != null) 'errorType': errorType,
      };

  factory StatisticalPackage.fromJson(Map<String, dynamic> json) {
    return StatisticalPackage(
      eventId: json['eventId'],
      timestamp: DateTime.parse(json['timestamp']),
      method: json['method'],
      url: json['url'],
      statusCode: json['statusCode'],
      durationMs: json['durationMs'],
      environment: json['environment'],
      appVersion: json['appVersion'],
      deviceId: json['deviceId'],
      isSuccess: json['isSuccess'] ?? false,
      errorType: json['errorType'],
    );
  }
}

/// Encrypted package - contains encrypted request/response bodies.
class EncryptedPackage {
  final String eventId;
  final DateTime timestamp;
  final String method;
  final String url;
  final int? statusCode;
  final String? errorType;
  final String? errorMessage;
  final String? encryptedRequestHeaders;
  final String? encryptedRequestBody;
  final String? encryptedResponseHeaders;
  final String? encryptedResponseBody;
  final int? durationMs;
  final String? environment;
  final String? appVersion;
  final String? deviceId;
  final Map<String, dynamic>? extra;

  const EncryptedPackage({
    required this.eventId,
    required this.timestamp,
    required this.method,
    required this.url,
    this.statusCode,
    this.errorType,
    this.errorMessage,
    this.encryptedRequestHeaders,
    this.encryptedRequestBody,
    this.encryptedResponseHeaders,
    this.encryptedResponseBody,
    this.durationMs,
    this.environment,
    this.appVersion,
    this.deviceId,
    this.extra,
  });

  Map<String, dynamic> toJson() => {
        'eventId': eventId,
        'timestamp': timestamp.toIso8601String(),
        'method': method,
        'url': url,
        'encrypted': true,
        if (statusCode != null) 'statusCode': statusCode,
        if (errorType != null) 'errorType': errorType,
        if (errorMessage != null) 'errorMessage': errorMessage,
        if (encryptedRequestHeaders != null)
          'requestHeaders': encryptedRequestHeaders,
        if (encryptedRequestBody != null) 'requestBody': encryptedRequestBody,
        if (encryptedResponseHeaders != null)
          'responseHeaders': encryptedResponseHeaders,
        if (encryptedResponseBody != null)
          'responseBody': encryptedResponseBody,
        if (durationMs != null) 'durationMs': durationMs,
        if (environment != null) 'environment': environment,
        if (appVersion != null) 'appVersion': appVersion,
        if (deviceId != null) 'deviceId': deviceId,
        if (extra != null) 'extra': extra,
      };

  factory EncryptedPackage.fromJson(Map<String, dynamic> json) {
    return EncryptedPackage(
      eventId: json['eventId'],
      timestamp: DateTime.parse(json['timestamp']),
      method: json['method'],
      url: json['url'],
      statusCode: json['statusCode'],
      errorType: json['errorType'],
      errorMessage: json['errorMessage'],
      encryptedRequestHeaders: json['requestHeaders'],
      encryptedRequestBody: json['requestBody'],
      encryptedResponseHeaders: json['responseHeaders'],
      encryptedResponseBody: json['responseBody'],
      durationMs: json['durationMs'],
      environment: json['environment'],
      appVersion: json['appVersion'],
      deviceId: json['deviceId'],
      extra: json['extra'],
    );
  }
}

/// Unencrypted complete package - stored locally only when local resend is enabled.
class UnencryptedPackage {
  final String eventId;
  final DateTime timestamp;
  final String method;
  final String url;
  final int? statusCode;
  final String? errorType;
  final String? errorMessage;
  final Map<String, dynamic>? requestHeaders;
  final dynamic requestBody;
  final Map<String, dynamic>? responseHeaders;
  final dynamic responseBody;
  final int? durationMs;
  final String? environment;
  final String? appVersion;
  final String? deviceId;
  final Map<String, dynamic>? extra;

  const UnencryptedPackage({
    required this.eventId,
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
  });

  Map<String, dynamic> toJson() => {
        'eventId': eventId,
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
      };

  factory UnencryptedPackage.fromJson(Map<String, dynamic> json) {
    return UnencryptedPackage(
      eventId: json['eventId'],
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
    );
  }
}

/// Combined event data that can produce all three package types.
class EventData {
  final String eventId;
  final DateTime timestamp;
  final String method;
  final String url;
  final int? statusCode;
  final String? errorType;
  final String? errorMessage;
  final Map<String, dynamic>? requestHeaders;
  final dynamic requestBody;
  final Map<String, dynamic>? responseHeaders;
  final dynamic responseBody;
  final int? durationMs;
  final String? environment;
  final String? appVersion;
  final String? deviceId;
  final Map<String, dynamic>? extra;
  final bool isSuccess;

  const EventData({
    required this.eventId,
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

  StatisticalPackage toStatisticalPackage() {
    return StatisticalPackage(
      eventId: eventId,
      timestamp: timestamp,
      method: method,
      url: url,
      statusCode: statusCode,
      durationMs: durationMs,
      environment: environment,
      appVersion: appVersion,
      deviceId: deviceId,
      isSuccess: isSuccess,
      errorType: errorType,
    );
  }

  UnencryptedPackage toUnencryptedPackage() {
    return UnencryptedPackage(
      eventId: eventId,
      timestamp: timestamp,
      method: method,
      url: url,
      statusCode: statusCode,
      errorType: errorType,
      errorMessage: errorMessage,
      requestHeaders: requestHeaders,
      requestBody: requestBody,
      responseHeaders: responseHeaders,
      responseBody: responseBody,
      durationMs: durationMs,
      environment: environment,
      appVersion: appVersion,
      deviceId: deviceId,
      extra: extra,
    );
  }

  EncryptedPackage toEncryptedPackage({
    required String Function(String) encryptFn,
  }) {
    String? encryptIfNotNull(dynamic value) {
      if (value == null) return null;
      final str = value is String ? value : jsonEncode(value);
      return encryptFn(str);
    }

    return EncryptedPackage(
      eventId: eventId,
      timestamp: timestamp,
      method: method,
      url: url,
      statusCode: statusCode,
      errorType: errorType,
      errorMessage: errorMessage,
      encryptedRequestHeaders: encryptIfNotNull(requestHeaders),
      encryptedRequestBody: encryptIfNotNull(requestBody),
      encryptedResponseHeaders: encryptIfNotNull(responseHeaders),
      encryptedResponseBody: encryptIfNotNull(responseBody),
      durationMs: durationMs,
      environment: environment,
      appVersion: appVersion,
      deviceId: deviceId,
      extra: extra,
    );
  }

  Map<String, dynamic> toJson() => {
        'eventId': eventId,
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

  factory EventData.fromJson(Map<String, dynamic> json) {
    return EventData(
      eventId: json['eventId'],
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
}
