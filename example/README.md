# EndpointVault Example

A complete example demonstrating how to use the EndpointVault SDK.

## Features Demonstrated

1. **SDK Initialization** — Setting up EndpointVault with API key and encryption key
2. **Dio Interceptor** — Automatic request capture for success and failure
3. **Critical Requests** — Marking important requests for priority capture
4. **Server Settings** — Checking `localResendEnabled` status
5. **Retry Queue** — Viewing pending retry count
6. **Local Events** — Accessing locally stored events (when local resend enabled)
7. **Event Stream** — Listening to captured events in real-time

## Running the Example

```bash
cd example
flutter pub get
flutter run
```

## Usage

1. **Success (200)** — Makes a successful GET request, captures stats only
2. **Failure (500)** — Makes a failing request, captures encrypted payload + stats
3. **Critical (503)** — Makes a critical POST request with payment data
4. **Network Error** — Simulates network failure (invalid host)
5. **View Local** — Shows locally stored events (if local resend enabled)

## Configuration

Update `main.dart` with your actual credentials:

```dart
await EndpointVault.init(
  apiKey: 'your-actual-api-key',
  encryptionKey: 'your-32-char-encryption-key!!!',
);
```

Get your API key at [endpoint.yahhi.me](https://endpoint.yahhi.me).

## Learn More

- **Documentation** — [endpoint.yahhi.me/docs](https://endpoint.yahhi.me/docs)
- **Getting Started** — [endpoint.yahhi.me/docs/getting-started](https://endpoint.yahhi.me/docs/getting-started)
- **API Reference** — [endpoint.yahhi.me/docs/api](https://endpoint.yahhi.me/docs/api)
