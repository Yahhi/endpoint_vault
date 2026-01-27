/// EndpointVault - Encrypted endpoint failure capture for Flutter
///
/// A Flutter SDK for capturing critical API failures with encryption,
/// endpoint reliability statistics, and recovery tools.
///
/// ## Quick Start
///
/// ```dart
/// import 'package:endpoint_vault/endpoint_vault.dart';
///
/// // Initialize in main()
/// await EndpointVault.init(
///   apiKey: 'your-api-key',
///   encryptionKey: 'your-encryption-key',
/// );
///
/// // Add interceptor to Dio
/// final dio = Dio();
/// dio.interceptors.add(EndpointVaultInterceptor());
///
/// // Mark critical requests
/// dio.get('/api/payment', options: Options(
///   extra: {'ev_critical': true},
/// ));
/// ```
///
/// See https://endpoint.yahhi.me/docs for full documentation.
library endpoint_vault;

export 'src/endpoint_vault_client.dart';
export 'src/dio_interceptor.dart';
export 'src/config.dart';
export 'src/models/captured_event.dart';
export 'src/models/event_package.dart';
export 'src/models/server_settings.dart';
export 'src/models/server_response.dart';
export 'src/models/pending_request.dart';
export 'src/encryption/encryption_service.dart';
export 'src/redaction/redaction_rules.dart';
export 'src/services/server_settings_service.dart';
export 'src/services/retry_manager.dart';
export 'src/storage/local_event_storage.dart';
