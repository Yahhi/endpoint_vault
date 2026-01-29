import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/event_package.dart';
import '../models/file_attachment.dart';

/// Local storage for unencrypted event data when local resend is enabled.
/// This data is stored only on device and never sent to server unencrypted.
class LocalEventStorage {
  static const String _dbName = 'endpoint_vault.db';
  static const String _tableName = 'local_events';
  static const String _attachmentsTable = 'event_attachments';
  static const int _dbVersion = 3;

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
        await _createTables(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await _createEventsTable(db);
        }
        if (oldVersion < 3) {
          await _createAttachmentsTable(db);
        }
      },
    );

    _db = db;
    return db;
  }

  Future<void> _createTables(Database db) async {
    await _createEventsTable(db);
    await _createAttachmentsTable(db);
  }

  Future<void> _createEventsTable(Database db) async {
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

  Future<void> _createAttachmentsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $_attachmentsTable(
        id TEXT PRIMARY KEY,
        event_id TEXT NOT NULL,
        field_name TEXT NOT NULL,
        filename TEXT NOT NULL,
        content_type TEXT,
        size_bytes INTEGER NOT NULL,
        checksum_sha256 TEXT NOT NULL,
        local_path TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        FOREIGN KEY(event_id) REFERENCES $_tableName(event_id) ON DELETE CASCADE
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_${_attachmentsTable}_event_id ON $_attachmentsTable(event_id)',
    );
  }

  /// Store an unencrypted event for local replay.
  Future<void> store(UnencryptedPackage package) async {
    final db = await _getDb();

    await db.transaction((txn) async {
      // Store the main event
      await txn.insert(
        _tableName,
        {
          'event_id': package.eventId,
          'timestamp': package.timestamp.millisecondsSinceEpoch,
          'payload': jsonEncode(package.toJson()),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      // Store attachment metadata if present
      if (package.attachments != null && package.attachments!.isNotEmpty) {
        for (final attachment in package.attachments!) {
          await txn.insert(
            _attachmentsTable,
            {
              'id': attachment.id,
              'event_id': package.eventId,
              'field_name': attachment.fieldName,
              'filename': attachment.filename,
              'content_type': attachment.contentType,
              'size_bytes': attachment.sizeBytes,
              'checksum_sha256': attachment.checksumSha256,
              'local_path': attachment.localPath,
              'created_at': attachment.createdAt.millisecondsSinceEpoch,
            },
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      }
    });

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
    var package = UnencryptedPackage.fromJson(payload);

    // Load attachments from separate table (in case they're not in payload)
    final attachmentRows = await db.query(
      _attachmentsTable,
      where: 'event_id = ?',
      whereArgs: [eventId],
    );

    if (attachmentRows.isNotEmpty) {
      final attachments = attachmentRows.map((row) {
        return FileAttachment(
          id: row['id'] as String,
          fieldName: row['field_name'] as String,
          filename: row['filename'] as String,
          contentType: row['content_type'] as String?,
          sizeBytes: row['size_bytes'] as int,
          checksumSha256: row['checksum_sha256'] as String,
          localPath: row['local_path'] as String,
          createdAt: DateTime.fromMillisecondsSinceEpoch(row['created_at'] as int),
        );
      }).toList();

      // Return package with attachments from DB
      package = UnencryptedPackage(
        eventId: package.eventId,
        timestamp: package.timestamp,
        method: package.method,
        url: package.url,
        statusCode: package.statusCode,
        errorType: package.errorType,
        errorMessage: package.errorMessage,
        requestHeaders: package.requestHeaders,
        requestBody: package.requestBody,
        responseHeaders: package.responseHeaders,
        responseBody: package.responseBody,
        durationMs: package.durationMs,
        environment: package.environment,
        appVersion: package.appVersion,
        deviceId: package.deviceId,
        extra: package.extra,
        attachments: attachments,
        formFields: package.formFields,
      );
    }

    return package;
  }

  /// Get all stored events.
  Future<List<UnencryptedPackage>> getAll() async {
    final db = await _getDb();
    final rows = await db.query(
      _tableName,
      orderBy: 'timestamp ASC',
    );

    final packages = <UnencryptedPackage>[];

    for (final row in rows) {
      final payload = jsonDecode(row['payload'] as String);
      var package = UnencryptedPackage.fromJson(payload);

      // Load attachments
      final eventId = row['event_id'] as String;
      final attachmentRows = await db.query(
        _attachmentsTable,
        where: 'event_id = ?',
        whereArgs: [eventId],
      );

      if (attachmentRows.isNotEmpty) {
        final attachments = attachmentRows.map((aRow) {
          return FileAttachment(
            id: aRow['id'] as String,
            fieldName: aRow['field_name'] as String,
            filename: aRow['filename'] as String,
            contentType: aRow['content_type'] as String?,
            sizeBytes: aRow['size_bytes'] as int,
            checksumSha256: aRow['checksum_sha256'] as String,
            localPath: aRow['local_path'] as String,
            createdAt:
                DateTime.fromMillisecondsSinceEpoch(aRow['created_at'] as int),
          );
        }).toList();

        package = UnencryptedPackage(
          eventId: package.eventId,
          timestamp: package.timestamp,
          method: package.method,
          url: package.url,
          statusCode: package.statusCode,
          errorType: package.errorType,
          errorMessage: package.errorMessage,
          requestHeaders: package.requestHeaders,
          requestBody: package.requestBody,
          responseHeaders: package.responseHeaders,
          responseBody: package.responseBody,
          durationMs: package.durationMs,
          environment: package.environment,
          appVersion: package.appVersion,
          deviceId: package.deviceId,
          extra: package.extra,
          attachments: attachments,
          formFields: package.formFields,
        );
      }

      packages.add(package);
    }

    return packages;
  }

  /// Get attachments for an event.
  Future<List<FileAttachment>> getAttachments(String eventId) async {
    final db = await _getDb();
    final rows = await db.query(
      _attachmentsTable,
      where: 'event_id = ?',
      whereArgs: [eventId],
    );

    return rows.map((row) {
      return FileAttachment(
        id: row['id'] as String,
        fieldName: row['field_name'] as String,
        filename: row['filename'] as String,
        contentType: row['content_type'] as String?,
        sizeBytes: row['size_bytes'] as int,
        checksumSha256: row['checksum_sha256'] as String,
        localPath: row['local_path'] as String,
        createdAt: DateTime.fromMillisecondsSinceEpoch(row['created_at'] as int),
      );
    }).toList();
  }

  /// Remove an event after successful replay or expiration.
  Future<void> remove(String eventId) async {
    final db = await _getDb();

    await db.transaction((txn) async {
      // Delete attachments first (or they'll be deleted by CASCADE)
      await txn.delete(
        _attachmentsTable,
        where: 'event_id = ?',
        whereArgs: [eventId],
      );
      // Delete the event
      await txn.delete(
        _tableName,
        where: 'event_id = ?',
        whereArgs: [eventId],
      );
    });

    if (debug) {
      print('[EndpointVault] Local event removed: $eventId');
    }
  }

  /// Remove an attachment record.
  Future<void> removeAttachment(String attachmentId) async {
    final db = await _getDb();
    await db.delete(
      _attachmentsTable,
      where: 'id = ?',
      whereArgs: [attachmentId],
    );
  }

  /// Clear all stored events.
  Future<void> clear() async {
    final db = await _getDb();
    await db.transaction((txn) async {
      await txn.delete(_attachmentsTable);
      await txn.delete(_tableName);
    });
  }

  /// Get count of stored events.
  Future<int> get count async {
    final db = await _getDb();
    final result = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM $_tableName'),
    );
    return result ?? 0;
  }

  /// Get count of stored attachments.
  Future<int> get attachmentCount async {
    final db = await _getDb();
    final result = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM $_attachmentsTable'),
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
        // Delete attachments first
        await txn.delete(
          _attachmentsTable,
          where: 'event_id = ?',
          whereArgs: [id],
        );
        await txn.delete(_tableName, where: 'event_id = ?', whereArgs: [id]);
      }
    });
  }

  void dispose() {
    _db?.close();
  }
}
