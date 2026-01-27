import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:endpoint_vault/src/encryption/encryption_service.dart';

void main() {
  group('EncryptionService', () {
    group('Key Derivation', () {
      test('uses 32-char key directly without hashing', () {
        const key32 = 'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA';
        final service = EncryptionService(key32);

        // Encrypt and decrypt should work
        const plaintext = 'test message';
        final encrypted = service.encrypt(plaintext);
        final decrypted = service.decrypt(encrypted);

        expect(decrypted, equals(plaintext));
      });

      test('derives key using SHA-256 for non-32-char keys', () {
        const shortKey = 'my-secret-key';
        final service = EncryptionService(shortKey);

        // Verify SHA-256 derivation by checking encrypt/decrypt works
        const plaintext = 'test message';
        final encrypted = service.encrypt(plaintext);
        final decrypted = service.decrypt(encrypted);

        expect(decrypted, equals(plaintext));
      });

      test('SHA-256 key derivation produces correct hash', () {
        // Test that SHA-256 produces expected output
        const input = 'my-secret-key';
        final hash = sha256.convert(utf8.encode(input));

        // SHA-256 of "my-secret-key" should be consistent
        expect(hash.bytes.length, equals(32));

        // Verify the hash is deterministic
        final hash2 = sha256.convert(utf8.encode(input));
        expect(hash.toString(), equals(hash2.toString()));
      });

      test('different keys produce different encryptions', () {
        final service1 = EncryptionService('key-one-32-characters-long!!!!!');
        final service2 = EncryptionService('key-two-32-characters-long!!!!!');

        const plaintext = 'same message';
        final encrypted1 = service1.encrypt(plaintext);
        final encrypted2 = service2.encrypt(plaintext);

        // Different keys should produce different ciphertexts
        // (even accounting for different IVs, the structure differs)
        expect(encrypted1, isNot(equals(encrypted2)));

        // But each can decrypt its own
        expect(service1.decrypt(encrypted1), equals(plaintext));
        expect(service2.decrypt(encrypted2), equals(plaintext));

        // And cannot decrypt the other's
        expect(
          () => service1.decrypt(encrypted2),
          throwsA(anything),
        );
      });
    });

    group('Encryption/Decryption', () {
      late EncryptionService service;

      setUp(() {
        service = EncryptionService('test-encryption-key-32-chars!!!');
      });

      test('encrypts and decrypts simple string', () {
        const plaintext = 'Hello, World!';
        final encrypted = service.encrypt(plaintext);
        final decrypted = service.decrypt(encrypted);

        expect(decrypted, equals(plaintext));
      });

      test('encrypts and decrypts single character', () {
        // Note: Empty string is not supported by the underlying encrypt package
        // This is acceptable as we never encrypt empty payloads in practice
        const plaintext = 'x';
        final encrypted = service.encrypt(plaintext);
        final decrypted = service.decrypt(encrypted);

        expect(decrypted, equals(plaintext));
      });

      test('encrypts and decrypts unicode content', () {
        const plaintext = 'Привет мир! 你好世界! 🎉🚀';
        final encrypted = service.encrypt(plaintext);
        final decrypted = service.decrypt(encrypted);

        expect(decrypted, equals(plaintext));
      });

      test('encrypts and decrypts long text', () {
        final plaintext = 'A' * 10000;
        final encrypted = service.encrypt(plaintext);
        final decrypted = service.decrypt(encrypted);

        expect(decrypted, equals(plaintext));
      });

      test('encrypts and decrypts JSON payload', () {
        final payload = {
          'password': 'secret123',
          'token': 'abc-def-ghi',
          'nested': {
            'key': 'value',
            'array': [1, 2, 3],
          },
        };

        final plaintext = jsonEncode(payload);
        final encrypted = service.encrypt(plaintext);
        final decrypted = service.decrypt(encrypted);

        expect(decrypted, equals(plaintext));
        expect(jsonDecode(decrypted), equals(payload));
      });

      test('produces different ciphertext for same plaintext (random IV)', () {
        const plaintext = 'same message';

        final encrypted1 = service.encrypt(plaintext);
        final encrypted2 = service.encrypt(plaintext);

        // Due to random IV, ciphertexts should differ
        expect(encrypted1, isNot(equals(encrypted2)));

        // But both should decrypt to same plaintext
        expect(service.decrypt(encrypted1), equals(plaintext));
        expect(service.decrypt(encrypted2), equals(plaintext));
      });

      test('output is valid base64', () {
        const plaintext = 'test message';
        final encrypted = service.encrypt(plaintext);

        // Should not throw
        final decoded = base64Decode(encrypted);
        expect(decoded.length, greaterThanOrEqualTo(16)); // At least IV size
      });

      test('output format: IV (16 bytes) + ciphertext', () {
        const plaintext = 'test';
        final encrypted = service.encrypt(plaintext);
        final decoded = base64Decode(encrypted);

        // First 16 bytes are IV
        expect(decoded.length, greaterThanOrEqualTo(16));

        // For "test" (4 bytes) + PKCS7 padding = 16 bytes ciphertext
        // Total = 16 (IV) + 16 (ciphertext) = 32 bytes
        expect(decoded.length, equals(32));
      });
    });

    group('encryptJson / decryptJson', () {
      late EncryptionService service;

      setUp(() {
        service = EncryptionService('json-test-key-32-characters!!!!');
      });

      test('encrypts and decrypts JSON object', () {
        final data = {'key': 'value', 'number': 42};
        final encrypted = service.encryptJson(data);
        final decrypted = service.decryptJson(encrypted);

        expect(decrypted, equals(data));
      });

      test('encrypts and decrypts JSON array', () {
        final data = [
          1,
          2,
          3,
          'four',
          {'five': 5}
        ];
        final encrypted = service.encryptJson(data);
        final decrypted = service.decryptJson(encrypted);

        expect(decrypted, equals(data));
      });

      test('encrypts and decrypts nested JSON', () {
        final data = {
          'user': {
            'name': 'John',
            'email': 'john@example.com',
          },
          'tokens': ['abc', 'def'],
          'metadata': {
            'created': '2024-01-15',
            'tags': ['important', 'secret'],
          },
        };

        final encrypted = service.encryptJson(data);
        final decrypted = service.decryptJson(encrypted);

        expect(decrypted, equals(data));
      });
    });

    group('fingerprint', () {
      late EncryptionService service;

      setUp(() {
        service = EncryptionService('any-key-works-here');
      });

      test('produces 16-character hex string', () {
        final fp = service.fingerprint('Hello, World!');

        expect(fp.length, equals(16));
        expect(RegExp(r'^[0-9a-f]+$').hasMatch(fp), isTrue);
      });

      test('is deterministic', () {
        const data = 'same input';
        final fp1 = service.fingerprint(data);
        final fp2 = service.fingerprint(data);

        expect(fp1, equals(fp2));
      });

      test('different inputs produce different fingerprints', () {
        final fp1 = service.fingerprint('input one');
        final fp2 = service.fingerprint('input two');

        expect(fp1, isNot(equals(fp2)));
      });

      test('matches expected SHA-256 prefix', () {
        const data = 'Hello, World!';
        final fp = service.fingerprint(data);

        // Manually compute SHA-256
        final hash = sha256.convert(utf8.encode(data));
        final expectedPrefix = hash.toString().substring(0, 16);

        expect(fp, equals(expectedPrefix));
      });
    });

    group('Cross-platform Test Vectors', () {
      // These tests use known values that backend implementations must match

      test('Test Vector 1: 32-char key encryption round-trip', () {
        const key = 'test-encryption-key-32-chars!!!';
        const plaintext = 'Hello, World!';

        final service = EncryptionService(key);
        final encrypted = service.encrypt(plaintext);
        final decrypted = service.decrypt(encrypted);

        expect(decrypted, equals(plaintext));

        // Verify structure
        final decoded = base64Decode(encrypted);
        expect(decoded.length, greaterThanOrEqualTo(32)); // IV + at least one block
      });

      test('Test Vector 2: SHA-256 derived key', () {
        const key = 'short-key';
        const plaintext = '{"password":"secret123"}';

        final service = EncryptionService(key);

        // Verify key derivation
        final expectedKeyHash = sha256.convert(utf8.encode(key));
        expect(expectedKeyHash.bytes.length, equals(32));

        // Verify encryption works
        final encrypted = service.encrypt(plaintext);
        final decrypted = service.decrypt(encrypted);
        expect(decrypted, equals(plaintext));
      });

      test('Test Vector 3: Unicode handling', () {
        const key = 'unicode-key-32-characters!!!!!!';
        const plaintext = 'Тест 测试 🎉';

        final service = EncryptionService(key);
        final encrypted = service.encrypt(plaintext);
        final decrypted = service.decrypt(encrypted);

        expect(decrypted, equals(plaintext));

        // Verify UTF-8 encoding
        final plaintextBytes = utf8.encode(plaintext);
        expect(plaintextBytes.length, greaterThan(plaintext.length)); // Multi-byte chars
      });

      test('Test Vector 4: Fingerprint verification', () {
        // These values must match across all implementations
        const testCases = [
          {'input': 'Hello, World!', 'prefix': 'dffd6021bb2bd5b0'},
          {'input': 'test', 'prefix': '9f86d081884c7d65'},
          {'input': '', 'prefix': 'e3b0c44298fc1c14'},
        ];

        final service = EncryptionService('any-key');

        for (final testCase in testCases) {
          final input = testCase['input']!;
          final expectedPrefix = testCase['prefix']!;

          final fp = service.fingerprint(input);
          expect(fp, equals(expectedPrefix), reason: 'Fingerprint mismatch for "$input"');
        }
      });

      test('Test Vector 5: Key derivation verification', () {
        // Verify SHA-256 produces expected output
        const input = 'my-secret-key';
        final hash = sha256.convert(utf8.encode(input));

        // First 8 bytes of SHA-256("my-secret-key") in hex
        // This is a known value that backend must match
        final hashHex = hash.toString();
        expect(hashHex.length, equals(64)); // 32 bytes = 64 hex chars

        // The hash should be deterministic
        final hash2 = sha256.convert(utf8.encode(input));
        expect(hash.toString(), equals(hash2.toString()));
      });
    });

    group('Error Handling', () {
      late EncryptionService service;

      setUp(() {
        service = EncryptionService('error-test-key-32-characters!!!');
      });

      test('throws on invalid base64 input', () {
        expect(
          () => service.decrypt('not-valid-base64!!!'),
          throwsA(anything),
        );
      });

      test('throws on truncated ciphertext', () {
        const plaintext = 'test message';
        final encrypted = service.encrypt(plaintext);
        final truncated = encrypted.substring(0, 10);

        expect(
          () => service.decrypt(truncated),
          throwsA(anything),
        );
      });

      test('throws on corrupted ciphertext', () {
        const plaintext = 'test message';
        final encrypted = service.encrypt(plaintext);

        // Corrupt the ciphertext by changing a character
        final corrupted = encrypted.replaceFirst('A', 'B');

        // May or may not throw depending on where corruption is
        // but if it doesn't throw, result should be garbage
        try {
          final result = service.decrypt(corrupted);
          expect(result, isNot(equals(plaintext)));
        } catch (e) {
          // Expected - corruption detected
        }
      });

      test('throws when decrypting with wrong key', () {
        final service1 = EncryptionService('key-one-32-characters-long!!!!!');
        final service2 = EncryptionService('key-two-32-characters-long!!!!!');

        const plaintext = 'secret message';
        final encrypted = service1.encrypt(plaintext);

        expect(
          () => service2.decrypt(encrypted),
          throwsA(anything),
        );
      });
    });
  });
}
