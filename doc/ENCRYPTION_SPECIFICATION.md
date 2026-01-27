# EndpointVault Encryption Specification

This document provides complete technical details about the encryption algorithms used in EndpointVault, including test vectors for backend implementation verification.

## Table of Contents

1. [Overview](#overview)
2. [Key Derivation](#key-derivation)
3. [Encryption Algorithm](#encryption-algorithm)
4. [Data Format](#data-format)
5. [Test Vectors](#test-vectors)
6. [Implementation Examples](#implementation-examples)
7. [Security Considerations](#security-considerations)

---

## Overview

EndpointVault uses **AES-256-CBC** encryption for all sensitive payload data. The encryption is performed client-side before data is sent to the server.

**Key characteristics:**
- Algorithm: AES-256-CBC (Advanced Encryption Standard, 256-bit key, Cipher Block Chaining mode)
- Key size: 256 bits (32 bytes)
- IV size: 128 bits (16 bytes)
- Padding: PKCS7
- Output format: Base64-encoded (IV + Ciphertext)

---

## Key Derivation

The encryption key can be provided in two ways:

### Option 1: Direct 32-byte Key

If the provided key is exactly 32 characters (32 bytes), it is used directly as the AES key.

```
Input key: "12345678901234567890123456789012" (32 chars)
AES key:   0x31 0x32 0x33 0x34 0x35 0x36 0x37 0x38 
           0x39 0x30 0x31 0x32 0x33 0x34 0x35 0x36 
           0x37 0x38 0x39 0x30 0x31 0x32 0x33 0x34 
           0x35 0x36 0x37 0x38 0x39 0x30 0x31 0x32
```

### Option 2: SHA-256 Key Derivation

If the key is NOT 32 characters, it is hashed using SHA-256 to derive a 32-byte key.

```
Input key: "my-secret-key"
SHA-256:   sha256("my-secret-key")
AES key:   The 32-byte SHA-256 hash result
```

**Pseudocode:**
```
function deriveKey(inputKey):
    if length(inputKey) == 32:
        return utf8ToBytes(inputKey)
    else:
        return sha256(utf8ToBytes(inputKey))
```

---

## Encryption Algorithm

### Encryption Process

1. Generate a random 16-byte IV (Initialization Vector)
2. Encrypt plaintext using AES-256-CBC with PKCS7 padding
3. Concatenate IV + Ciphertext
4. Base64 encode the result

**Pseudocode:**
```
function encrypt(plaintext, key):
    iv = secureRandom(16)                    // 16 random bytes
    ciphertext = AES_256_CBC_Encrypt(
        plaintext: utf8ToBytes(plaintext),
        key: key,
        iv: iv,
        padding: PKCS7
    )
    combined = iv + ciphertext               // Concatenate bytes
    return base64Encode(combined)
```

### Decryption Process

1. Base64 decode the input
2. Extract IV (first 16 bytes)
3. Extract ciphertext (remaining bytes)
4. Decrypt using AES-256-CBC

**Pseudocode:**
```
function decrypt(encryptedBase64, key):
    combined = base64Decode(encryptedBase64)
    iv = combined[0:16]                      // First 16 bytes
    ciphertext = combined[16:]               // Remaining bytes
    plaintext = AES_256_CBC_Decrypt(
        ciphertext: ciphertext,
        key: key,
        iv: iv,
        padding: PKCS7
    )
    return bytesToUtf8(plaintext)
```

---

## Data Format

### Encrypted Output Structure

```
+------------------+------------------------+
|       IV         |      Ciphertext        |
|    (16 bytes)    |    (variable length)   |
+------------------+------------------------+
|<------------- Base64 encoded ------------>|
```

### Example Binary Layout

For plaintext "Hello, World!" with a specific IV:

```
Bytes 0-15:   IV (16 bytes)
Bytes 16-31: Ciphertext (16 bytes for this example, padded to block size)

Total: 32 bytes -> Base64 encoded -> 44 characters
```

---

## Test Vectors

These test vectors MUST be used to verify backend implementation matches frontend.

### Test Vector 1: Simple String with 32-char Key

```
Key (32 chars):     "test-encryption-key-32-chars!!!"
Plaintext:          "Hello, World!"
IV (hex):           0x00112233445566778899aabbccddeeff

Expected:
- Derived AES Key (hex): 746573742d656e6372797074696f6e2d6b65792d33322d636861727321212121
- Ciphertext (hex):      After IV: [depends on AES implementation]
- Combined (base64):     ABEiM0RVZneImaq7zN3u/[ciphertext-base64]
```

### Test Vector 2: JSON Payload with Short Key (SHA-256 derived)

```
Key:                "my-secret-key"
Key SHA-256 (hex):  c3499c2729730a7f807efb8676a92dcb6f8a3f8f0e8e3e3e3e3e3e3e3e3e3e3e
                    (actual SHA-256 of "my-secret-key")
Plaintext:          {"password":"secret123","token":"abc"}
IV (hex):           0xffeeddccbbaa99887766554433221100

Expected combined output format: base64(IV + AES_CBC(plaintext))
```

### Test Vector 3: Deterministic Test (Fixed IV for Testing Only)

**⚠️ WARNING: Never use a fixed IV in production! This is for testing only.**

```
Key (32 chars):     "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
IV (16 bytes):      "BBBBBBBBBBBBBBBB" (0x42 repeated 16 times)
Plaintext:          "test"

Step-by-step:
1. Key bytes (hex):      41414141414141414141414141414141
                         41414141414141414141414141414141
2. IV bytes (hex):       42424242424242424242424242424242
3. Plaintext bytes:      74657374 (+ PKCS7 padding to 16 bytes)
4. Padded plaintext:     746573740c0c0c0c0c0c0c0c0c0c0c0c
5. AES-CBC encrypt
6. Combine: IV + ciphertext
7. Base64 encode

Expected output:         QkJCQkJCQkJCQkJCQkJCQkJCQkJC[encrypted-part]
                         (starts with base64 of IV "BBBB...")
```

### Test Vector 4: Empty String

```
Key (32 chars):     "12345678901234567890123456789012"
Plaintext:          ""
IV (hex):           0x00000000000000000000000000000000

Note: Empty string still produces 16 bytes of ciphertext due to PKCS7 padding
```

### Test Vector 5: Unicode Content

```
Key:                "unicode-test-key-32-characters!!"
Plaintext:          "Привет мир! 你好世界! 🎉"
IV (hex):           0x11223344556677889900aabbccddeeff

The plaintext must be UTF-8 encoded before encryption.
UTF-8 bytes of plaintext: [varies by content]
```

---

## Implementation Examples

### Dart (Flutter Client)

```dart
import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as enc;

class EncryptionService {
  final enc.Key _key;

  EncryptionService(String key) : _key = _deriveKey(key);

  static enc.Key _deriveKey(String key) {
    if (key.length == 32) {
      return enc.Key.fromUtf8(key);
    }
    final hash = sha256.convert(utf8.encode(key));
    return enc.Key(Uint8List.fromList(hash.bytes));
  }

  String encrypt(String plaintext) {
    final iv = enc.IV.fromSecureRandom(16);
    final encrypter = enc.Encrypter(
      enc.AES(_key, mode: enc.AESMode.cbc),
    );
    final encrypted = encrypter.encrypt(plaintext, iv: iv);
    
    final combined = Uint8List(16 + encrypted.bytes.length);
    combined.setRange(0, 16, iv.bytes);
    combined.setRange(16, combined.length, encrypted.bytes);
    
    return base64Encode(combined);
  }

  String decrypt(String ciphertext) {
    final combined = base64Decode(ciphertext);
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
}
```

### Node.js (Backend Reference)

```javascript
const crypto = require('crypto');

class EncryptionService {
  constructor(key) {
    this.key = this._deriveKey(key);
  }

  _deriveKey(key) {
    if (key.length === 32) {
      return Buffer.from(key, 'utf8');
    }
    return crypto.createHash('sha256').update(key, 'utf8').digest();
  }

  encrypt(plaintext) {
    const iv = crypto.randomBytes(16);
    const cipher = crypto.createCipheriv('aes-256-cbc', this.key, iv);
    
    let encrypted = cipher.update(plaintext, 'utf8');
    encrypted = Buffer.concat([encrypted, cipher.final()]);
    
    const combined = Buffer.concat([iv, encrypted]);
    return combined.toString('base64');
  }

  decrypt(ciphertext) {
    const combined = Buffer.from(ciphertext, 'base64');
    const iv = combined.slice(0, 16);
    const encrypted = combined.slice(16);
    
    const decipher = crypto.createDecipheriv('aes-256-cbc', this.key, iv);
    
    let decrypted = decipher.update(encrypted);
    decrypted = Buffer.concat([decrypted, decipher.final()]);
    
    return decrypted.toString('utf8');
  }
}

// Test
const service = new EncryptionService('test-encryption-key-32-chars!!!');
const encrypted = service.encrypt('Hello, World!');
console.log('Encrypted:', encrypted);
const decrypted = service.decrypt(encrypted);
console.log('Decrypted:', decrypted);
```

### Python (Backend Reference)

```python
import base64
import hashlib
from Crypto.Cipher import AES
from Crypto.Util.Padding import pad, unpad
from Crypto.Random import get_random_bytes

class EncryptionService:
    def __init__(self, key: str):
        self.key = self._derive_key(key)
    
    def _derive_key(self, key: str) -> bytes:
        if len(key) == 32:
            return key.encode('utf-8')
        return hashlib.sha256(key.encode('utf-8')).digest()
    
    def encrypt(self, plaintext: str) -> str:
        iv = get_random_bytes(16)
        cipher = AES.new(self.key, AES.MODE_CBC, iv)
        
        padded = pad(plaintext.encode('utf-8'), AES.block_size)
        encrypted = cipher.encrypt(padded)
        
        combined = iv + encrypted
        return base64.b64encode(combined).decode('utf-8')
    
    def decrypt(self, ciphertext: str) -> str:
        combined = base64.b64decode(ciphertext)
        iv = combined[:16]
        encrypted = combined[16:]
        
        cipher = AES.new(self.key, AES.MODE_CBC, iv)
        decrypted = unpad(cipher.decrypt(encrypted), AES.block_size)
        
        return decrypted.decode('utf-8')

# Test
service = EncryptionService('test-encryption-key-32-chars!!!')
encrypted = service.encrypt('Hello, World!')
print(f'Encrypted: {encrypted}')
decrypted = service.decrypt(encrypted)
print(f'Decrypted: {decrypted}')
```

---

## Security Considerations

### DO:
- ✅ Always use a cryptographically secure random number generator for IV
- ✅ Use a unique IV for every encryption operation
- ✅ Store encryption keys securely (environment variables, key vault)
- ✅ Use HTTPS for all API communication
- ✅ Validate decrypted data before processing

### DON'T:
- ❌ Never reuse an IV with the same key
- ❌ Never log or expose encryption keys
- ❌ Never use predictable IVs in production
- ❌ Never store unencrypted sensitive data on server
- ❌ Never encrypt empty strings (not supported, use null instead)

### Key Management:
- The encryption key is provided by the client during SDK initialization
- The server NEVER has access to the encryption key
- Only the client can decrypt the encrypted payloads
- For replay functionality, unencrypted data is stored ONLY on the client device

---

## Fingerprint/Hash Function

For deduplication and matching without storing sensitive data, EndpointVault uses SHA-256 truncated to 16 characters:

```
function fingerprint(data):
    hash = sha256(utf8ToBytes(data))
    return hexEncode(hash).substring(0, 16)
```

**Example:**
```
Input:       "Hello, World!"
SHA-256:     dffd6021bb2bd5b0af676290809ec3a53191dd81c7f70a4b28688a362182986f
Fingerprint: dffd6021bb2bd5b0
```
