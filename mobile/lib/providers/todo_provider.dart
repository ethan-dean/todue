import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/todo.dart';
import '../models/recurring_todo.dart';
import '../services/todo_api.dart';
import '../services/database_service.dart';
import '../services/offline_queue_service.dart';
import '../services/websocket_service.dart';

class TodoProvider extends ChangeNotifier {
  final TodoApi _todoApi;
  final DatabaseService _databaseService;
  final OfflineQueueService _offlineQueueService;
  final WebSocketService _websocketService;

  // State
  Map<String, List<Todo>> _todos = {};
  List<RecurringTodo> _recurringTodos = [];
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;
  String? _error;
  bool _isOnline = true;
  StreamSubscription? _wsSubscription;

  // Getters
  Map<String, List<Todo>> get todos => _todos;
  List<RecurringTodo> get recurringTodos => _recurringTodos;
  DateTime get selectedDate => _selectedDate;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isOnline => _isOnline;

  // Get todos for a specific date
  List<Todo> getTodosForDate(DateTime date) {
    final dateStr = _formatDate(date);
    return _todos[dateStr] ?? [];
  }

  // Get todos for the selected date
  List<Todo> get selectedDateTodos => getTodosForDate(_selectedDate);

  TodoProvider({
    required TodoApi todoApi,
    required DatabaseService databaseService,
    required OfflineQueueService offlineQueueService,
    required WebSocketService websocketService,
  })  : _todoApi = todoApi,
        _databaseService = databaseService,
        _offlineQueueService = offlineQueueService,
        _websocketService = websocketService {
    _init();
  }

  Future<void> _init() async {
    // Restore selected date from preferences
    final prefs = await SharedPreferences.getInstance();
    final savedDate = prefs.getString('selectedDate');
    if (savedDate != null) {
      _selectedDate = DateTime.parse(savedDate);
    }

    // Set up WebSocket listener
    _wsSubscription = _websocketService.messageStream.listen((message) {
      _handleWebSocketMessage(message);
    });

    // Check online status and load initial data
    await _checkOnlineStatus();
    await loadTodos(force: true);
    await loadRecurringTodos();
  }

  @override
  void dispose() {
    _wsSubscription?.cancel();
    super.dispose();
  }

  // Helper to format date as YYYY-MM-DD
  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  // Set loading state
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  // Set error state
  void _setError(String? error) {
    _error = error;
    notifyListeners();
  }

  // Check if device is online
  Future<void> _checkOnlineStatus() async {
    _isOnline = await _offlineQueueService.isOnline();
    notifyListeners();
  }

  // Handle WebSocket messages
  void _handleWebSocketMessage(WebSocketMessage message) {
    switch (message.type) {
      case WebSocketMessageType.TODOS_CHANGED:
        // Single date changed - refetch that specific date
        if (message.data != null && message.data is Map) {
          final dateStr = message.data['date'] as String?;
          if (dateStr != null) {
            try {
              final date = DateTime.parse(dateStr);
              // Only refetch if this date is currently loaded
              if (_todos.containsKey(dateStr)) {
                loadTodos(date: date, force: true);
              }
            } catch (e) {
              print('Error parsing date from WebSocket message: $e');
            }
          }
        }
        break;

      case WebSocketMessageType.RECURRING_CHANGED:
        // Recurring pattern changed - refetch all loaded dates
        loadRecurringTodos();
        // Also refetch all currently loaded dates to update virtual todos
        _todos.keys.toList().forEach((dateStr) {
          try {
            final date = DateTime.parse(dateStr);
            loadTodos(date: date, force: true);
          } catch (e) {
            print('Error reloading date $dateStr: $e');
          }
        });
        break;

      default:
        print('Unknown WebSocket message type: ${message.type}');
    }
  }

  // Change selected date
  Future<void> selectDate(DateTime date) async {
    _selectedDate = date;

    // Save to preferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selectedDate', _formatDate(date));

    notifyListeners();

    // Load todos for the new date if not already loaded
    final dateStr = _formatDate(date);
    if (!_todos.containsKey(dateStr)) {
      await loadTodos(date: date);
    }
  }

  // Load todos for a date (or selected date if not specified)
  Future<void> loadTodos({DateTime? date, bool force = false}) async {
    final targetDate = date ?? _selectedDate;
    final dateStr = _formatDate(targetDate);

    // Skip if already loaded and not forcing
    if (!force && _todos.containsKey(dateStr) && _todos[dateStr]!.isNotEmpty) {
      return;
    }

    _setLoading(true);
    _setError(null);

    try {
      await _checkOnlineStatus();

      if (_isOnline) {
        // Online mode: fetch from backend
        try {
          final fetchedTodos = await _todoApi.getTodos(date: dateStr);
          _todos[dateStr] = fetchedTodos;

          // Update local database
          await _databaseService.saveTodosForDate(dateStr, fetchedTodos);

          // Sync any pending changes
          await _offlineQueueService.syncPendingChanges();
        } catch (e) {
          // If API fails, fall back to local database
          _isOnline = false;
          final localTodos = await _databaseService.getTodos(date: dateStr);
          _todos[dateStr] = localTodos;
        }
      } else {
        // Offline mode: read from local database
        final localTodos = await _databaseService.getTodos(date: dateStr);
        _todos[dateStr] = localTodos;
      }

      notifyListeners();
    } catch (e) {
      _setError('Failed to load todos: $e');
    } finally {
      _setLoading(false);
    }
  }

