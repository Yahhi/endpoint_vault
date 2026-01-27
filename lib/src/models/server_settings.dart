/// Server settings fetched from EndpointVault server.
/// 
/// These settings control client behavior and are fetched during initialization.
class ServerSettings {
  /// Whether local resend/replay functionality is enabled.
  /// When true, unencrypted data is stored locally for potential replay.
  final bool localResendEnabled;

  /// Raw settings map for future extensibility.
  final Map<String, dynamic> rawSettings;

  const ServerSettings({
    required this.localResendEnabled,
    required this.rawSettings,
  });

  factory ServerSettings.fromJson(Map<String, dynamic> json) {
    return ServerSettings(
      localResendEnabled: json['localResendEnabled'] ?? false,
      rawSettings: json,
    );
  }

  Map<String, dynamic> toJson() => {
        'localResendEnabled': localResendEnabled,
        ...rawSettings,
      };

  /// Default settings when server is unavailable.
  static const ServerSettings defaults = ServerSettings(
    localResendEnabled: false,
    rawSettings: {},
  );

  /// Get a setting value by key with optional default.
  T? getSetting<T>(String key, [T? defaultValue]) {
    return rawSettings[key] as T? ?? defaultValue;
  }

  ServerSettings copyWith({
    bool? localResendEnabled,
    Map<String, dynamic>? rawSettings,
  }) {
    return ServerSettings(
      localResendEnabled: localResendEnabled ?? this.localResendEnabled,
      rawSettings: rawSettings ?? this.rawSettings,
    );
  }
}
