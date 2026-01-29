import 'dart:convert';

import 'file_attachment.dart';

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

  /// Whether this event has file attachments.
  final bool hasAttachments;

  /// Number of file attachments.
  final int attachmentCount;

  /// Total size of all attachments in bytes.
  final int totalAttachmentBytes;

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
    this.hasAttachments = false,
    this.attachmentCount = 0,
    this.totalAttachmentBytes = 0,
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
        'hasAttachments': hasAttachments,
        'attachmentCount': attachmentCount,
        'totalAttachmentBytes': totalAttachmentBytes,
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
      hasAttachments: json['hasAttachments'] ?? false,
      attachmentCount: json['attachmentCount'] ?? 0,
      totalAttachmentBytes: json['totalAttachmentBytes'] ?? 0,
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

  /// Encrypted file attachment metadata.
  /// The actual file data is stored separately and uploaded via uploadAttachment.
  final List<EncryptedFileAttachment>? attachments;

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
    this.attachments,
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
        if (attachments != null && attachments!.isNotEmpty)
          'attachments': attachments!.map((a) => a.toJson()).toList(),
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
      attachments: json['attachments'] != null
          ? (json['attachments'] as List)
              .map((a) => EncryptedFileAttachment.fromJson(a))
              .toList()
          : null,
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

  /// File attachments with metadata and local file paths.
  /// Files are stored encrypted on the device file system.
  final List<FileAttachment>? attachments;

  /// Form fields extracted from FormData (non-file entries).
  /// Used for replay to reconstruct the original FormData.
  final List<Map<String, String>>? formFields;

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
    this.attachments,
    this.formFields,
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
        if (attachments != null && attachments!.isNotEmpty)
          'attachments': attachments!.map((a) => a.toJson()).toList(),
        if (formFields != null && formFields!.isNotEmpty)
          'formFields': formFields,
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
      attachments: json['attachments'] != null
          ? (json['attachments'] as List)
              .map((a) => FileAttachment.fromJson(a))
              .toList()
          : null,
      formFields: json['formFields'] != null
          ? (json['formFields'] as List)
              .map((f) => Map<String, String>.from(f))
              .toList()
          : null,
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

  /// File attachments captured from FormData.
  final List<FileAttachment>? attachments;

  /// Form fields extracted from FormData (non-file entries).
  final List<MapEntry<String, String>>? formFields;

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
    this.attachments,
    this.formFields,
  });

  StatisticalPackage toStatisticalPackage() {
    final hasAttachments = attachments != null && attachments!.isNotEmpty;
    final attachmentCount = attachments?.length ?? 0;
    final totalAttachmentBytes =
        attachments?.fold<int>(0, (sum, a) => sum + a.sizeBytes) ?? 0;

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
      hasAttachments: hasAttachments,
      attachmentCount: attachmentCount,
      totalAttachmentBytes: totalAttachmentBytes,
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
      attachments: attachments,
      formFields: formFields
          ?.map((e) => {'key': e.key, 'value': e.value})
          .toList(),
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

    // Encrypt attachment metadata (not the file data, which is stored separately)
    List<EncryptedFileAttachment>? encryptedAttachments;
    if (attachments != null && attachments!.isNotEmpty) {
      encryptedAttachments = attachments!.map((a) {
        return EncryptedFileAttachment(
          id: a.id,
          encryptedFieldName: encryptFn(a.fieldName),
          encryptedFilename: encryptFn(a.filename),
          encryptedContentType:
              a.contentType != null ? encryptFn(a.contentType!) : null,
          sizeBytes: a.sizeBytes,
          checksumSha256: a.checksumSha256,
          localPath: a.localPath,
        );
      }).toList();
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
      attachments: encryptedAttachments,
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
        if (attachments != null && attachments!.isNotEmpty)
          'attachments': attachments!.map((a) => a.toJson()).toList(),
        if (formFields != null && formFields!.isNotEmpty)
          'formFields': formFields!
              .map((e) => {'key': e.key, 'value': e.value})
              .toList(),
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
      attachments: json['attachments'] != null
          ? (json['attachments'] as List)
              .map((a) => FileAttachment.fromJson(a))
              .toList()
          : null,
      formFields: json['formFields'] != null
          ? (json['formFields'] as List)
              .map((f) => MapEntry<String, String>(f['key'], f['value']))
              .toList()
          : null,
    );
  }

  /// Create a copy with updated attachments.
  EventData copyWithAttachments({
    List<FileAttachment>? attachments,
    List<MapEntry<String, String>>? formFields,
  }) {
    return EventData(
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
      isSuccess: isSuccess,
      attachments: attachments ?? this.attachments,
      formFields: formFields ?? this.formFields,
    );
  }
}