  // Load recurring todos
  Future<void> loadRecurringTodos() async {
    try {
      await _checkOnlineStatus();

      if (_isOnline) {
        try {
          _recurringTodos = await _todoApi.getRecurringTodos();

          // Update local database
          await _databaseService.saveRecurringTodos(_recurringTodos);
        } catch (e) {
          // Fall back to local database
          _recurringTodos = await _databaseService.getRecurringTodos();
        }
      } else {
        _recurringTodos = await _databaseService.getRecurringTodos();
      }

      notifyListeners();
    } catch (e) {
      _setError('Failed to load recurring todos: $e');
    }
  }

  // Create a new todo
  Future<void> createTodo({
    required String text,
    DateTime? date,
    int? recurringTodoId,
  }) async {
    final targetDate = date ?? _selectedDate;
    final dateStr = _formatDate(targetDate);

    try {
      await _checkOnlineStatus();

      if (_isOnline) {
        // Online mode: send to backend
        final todo = await _todoApi.createTodo(
          text: text,
          assignedDate: dateStr,
          recurringTodoId: recurringTodoId,
        );

        if (!_todos.containsKey(dateStr)) {
          _todos[dateStr] = [];
        }
        _todos[dateStr]!.add(todo);
        _todos[dateStr]!.sort((a, b) => a.position.compareTo(b.position));

        // Update local database
        await _databaseService.saveTodo(todo);
      } else {
        // Offline mode: save to local database and queue
        final position = _todos[dateStr]?.length ?? 0;
        final todo = Todo(
          id: null, // Will be assigned by backend when synced
          text: text,
          assignedDate: dateStr,
          instanceDate: dateStr,
          position: position,
          recurringTodoId: recurringTodoId,
          isCompleted: false,
          isRolledOver: false,
          isVirtual: false,
        );

        if (!_todos.containsKey(dateStr)) {
          _todos[dateStr] = [];
        }
        _todos[dateStr]!.add(todo);

        // Save to local database
        await _databaseService.saveTodo(todo);

        // Queue the change
        await _offlineQueueService.queueChange(
          type: 'CREATE_TODO',
          payload: {
            'text': text,
            'assignedDate': dateStr,
            'recurringTodoId': recurringTodoId,
          },
        );
      }

      notifyListeners();
    } catch (e) {
      _setError('Failed to create todo: $e');
      rethrow;
    }
  }

  // Update a todo
  Future<void> updateTodo({
    required int todoId,
    String? text,
    String? assignedDate,
  }) async {
    try {
      await _checkOnlineStatus();

      if (_isOnline) {
        // Online mode: send to backend
        final updatedTodo = await _todoApi.updateTodo(
          id: todoId,
          text: text,
          assignedDate: assignedDate,
        );

        // Update in state
        final dateStr = updatedTodo.assignedDate;
        if (_todos.containsKey(dateStr)) {
          final index = _todos[dateStr]!.indexWhere((t) => t.id == todoId);
          if (index != -1) {
            _todos[dateStr]![index] = updatedTodo;
          }
        }

        // Update local database
        await _databaseService.saveTodo(updatedTodo);
      } else {
        // Offline mode: update local database and queue
        final allTodos = <Todo>[];
        for (final todoList in _todos.values) {
          allTodos.addAll(todoList);
        }

        final todo = allTodos.firstWhere((t) => t.id == todoId);
        final updatedTodo = Todo(
          id: todo.id,
          text: text ?? todo.text,
          assignedDate: assignedDate ?? todo.assignedDate,
          instanceDate: todo.instanceDate,
          position: todo.position,
          recurringTodoId: todo.recurringTodoId,
          isCompleted: todo.isCompleted,
          isRolledOver: todo.isRolledOver,
          isVirtual: todo.isVirtual,
        );

        final dateStr = updatedTodo.assignedDate;
        if (_todos.containsKey(dateStr)) {
          final index = _todos[dateStr]!.indexWhere((t) => t.id == todoId);
          if (index != -1) {
            _todos[dateStr]![index] = updatedTodo;
          }
        }

        // Update local database
        await _databaseService.saveTodo(updatedTodo);

        // Queue the change
        await _offlineQueueService.queueChange(
          type: 'UPDATE_TODO',
          payload: {
            'id': todoId,
            'text': text,
            'assignedDate': assignedDate,
          },
        );
      }

      notifyListeners();
    } catch (e) {
      _setError('Failed to update todo: $e');
      rethrow;
    }
  }

