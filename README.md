# EndpointVault

[![pub package](https://img.shields.io/pub/v/endpoint_vault.svg)](https://pub.dev/packages/endpoint_vault)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)

**Encrypted endpoint failure capture for Flutter apps.**

Stop losing user data when API calls fail. EndpointVault captures critical failures with client-side encryption, tracks endpoint reliability, and enables request replay.

## Quick Start

```yaml
dependencies:
  endpoint_vault: ^0.1.0
```

```dart
import 'package:endpoint_vault/endpoint_vault.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await EndpointVault.init(
    apiKey: 'your-api-key',
    encryptionKey: 'your-32-character-key',
  );

  runApp(MyApp());
}
```

```dart
final dio = Dio();
dio.interceptors.add(EndpointVaultInterceptor());

// Mark critical requests
await dio.post('/api/payment',
  data: paymentData,
  options: Options().critical(),
);
```

## Features

- **Encrypted Capture** — AES-256 client-side encryption
- **File Attachments** — Capture FormData file uploads
- **Automatic Redaction** — Strip passwords, tokens, PII
- **Offline Queue** — Queue events when offline
- **Device-side Replay** — Re-execute failed requests
- **Replay Success Callbacks** — Continue workflows after successful replays

## Replay Success Callbacks

For workflows that depend on response data (like file uploads), use the `onReplaySuccess` callback to continue processing after a successful replay:

```dart
// Using the interceptor with Options extension
await dio.post(
  '/api/get-upload-urls',
  data: {'files': fileNames},
  options: Options().critical().onReplaySuccess((response) async {
    // Called when the request is successfully replayed
    final urls = response.data['uploadUrls'] as List;
    for (var i = 0; i < urls.length; i++) {
      await uploadFile(files[i], urls[i]);
    }
  }),
);

// Or using captureFailure directly
await EndpointVault.instance.captureFailure(
  method: 'POST',
  url: 'https://api.example.com/upload-urls',
  statusCode: 500,
  errorType: 'server_error',
  onReplaySuccess: (response) async {
    // Extract URLs and upload files
    final urls = response.data['uploadUrls'] as List;
    await uploadFilesToUrls(urls);
  },
);

// Execute a replay manually
final replayRequest = await EndpointVault.instance.checkForReplayRequest();
if (replayRequest != null) {
  await EndpointVault.instance.executeReplay(
    replayRequest: replayRequest,
    dio: myAppDio,  // Your app's Dio instance
  );
}
```

## Documentation

Full documentation at **[endpoint.yahhi.me/docs](https://endpoint.yahhi.me/docs)**

- [Getting Started](https://endpoint.yahhi.me/docs/getting-started.html)
- [Configuration](https://endpoint.yahhi.me/docs/configuration.html)
- [File Attachments](https://endpoint.yahhi.me/docs/file-attachments.html)
- [Encryption](https://endpoint.yahhi.me/docs/encryption.html)
- [Redaction](https://endpoint.yahhi.me/docs/redaction.html)
- [Device-side Replay](https://endpoint.yahhi.me/docs/replay.html)
- [Self-Hosting](https://endpoint.yahhi.me/docs/self-hosting.html)
- [API Reference](https://endpoint.yahhi.me/docs/api-reference.html)

## Links

- **Website:** [endpoint.yahhi.me](https://endpoint.yahhi.me)
- **Dashboard:** [endpoint.yahhi.me/dashboard](https://endpoint.yahhi.me/dashboard)
- **GitHub:** [github.com/Yahhi/endpoint_vault](https://github.com/Yahhi/endpoint_vault)

## License

MIT License - see [LICENSE](LICENSE) for details.
