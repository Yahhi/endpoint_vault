import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../encryption/encryption_service.dart';
import '../models/file_attachment.dart';

/// Storage service for encrypted file attachments.
///
/// Handles storing, retrieving, and cleaning up encrypted attachment files
/// on the device file system.
class AttachmentStorage {
  final EncryptionService _encryption;
  final String? _customStorageDir;
  final bool debug;

  String? _storageDir;

  AttachmentStorage({
    required EncryptionService encryption,
    String? storageDir,
    this.debug = false,
  })  : _encryption = encryption,
        _customStorageDir = storageDir;

  /// Get the storage directory path, creating it if necessary.
  Future<String> get storageDir async {
    if (_storageDir != null) return _storageDir!;

    if (_customStorageDir != null) {
      _storageDir = _customStorageDir;
    } else {
      final appDir = await getApplicationDocumentsDirectory();
      _storageDir = p.join(appDir.path, 'endpoint_vault_attachments');
    }

    final dir = Directory(_storageDir!);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    return _storageDir!;
  }

  /// Store file bytes encrypted to file system.
  ///
  /// Encrypts the data and writes it to a file. Returns the [FileAttachment]
  /// containing metadata and the path to the encrypted file.
  Future<FileAttachment> storeEncrypted({
    required String fieldName,
    required String filename,
    String? contentType,
    required Uint8List data,
  }) async {
    final attachmentId = const Uuid().v4();
    final dir = await storageDir;
    final localPath = p.join(dir, '$attachmentId.enc');

    // Calculate checksum before encryption
    final checksum = _encryption.checksumSha256(data);

    // Encrypt and write to file
    await _encryption.encryptBytesToFile(
      data: data,
      outputPath: localPath,
    );

    final attachment = FileAttachment(
      id: attachmentId,
      fieldName: fieldName,
      filename: filename,
      contentType: contentType,
      sizeBytes: data.length,
      localPath: localPath,
      checksumSha256: checksum,
      createdAt: DateTime.now().toUtc(),
    );

    if (debug) {
      print('[EndpointVault] Attachment stored: $attachmentId '
          '(${_formatBytes(data.length)})');
    }

    return attachment;
  }

  /// Read encrypted file from storage and decrypt.
  ///
  /// Returns the decrypted file bytes.
  Future<Uint8List> readDecrypted(String attachmentId) async {
    final dir = await storageDir;
    final localPath = p.join(dir, '$attachmentId.enc');

    return _encryption.decryptFileToBytes(localPath);
  }

  /// Read encrypted file from storage by path and decrypt.
  Future<Uint8List> readDecryptedByPath(String localPath) async {
    return _encryption.decryptFileToBytes(localPath);
  }

  /// Get encrypted file bytes (without decryption) for upload.
  Future<Uint8List> readEncrypted(String attachmentId) async {
    final dir = await storageDir;
    final localPath = p.join(dir, '$attachmentId.enc');

    final file = File(localPath);
    return file.readAsBytes();
  }

  /// Get encrypted file bytes by path (without decryption) for upload.
  Future<Uint8List> readEncryptedByPath(String localPath) async {
    final file = File(localPath);
    return file.readAsBytes();
  }

  /// Delete an attachment file.
  Future<void> delete(String attachmentId) async {
    final dir = await storageDir;
    final localPath = p.join(dir, '$attachmentId.enc');

    final file = File(localPath);
    if (await file.exists()) {
      await file.delete();
      if (debug) {
        print('[EndpointVault] Attachment deleted: $attachmentId');
      }
    }
  }

  /// Delete an attachment file by path.
  Future<void> deleteByPath(String localPath) async {
    final file = File(localPath);
    if (await file.exists()) {
      await file.delete();
      if (debug) {
        print('[EndpointVault] Attachment file deleted: $localPath');
      }
    }
  }

  /// Delete multiple attachments.
  Future<void> deleteAll(List<FileAttachment> attachments) async {
    for (final attachment in attachments) {
      await deleteByPath(attachment.localPath);
    }
  }

  /// Get all stored attachment IDs.
  Future<List<String>> listAttachmentIds() async {
    final dir = await storageDir;
    final directory = Directory(dir);

    if (!await directory.exists()) {
      return [];
    }

    final files = await directory.list().toList();
    return files
        .whereType<File>()
        .where((f) => f.path.endsWith('.enc'))
        .map((f) => p.basenameWithoutExtension(f.path))
        .toList();
  }

  /// Clean up orphaned attachments older than the specified duration.
  ///
  /// This should be called periodically to remove attachment files that
  /// were never uploaded or whose events have been cleaned up.
  Future<int> cleanup({Duration maxAge = const Duration(days: 7)}) async {
    final dir = await storageDir;
    final directory = Directory(dir);

    if (!await directory.exists()) {
      return 0;
    }

    final cutoff = DateTime.now().subtract(maxAge);
    var deletedCount = 0;

    await for (final entity in directory.list()) {
      if (entity is File && entity.path.endsWith('.enc')) {
        final stat = await entity.stat();
        if (stat.modified.isBefore(cutoff)) {
          await entity.delete();
          deletedCount++;
        }
      }
    }

    if (debug && deletedCount > 0) {
      print('[EndpointVault] Cleaned up $deletedCount old attachments');
    }

    return deletedCount;
  }

  /// Calculate total storage used by attachments.
  Future<int> totalStorageBytes() async {
    final dir = await storageDir;
    final directory = Directory(dir);

    if (!await directory.exists()) {
      return 0;
    }

    var totalBytes = 0;
    await for (final entity in directory.list()) {
      if (entity is File && entity.path.endsWith('.enc')) {
        final stat = await entity.stat();
        totalBytes += stat.size;
      }
    }

    return totalBytes;
  }

  /// Check if an attachment file exists.
  Future<bool> exists(String attachmentId) async {
    final dir = await storageDir;
    final localPath = p.join(dir, '$attachmentId.enc');
    return File(localPath).exists();
  }

  /// Check if an attachment file exists by path.
  Future<bool> existsByPath(String localPath) async {
    return File(localPath).exists();
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
