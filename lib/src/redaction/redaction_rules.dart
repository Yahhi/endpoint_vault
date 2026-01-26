import '../config.dart';

/// Service for redacting sensitive data from requests.
class RedactionService {
  final RedactionConfig config;

  /// The placeholder text used for redacted values.
  static const String redactedPlaceholder = '[REDACTED]';

  RedactionService(this.config);

  /// Redact sensitive headers.
  Map<String, dynamic> redactHeaders(Map<String, dynamic> headers) {
    final result = <String, dynamic>{};

    for (final entry in headers.entries) {
      final keyLower = entry.key.toLowerCase();

      // Check if this header should be redacted
      if (config.redactAuthorizationHeader &&
          keyLower == 'authorization') {
        result[entry.key] = redactedPlaceholder;
      } else if (config.redactHeaders.any(
        (h) => h.toLowerCase() == keyLower,
      )) {
        result[entry.key] = redactedPlaceholder;
      } else {
        result[entry.key] = entry.value;
      }
    }

    return result;
  }

  /// Redact sensitive fields from request body.
  dynamic redactBody(dynamic body) {
    if (body == null) return null;

    if (body is Map) {
      return _redactMap(Map<String, dynamic>.from(body));
    }

    if (body is List) {
      return body.map((item) => redactBody(item)).toList();
    }

    if (body is String) {
      // Apply custom patterns
      var result = body;
      for (final pattern in config.customPatterns) {
        result = result.replaceAll(pattern, redactedPlaceholder);
      }
      return result;
    }

    return body;
  }

  Map<String, dynamic> _redactMap(Map<String, dynamic> map) {
    final result = <String, dynamic>{};

    for (final entry in map.entries) {
      final key = entry.key;
      final value = entry.value;

      // Check if this field should be redacted
      if (_shouldRedactField(key)) {
        result[key] = redactedPlaceholder;
      } else if (value is Map) {
        result[key] = _redactMap(Map<String, dynamic>.from(value));
      } else if (value is List) {
        result[key] = value.map((item) => redactBody(item)).toList();
      } else if (value is String) {
        result[key] = _redactString(value);
      } else {
        result[key] = value;
      }
    }

    return result;
  }

  bool _shouldRedactField(String fieldName) {
    final fieldLower = fieldName.toLowerCase();
    return config.redactBodyFields.any((f) => f.toLowerCase() == fieldLower);
  }

  String _redactString(String value) {
    var result = value;
    for (final pattern in config.customPatterns) {
      result = result.replaceAll(pattern, redactedPlaceholder);
    }
    return result;
  }

  /// Redact query parameters from URL.
  String redactUrl(String url) {
    final uri = Uri.parse(url);
    if (uri.queryParameters.isEmpty) return url;

    final redactedParams = <String, String>{};
    for (final entry in uri.queryParameters.entries) {
      if (config.redactQueryParams.any(
        (p) => p.toLowerCase() == entry.key.toLowerCase(),
      )) {
        redactedParams[entry.key] = redactedPlaceholder;
      } else {
        redactedParams[entry.key] = entry.value;
      }
    }

    return uri.replace(queryParameters: redactedParams).toString();
  }
}

/// Predefined redaction patterns for common sensitive data.
class RedactionPatterns {
  /// Credit card number pattern (basic).
  static final creditCard = RegExp(r'\b\d{4}[\s-]?\d{4}[\s-]?\d{4}[\s-]?\d{4}\b');

  /// Email address pattern.
  static final email = RegExp(r'\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b');

  /// Phone number pattern (basic international).
  static final phone = RegExp(r'\b\+?[\d\s-]{10,}\b');

  /// SSN pattern (US).
  static final ssn = RegExp(r'\b\d{3}-\d{2}-\d{4}\b');

  /// JWT token pattern.
  static final jwt = RegExp(r'eyJ[A-Za-z0-9-_]+\.eyJ[A-Za-z0-9-_]+\.[A-Za-z0-9-_]+');

  /// Bearer token pattern.
  static final bearerToken = RegExp(r'Bearer\s+[A-Za-z0-9-_]+');

  /// API key pattern (generic).
  static final apiKey = RegExp(r'\b[A-Za-z0-9]{32,}\b');
}
