/// Retry command that can be included in any server response.
class RetryCommand {
  /// Unique identifier for this retry command.
  final String retryId;

  /// The type of command to retry (e.g., 'send_event', 'send_stats').
  final String commandType;

  /// Delay in milliseconds before retrying.
  final int delayMs;

  /// Maximum number of retry attempts.
  final int maxAttempts;

  /// Additional parameters for the retry.
  final Map<String, dynamic>? parameters;

  const RetryCommand({
    required this.retryId,
    required this.commandType,
    this.delayMs = 5000,
    this.maxAttempts = 3,
    this.parameters,
  });

  factory RetryCommand.fromJson(Map<String, dynamic> json) {
    return RetryCommand(
      retryId: json['retryId'],
      commandType: json['commandType'],
      delayMs: json['delayMs'] ?? 5000,
      maxAttempts: json['maxAttempts'] ?? 3,
      parameters: json['parameters'],
    );
  }

  Map<String, dynamic> toJson() => {
        'retryId': retryId,
        'commandType': commandType,
        'delayMs': delayMs,
        'maxAttempts': maxAttempts,
        if (parameters != null) 'parameters': parameters,
      };
}

/// Parsed server response that may contain retry commands.
class ServerResponse {
  /// Whether the request was successful.
  final bool success;

  /// Optional message from server.
  final String? message;

  /// Retry command if server requests a retry.
  final RetryCommand? retryCommand;

  /// Raw response data.
  final Map<String, dynamic>? data;

  const ServerResponse({
    required this.success,
    this.message,
    this.retryCommand,
    this.data,
  });

  factory ServerResponse.fromJson(Map<String, dynamic> json) {
    return ServerResponse(
      success: json['success'] ?? true,
      message: json['message'],
      retryCommand: json['retry'] != null
          ? RetryCommand.fromJson(json['retry'])
          : null,
      data: json,
    );
  }

  bool get hasRetryCommand => retryCommand != null;
}
