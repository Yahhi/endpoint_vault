import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/captured_event.dart';

/// Offline queue for storing events when network is unavailable.
class OfflineQueue {
  static const String _storageKey = 'endpoint_vault_offline_queue';
  static const String _dbName = 'endpoint_vault.db';
  static const String _tableName = 'offline_queue';
  static const int _dbVersion = 1;

  final int maxSize;
  Database? _db;
  bool _didMigrateFromPrefs = false;

  OfflineQueue(this.maxSize);

  Future<Database> _getDb() async {
    final existing = _db;
    if (existing != null) return existing;

    final dbPath = await getDatabasesPath();
    final fullPath = p.join(dbPath, _dbName);

    final db = await openDatabase(
      fullPath,
      version: _dbVersion,
      onCreate: (db, version) async {
        await db.execute(
          'CREATE TABLE $_tableName('
          'id TEXT PRIMARY KEY,'
          'timestamp INTEGER NOT NULL,'
          'payload TEXT NOT NULL'
          ')',
        );
        await db.execute(
          'CREATE INDEX idx_${_tableName}_timestamp ON $_tableName(timestamp)',
        );
      },
    );

    _db = db;
    return db;
  }

  Future<void> _maybeMigrateFromPrefs() async {
    if (_didMigrateFromPrefs) return;
    _didMigrateFromPrefs = true;

    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_storageKey);

    if (jsonString == null || jsonString.isEmpty) {
      return;
    }

    try {
      final jsonList = jsonDecode(jsonString) as List;
      final events = jsonList.map((json) => CapturedEvent.fromJson(json)).toList();
      if (events.isEmpty) {
        await prefs.remove(_storageKey);
        return;
      }

      final db = await _getDb();
      await db.transaction((txn) async {
        for (final event in events) {
          await txn.insert(
            _tableName,
            {
              'id': event.id,
              'timestamp': event.timestamp.millisecondsSinceEpoch,
              'payload': jsonEncode(event.toJson()),
            },
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      });

      await _enforceMaxSize();
      await prefs.remove(_storageKey);
    } catch (_) {
      // If prefs data is corrupted, keep prior behavior and clear it.
      await prefs.remove(_storageKey);
    }
  }

  Future<void> _enforceMaxSize() async {
    final db = await _getDb();
    final rows = await db.query(
      _tableName,
      columns: ['id'],
      orderBy: 'timestamp ASC',
    );

    final overflow = rows.length - maxSize;
    if (overflow <= 0) return;

    final idsToDelete = rows.take(overflow).map((r) => r['id'] as String).toList();

    await db.transaction((txn) async {
      for (final id in idsToDelete) {
        await txn.delete(_tableName, where: 'id = ?', whereArgs: [id]);
      }
    });
  }

  /// Add an event to the offline queue.
  Future<void> add(CapturedEvent event) async {
    await _maybeMigrateFromPrefs();
    final db = await _getDb();

    await db.insert(
      _tableName,
      {
        'id': event.id,
        'timestamp': event.timestamp.millisecondsSinceEpoch,
        'payload': jsonEncode(event.toJson()),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    await _enforceMaxSize();
  }

  /// Get all queued events.
  Future<List<CapturedEvent>> getAll() async {
    await _maybeMigrateFromPrefs();
    final db = await _getDb();
    final rows = await db.query(
      _tableName,
      columns: ['payload'],
      orderBy: 'timestamp ASC',
    );

    final events = <CapturedEvent>[];
    for (final row in rows) {
      final payload = row['payload'] as String;
      try {
        final decoded = jsonDecode(payload) as Map<String, dynamic>;
        events.add(CapturedEvent.fromJson(decoded));
      } catch (_) {
        // Skip corrupted row.
      }
    }

    return events;
  }

  /// Remove an event from the queue by ID.
  Future<void> remove(String eventId) async {
    await _maybeMigrateFromPrefs();
    final db = await _getDb();
    await db.delete(_tableName, where: 'id = ?', whereArgs: [eventId]);
  }

  /// Clear all queued events.
  Future<void> clear() async {
    await _maybeMigrateFromPrefs();
    final db = await _getDb();
    await db.delete(_tableName);

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
  }

  /// Get the number of queued events.
  Future<int> get length async {
    await _maybeMigrateFromPrefs();
    final db = await _getDb();
    final result = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM $_tableName'),
    );
    return result ?? 0;
  }
}
