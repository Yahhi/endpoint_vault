import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:endpoint_vault/endpoint_vault.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize EndpointVault
  await EndpointVault.init(apiKey: 'your-api-key', encryptionKey: 'your-32-char-encryption-key!!!');

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
  final Dio _dio = Dio();
  String _status = 'Ready';
  final List<String> _logs = [];

  @override
  void initState() {
    super.initState();
    _setupDio();
  }

  void _setupDio() {
    // Add EndpointVault interceptor
    _dio.interceptors.add(EndpointVaultInterceptor());

    // Listen to captured events
    EndpointVault.instance.eventStream.listen((event) {
      setState(() {
        _logs.add(
          '[${event.isSuccess ? 'SUCCESS' : 'FAILURE'}] '
          '${event.method} ${event.url} - ${event.statusCode}',
        );
      });
    });
  }

  Future<void> _makeSuccessRequest() async {
    setState(() => _status = 'Making request...');
    try {
      await _dio.get('https://httpbin.org/get');
      setState(() => _status = 'Request succeeded');
    } catch (e) {
      setState(() => _status = 'Request failed: $e');
    }
  }

  Future<void> _makeFailureRequest() async {
    setState(() => _status = 'Making failing request...');
    try {
      await _dio.get('https://httpbin.org/status/500');
      setState(() => _status = 'Request succeeded');
    } catch (e) {
      setState(() => _status = 'Request failed (expected)');
    }
  }

  Future<void> _makeCriticalRequest() async {
    setState(() => _status = 'Making critical request...');
    try {
      await _dio.get('https://httpbin.org/status/503', options: Options(extra: {'ev_critical': true}));
      setState(() => _status = 'Request succeeded');
    } catch (e) {
      setState(() => _status = 'Critical request captured');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('EndpointVault Example'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Status: $_status', style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _makeSuccessRequest, child: const Text('Make Success Request')),
            const SizedBox(height: 8),
            ElevatedButton(onPressed: _makeFailureRequest, child: const Text('Make Failure Request (500)')),
            const SizedBox(height: 8),
            ElevatedButton(onPressed: _makeCriticalRequest, child: const Text('Make Critical Request (503)')),
            const SizedBox(height: 16),
            const Text('Event Log:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(8)),
                child: ListView.builder(
                  itemCount: _logs.length,
                  itemBuilder: (context, index) {
                    return Text(
                      _logs[index],
                      style: TextStyle(
                        fontSize: 12,
                        color: _logs[index].contains('FAILURE') ? Colors.red : Colors.green,
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
}
