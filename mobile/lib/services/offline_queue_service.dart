import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'database_service.dart';
import 'todo_api.dart';

enum ChangeType {
  CREATE_TODO,
  UPDATE_TODO_TEXT,
  UPDATE_TODO_POSITION,
  COMPLETE_TODO,
  DELETE_TODO,
  COMPLETE_VIRTUAL_TODO,
  UPDATE_VIRTUAL_TODO_TEXT,
  UPDATE_VIRTUAL_TODO_POSITION,
  DELETE_VIRTUAL_TODO,
}

class PendingChange {
  final int? id;
  final ChangeType type;
  final Map<String, dynamic> payload;
  final DateTime timestamp;
  final int attempts;

  PendingChange({
    this.id,
    required this.type,
    required this.payload,
    required this.timestamp,
    this.attempts = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type.name,
      'payload': jsonEncode(payload),
      'timestamp': timestamp.toIso8601String(),
      'attempts': attempts,
    };
  }

  factory PendingChange.fromMap(Map<String, dynamic> map) {
    return PendingChange(
      id: map['id'] as int?,
      type: ChangeType.values.firstWhere((e) => e.name == map['type']),
      payload: jsonDecode(map['payload'] as String) as Map<String, dynamic>,
      timestamp: DateTime.parse(map['timestamp'] as String),
      attempts: map['attempts'] as int,
    );
  }
}

class OfflineQueueService {
  final DatabaseService _databaseService;
  final TodoApi _todoApi;
  final Connectivity _connectivity;

  bool _isSyncing = false;
  static const int _maxAttempts = 3;

  OfflineQueueService({
    DatabaseService? databaseService,
    TodoApi? todoApi,
    Connectivity? connectivity,
  })  : _databaseService = databaseService ?? databaseService,
        _todoApi = todoApi ?? todoApi,
        _connectivity = connectivity ?? Connectivity();

  /// Add a change to the offline queue
  Future<void> addChange(ChangeType type, Map<String, dynamic> payload) async {
    final db = await _databaseService.database;

    final change = PendingChange(
      type: type,
      payload: payload,
      timestamp: DateTime.now(),
    );

    await db.insert('pending_changes', change.toMap());
    print('Added change to offline queue: ${type.name}');
  }

  /// Get all pending changes
  Future<List<PendingChange>> getPendingChanges() async {
    final db = await _databaseService.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'pending_changes',
      orderBy: 'timestamp ASC',
    );

    return maps.map((map) => PendingChange.fromMap(map)).toList();
  }

  /// Remove a change from the queue
  Future<void> removeChange(int id) async {
    final db = await _databaseService.database;
    await db.delete('pending_changes', where: 'id = ?', whereArgs: [id]);
  }

  /// Increment attempt count for a change
  Future<void> incrementAttempts(int id, int currentAttempts) async {
    final db = await _databaseService.database;
    await db.update(
      'pending_changes',
      {'attempts': currentAttempts + 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Check if device is online
  Future<bool> isOnline() async {
    final connectivityResult = await _connectivity.checkConnectivity();
    return connectivityResult != ConnectivityResult.none;
  }

  /// Sync all pending changes with the backend
  Future<SyncResult> syncPendingChanges() async {
    if (_isSyncing) {
      return SyncResult(success: false, message: 'Sync already in progress');
    }

    _isSyncing = true;

    try {
      // Check if online
      if (!await isOnline()) {
        return SyncResult(success: false, message: 'Device is offline');
      }

      final pendingChanges = await getPendingChanges();

      if (pendingChanges.isEmpty) {
        return SyncResult(success: true, message: 'No changes to sync');
      }

      int successCount = 0;
      int failureCount = 0;
      final List<String> errors = [];

      for (final change in pendingChanges) {
        try {
          await _executeChange(change);
          await removeChange(change.id!);
          successCount++;
        } catch (e) {
          failureCount++;
          errors.add('${change.type.name}: $e');

          // Increment attempts
          await incrementAttempts(change.id!, change.attempts);

          // Remove if max attempts reached
          if (change.attempts + 1 >= _maxAttempts) {
            await removeChange(change.id!);
            print('Removed change after max attempts: ${change.type.name}');
          }
        }
      }

      final message = 'Synced $successCount changes, $failureCount failed';
      print(message);

      return SyncResult(
        success: failureCount == 0,
        message: message,
        successCount: successCount,
        failureCount: failureCount,
        errors: errors,
      );
    } finally {
      _isSyncing = false;
    }
  }

  /// Execute a single change
  Future<void> _executeChange(PendingChange change) async {
    final payload = change.payload;

    switch (change.type) {
      case ChangeType.CREATE_TODO:
        await _todoApi.createTodo(
          text: payload['text'] as String,
          assignedDate: payload['assignedDate'] as String,
        );
        break;

      case ChangeType.UPDATE_TODO_TEXT:
        await _todoApi.updateTodoText(
          id: payload['id'] as int,
          text: payload['text'] as String,
        );
        break;

      case ChangeType.UPDATE_TODO_POSITION:
        await _todoApi.updateTodoPosition(
          id: payload['id'] as int,
          position: payload['position'] as int,
        );
        break;

      case ChangeType.COMPLETE_TODO:
        await _todoApi.completeTodo(id: payload['id'] as int);
        break;

      case ChangeType.DELETE_TODO:
        await _todoApi.deleteTodo(
          id: payload['id'] as int,
          deleteAllFuture: payload['deleteAllFuture'] as bool?,
        );
        break;

      case ChangeType.COMPLETE_VIRTUAL_TODO:
        await _todoApi.completeVirtualTodo(
          recurringTodoId: payload['recurringTodoId'] as int,
          instanceDate: payload['instanceDate'] as String,
        );
        break;

      case ChangeType.UPDATE_VIRTUAL_TODO_TEXT:
        await _todoApi.updateVirtualTodoText(
          recurringTodoId: payload['recurringTodoId'] as int,
          instanceDate: payload['instanceDate'] as String,
          text: payload['text'] as String,
        );
        break;

      case ChangeType.UPDATE_VIRTUAL_TODO_POSITION:
        await _todoApi.updateVirtualTodoPosition(
          recurringTodoId: payload['recurringTodoId'] as int,
          instanceDate: payload['instanceDate'] as String,
          position: payload['position'] as int,
        );
        break;

      case ChangeType.DELETE_VIRTUAL_TODO:
        await _todoApi.deleteVirtualTodo(
          recurringTodoId: payload['recurringTodoId'] as int,
          instanceDate: payload['instanceDate'] as String,
          deleteAllFuture: payload['deleteAllFuture'] as bool?,
        );
        break;
    }
  }

  /// Clear all pending changes
  Future<void> clearQueue() async {
    final db = await _databaseService.database;
    await db.delete('pending_changes');
  }

  /// Get count of pending changes
  Future<int> getPendingCount() async {
    final db = await _databaseService.database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM pending_changes');
    return Sqflite.firstIntValue(result) ?? 0;
  }
}

class SyncResult {
  final bool success;
  final String message;
  final int successCount;
  final int failureCount;
  final List<String> errors;

  SyncResult({
    required this.success,
    required this.message,
    this.successCount = 0,
    this.failureCount = 0,
    this.errors = const [],
  });
}

// Import sqflite for firstIntValue
import 'package:sqflite/sqflite.dart' as Sqflite;

// Singleton instance
final offlineQueueService = OfflineQueueService();
