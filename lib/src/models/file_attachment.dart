import 'dart:typed_data';

/// Represents a file attachment extracted from a FormData request.
///
/// This model captures file metadata and references the encrypted file
/// stored on the device file system. The actual file bytes are stored
/// separately using [AttachmentStorage].
class FileAttachment {
  /// Unique identifier for this attachment.
  final String id;

  /// The FormData field name this file was attached to.
  final String fieldName;

  /// Original filename of the attachment.
  final String filename;

  /// MIME content type (e.g., 'image/jpeg', 'application/pdf').
  final String? contentType;

  /// Size of the original file in bytes.
  final int sizeBytes;

  /// Path to the encrypted file on the device file system.
  final String localPath;

  /// SHA-256 checksum of the original file data.
  final String checksumSha256;

  /// When this attachment was created.
  final DateTime createdAt;

  const FileAttachment({
    required this.id,
    required this.fieldName,
    required this.filename,
    this.contentType,
    required this.sizeBytes,
    required this.localPath,
    required this.checksumSha256,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'fieldName': fieldName,
        'filename': filename,
        if (contentType != null) 'contentType': contentType,
        'sizeBytes': sizeBytes,
        'localPath': localPath,
        'checksumSha256': checksumSha256,
        'createdAt': createdAt.toIso8601String(),
      };

  factory FileAttachment.fromJson(Map<String, dynamic> json) {
    return FileAttachment(
      id: json['id'] as String,
      fieldName: json['fieldName'] as String,
      filename: json['filename'] as String,
      contentType: json['contentType'] as String?,
      sizeBytes: json['sizeBytes'] as int,
      localPath: json['localPath'] as String,
      checksumSha256: json['checksumSha256'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  FileAttachment copyWith({
    String? id,
    String? fieldName,
    String? filename,
    String? contentType,
    int? sizeBytes,
    String? localPath,
    String? checksumSha256,
    DateTime? createdAt,
  }) {
    return FileAttachment(
      id: id ?? this.id,
      fieldName: fieldName ?? this.fieldName,
      filename: filename ?? this.filename,
      contentType: contentType ?? this.contentType,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      localPath: localPath ?? this.localPath,
      checksumSha256: checksumSha256 ?? this.checksumSha256,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() =>
      'FileAttachment(id: $id, filename: $filename, size: $sizeBytes)';
}

/// Represents an encrypted file attachment ready for server upload.
///
/// Contains encrypted metadata and references the encrypted file data.
class EncryptedFileAttachment {
  /// Unique identifier for this attachment (same as [FileAttachment.id]).
  final String id;

  /// Encrypted field name.
  final String encryptedFieldName;

  /// Encrypted original filename.
  final String encryptedFilename;

  /// Encrypted content type (if present).
  final String? encryptedContentType;

  /// Size of the encrypted file in bytes.
  final int sizeBytes;

  /// SHA-256 checksum of the original (unencrypted) file data.
  final String checksumSha256;

  /// Path to the encrypted file on the device file system.
  final String localPath;

  const EncryptedFileAttachment({
    required this.id,
    required this.encryptedFieldName,
    required this.encryptedFilename,
    this.encryptedContentType,
    required this.sizeBytes,
    required this.checksumSha256,
    required this.localPath,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'fieldName': encryptedFieldName,
        'filename': encryptedFilename,
        if (encryptedContentType != null) 'contentType': encryptedContentType,
        'sizeBytes': sizeBytes,
        'checksumSha256': checksumSha256,
        'localPath': localPath,
      };

  factory EncryptedFileAttachment.fromJson(Map<String, dynamic> json) {
    return EncryptedFileAttachment(
      id: json['id'] as String,
      encryptedFieldName: json['fieldName'] as String,
      encryptedFilename: json['filename'] as String,
      encryptedContentType: json['contentType'] as String?,
      sizeBytes: json['sizeBytes'] as int,
      checksumSha256: json['checksumSha256'] as String,
      localPath: json['localPath'] as String,
    );
  }

  @override
  String toString() =>
      'EncryptedFileAttachment(id: $id, size: $sizeBytes)';
}

/// Metadata for uploading an attachment to the server.
class AttachmentUploadMetadata {
  final String attachmentId;
  final String eventId;
  final String encryptedFieldName;
  final String encryptedFilename;
  final String? encryptedContentType;
  final int sizeBytes;
  final String checksumSha256;

  const AttachmentUploadMetadata({
    required this.attachmentId,
    required this.eventId,
    required this.encryptedFieldName,
    required this.encryptedFilename,
    this.encryptedContentType,
    required this.sizeBytes,
    required this.checksumSha256,
  });

  Map<String, dynamic> toJson() => {
        'attachmentId': attachmentId,
        'eventId': eventId,
        'fieldName': encryptedFieldName,
        'filename': encryptedFilename,
        if (encryptedContentType != null) 'contentType': encryptedContentType,
        'sizeBytes': sizeBytes,
        'checksumSha256': checksumSha256,
      };
}

/// Holds extracted file bytes before encryption/storage.
///
/// This is an internal class used during FormData extraction to temporarily
/// hold file data before it's encrypted and written to storage.
class ExtractedFileData {
  final String fieldName;
  final String filename;
  final String? contentType;
  final Uint8List bytes;

  const ExtractedFileData({
    required this.fieldName,
    required this.filename,
    this.contentType,
    required this.bytes,
  });

  int get sizeBytes => bytes.length;
}
