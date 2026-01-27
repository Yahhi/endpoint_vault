import 'event_package.dart';

/// Type of package being stored for retry.
enum PackageType {
  statistical,
  encrypted,
  unencrypted,
}

/// A pending request that needs to be sent to the server.
/// Stores the data that was intended to be sent when the request failed.
class PendingRequest {
  /// Unique identifier for this pending request.
  final String id;

  /// The event ID this request is associated with.
  final String eventId;

  /// When this request was originally created.
  final DateTime createdAt;

  /// Number of retry attempts made.
  final int attemptCount;

  /// Retry command identifier if this was triggered by server.
  final String? retryId;

  /// Statistical package (always present).
  final StatisticalPackage? statisticalPackage;

  /// Encrypted package (present for failures/errors).
  final EncryptedPackage? encryptedPackage;

  /// Unencrypted package (only when local resend is enabled).
  final UnencryptedPackage? unencryptedPackage;

  /// What packages should be sent.
  final Set<PackageType> packagesToSend;

  const PendingRequest({
    required this.id,
    required this.eventId,
    required this.createdAt,
    this.attemptCount = 0,
    this.retryId,
    this.statisticalPackage,
    this.encryptedPackage,
    this.unencryptedPackage,
    required this.packagesToSend,
  });

  PendingRequest copyWith({
    int? attemptCount,
    String? retryId,
    Set<PackageType>? packagesToSend,
  }) {
    return PendingRequest(
      id: id,
      eventId: eventId,
      createdAt: createdAt,
      attemptCount: attemptCount ?? this.attemptCount,
      retryId: retryId ?? this.retryId,
      statisticalPackage: statisticalPackage,
      encryptedPackage: encryptedPackage,
      unencryptedPackage: unencryptedPackage,
      packagesToSend: packagesToSend ?? this.packagesToSend,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'eventId': eventId,
        'createdAt': createdAt.toIso8601String(),
        'attemptCount': attemptCount,
        if (retryId != null) 'retryId': retryId,
        if (statisticalPackage != null) 'statisticalPackage': statisticalPackage!.toJson(),
        if (encryptedPackage != null) 'encryptedPackage': encryptedPackage!.toJson(),
        if (unencryptedPackage != null) 'unencryptedPackage': unencryptedPackage!.toJson(),
        'packagesToSend': packagesToSend.map((e) => e.name).toList(),
      };

  factory PendingRequest.fromJson(Map<String, dynamic> json) {
    return PendingRequest(
      id: json['id'],
      eventId: json['eventId'],
      createdAt: DateTime.parse(json['createdAt']),
      attemptCount: json['attemptCount'] ?? 0,
      retryId: json['retryId'],
      statisticalPackage:
          json['statisticalPackage'] != null ? StatisticalPackage.fromJson(json['statisticalPackage']) : null,
      encryptedPackage: json['encryptedPackage'] != null ? EncryptedPackage.fromJson(json['encryptedPackage']) : null,
      unencryptedPackage:
          json['unencryptedPackage'] != null ? UnencryptedPackage.fromJson(json['unencryptedPackage']) : null,
      packagesToSend:
          (json['packagesToSend'] as List).map((e) => PackageType.values.firstWhere((t) => t.name == e)).toSet(),
    );
  }
}
