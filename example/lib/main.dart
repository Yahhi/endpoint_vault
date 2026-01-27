import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:endpoint_vault/endpoint_vault.dart';

/// EndpointVault Example App
///
/// This example demonstrates:
/// 1. SDK initialization with API key and encryption key
/// 2. Dio interceptor setup for automatic request capture
/// 3. Success vs failure request handling
/// 4. Critical request marking
/// 5. Server settings (local resend enabled)
/// 6. Retry queue status
/// 7. Local event storage access

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ============================================================
  // STEP 1: Initialize EndpointVault SDK
  // ============================================================
  // This should be done once at app startup, before runApp()
  //
  // Required parameters:
  // - apiKey: Your API key from EndpointVault dashboard
  // - encryptionKey: Your secret key for AES-256 encryption
  //   (32 chars used directly, other lengths are SHA-256 hashed)
  //
  // Optional parameters shown below with their defaults:
  await EndpointVault.init(
    apiKey: 'your-api-key-from-dashboard',
    encryptionKey: 'your-32-char-encryption-key!!!',
    environment: 'development', // 'production', 'staging', etc.
    appVersion: '1.0.0',
    captureSuccessStats: true, // Also capture successful requests (stats only)
    enableOfflineQueue: true, // Queue failed uploads for retry
    maxOfflineQueueSize: 100, // Max events in retry queue
    debug: true, // Enable console logging for this example
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EndpointVault Example',
      theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple), useMaterial3: true),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final Dio _dio;
  String _status = 'Ready';
  final List<String> _logs = [];

  // SDK status info
  bool _localResendEnabled = false;
  int _pendingRetries = 0;
  int _localEvents = 0;

  @override
  void initState() {
    super.initState();
    _setupDio();
    _updateSdkStatus();
  }

  void _setupDio() {
    // Create Dio instance
    _dio = Dio(BaseOptions(connectTimeout: const Duration(seconds: 10), receiveTimeout: const Duration(seconds: 10)));

    // ============================================================
    // STEP 2: Add EndpointVault Interceptor
    // ============================================================
    // The interceptor automatically captures:
    // - Success requests: stats only (method, url, status, duration)
    // - Failed requests: full encrypted payload + stats
    //
    // Options:
    // - onlyCritical: if true, only capture requests marked as critical
    // - captureSuccessStats: capture stats for successful requests
    _dio.interceptors.add(
      EndpointVaultInterceptor(
        onlyCritical: false, // Capture all failures
        captureSuccessStats: true, // Also capture success stats
      ),
    );

    // ============================================================
    // STEP 3: Listen to Event Stream (Optional)
    // ============================================================
    // You can listen to captured events for debugging/UI updates
    EndpointVault.instance.eventStream.listen((event) {
      _addLog(
        '[${event.isSuccess ? 'SUCCESS' : 'FAILURE'}] '
        '${event.method} ${event.url} → ${event.statusCode ?? 'N/A'}',
        isError: !event.isSuccess,
      );
      _updateSdkStatus();
    });
  }

  Future<void> _updateSdkStatus() async {
    final pendingRetries = await EndpointVault.instance.pendingRetryCount;
    final localEvents = await EndpointVault.instance.localEventCount;

    setState(() {
      _localResendEnabled = EndpointVault.instance.localResendEnabled;
      _pendingRetries = pendingRetries;
      _localEvents = localEvents;
    });
  }

  void _addLog(String message, {bool isError = false}) {
    setState(() {
      _logs.insert(0, '${DateTime.now().toIso8601String().substring(11, 19)} $message');
      if (_logs.length > 50) _logs.removeLast();
    });
  }

  // ============================================================
  // STEP 4: Make Requests - They're Automatically Captured
  // ============================================================

  Future<void> _makeSuccessRequest() async {
    setState(() => _status = 'Making GET request...');
    try {
      final response = await _dio.get('https://httpbin.org/get');
      setState(() => _status = 'Success: ${response.statusCode}');
    } catch (e) {
      setState(() => _status = 'Failed: $e');
    }
  }

  Future<void> _makeFailureRequest() async {
    setState(() => _status = 'Making failing request (500)...');
    try {
      await _dio.get('https://httpbin.org/status/500');
      setState(() => _status = 'Unexpected success');
    } catch (e) {
      setState(() => _status = 'Failed as expected (500)');
    }
  }

  Future<void> _makeCriticalRequest() async {
    setState(() => _status = 'Making CRITICAL request...');
    try {
      // ============================================================
      // STEP 5: Mark Critical Requests
      // ============================================================
      // Use extra: {'ev_critical': true} to mark important requests
      // Or use the extension method: Options().critical()
      await _dio.post(
        'https://httpbin.org/status/503',
        data: {'payment_id': '12345', 'amount': 99.99},
        options: Options(
          extra: {
            'ev_critical': true,
            'ev_context': 'payment_checkout', // Optional context
          },
        ),
      );
      setState(() => _status = 'Unexpected success');
    } catch (e) {
      setState(() => _status = 'Critical failure captured');
    }
  }

  Future<void> _makeNetworkErrorRequest() async {
    setState(() => _status = 'Making request to invalid host...');
    try {
      await _dio.get('https://invalid-host-that-does-not-exist.local/api');
      setState(() => _status = 'Unexpected success');
    } catch (e) {
      setState(() => _status = 'Network error captured');
    }
  }

  Future<void> _refreshSettings() async {
    setState(() => _status = 'Refreshing server settings...');
    await EndpointVault.instance.refreshSettings();
    await _updateSdkStatus();
    setState(() => _status = 'Settings refreshed');
    _addLog('Server settings refreshed');
  }

  Future<void> _viewLocalEvents() async {
    // ============================================================
    // STEP 6: Access Local Events (if local resend enabled)
    // ============================================================
    final events = await EndpointVault.instance.getLocalEvents();
    if (events.isEmpty) {
      _addLog('No local events stored');
    } else {
      _addLog('Local events: ${events.length}');
      for (final event in events.take(3)) {
        _addLog('  → ${event.method} ${event.url}');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('EndpointVault Example'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _refreshSettings, tooltip: 'Refresh Settings'),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Status: $_status', style: const TextStyle(fontWeight: FontWeight.bold)),
                    const Divider(),
                    _buildStatusRow('Local Resend', _localResendEnabled ? 'Enabled' : 'Disabled'),
                    _buildStatusRow('Pending Retries', '$_pendingRetries'),
                    _buildStatusRow('Local Events', '$_localEvents'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Action buttons
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton.icon(
                  onPressed: _makeSuccessRequest,
                  icon: const Icon(Icons.check_circle, color: Colors.green),
                  label: const Text('Success (200)'),
                ),
                ElevatedButton.icon(
                  onPressed: _makeFailureRequest,
                  icon: const Icon(Icons.error, color: Colors.orange),
                  label: const Text('Failure (500)'),
                ),
                ElevatedButton.icon(
                  onPressed: _makeCriticalRequest,
                  icon: const Icon(Icons.warning, color: Colors.red),
                  label: const Text('Critical (503)'),
                ),
                ElevatedButton.icon(
                  onPressed: _makeNetworkErrorRequest,
                  icon: const Icon(Icons.wifi_off, color: Colors.grey),
                  label: const Text('Network Error'),
                ),
                OutlinedButton.icon(
                  onPressed: _viewLocalEvents,
                  icon: const Icon(Icons.storage),
                  label: const Text('View Local'),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Event log
            const Text('Event Log:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: ListView.builder(
                  itemCount: _logs.length,
                  itemBuilder: (context, index) {
                    final log = _logs[index];
                    final isError = log.contains('FAILURE') || log.contains('error') || log.contains('Error');
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Text(
                        log,
                        style: TextStyle(
                          fontSize: 11,
                          fontFamily: 'monospace',
                          color: isError ? Colors.red[700] : Colors.grey[800],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[600])),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _dio.close();
    super.dispose();
  }
}
