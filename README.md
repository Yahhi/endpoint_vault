# EndpointVault

[![pub package](https://img.shields.io/pub/v/endpoint_vault.svg)](https://pub.dev/packages/endpoint_vault)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)

**Encrypted endpoint failure capture, reliability statistics, and recovery tools for Flutter apps.**

EndpointVault helps you stop losing valuable user data when API requests fail. Capture critical failures with client-side encryption, track endpoint reliability, and recover failed requests — all while keeping sensitive data secure.

🌐 **[endpoint.yahhi.me](https://endpoint.yahhi.me)** — Dashboard, documentation, and backend setup

## Features

- **Encrypted Capture** — Payloads are encrypted client-side before storage
- **Automatic Redaction** — Sensitive fields (passwords, tokens, PII) are redacted by default
- **Endpoint Statistics** — Track error rates, status codes, and latency per endpoint
- **Dio Integration** — Drop-in interceptor for automatic capture
- **Offline Queue** — Queue events when offline, sync when connected
- **Device-side Replay** — Re-execute failed requests with fresh auth tokens
- **Serverpod Backend** — Open-source, self-hostable on your AWS

## Quick Start

### 1. Install

```yaml
dependencies:
  endpoint_vault: ^0.1.0
```

### 2. Initialize

```dart
import 'package:endpoint_vault/endpoint_vault.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await EndpointVault.init(
    apiKey: 'your-api-key',
    encryptionKey: 'your-32-character-encryption-key',
    environment: 'production',
    appVersion: '1.0.0',
  );

  runApp(MyApp());
}
```

### 3. Add Dio Interceptor

```dart
final dio = Dio();
dio.interceptors.add(EndpointVaultInterceptor());
```

### 4. Mark Critical Requests

```dart
// Option 1: Use extra parameter
dio.post('/api/payment',
  data: paymentData,
  options: Options(extra: {'ev_critical': true}),
);

// Option 2: Use extension method
dio.post('/api/payment',
  data: paymentData,
  options: Options().critical(context: 'checkout_flow'),
);
```

That's it! Failed critical requests are now captured with encryption.

## Configuration

### Full Configuration Options

```dart
await EndpointVault.init(
  // Required
  apiKey: 'your-api-key',
  encryptionKey: 'your-32-character-key',

  // Optional
  serverUrl: 'https://api.endpoint.yahhi.me', // Your server if self-hosted
  environment: 'production',                    // production, staging, development
  appVersion: '1.0.0',                          // For regression tracking
  captureSuccessStats: true,                    // Capture success metrics (no payload)
  enableOfflineQueue: true,                     // Queue events when offline
  maxOfflineQueueSize: 100,                     // Max queued events
  debug: false,                                 // Console logging

  // Redaction rules
  redaction: RedactionConfig(
    redactHeaders: ['authorization', 'x-api-key', 'cookie'],
    redactBodyFields: ['password', 'token', 'credit_card', 'ssn'],
    redactQueryParams: ['token', 'key', 'secret'],
    redactAuthorizationHeader: true,
    customPatterns: [
      RedactionPatterns.creditCard,
      RedactionPatterns.email,
    ],
  ),

  // Retry behavior
  retry: RetryConfig(
    maxRetries: 3,
    initialDelay: Duration(seconds: 1),
    maxDelay: Duration(seconds: 30),
  ),
);
```

### Interceptor Options

```dart
dio.interceptors.add(EndpointVaultInterceptor(
  // Only capture requests marked with ev_critical: true
  onlyCritical: true,

  // Capture success statistics (default: true)
  captureSuccessStats: true,

  // Custom filter for which requests to capture
  shouldCapture: (request) {
    return !request.uri.path.contains('/health');
  },

  // Custom filter for critical requests
  isCritical: (request) {
    return request.uri.path.contains('/payment') ||
           request.uri.path.contains('/order');
  },
));
```

## Encryption

EndpointVault uses AES-256 encryption. Your encryption key never leaves the device — only encrypted payloads are sent to the server.

### Key Management

```dart
// Use a strong 32-character key
const encryptionKey = 'your-32-character-secure-key!!!';

// Or derive from a shorter key (hashed with SHA-256)
const shortKey = 'my-password';
// SDK automatically derives a 32-byte key using SHA-256
```

### Manual Encryption

```dart
final encryption = EncryptionService('your-encryption-key');

// Encrypt
final encrypted = encryption.encrypt('sensitive data');

// Decrypt
final decrypted = encryption.decrypt(encrypted);

// JSON
final encryptedJson = encryption.encryptJson({'user': 'data'});
final decryptedJson = encryption.decryptJson(encryptedJson);
```

## Redaction

Sensitive data is automatically redacted before capture.

### Default Redacted Fields

**Headers:**
- `Authorization`
- `X-API-Key`
- `X-Auth-Token`
- `Cookie`
- `Set-Cookie`

**Body Fields:**
- `password`
- `token`
- `refresh_token`
- `access_token`
- `secret`
- `api_key`
- `credit_card`
- `cvv`
- `ssn`

### Custom Redaction

```dart
RedactionConfig(
  // Add custom header redaction
  redactHeaders: [
    ...RedactionConfig().redactHeaders,
    'x-custom-secret',
  ],

  // Add custom body field redaction
  redactBodyFields: [
    ...RedactionConfig().redactBodyFields,
    'social_security_number',
    'bank_account',
  ],

  // Use regex patterns
  customPatterns: [
    RedactionPatterns.creditCard,
    RedactionPatterns.email,
    RedactionPatterns.phone,
    RegExp(r'CUSTOM-\d{8}'), // Custom pattern
  ],
)
```

## Device-side Replay

When server-side replay isn't possible (e.g., requests require fresh auth tokens), use device-side replay.

### Setup Replay Handler

```dart
final replayHandler = ReplayHandler(
  dio,
  refreshAuth: () async {
    // Return fresh auth headers
    final token = await authService.getFreshToken();
    return {'Authorization': 'Bearer $token'};
  },
  onReplayRequested: (request) {
    print('Replay requested: ${request.method} ${request.url}');
  },
  onReplayComplete: (request, success) {
    print('Replay ${success ? 'succeeded' : 'failed'}');
  },
);

// Check for pending replays on app resume
void onAppResumed() async {
  await replayHandler.checkAndExecute();
}
```

### Manual Replay

```dart
final request = await EndpointVault.instance.checkForReplayRequest();
if (request != null) {
  try {
    final response = await replayHandler.executeReplay(
      request,
      additionalHeaders: {'X-Retry': 'true'},
    );
    print('Replay succeeded: ${response.statusCode}');
  } catch (e) {
    print('Replay failed: $e');
  }
}
```

## Offline Support

Events are automatically queued when offline and synced when connection is restored.

```dart
await EndpointVault.init(
  // ... other config
  enableOfflineQueue: true,
  maxOfflineQueueSize: 100, // Keep last 100 events
);
```

## Event Stream

Monitor captured events in real-time (useful for debugging):

```dart
EndpointVault.instance.eventStream.listen((event) {
  print('Captured: ${event.method} ${event.url}');
  print('Status: ${event.statusCode}');
  print('Error: ${event.errorType}');
});
```

## Self-Hosting

EndpointVault backend is built on [Serverpod](https://serverpod.dev) and can be self-hosted on your AWS infrastructure.

```dart
await EndpointVault.init(
  apiKey: 'your-api-key',
  encryptionKey: 'your-encryption-key',
  serverUrl: 'https://your-self-hosted-server.com',
);
```

See [endpoint.yahhi.me/docs/self-hosting](https://endpoint.yahhi.me/docs/self-hosting) for deployment guides.

## Example

```dart
import 'package:dio/dio.dart';
import 'package:endpoint_vault/endpoint_vault.dart';
import 'package:flutter/material.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize EndpointVault
  await EndpointVault.init(
    apiKey: 'ev_live_xxxxx',
    encryptionKey: 'your-32-char-encryption-key!!!!',
    environment: 'production',
    appVersion: '1.0.0',
    debug: true,
  );

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  // Create Dio instance with EndpointVault interceptor
  final dio = Dio()..interceptors.add(EndpointVaultInterceptor());

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: ElevatedButton(
            onPressed: () => _makePayment(),
            child: Text('Pay Now'),
          ),
        ),
      ),
    );
  }

  Future<void> _makePayment() async {
    try {
      // Critical request - will be captured on failure
      await dio.post(
        'https://api.example.com/payment',
        data: {
          'amount': 99.99,
          'currency': 'USD',
          'card_number': '4111111111111111', // Will be redacted
        },
        options: Options().critical(context: 'checkout'),
      );
    } on DioException catch (e) {
      // Error is automatically captured by EndpointVault
      print('Payment failed: ${e.message}');
    }
  }
}
```

## How It Works

1. **Initialize** — SDK fetches server settings and sets up encryption
2. **Intercept** — Dio interceptor captures all requests automatically
3. **Process** — On failure: redact sensitive data → encrypt payload → send to server
4. **Store** — Server stores encrypted data (only you can decrypt with your key)
5. **Retry** — If server unavailable, queue locally and retry with exponential backoff
6. **Replay** — Optionally replay failed requests from device with fresh auth tokens

For detailed architecture and data flow, visit [endpoint.yahhi.me/docs/how-it-works](https://endpoint.yahhi.me/docs/how-it-works).

## Dashboard

View your endpoint statistics and captured events at [endpoint.yahhi.me](https://endpoint.yahhi.me).

- **Endpoint Stats** — Error rates, latency, status code distribution
- **Event Browser** — Search and filter captured events  
- **Replay Tools** — Server-side or device-side replay
- **Alerts** — Email, Slack, and webhook notifications
- **API Keys** — Manage your API keys and encryption settings

## Backend & API

EndpointVault backend is built on [Serverpod](https://serverpod.dev). You can use our hosted service or self-host on your infrastructure.

- **Hosted Service** — [endpoint.yahhi.me](https://endpoint.yahhi.me) (recommended for quick start)
- **Self-Hosting Guide** — [endpoint.yahhi.me/docs/self-hosting](https://endpoint.yahhi.me/docs/self-hosting)
- **API Documentation** — [endpoint.yahhi.me/docs/api](https://endpoint.yahhi.me/docs/api)

## Support

- **Documentation** — [endpoint.yahhi.me/docs](https://endpoint.yahhi.me/docs)
- **Getting Started** — [endpoint.yahhi.me/docs/getting-started](https://endpoint.yahhi.me/docs/getting-started)
- **GitHub Issues** — [github.com/endpointvault/endpoint_vault_flutter/issues](https://github.com/endpointvault/endpoint_vault_flutter/issues)
- **Email** — support@endpoint.yahhi.me

## License

MIT License - see [LICENSE](LICENSE) for details.
