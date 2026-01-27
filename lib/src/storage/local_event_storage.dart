import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/event_package.dart';

/// Local storage for unencrypted event data when local resend is enabled.
/// This data is stored only on device and never sent to server unencrypted.
class LocalEventStorage {
  static const String _dbName = 'endpoint_vault.db';
  static const String _tableName = 'local_events';
  static const int _dbVersion = 2;

  final int maxSize;
  final bool debug;

  Database? _db;

  LocalEventStorage({
    this.maxSize = 100,
    this.debug = false,
  });

  Future<Database> _getDb() async {
    final existing = _db;
    if (existing != null) return existing;

    final dbPath = await getDatabasesPath();
    final fullPath = p.join(dbPath, _dbName);

    final db = await openDatabase(
      fullPath,
      version: _dbVersion,
      onCreate: (db, version) async {
        await _createTable(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await _createTable(db);
        }
      },
    );

    _db = db;
    return db;
  }

  Future<void> _createTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $_tableName(
        event_id TEXT PRIMARY KEY,
        timestamp INTEGER NOT NULL,
        payload TEXT NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_${_tableName}_timestamp ON $_tableName(timestamp)',
    );
  }

  /// Store an unencrypted event for local replay.
  Future<void> store(UnencryptedPackage package) async {
    final db = await _getDb();

    await db.insert(
      _tableName,
      {
        'event_id': package.eventId,
        'timestamp': package.timestamp.millisecondsSinceEpoch,
        'payload': jsonEncode(package.toJson()),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    await _enforceMaxSize();

    if (debug) {
      print('[EndpointVault] Local event stored: ${package.eventId}');
    }
  }

  /// Get an unencrypted event by ID for replay.
  Future<UnencryptedPackage?> get(String eventId) async {
    final db = await _getDb();
    final rows = await db.query(
      _tableName,
      where: 'event_id = ?',
      whereArgs: [eventId],
      limit: 1,
    );

    if (rows.isEmpty) return null;

    final payload = jsonDecode(rows.first['payload'] as String);
    return UnencryptedPackage.fromJson(payload);
  }

  /// Get all stored events.
  Future<List<UnencryptedPackage>> getAll() async {
    final db = await _getDb();
    final rows = await db.query(
      _tableName,
      orderBy: 'timestamp ASC',
    );

    return rows.map((row) {
      final payload = jsonDecode(row['payload'] as String);
      return UnencryptedPackage.fromJson(payload);
    }).toList();
  }

  /// Remove an event after successful replay or expiration.
  Future<void> remove(String eventId) async {
    final db = await _getDb();
    await db.delete(_tableName, where: 'event_id = ?', whereArgs: [eventId]);

    if (debug) {
      print('[EndpointVault] Local event removed: $eventId');
    }
  }

  /// Clear all stored events.
  Future<void> clear() async {
    final db = await _getDb();
    await db.delete(_tableName);
  }

  /// Get count of stored events.
  Future<int> get count async {
    final db = await _getDb();
    final result = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM $_tableName'),
    );
    return result ?? 0;
  }

  Future<void> _enforceMaxSize() async {
    final db = await _getDb();
    final rows = await db.query(
      _tableName,
      columns: ['event_id'],
      orderBy: 'timestamp ASC',
    );

    final overflow = rows.length - maxSize;
    if (overflow <= 0) return;

    final idsToDelete =
        rows.take(overflow).map((r) => r['event_id'] as String).toList();

    await db.transaction((txn) async {
      for (final id in idsToDelete) {
        await txn.delete(_tableName, where: 'event_id = ?', whereArgs: [id]);
      }
    });
  }

  void dispose() {
    _db?.close();
  }
}
