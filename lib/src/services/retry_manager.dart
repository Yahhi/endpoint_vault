import 'dart:async';
import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/pending_request.dart';
import '../models/server_response.dart';

/// Callback type for executing a retry.
typedef RetryExecutor = Future<bool> Function(PendingRequest request);

/// Manages retry scheduling and execution for failed requests.
class RetryManager {
  static const String _dbName = 'endpoint_vault.db';
  static const String _tableName = 'pending_requests';
  static const int _dbVersion = 2;

  final int maxRetries;
  final Duration baseDelay;
  final bool debug;

  Database? _db;
  Timer? _retryTimer;
  RetryExecutor? _executor;
  bool _isProcessing = false;

  RetryManager({
    this.maxRetries = 3,
    this.baseDelay = const Duration(seconds: 5),
    this.debug = false,
  });

  /// Set the executor callback for processing retries.
  void setExecutor(RetryExecutor executor) {
    _executor = executor;
  }

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
          await _createTables(db);
        }
      },
    );

    _db = db;
    return db;
  }

  Future<void> _createTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $_tableName(
        id TEXT PRIMARY KEY,
        event_id TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        attempt_count INTEGER NOT NULL DEFAULT 0,
        retry_id TEXT,
        next_retry_at INTEGER,
        payload TEXT NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_${_tableName}_next_retry ON $_tableName(next_retry_at)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_${_tableName}_retry_id ON $_tableName(retry_id)',
    );
  }

  /// Add a pending request for retry.
  Future<void> addPendingRequest(PendingRequest request) async {
    final db = await _getDb();

    final nextRetryAt = DateTime.now().add(baseDelay);

    await db.insert(
      _tableName,
      {
        'id': request.id,
        'event_id': request.eventId,
        'created_at': request.createdAt.millisecondsSinceEpoch,
        'attempt_count': request.attemptCount,
        'retry_id': request.retryId,
        'next_retry_at': nextRetryAt.millisecondsSinceEpoch,
        'payload': jsonEncode(request.toJson()),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    if (debug) {
      print('[EndpointVault] Pending request added: ${request.id}');
    }

    _scheduleNextRetry();
  }

  /// Handle a retry command from server response.
  Future<void> handleRetryCommand(
    RetryCommand command,
    PendingRequest request,
  ) async {
    final db = await _getDb();

    final nextRetryAt = DateTime.now().add(
      Duration(milliseconds: command.delayMs),
    );

    final updatedRequest = request.copyWith(
      retryId: command.retryId,
    );

    await db.update(
      _tableName,
      {
        'retry_id': command.retryId,
        'next_retry_at': nextRetryAt.millisecondsSinceEpoch,
        'payload': jsonEncode(updatedRequest.toJson()),
      },
      where: 'id = ?',
      whereArgs: [request.id],
    );

    if (debug) {
      print('[EndpointVault] Retry scheduled for ${request.id} '
          'with retryId: ${command.retryId}');
    }

    _scheduleNextRetry();
  }

  /// Get all pending requests.
  Future<List<PendingRequest>> getPendingRequests() async {
    final db = await _getDb();
    final rows = await db.query(
      _tableName,
      orderBy: 'created_at ASC',
    );

    return rows.map((row) {
      final payload = jsonDecode(row['payload'] as String);
      return PendingRequest.fromJson(payload);
    }).toList();
  }

  /// Get pending requests that are due for retry.
  Future<List<PendingRequest>> getDueRequests() async {
    final db = await _getDb();
    final now = DateTime.now().millisecondsSinceEpoch;

    final rows = await db.query(
      _tableName,
      where: 'next_retry_at <= ?',
      whereArgs: [now],
      orderBy: 'next_retry_at ASC',
    );

    return rows.map((row) {
      final payload = jsonDecode(row['payload'] as String);
      return PendingRequest.fromJson(payload);
    }).toList();
  }

  /// Get a pending request by retry ID.
  Future<PendingRequest?> getByRetryId(String retryId) async {
    final db = await _getDb();
    final rows = await db.query(
      _tableName,
      where: 'retry_id = ?',
      whereArgs: [retryId],
      limit: 1,
    );

    if (rows.isEmpty) return null;

    final payload = jsonDecode(rows.first['payload'] as String);
    return PendingRequest.fromJson(payload);
  }

  /// Remove a pending request after successful send.
  Future<void> removePendingRequest(String requestId) async {
    final db = await _getDb();
    await db.delete(_tableName, where: 'id = ?', whereArgs: [requestId]);

    if (debug) {
      print('[EndpointVault] Pending request removed: $requestId');
    }
  }

  /// Update attempt count and schedule next retry.
  Future<void> incrementAttempt(PendingRequest request) async {
    final db = await _getDb();
    final newAttemptCount = request.attemptCount + 1;

    if (newAttemptCount >= maxRetries) {
      // Max retries reached, remove the request
      await removePendingRequest(request.id);
      if (debug) {
        print('[EndpointVault] Max retries reached for ${request.id}, removing');
      }
      return;
    }

    // Exponential backoff
    final delay = baseDelay * (1 << newAttemptCount);
    final nextRetryAt = DateTime.now().add(delay);

    final updatedRequest = request.copyWith(attemptCount: newAttemptCount);

    await db.update(
      _tableName,
      {
        'attempt_count': newAttemptCount,
        'next_retry_at': nextRetryAt.millisecondsSinceEpoch,
        'payload': jsonEncode(updatedRequest.toJson()),
      },
      where: 'id = ?',
      whereArgs: [request.id],
    );

    if (debug) {
      print('[EndpointVault] Retry ${newAttemptCount + 1}/$maxRetries '
          'scheduled for ${request.id}');
    }
  }

  /// Clear all pending requests.
  Future<void> clearAll() async {
    final db = await _getDb();
    await db.delete(_tableName);
  }

  /// Get count of pending requests.
  Future<int> get pendingCount async {
    final db = await _getDb();
    final result = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM $_tableName'),
    );
    return result ?? 0;
  }

  void _scheduleNextRetry() {
    _retryTimer?.cancel();

    // Schedule processing in a short delay
    _retryTimer = Timer(const Duration(seconds: 1), () {
      _processRetries();
    });
  }

  Future<void> _processRetries() async {
    if (_isProcessing || _executor == null) return;
    _isProcessing = true;

    try {
      final dueRequests = await getDueRequests();

      for (final request in dueRequests) {
        try {
          final success = await _executor!(request);

          if (success) {
            await removePendingRequest(request.id);
          } else {
            await incrementAttempt(request);
          }
        } catch (e) {
          if (debug) {
            print('[EndpointVault] Retry failed for ${request.id}: $e');
          }
          await incrementAttempt(request);
        }
      }
    } finally {
      _isProcessing = false;
    }

    // Check if there are more pending requests
    final remaining = await pendingCount;
    if (remaining > 0) {
      _scheduleNextRetry();
    }
  }

  /// Start processing retries (called during initialization).
  Future<void> startProcessing() async {
    final pending = await pendingCount;
    if (pending > 0) {
      if (debug) {
        print('[EndpointVault] Found $pending pending requests');
      }
      _scheduleNextRetry();
    }
  }

  /// Stop retry processing.
  void dispose() {
    _retryTimer?.cancel();
    _db?.close();
  }
}
