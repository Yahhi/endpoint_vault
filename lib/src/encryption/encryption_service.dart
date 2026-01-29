import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as enc;

/// Service for encrypting and decrypting payloads.
///
/// Uses AES-256-CBC encryption with a random IV for each encryption.
class EncryptionService {
  final enc.Key _key;

  /// The raw key bytes for file encryption operations.
  Uint8List get keyBytes => _key.bytes;

  /// Create an encryption service with the given key.
  ///
  /// Key must be exactly 32 characters (256 bits) for AES-256.
  EncryptionService(String key) : _key = _deriveKey(key);

  static enc.Key _deriveKey(String key) {
    // If key is already 32 bytes, use it directly
    if (key.length == 32) {
      return enc.Key.fromUtf8(key);
    }

    // Otherwise, derive a 32-byte key using SHA-256
    final hash = sha256.convert(utf8.encode(key));
    return enc.Key(Uint8List.fromList(hash.bytes));
  }

  /// Encrypt a string payload.
  ///
  /// Returns a base64-encoded string containing IV + ciphertext.
  String encrypt(String plaintext) {
    final iv = enc.IV.fromSecureRandom(16);
    final encrypter = enc.Encrypter(
      enc.AES(_key, mode: enc.AESMode.cbc),
    );

    final encrypted = encrypter.encrypt(plaintext, iv: iv);

    // Combine IV and ciphertext
    final combined = Uint8List(16 + encrypted.bytes.length);
    combined.setRange(0, 16, iv.bytes);
    combined.setRange(16, combined.length, encrypted.bytes);

    return base64Encode(combined);
  }

  /// Decrypt a previously encrypted payload.
  ///
  /// Input should be the base64-encoded string from [encrypt].
  String decrypt(String ciphertext) {
    final combined = base64Decode(ciphertext);

    // Extract IV and ciphertext
    final iv = enc.IV(Uint8List.fromList(combined.sublist(0, 16)));
    final encryptedBytes = combined.sublist(16);

    final encrypter = enc.Encrypter(
      enc.AES(_key, mode: enc.AESMode.cbc),
    );

    return encrypter.decrypt(
      enc.Encrypted(Uint8List.fromList(encryptedBytes)),
      iv: iv,
    );
  }

  /// Encrypt a JSON-serializable object.
  String encryptJson(dynamic data) {
    return encrypt(jsonEncode(data));
  }

  /// Decrypt to a JSON object.
  dynamic decryptJson(String ciphertext) {
    return jsonDecode(decrypt(ciphertext));
  }

  /// Generate a fingerprint/hash of the payload without storing the actual data.
  ///
  /// Useful for deduplication and matching without storing sensitive data.
  String fingerprint(String data) {
    final hash = sha256.convert(utf8.encode(data));
    return hash.toString().substring(0, 16);
  }

  /// Encrypt binary data and return as bytes.
  ///
  /// Returns bytes containing [16-byte IV][encrypted data].
  Uint8List encryptBytes(Uint8List data) {
    final iv = enc.IV.fromSecureRandom(16);
    final encrypter = enc.Encrypter(
      enc.AES(_key, mode: enc.AESMode.cbc),
    );

    final encrypted = encrypter.encryptBytes(data, iv: iv);

    // Combine IV and ciphertext
    final combined = Uint8List(16 + encrypted.bytes.length);
    combined.setRange(0, 16, iv.bytes);
    combined.setRange(16, combined.length, encrypted.bytes);

    return combined;
  }

  /// Decrypt binary data.
  ///
  /// Input should be bytes from [encryptBytes] containing IV + ciphertext.
  Uint8List decryptBytes(Uint8List encryptedData) {
    // Extract IV and ciphertext
    final iv = enc.IV(Uint8List.fromList(encryptedData.sublist(0, 16)));
    final ciphertextBytes = encryptedData.sublist(16);

    final encrypter = enc.Encrypter(
      enc.AES(_key, mode: enc.AESMode.cbc),
    );

    return Uint8List.fromList(
      encrypter.decryptBytes(
        enc.Encrypted(Uint8List.fromList(ciphertextBytes)),
        iv: iv,
      ),
    );
  }

  /// Encrypt bytes and write directly to a file.
  ///
  /// This is more memory-efficient for large files as it writes
  /// the encrypted data directly to disk.
  Future<void> encryptBytesToFile({
    required Uint8List data,
    required String outputPath,
  }) async {
    final encrypted = encryptBytes(data);
    final file = File(outputPath);
    await file.writeAsBytes(encrypted, flush: true);
  }

  /// Read and decrypt a file to bytes.
  ///
  /// Reads the encrypted file and returns the decrypted data.
  Future<Uint8List> decryptFileToBytes(String inputPath) async {
    final file = File(inputPath);
    final encryptedData = await file.readAsBytes();
    return decryptBytes(encryptedData);
  }

  /// Calculate SHA-256 checksum of bytes.
  String checksumSha256(Uint8List data) {
    final hash = sha256.convert(data);
    return hash.toString();
  }

  /// Calculate SHA-256 checksum of a file.
  Future<String> checksumSha256File(String filePath) async {
    final file = File(filePath);
    final bytes = await file.readAsBytes();
    return checksumSha256(bytes);
  }
}
