# EndpointVault SDK - How It Works

A step-by-step guide explaining how the EndpointVault SDK captures, encrypts, and stores API failure data.

## Table of Contents

1. [Overview](#overview)
2. [Step 1: Initialize the SDK](#step-1-initialize-the-sdk)
3. [Step 2: Connect the Interceptor](#step-2-connect-the-interceptor)
4. [Step 3: How Requests Are Captured](#step-3-how-requests-are-captured)
5. [Step 4: Data Processing Flow](#step-4-data-processing-flow)
6. [Step 5: What Gets Stored](#step-5-what-gets-stored)
7. [Step 6: Retry Mechanism](#step-6-retry-mechanism)
8. [Step 7: Local Replay (Optional)](#step-7-local-replay-optional)
9. [Complete Flow Diagram](#complete-flow-diagram)

---

## Overview

EndpointVault is a Flutter SDK that:
- Captures API failures automatically via Dio interceptor
- Encrypts sensitive data client-side (server never sees plaintext)
- Sends encrypted data + statistics to EndpointVault server
- Optionally stores unencrypted data locally for replay (if enabled by server)
- Handles offline scenarios with automatic retry

---

## Step 1: Initialize the SDK

**When:** At app startup, in `main()` before `runApp()`

**Code:**
```dart
import 'package:endpoint_vault/endpoint_vault.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize EndpointVault
  await EndpointVault.init(
    apiKey: 'your-api-key',           // From EndpointVault dashboard
    encryptionKey: 'your-32-char-key', // Your secret encryption key
    environment: 'production',         // or 'staging', 'development'
    appVersion: '1.2.3',              // Your app version
    debug: false,                      // Set true for console logs
  );
  
  runApp(MyApp());
}
```

**What happens during init:**

1. **Creates encryption service** with your key (AES-256-CBC)
2. **Fetches server settings** from `GET /v1/settings`
   - Gets `localResendEnabled` flag
   - Caches settings locally
3. **Generates/retrieves device ID** (stored in SharedPreferences)
4. **Initializes SQLite databases** for:
   - Pending requests (retry queue)
   - Local event storage (if local resend enabled)
5. **Starts retry processor** for any queued requests from previous sessions

**Server settings response:**
```json
{
  "localResendEnabled": true
}
```

---

## Step 2: Connect the Interceptor

**When:** When creating your Dio instance(s)

**Code:**
```dart
import 'package:dio/dio.dart';
import 'package:endpoint_vault/endpoint_vault.dart';

final dio = Dio(BaseOptions(
  baseUrl: 'https://api.yourapp.com',
));

// Add EndpointVault interceptor
dio.interceptors.add(EndpointVaultInterceptor(
  onlyCritical: false,        // Capture all failures (not just critical)
  captureSuccessStats: true,  // Also capture success metrics
));
```

**What the interceptor does:**

| Event | Action |
|-------|--------|
| `onRequest` | Records request start time |
| `onResponse` | Captures success stats (method, URL, status, duration) |
| `onError` | Captures full failure data (headers, body, error details) |

**Marking critical requests:**
```dart
// Option 1: Using extra parameter
dio.post('/api/payment', 
  data: paymentData,
  options: Options(extra: {'ev_critical': true}),
);

// Option 2: Using extension method
dio.post('/api/payment',
  data: paymentData,
  options: Options().critical(context: 'checkout_flow'),
);
```

---

## Step 3: How Requests Are Captured

### Successful Request (2xx status)

```
App makes request → Dio sends → Server responds 200 → Interceptor captures
                                                              ↓
                                                    StatisticalPackage only
                                                    (method, url, status, duration)
                                                              ↓
                                                    POST /v1/events/stats
```

**Data sent to server:**
```json
{
  "eventId": "uuid",
  "timestamp": "2024-01-15T10:30:00.000Z",
  "method": "GET",
  "url": "https://api.yourapp.com/users/123",
  "statusCode": 200,
  "durationMs": 150,
  "environment": "production",
  "appVersion": "1.2.3",
  "deviceId": "device-uuid",
  "isSuccess": true
}
```

### Failed Request (4xx, 5xx, network error)

```
App makes request → Dio sends → Error occurs → Interceptor captures
                                                       ↓
                                            Redaction applied to headers/body
                                                       ↓
                                            Encryption applied (AES-256-CBC)
                                                       ↓
                                            EncryptedPackage + StatisticalPackage
                                                       ↓
                                            POST /v1/events
```

**Data sent to server:**
```json
{
  "encrypted": {
    "eventId": "uuid",
    "timestamp": "2024-01-15T10:30:00.000Z",
    "method": "POST",
    "url": "https://api.yourapp.com/users",
    "encrypted": true,
    "statusCode": 500,
    "errorType": "bad_response",
    "errorMessage": "Internal Server Error",
    "requestHeaders": "BASE64_ENCRYPTED_DATA",
    "requestBody": "BASE64_ENCRYPTED_DATA",
    "responseHeaders": "BASE64_ENCRYPTED_DATA",
    "responseBody": "BASE64_ENCRYPTED_DATA",
    "durationMs": 1234,
    "environment": "production",
    "appVersion": "1.2.3",
    "deviceId": "device-uuid"
  },
  "stats": {
    "eventId": "uuid",
    "timestamp": "2024-01-15T10:30:00.000Z",
    "method": "POST",
    "url": "https://api.yourapp.com/users",
    "statusCode": 500,
    "durationMs": 1234,
    "isSuccess": false,
    "errorType": "bad_response"
  }
}
```

---

## Step 4: Data Processing Flow

### Redaction (Before Encryption)

Sensitive fields are automatically redacted before encryption:

**Headers redacted:**
- `authorization`
- `x-api-key`
- `x-auth-token`
- `cookie`, `set-cookie`

**Body fields redacted:**
- `password`, `token`, `refresh_token`, `access_token`
- `secret`, `api_key`, `apiKey`
- `credit_card`, `creditCard`, `cvv`, `ssn`

**Example:**
```
Original: {"email": "user@example.com", "password": "secret123"}
Redacted: {"email": "user@example.com", "password": "[REDACTED]"}
```

### Encryption

After redaction, data is encrypted using AES-256-CBC:

```
Plaintext JSON → UTF-8 bytes → AES-256-CBC encrypt → IV + Ciphertext → Base64
```

**Key derivation:**
- If key is 32 characters: used directly
- If key is other length: SHA-256 hash produces 32-byte key

**Output format:**
```
Base64( IV[16 bytes] + Ciphertext[variable] )
```

---

## Step 5: What Gets Stored

### On EndpointVault Server (Always)

| Data | Encrypted? | Purpose |
|------|------------|---------|
| Event metadata | No | Indexing, search |
| Request/response headers | **Yes** | Debug with decryption |
| Request/response body | **Yes** | Debug with decryption |
| Statistics | No | Analytics, dashboards |

**Important:** Server cannot decrypt data without your encryption key!

### On Device - SQLite Database

**Table: `pending_requests`** (retry queue)
```
- id: TEXT PRIMARY KEY
- event_id: TEXT
- created_at: INTEGER (timestamp)
- attempt_count: INTEGER
- retry_id: TEXT (from server)
- next_retry_at: INTEGER (timestamp)
- payload: TEXT (JSON with encrypted packages)
```

**Table: `local_events`** (only if `localResendEnabled = true`)
```
- event_id: TEXT PRIMARY KEY
- timestamp: INTEGER
- payload: TEXT (JSON, UNENCRYPTED)
```

### Storage Summary

| Condition | Server Storage | Local Storage |
|-----------|---------------|---------------|
| Success request | Stats only | Nothing |
| Error, server available | Encrypted + Stats | Unencrypted (if local resend enabled) |
| Error, server unavailable | Queued for retry | Unencrypted (if local resend enabled) |

---

## Step 6: Retry Mechanism

When server is unavailable (no internet, server down):

```
Request fails → Try to send to EndpointVault → Network error
                                                    ↓
                                          Save to pending_requests table
                                                    ↓
                                          Schedule retry (exponential backoff)
                                                    ↓
                                          5s → 10s → 20s → 40s... (max 3 attempts)
```

**Retry with server command:**

Server can request specific retry behavior:
```json
{
  "success": true,
  "retry": {
    "retryId": "retry-123",
    "commandType": "send_event",
    "delayMs": 10000,
    "maxAttempts": 5
  }
}
```

The `retryId` allows server to track specific retry attempts.

---

## Step 7: Local Replay (Optional)

**Only available when `localResendEnabled = true` (server setting)**

### Purpose
Allow developers to replay failed requests from the original device for debugging.

### How it works

1. **Error occurs** → Unencrypted data stored locally
2. **Developer requests replay** via dashboard
3. **App checks for pending replays:**
   ```dart
   final replay = await EndpointVault.instance.checkForReplayRequest();
   if (replay != null) {
     // Execute the original request again
     final response = await dio.request(
       replay.url,
       options: Options(method: replay.method, headers: replay.headers),
       data: replay.body,
     );
     
     // Report result
     await EndpointVault.instance.reportReplayResult(
       replayId: replay.id,
       success: response.statusCode == 200,
       statusCode: response.statusCode,
     );
   }
   ```

### Local storage access
```dart
// Get all locally stored events
final events = await EndpointVault.instance.getLocalEvents();

// Get specific event
final event = await EndpointVault.instance.getLocalEvent('event-id');

// Remove after successful replay
await EndpointVault.instance.removeLocalEvent('event-id');
```

---

## Complete Flow Diagram

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              APP STARTUP                                     │
├─────────────────────────────────────────────────────────────────────────────┤
│  1. EndpointVault.init()                                                    │
│     ├── Create EncryptionService (AES-256-CBC)                              │
│     ├── Fetch server settings (GET /v1/settings)                            │
│     │   └── localResendEnabled: true/false                                  │
│     ├── Initialize SQLite databases                                         │
│     └── Start retry processor                                               │
│                                                                             │
│  2. Add interceptor to Dio                                                  │
│     dio.interceptors.add(EndpointVaultInterceptor())                        │
└─────────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                           API REQUEST MADE                                   │
├─────────────────────────────────────────────────────────────────────────────┤
│  dio.post('/api/users', data: userData)                                     │
│     │                                                                       │
│     ├── Interceptor.onRequest() → Record start time                         │
│     │                                                                       │
│     ▼                                                                       │
│  ┌─────────────┐                                                            │
│  │   SUCCESS   │ ──► Interceptor.onResponse()                               │
│  │   (2xx)     │     └── captureSuccess() → POST /v1/events/stats           │
│  └─────────────┘         (stats only, no encryption)                        │
│                                                                             │
│  ┌─────────────┐                                                            │
│  │   FAILURE   │ ──► Interceptor.onError()                                  │
│  │ (4xx/5xx/   │     │                                                      │
│  │  network)   │     ├── Redact sensitive fields                            │
│  └─────────────┘     ├── Encrypt headers/body (AES-256-CBC)                 │
│                      ├── If localResendEnabled: store unencrypted locally   │
│                      └── Try POST /v1/events                                │
│                          │                                                  │
│                          ├── Success → Done                                 │
│                          └── Failure → Queue for retry                      │
└─────────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                            DATA STORAGE                                      │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐    │
│  │                    ENDPOINTVAULT SERVER                              │    │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐                  │    │
│  │  │  Encrypted  │  │  Encrypted  │  │ Statistics  │                  │    │
│  │  │  Headers    │  │    Body     │  │  (plain)    │                  │    │
│  │  └─────────────┘  └─────────────┘  └─────────────┘                  │    │
│  │        ▲                ▲                                            │    │
│  │        │                │                                            │    │
│  │   Only decryptable with YOUR encryption key                          │    │
│  └─────────────────────────────────────────────────────────────────────┘    │
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐    │
│  │                    DEVICE (SQLite)                                   │    │
│  │                                                                      │    │
│  │  pending_requests table:     local_events table:                     │    │
│  │  ├── Encrypted packages      ├── Unencrypted data                    │    │
│  │  ├── Retry metadata          ├── Only if localResendEnabled          │    │
│  │  └── Exponential backoff     └── For local replay                    │    │
│  └─────────────────────────────────────────────────────────────────────┘    │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Quick Reference

### Initialization
```dart
await EndpointVault.init(
  apiKey: 'your-api-key',
  encryptionKey: 'your-32-char-encryption-key!!!',
);
```

### Add Interceptor
```dart
dio.interceptors.add(EndpointVaultInterceptor());
```

### Mark Critical Request
```dart
dio.post('/payment', options: Options(extra: {'ev_critical': true}));
```

### Check Status
```dart
final pendingCount = await EndpointVault.instance.pendingRetryCount;
final localCount = await EndpointVault.instance.localEventCount;
print('Pending retries: $pendingCount, Local events: $localCount');
```

### Refresh Settings
```dart
await EndpointVault.instance.refreshSettings();
print('Local resend enabled: ${EndpointVault.instance.localResendEnabled}');
```

### Cleanup
```dart
EndpointVault.instance.dispose();
```