  // Delete a todo
  Future<void> deleteTodo(int todoId, String assignedDate) async {
    try {
      await _checkOnlineStatus();

      if (_isOnline) {
        // Online mode: send to backend
        await _todoApi.deleteTodo(id: todoId);

        // Remove from state
        if (_todos.containsKey(assignedDate)) {
          _todos[assignedDate]!.removeWhere((t) => t.id == todoId);
        }

        // Delete from local database
        await _databaseService.deleteTodo(todoId);
      } else {
        // Offline mode: remove from local database and queue
        if (_todos.containsKey(assignedDate)) {
          _todos[assignedDate]!.removeWhere((t) => t.id == todoId);
        }

        // Delete from local database
        await _databaseService.deleteTodo(todoId);

        // Queue the change
        await _offlineQueueService.queueChange(
          type: 'DELETE_TODO',
          payload: {
            'id': todoId,
          },
        );
      }

      notifyListeners();
    } catch (e) {
      _setError('Failed to delete todo: $e');
      rethrow;
    }
  }

  // Complete/uncomplete a todo
  Future<void> completeTodo(int todoId, String assignedDate, bool isCompleted) async {
    try {
      await _checkOnlineStatus();

      if (_isOnline) {
        // Online mode: send to backend
        final updatedTodo = await _todoApi.completeTodo(
          id: todoId,
          isCompleted: isCompleted,
        );

        // Update in state
        if (_todos.containsKey(assignedDate)) {
          final index = _todos[assignedDate]!.indexWhere((t) => t.id == todoId);
          if (index != -1) {
            _todos[assignedDate]![index] = updatedTodo;
          }
        }

        // Update local database
        await _databaseService.saveTodo(updatedTodo);
      } else {
        // Offline mode: update local database and queue
        if (_todos.containsKey(assignedDate)) {
          final index = _todos[assignedDate]!.indexWhere((t) => t.id == todoId);
          if (index != -1) {
            final todo = _todos[assignedDate]![index];
            final updatedTodo = Todo(
              id: todo.id,
              text: todo.text,
              assignedDate: todo.assignedDate,
              instanceDate: todo.instanceDate,
              position: todo.position,
              recurringTodoId: todo.recurringTodoId,
              isCompleted: isCompleted,
              isRolledOver: todo.isRolledOver,
              isVirtual: todo.isVirtual,
            );
            _todos[assignedDate]![index] = updatedTodo;

            // Update local database
            await _databaseService.saveTodo(updatedTodo);
          }
        }

        // Queue the change
        await _offlineQueueService.queueChange(
          type: 'COMPLETE_TODO',
          payload: {
            'id': todoId,
            'isCompleted': isCompleted,
          },
        );
      }

      notifyListeners();
    } catch (e) {
      _setError('Failed to complete todo: $e');
      rethrow;
    }
  }

  // Reorder todos
  Future<void> reorderTodos(String date, List<int> todoIds) async {
    try {
      await _checkOnlineStatus();

      if (_isOnline) {
        // Online mode: send to backend
        await _todoApi.reorderTodos(date: date, todoIds: todoIds);

        // Update positions in state
        if (_todos.containsKey(date)) {
          for (int i = 0; i < todoIds.length; i++) {
            final todoId = todoIds[i];
            final index = _todos[date]!.indexWhere((t) => t.id == todoId);
            if (index != -1) {
              final todo = _todos[date]![index];
              final updatedTodo = Todo(
                id: todo.id,
                text: todo.text,
                assignedDate: todo.assignedDate,
                instanceDate: todo.instanceDate,
                position: i,
                recurringTodoId: todo.recurringTodoId,
                isCompleted: todo.isCompleted,
                isRolledOver: todo.isRolledOver,
                isVirtual: todo.isVirtual,
              );
              _todos[date]![index] = updatedTodo;

              // Update local database
              await _databaseService.saveTodo(updatedTodo);
            }
          }
          _todos[date]!.sort((a, b) => a.position.compareTo(b.position));
        }
      } else {
        // Offline mode: update local database and queue
        if (_todos.containsKey(date)) {
          for (int i = 0; i < todoIds.length; i++) {
            final todoId = todoIds[i];
            final index = _todos[date]!.indexWhere((t) => t.id == todoId);
            if (index != -1) {
              final todo = _todos[date]![index];
              final updatedTodo = Todo(
                id: todo.id,
                text: todo.text,
                assignedDate: todo.assignedDate,
                instanceDate: todo.instanceDate,
                position: i,
                recurringTodoId: todo.recurringTodoId,
                isCompleted: todo.isCompleted,
                isRolledOver: todo.isRolledOver,
                isVirtual: todo.isVirtual,
              );
              _todos[date]![index] = updatedTodo;

              // Update local database
              await _databaseService.saveTodo(updatedTodo);
            }
          }
          _todos[date]!.sort((a, b) => a.position.compareTo(b.position));
        }

        // Queue the change
        await _offlineQueueService.queueChange(
          type: 'REORDER_TODOS',
          payload: {
            'date': date,
            'todoIds': todoIds,
          },
        );
      }

      notifyListeners();
    } catch (e) {
      _setError('Failed to reorder todos: $e');
      rethrow;
    }
  }

  // Refresh todos (force reload from backend)
  Future<void> refresh() async {
    await _checkOnlineStatus();
    await loadTodos(force: true);
    await loadRecurringTodos();
  }
}
