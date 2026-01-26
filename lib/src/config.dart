/// Configuration options for EndpointVault SDK.
class EndpointVaultConfig {
  /// Your EndpointVault API key from the dashboard.
  final String apiKey;

  /// Your encryption key for payload encryption.
  /// Must be 32 characters (256-bit AES).
  final String encryptionKey;

  /// Project ID (optional, derived from API key if not provided).
  final String? projectId;

  /// EndpointVault server URL.
  /// Defaults to hosted service. Set for self-hosted deployments.
  final String serverUrl;

  /// Environment name (e.g., 'production', 'staging', 'development').
  final String environment;

  /// App version for regression tracking.
  final String? appVersion;

  /// Whether to capture successful requests (for stats only, no payload).
  final bool captureSuccessStats;

  /// Whether to enable offline queue for failed uploads.
  final bool enableOfflineQueue;

  /// Maximum offline queue size.
  final int maxOfflineQueueSize;

  /// Custom redaction rules.
  final RedactionConfig redaction;

  /// Retry configuration for failed uploads.
  final RetryConfig retry;

  /// Debug mode - logs to console.
  final bool debug;

  const EndpointVaultConfig({
    required this.apiKey,
    required this.encryptionKey,
    this.projectId,
    this.serverUrl = 'https://api.endpoint.yahhi.me',
    this.environment = 'production',
    this.appVersion,
    this.captureSuccessStats = true,
    this.enableOfflineQueue = true,
    this.maxOfflineQueueSize = 100,
    this.redaction = const RedactionConfig(),
    this.retry = const RetryConfig(),
    this.debug = false,
  });

  EndpointVaultConfig copyWith({
    String? apiKey,
    String? encryptionKey,
    String? projectId,
    String? serverUrl,
    String? environment,
    String? appVersion,
    bool? captureSuccessStats,
    bool? enableOfflineQueue,
    int? maxOfflineQueueSize,
    RedactionConfig? redaction,
    RetryConfig? retry,
    bool? debug,
  }) {
    return EndpointVaultConfig(
      apiKey: apiKey ?? this.apiKey,
      encryptionKey: encryptionKey ?? this.encryptionKey,
      projectId: projectId ?? this.projectId,
      serverUrl: serverUrl ?? this.serverUrl,
      environment: environment ?? this.environment,
      appVersion: appVersion ?? this.appVersion,
      captureSuccessStats: captureSuccessStats ?? this.captureSuccessStats,
      enableOfflineQueue: enableOfflineQueue ?? this.enableOfflineQueue,
      maxOfflineQueueSize: maxOfflineQueueSize ?? this.maxOfflineQueueSize,
      redaction: redaction ?? this.redaction,
      retry: retry ?? this.retry,
      debug: debug ?? this.debug,
    );
  }
}

/// Configuration for automatic field redaction.
class RedactionConfig {
  /// Header keys to redact (case-insensitive).
  final List<String> redactHeaders;

  /// Body field keys to redact (supports nested paths like 'user.password').
  final List<String> redactBodyFields;

  /// Query parameter keys to redact.
  final List<String> redactQueryParams;

  /// Whether to redact all Authorization headers.
  final bool redactAuthorizationHeader;

  /// Custom redaction patterns (regex).
  final List<RegExp> customPatterns;

  const RedactionConfig({
    this.redactHeaders = const [
      'authorization',
      'x-api-key',
      'x-auth-token',
      'cookie',
      'set-cookie',
    ],
    this.redactBodyFields = const [
      'password',
      'token',
      'refresh_token',
      'access_token',
      'secret',
      'api_key',
      'apiKey',
      'credit_card',
      'creditCard',
      'cvv',
      'ssn',
    ],
    this.redactQueryParams = const [
      'token',
      'key',
      'api_key',
      'secret',
    ],
    this.redactAuthorizationHeader = true,
    this.customPatterns = const [],
  });
}

/// Configuration for retry behavior.
class RetryConfig {
  /// Maximum number of retry attempts.
  final int maxRetries;

  /// Initial delay between retries (exponential backoff).
  final Duration initialDelay;

  /// Maximum delay between retries.
  final Duration maxDelay;

  const RetryConfig({
    this.maxRetries = 3,
    this.initialDelay = const Duration(seconds: 1),
    this.maxDelay = const Duration(seconds: 30),
  });
}
