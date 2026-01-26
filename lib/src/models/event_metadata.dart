/// Metadata for captured events.
class EventMetadata {
  /// User ID (if available and consented).
  final String? userId;

  /// Session ID.
  final String? sessionId;

  /// Device model.
  final String? deviceModel;

  /// Operating system.
  final String? osVersion;

  /// Network type (wifi, cellular, etc.).
  final String? networkType;

  /// Geographic region (if available).
  final String? region;

  /// Custom tags for filtering.
  final Map<String, String>? tags;

  EventMetadata({
    this.userId,
    this.sessionId,
    this.deviceModel,
    this.osVersion,
    this.networkType,
    this.region,
    this.tags,
  });

  Map<String, dynamic> toJson() {
    return {
      if (userId != null) 'userId': userId,
      if (sessionId != null) 'sessionId': sessionId,
      if (deviceModel != null) 'deviceModel': deviceModel,
      if (osVersion != null) 'osVersion': osVersion,
      if (networkType != null) 'networkType': networkType,
      if (region != null) 'region': region,
      if (tags != null) 'tags': tags,
    };
  }

  factory EventMetadata.fromJson(Map<String, dynamic> json) {
    return EventMetadata(
      userId: json['userId'],
      sessionId: json['sessionId'],
      deviceModel: json['deviceModel'],
      osVersion: json['osVersion'],
      networkType: json['networkType'],
      region: json['region'],
      tags: json['tags'] != null
          ? Map<String, String>.from(json['tags'])
          : null,
    );
  }
}

/// Endpoint statistics from the dashboard.
class EndpointStats {
  /// Endpoint route pattern.
  final String route;

  /// HTTP method.
  final String method;

  /// Total request count.
  final int totalRequests;

  /// Failed request count.
  final int failedRequests;

  /// Error rate (0.0 - 1.0).
  final double errorRate;

  /// Average duration in milliseconds.
  final double avgDurationMs;

  /// P95 duration in milliseconds.
  final double? p95DurationMs;

  /// Status code distribution.
  final Map<int, int> statusCodeDistribution;

  /// Error type distribution.
  final Map<String, int> errorTypeDistribution;

  /// Time period for these stats.
  final Duration timePeriod;

  EndpointStats({
    required this.route,
    required this.method,
    required this.totalRequests,
    required this.failedRequests,
    required this.errorRate,
    required this.avgDurationMs,
    this.p95DurationMs,
    required this.statusCodeDistribution,
    required this.errorTypeDistribution,
    required this.timePeriod,
  });

  factory EndpointStats.fromJson(Map<String, dynamic> json) {
    return EndpointStats(
      route: json['route'],
      method: json['method'],
      totalRequests: json['totalRequests'],
      failedRequests: json['failedRequests'],
      errorRate: (json['errorRate'] as num).toDouble(),
      avgDurationMs: (json['avgDurationMs'] as num).toDouble(),
      p95DurationMs: json['p95DurationMs'] != null
          ? (json['p95DurationMs'] as num).toDouble()
          : null,
      statusCodeDistribution: Map<int, int>.from(
        (json['statusCodeDistribution'] as Map).map(
          (k, v) => MapEntry(int.parse(k.toString()), v as int),
        ),
      ),
      errorTypeDistribution: Map<String, int>.from(json['errorTypeDistribution']),
      timePeriod: Duration(seconds: json['timePeriodSeconds']),
    );
  }
}
