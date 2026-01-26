import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/captured_event.dart';

/// Offline queue for storing events when network is unavailable.
class OfflineQueue {
  static const String _storageKey = 'endpoint_vault_offline_queue';

  final int maxSize;

  OfflineQueue(this.maxSize);

  /// Add an event to the offline queue.
  Future<void> add(CapturedEvent event) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = await getAll();

    // Remove oldest if at max capacity
    if (existing.length >= maxSize) {
      existing.removeAt(0);
    }

    existing.add(event);

    final jsonList = existing.map((e) => e.toJson()).toList();
    await prefs.setString(_storageKey, jsonEncode(jsonList));
  }

  /// Get all queued events.
  Future<List<CapturedEvent>> getAll() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_storageKey);

    if (jsonString == null || jsonString.isEmpty) {
      return [];
    }

    try {
      final jsonList = jsonDecode(jsonString) as List;
      return jsonList
          .map((json) => CapturedEvent.fromJson(json))
          .toList();
    } catch (e) {
      // Corrupted data, clear it
      await clear();
      return [];
    }
  }

  /// Remove an event from the queue by ID.
  Future<void> remove(String eventId) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = await getAll();

    existing.removeWhere((e) => e.id == eventId);

    final jsonList = existing.map((e) => e.toJson()).toList();
    await prefs.setString(_storageKey, jsonEncode(jsonList));
  }

  /// Clear all queued events.
  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
  }

  /// Get the number of queued events.
  Future<int> get length async {
    final events = await getAll();
    return events.length;
  }
}
