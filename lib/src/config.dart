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

  /// Enable file attachment capture from FormData requests.
  ///
  /// When enabled, file attachments in FormData requests are captured
  /// before the request is sent, encrypted, and stored on the device.
  /// If the request fails, the encrypted files are included with the failure event.
  final bool captureFileAttachments;

  /// Maximum size for a single file attachment in bytes.
  /// Default is 50MB (52,428,800 bytes).
  final int maxAttachmentFileSize;

  /// Maximum total size of all attachments per event in bytes.
  /// Default is 100MB (104,857,600 bytes).
  final int maxTotalAttachmentSize;

  /// Maximum number of attachments per event.
  /// Default is 10.
  final int maxAttachmentsPerEvent;

  /// Custom directory for storing encrypted attachment files.
  ///
  /// If null, uses the application's documents directory with
  /// an 'endpoint_vault_attachments' subdirectory.
  final String? attachmentStorageDir;

  /// How long to retain attachment files on device before cleanup.
  /// Default is 7 days.
  final Duration attachmentRetentionDuration;

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
    this.captureFileAttachments = true,
    this.maxAttachmentFileSize = 52428800, // 50MB
    this.maxTotalAttachmentSize = 104857600, // 100MB
    this.maxAttachmentsPerEvent = 10,
    this.attachmentStorageDir,
    this.attachmentRetentionDuration = const Duration(days: 7),
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
    bool? captureFileAttachments,
    int? maxAttachmentFileSize,
    int? maxTotalAttachmentSize,
    int? maxAttachmentsPerEvent,
    String? attachmentStorageDir,
    Duration? attachmentRetentionDuration,
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
      captureFileAttachments:
          captureFileAttachments ?? this.captureFileAttachments,
      maxAttachmentFileSize:
          maxAttachmentFileSize ?? this.maxAttachmentFileSize,
      maxTotalAttachmentSize:
          maxTotalAttachmentSize ?? this.maxTotalAttachmentSize,
      maxAttachmentsPerEvent:
          maxAttachmentsPerEvent ?? this.maxAttachmentsPerEvent,
      attachmentStorageDir: attachmentStorageDir ?? this.attachmentStorageDir,
      attachmentRetentionDuration:
          attachmentRetentionDuration ?? this.attachmentRetentionDuration,
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
