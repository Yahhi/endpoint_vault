import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

import '../models/server_settings.dart';

/// Service for fetching and caching server settings.
class ServerSettingsService {
  static const String _cacheKey = 'endpoint_vault_server_settings';
  static const Duration _cacheDuration = Duration(hours: 1);

  final Dio _dio;
  final bool _debug;

  ServerSettings _settings = ServerSettings.defaults;
  DateTime? _lastFetchTime;

  ServerSettingsService({
    required Dio dio,
    bool debug = false,
  })  : _dio = dio,
        _debug = debug;

  /// Current settings (may be cached or defaults).
  ServerSettings get settings => _settings;

  /// Whether local resend is enabled.
  bool get localResendEnabled => _settings.localResendEnabled;

  /// Fetch settings from server. Called during SDK initialization.
  Future<ServerSettings> fetchSettings() async {
    try {
      final response = await _dio.get('/v1/settings');

      if (response.statusCode == 200 && response.data != null) {
        _settings = ServerSettings.fromJson(response.data);
        _lastFetchTime = DateTime.now();
        await _cacheSettings(_settings);

        if (_debug) {
          print('[EndpointVault] Server settings fetched: ${_settings.toJson()}');
        }

        return _settings;
      }
    } catch (e) {
      if (_debug) {
        print('[EndpointVault] Failed to fetch server settings: $e');
      }
    }

    // Try to load from cache if server fetch failed
    final cached = await _loadCachedSettings();
    if (cached != null) {
      _settings = cached;
      if (_debug) {
        print('[EndpointVault] Using cached server settings');
      }
      return _settings;
    }

    // Fall back to defaults
    if (_debug) {
      print('[EndpointVault] Using default server settings');
    }
    return _settings;
  }

  /// Refresh settings if cache is stale.
  Future<void> refreshIfNeeded() async {
    if (_lastFetchTime == null ||
        DateTime.now().difference(_lastFetchTime!) > _cacheDuration) {
      await fetchSettings();
    }
  }

  Future<void> _cacheSettings(ServerSettings settings) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = {
        'settings': settings.toJson(),
        'cachedAt': DateTime.now().toIso8601String(),
      };
      await prefs.setString(_cacheKey, jsonEncode(data));
    } catch (e) {
      if (_debug) {
        print('[EndpointVault] Failed to cache settings: $e');
      }
    }
  }

  Future<ServerSettings?> _loadCachedSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_cacheKey);

      if (jsonString == null) return null;

      final data = jsonDecode(jsonString) as Map<String, dynamic>;
      final cachedAt = DateTime.parse(data['cachedAt']);

      // Check if cache is still valid
      if (DateTime.now().difference(cachedAt) > _cacheDuration) {
        return null;
      }

      return ServerSettings.fromJson(data['settings']);
    } catch (e) {
      return null;
    }
  }

  /// Clear cached settings.
  Future<void> clearCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_cacheKey);
    _settings = ServerSettings.defaults;
    _lastFetchTime = null;
  }
}
