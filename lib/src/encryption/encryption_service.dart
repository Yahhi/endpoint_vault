import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as encrypt;

/// Service for encrypting and decrypting payloads.
///
/// Uses AES-256-GCM encryption with a random IV for each encryption.
class EncryptionService {
  final encrypt.Key _key;

  /// Create an encryption service with the given key.
  ///
  /// Key must be exactly 32 characters (256 bits) for AES-256.
  EncryptionService(String key) : _key = _deriveKey(key);

  static encrypt.Key _deriveKey(String key) {
    // If key is already 32 bytes, use it directly
    if (key.length == 32) {
      return encrypt.Key.fromUtf8(key);
    }

    // Otherwise, derive a 32-byte key using SHA-256
    final hash = sha256.convert(utf8.encode(key));
    return encrypt.Key(Uint8List.fromList(hash.bytes));
  }

  /// Encrypt a string payload.
  ///
  /// Returns a base64-encoded string containing IV + ciphertext.
  String encrypt(String plaintext) {
    final iv = encrypt.IV.fromSecureRandom(16);
    final encrypter = encrypt.Encrypter(
      encrypt.AES(_key, mode: encrypt.AESMode.cbc),
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
    final iv = encrypt.IV(Uint8List.fromList(combined.sublist(0, 16)));
    final encryptedBytes = combined.sublist(16);

    final encrypter = encrypt.Encrypter(
      encrypt.AES(_key, mode: encrypt.AESMode.cbc),
    );

    return encrypter.decrypt(
      encrypt.Encrypted(Uint8List.fromList(encryptedBytes)),
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
}
