import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../models/file_attachment.dart';
import '../storage/attachment_storage.dart';

/// Service for extracting and capturing file attachments from FormData.
///
/// This service intercepts FormData before a request is sent, extracts
/// file attachments, encrypts them, and stores them on the device.
/// This is necessary because MultipartFile streams are consumed during
/// request transmission and cannot be read again after a failure.
class FormDataExtractor {
  final AttachmentStorage _storage;
  final int maxFileSize;
  final int maxTotalSize;
  final int maxAttachments;
  final bool debug;

  FormDataExtractor({
    required AttachmentStorage storage,
    required this.maxFileSize,
    required this.maxTotalSize,
    required this.maxAttachments,
    this.debug = false,
  }) : _storage = storage;

  /// Extract file attachments from FormData before request is sent.
  ///
  /// Reads all file data from MultipartFile objects, stores them encrypted
  /// on disk, and returns extraction result with attachment metadata and
  /// a recreated FormData with fresh streams for the actual request.
  ///
  /// Returns null if the FormData has no files or an error occurs.
  Future<FormDataExtractionResult?> extract(FormData formData) async {
    final files = <MapEntry<String, MultipartFile>>[];
    final fields = <MapEntry<String, String>>[];

    // Separate files from regular fields
    for (final entry in formData.fields) {
      fields.add(entry);
    }

    for (final entry in formData.files) {
      files.add(entry);
    }

    if (files.isEmpty) {
      return null; // No files to extract
    }

    // Check attachment count limit
    if (files.length > maxAttachments) {
      if (debug) {
        print('[EndpointVault] Too many attachments: ${files.length} > $maxAttachments');
      }
      // Only take the first maxAttachments files
      files.removeRange(maxAttachments, files.length);
    }

    final extractedFiles = <ExtractedFileData>[];
    final attachments = <FileAttachment>[];
    var totalSize = 0;

    // Extract file bytes from MultipartFile objects
    for (final entry in files) {
      final fieldName = entry.key;
      final multipartFile = entry.value;

      try {
        // Read file bytes from the stream
        final bytes = await _readMultipartFile(multipartFile);

        // Check single file size limit
        if (bytes.length > maxFileSize) {
          if (debug) {
            print('[EndpointVault] File too large: ${multipartFile.filename} '
                '(${bytes.length} > $maxFileSize)');
          }
          continue; // Skip this file
        }

        // Check total size limit
        if (totalSize + bytes.length > maxTotalSize) {
          if (debug) {
            print('[EndpointVault] Total attachment size limit reached');
          }
          break; // Stop extracting more files
        }

        totalSize += bytes.length;

        extractedFiles.add(ExtractedFileData(
          fieldName: fieldName,
          filename: multipartFile.filename ?? 'unnamed',
          contentType: multipartFile.contentType?.mimeType,
          bytes: bytes,
        ));
      } catch (e) {
        if (debug) {
          print('[EndpointVault] Failed to extract file ${multipartFile.filename}: $e');
        }
        // Continue with other files
      }
    }

    if (extractedFiles.isEmpty) {
      return null;
    }

    // Store encrypted files and create attachments
    for (final extracted in extractedFiles) {
      try {
        final attachment = await _storage.storeEncrypted(
          fieldName: extracted.fieldName,
          filename: extracted.filename,
          contentType: extracted.contentType,
          data: extracted.bytes,
        );
        attachments.add(attachment);
      } catch (e) {
        if (debug) {
          print('[EndpointVault] Failed to store attachment ${extracted.filename}: $e');
        }
      }
    }

    if (attachments.isEmpty) {
      return null;
    }

    // Create new FormData with fresh streams for the actual request
    final recreatedFormData = await _recreateFormData(
      fields: fields,
      extractedFiles: extractedFiles,
    );

    if (debug) {
      print('[EndpointVault] Extracted ${attachments.length} attachments '
          '(total: ${_formatBytes(totalSize)})');
    }

    return FormDataExtractionResult(
      attachments: attachments,
      fields: fields,
      recreatedFormData: recreatedFormData,
      extractedFiles: extractedFiles,
    );
  }

  /// Recreate FormData with fresh streams from extracted file data.
  ///
  /// This is necessary because the original MultipartFile streams have
  /// been consumed during extraction.
  Future<FormData> _recreateFormData({
    required List<MapEntry<String, String>> fields,
    required List<ExtractedFileData> extractedFiles,
  }) async {
    final newFormData = FormData();

    // Add regular fields
    for (final field in fields) {
      newFormData.fields.add(field);
    }

    // Add files with fresh streams from extracted bytes
    for (final extracted in extractedFiles) {
      final multipartFile = MultipartFile.fromBytes(
        extracted.bytes,
        filename: extracted.filename,
        contentType: extracted.contentType != null
            ? DioMediaType.parse(extracted.contentType!)
            : null,
      );
      newFormData.files.add(MapEntry(extracted.fieldName, multipartFile));
    }

    return newFormData;
  }

  /// Read all bytes from a MultipartFile.
  Future<Uint8List> _readMultipartFile(MultipartFile file) async {
    // For files created from bytes, we can access them directly
    // For files created from streams or file paths, we need to read the stream

    // Try to get the stream and read it
    final stream = file.finalize();
    final chunks = <List<int>>[];

    await for (final chunk in stream) {
      chunks.add(chunk);
    }

    // Combine all chunks into a single Uint8List
    var totalLength = 0;
    for (final chunk in chunks) {
      totalLength += chunk.length;
    }

    final result = Uint8List(totalLength);
    var offset = 0;
    for (final chunk in chunks) {
      result.setRange(offset, offset + chunk.length, chunk);
      offset += chunk.length;
    }

    return result;
  }

  /// Recreate FormData for replay from stored attachments.
  ///
  /// Used when replaying a failed request to recreate the original FormData.
  Future<FormData> recreateForReplay({
    required List<MapEntry<String, String>> fields,
    required List<FileAttachment> attachments,
  }) async {
    final newFormData = FormData();

    // Add regular fields
    for (final field in fields) {
      newFormData.fields.add(field);
    }

    // Add files from stored attachments
    for (final attachment in attachments) {
      try {
        final bytes = await _storage.readDecryptedByPath(attachment.localPath);
        final multipartFile = MultipartFile.fromBytes(
          bytes,
          filename: attachment.filename,
          contentType: attachment.contentType != null
              ? DioMediaType.parse(attachment.contentType!)
              : null,
        );
        newFormData.files.add(MapEntry(attachment.fieldName, multipartFile));
      } catch (e) {
        if (debug) {
          print('[EndpointVault] Failed to read attachment for replay: '
              '${attachment.id}: $e');
        }
      }
    }

    return newFormData;
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

/// Result of extracting file attachments from FormData.
class FormDataExtractionResult {
  /// List of stored file attachments with metadata.
  final List<FileAttachment> attachments;

  /// Original form fields (non-file entries).
  final List<MapEntry<String, String>> fields;

  /// Recreated FormData with fresh streams for the actual request.
  final FormData recreatedFormData;

  /// Extracted file data (in-memory, used for recreating FormData).
  final List<ExtractedFileData> extractedFiles;

  const FormDataExtractionResult({
    required this.attachments,
    required this.fields,
    required this.recreatedFormData,
    required this.extractedFiles,
  });

  /// Total size of all attachments in bytes.
  int get totalBytes => attachments.fold(0, (sum, a) => sum + a.sizeBytes);

  /// Number of attachments.
  int get count => attachments.length;
}
