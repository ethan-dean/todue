import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../models/todo.dart';
import '../models/recurring_todo.dart';
import '../services/todo_api.dart';
import '../services/database_service.dart';
import '../services/websocket_service.dart';

class TodoProvider extends ChangeNotifier {
  final TodoApi _todoApi;
  final DatabaseService _databaseService;
  final WebSocketService _websocketService;

  // State
  Map<String, List<Todo>> _todos = {};
  List<RecurringTodo> _recurringTodos = [];
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;
  String? _error;
  bool _isOnline = true;
  StreamSubscription? _wsSubscription;
  DateTime _lastMutationTime = DateTime.fromMillisecondsSinceEpoch(0);

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
    required WebSocketService websocketService,
  })  : _todoApi = todoApi,
        _databaseService = databaseService,
        _websocketService = websocketService {
    _init();
  }

  Future<void> _init() async {
    // Set up WebSocket listener
    _wsSubscription = _websocketService.messageStream.listen((message) {
      _handleWebSocketMessage(message);
    });

    // Check online status and load initial data
    await _checkOnlineStatus();
    await loadTodos(force: true);
    await loadRecurringTodos();
    
    // Background pre-fetch for offline availability (-7 to +14 days)
    _prefetchWindow();
  }

  /// Pre-fetch data for the surrounding days to ensure offline availability
  /// Window: Today - 7 days to Today + 14 days
  Future<void> _prefetchWindow() async {
    if (!_isOnline) return;

    try {
      final now = DateTime.now();
      final startDate = now.subtract(const Duration(days: 7));
      final endDate = now.add(const Duration(days: 14));
      
      final startStr = _formatDate(startDate);
      final endStr = _formatDate(endDate);

      // Fetch range from API
      // Note: This assumes TodoApi has a range endpoint. If not, we'd loop.
      // TodoApi has getTodosForDateRange.
      final todosInRange = await _todoApi.getTodosForDateRange(
        startDate: startStr,
        endDate: endStr,
      );

      // Group by date and save to DB
      // We need to clear/update the DB for this range. 
      // Efficient approach: Group by date and save each day.
      final Map<String, List<Todo>> groupedTodos = {};
      
      // Initialize keys for all days in range to ensure empty days are cached as empty
      for (int i = 0; i <= 21; i++) {
        final date = startDate.add(Duration(days: i));
        groupedTodos[_formatDate(date)] = [];
      }

      for (final todo in todosInRange) {
        if (!groupedTodos.containsKey(todo.assignedDate)) {
          groupedTodos[todo.assignedDate] = [];
        }
        groupedTodos[todo.assignedDate]!.add(todo);
      }

      // Save each day to DB
      for (final entry in groupedTodos.entries) {
        // Only update RAM if we haven't loaded it yet (to avoid overwriting user interactions)
        // Actually, for "cache-only" purposes, we mainly want to hit the DB.
        // But if we are looking at that day, we might as well update RAM.
        if (_todos.containsKey(entry.key)) {
          _todos[entry.key] = entry.value;
        }
        
        await _databaseService.saveTodosForDate(entry.key, entry.value);
      }
      
      print('Prefetched window: $startStr to $endStr');
    } catch (e) {
      print('Prefetch failed: $e');
    }
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
    final result = await Connectivity().checkConnectivity();
    _isOnline = result != ConnectivityResult.none;
    notifyListeners();
  }

  // Handle WebSocket messages
  void _handleWebSocketMessage(WebSocketMessage message) async {
    // Delay to allow backend DB to settle
    await Future.delayed(const Duration(milliseconds: 300));

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
    final fetchStartTime = DateTime.now();
    final targetDate = date ?? _selectedDate;
    final dateStr = _formatDate(targetDate);

    // Skip if already loaded and not forcing
    if (!force && _todos.containsKey(dateStr) && _todos[dateStr]!.isNotEmpty) {
      return;
    }

    _setError(null);

    // 1. Load from Cache (DB) immediately - BUT only if no recent mutation
    // If we just mutated, the DB might be stale compared to our optimistic RAM state.
    // We want to keep showing RAM state until API confirms.
    const recentMutationWindow = Duration(seconds: 2);
    final hasRecentMutation = DateTime.now().difference(_lastMutationTime) < recentMutationWindow;

    if (!hasRecentMutation) {
      try {
        final localTodos = await _databaseService.getTodos(date: dateStr);
        if (localTodos.isNotEmpty) {
          _todos[dateStr] = localTodos;
          notifyListeners(); // Show cached data instantly
        } else {
          _setLoading(true); // Only show spinner if cache is empty
        }
      } catch (e) {
        print('Cache load failed: $e');
      }
    } else {
      print('Skipping DB load due to recent mutation');
    }

    // 2. Fetch from API (Stale-While-Revalidate)
    try {
      final fetchedTodos = await _todoApi.getTodos(date: dateStr);
      
      // Guard: If a mutation happened since we started fetching, ignore this result
      // to avoid overwriting optimistic updates with stale data.
      if (_lastMutationTime.isAfter(fetchStartTime)) {
        print('Discarding stale fetch result (mutation occurred during fetch)');
        return;
      }

      _todos[dateStr] = fetchedTodos;
      _isOnline = true;

      // Update Cache
      await _databaseService.saveTodosForDate(dateStr, fetchedTodos);
    } catch (e) {
      print('API load failed: $e');
      _isOnline = false;
      // If we failed to load from API and cache was empty, show error
      if (!_todos.containsKey(dateStr) || _todos[dateStr]!.isEmpty) {
        _setError('Failed to load todos');
      }
    } finally {
      if (!hasRecentMutation) {
        _setLoading(false);
      }
      notifyListeners();
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
    _lastMutationTime = DateTime.now(); // Track local mutation
    
    await _checkOnlineStatus();
    if (!_isOnline) {
      throw Exception('Cannot create todo while offline');
    }

    final targetDate = date ?? _selectedDate;
    final dateStr = _formatDate(targetDate);

    // Optimistic Update
    final tempId = -1 * DateTime.now().millisecondsSinceEpoch; // Temporary negative ID
    final optimisticTodo = Todo(
      id: tempId,
      text: text,
      assignedDate: dateStr,
      instanceDate: dateStr,
      position: 999999, // Place at bottom temporarily
      recurringTodoId: recurringTodoId,
      isCompleted: false,
      isRolledOver: false,
      isVirtual: false,
    );

    // Apply optimistic update
    if (!_todos.containsKey(dateStr)) {
      _todos[dateStr] = [];
    }
    _todos[dateStr]!.add(optimisticTodo);
    notifyListeners();

    try {
      // Call API
      final serverTodo = await _todoApi.createTodo(
        text: text,
        assignedDate: dateStr,
        recurringTodoId: recurringTodoId,
      );

      // Replace optimistic todo with real one
      final index = _todos[dateStr]!.indexWhere((t) => t.id == tempId);
      if (index != -1) {
        _todos[dateStr]![index] = serverTodo;
        _todos[dateStr]!.sort((a, b) => a.position.compareTo(b.position));
      } else {
        // Fallback if list changed (unlikely)
        _todos[dateStr]!.add(serverTodo);
      }

      // Update Cache
      await _databaseService.saveTodo(serverTodo);
      notifyListeners();
    } catch (e) {
      // Rollback
      _todos[dateStr]!.removeWhere((t) => t.id == tempId);
      notifyListeners();
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
    _lastMutationTime = DateTime.now(); // Track local mutation

    await _checkOnlineStatus();
    if (!_isOnline) {
      throw Exception('Cannot update todo while offline');
    }

    // Identify the date key - if assignedDate is provided, it might move, which is complex.
    // Assuming assignedDate is not changing for this simple refactor or is the same.
    // If we support moving dates, we need to know the *old* date to remove it from there.
    // For now, we search all lists (inefficient but safe) or rely on current implementation assumption.
    // Current implementation assumes we know the dateStr from `updatedTodo.assignedDate` AFTER API.
    // To be optimistic, we need to know where it is NOW.
    
    String? foundDateStr;
    int? foundIndex;
    Todo? originalTodo;

    _todos.forEach((key, list) {
      final idx = list.indexWhere((t) => t.id == todoId);
      if (idx != -1) {
        foundDateStr = key;
        foundIndex = idx;
        originalTodo = list[idx];
      }
    });

    if (foundDateStr == null || originalTodo == null) return;

    // Optimistic Update
    final optimisticTodo = originalTodo!.copyWith(
      text: text ?? originalTodo!.text,
      // Note: Changing date optimistically requires moving lists. 
      // We will skip optimistic date change for simplicity unless strictly needed.
    );

    _todos[foundDateStr]![foundIndex!] = optimisticTodo;
    notifyListeners();

    try {
      // Call API
      final serverTodo = await _todoApi.updateTodo(
        id: todoId,
        text: text,
        assignedDate: assignedDate,
      );

      // Update with server data
      // Check if it moved dates (server response vs local)
      if (serverTodo.assignedDate != foundDateStr) {
        // It moved! Remove from old, add to new.
        _todos[foundDateStr]!.removeWhere((t) => t.id == todoId);
        
        if (!_todos.containsKey(serverTodo.assignedDate)) {
          _todos[serverTodo.assignedDate] = [];
        }
        _todos[serverTodo.assignedDate]!.add(serverTodo);
      } else {
        // Just update in place
        final idx = _todos[foundDateStr]!.indexWhere((t) => t.id == todoId);
        if (idx != -1) {
          _todos[foundDateStr]![idx] = serverTodo;
        }
      }
      
      // Sort the target list
      _todos[serverTodo.assignedDate]?.sort((a, b) => a.position.compareTo(b.position));

      // Update Cache
      await _databaseService.saveTodo(serverTodo);
      notifyListeners();
    } catch (e) {
      // Rollback
      if (foundDateStr != null && foundIndex != null) {
        // Put it back exactly as it was
        // If we moved lists in optimistic (we didn't here), we'd need to revert that too.
        _todos[foundDateStr!]![foundIndex!] = originalTodo!;
        notifyListeners();
      }
      _setError('Failed to update todo: $e');
      rethrow;
    }
  }

  // Delete a todo
  Future<void> deleteTodo(int todoId, String assignedDate) async {
    _lastMutationTime = DateTime.now(); // Track local mutation

    await _checkOnlineStatus();
    if (!_isOnline) {
      throw Exception('Cannot delete todo while offline');
    }

    if (!_todos.containsKey(assignedDate)) return;

    final index = _todos[assignedDate]!.indexWhere((t) => t.id == todoId);
    if (index == -1) return;

    // Snapshot for rollback
    final originalTodo = _todos[assignedDate]![index];

    // Optimistic Update
    _todos[assignedDate]!.removeAt(index);
    notifyListeners();

    try {
      // Call API
      await _todoApi.deleteTodo(id: todoId);

      // Delete from Cache
      await _databaseService.deleteTodo(todoId);
    } catch (e) {
      // Rollback
      _todos[assignedDate]!.insert(index, originalTodo);
      notifyListeners();
      _setError('Failed to delete todo: $e');
      rethrow;
    }
  }

  // Complete/uncomplete a todo
  Future<void> completeTodo(int todoId, String assignedDate, bool isCompleted) async {
    _lastMutationTime = DateTime.now(); // Track local mutation

    await _checkOnlineStatus();
    if (!_isOnline) {
      throw Exception('Cannot complete todo while offline');
    }

    if (!_todos.containsKey(assignedDate)) return;

    final index = _todos[assignedDate]!.indexWhere((t) => t.id == todoId);
    if (index == -1) return;

    // Snapshot for rollback
    final originalList = List<Todo>.from(_todos[assignedDate]!);
    final originalTodo = _todos[assignedDate]![index];
    
    // Optimistic Update
    final optimisticTodo = originalTodo.copyWith(isCompleted: isCompleted);
    
    // Remove from old position
    final newList = List<Todo>.from(originalList);
    newList.removeAt(index);
    
    // Calculate new insertion index
    int newIndex = 0;
    if (isCompleted) {
      // Move to top of COMPLETED section
      // Find first completed item
      int firstCompleted = newList.indexWhere((t) => t.isCompleted);
      if (firstCompleted == -1) {
        newIndex = newList.length; // Append to end
      } else {
        newIndex = firstCompleted; // Insert before first completed
      }
    } else {
      // Move to bottom of ACTIVE section
      // Find first completed item (start of completed section)
      int firstCompleted = newList.indexWhere((t) => t.isCompleted);
      if (firstCompleted == -1) {
        newIndex = newList.length; // Append to end (all active)
      } else {
        newIndex = firstCompleted; // Insert before first completed (end of active)
      }
    }
    
    newList.insert(newIndex, optimisticTodo);
    
    // Renumber positions (1-based) locally for UI consistency
    // Note: Backend handles authoritative renumbering
    // We update local position state just for UI logic consistency if needed
    // But since we use ReorderableListView with a list, order in list matters most.
    
    _todos[assignedDate] = newList;
    notifyListeners();

    try {
      // Call API
      final serverTodo = await _todoApi.completeTodo(
        id: todoId,
        isCompleted: isCompleted,
      );

      // Update with server data
      final idx = _todos[assignedDate]!.indexWhere((t) => t.id == todoId);
      if (idx != -1) {
        _todos[assignedDate]![idx] = serverTodo;
      }

      // Update Cache
      await _databaseService.saveTodosForDate(assignedDate, _todos[assignedDate]!);
      notifyListeners();
    } catch (e) {
      // Rollback
      _todos[assignedDate] = originalList;
      notifyListeners();
      _setError('Failed to update completion status: $e');
      rethrow;
    }
  }

  // Reorder todos
  void reorderTodos(String date, int oldIndex, int newIndex) {
    _lastMutationTime = DateTime.now(); // Track local mutation

    // Check cached online status immediately
    if (!_isOnline) {
      _setError('Cannot reorder todos while offline');
      notifyListeners(); // Force UI to snap back
      return;
    }

    if (!_todos.containsKey(date)) return;

    // Snapshot for rollback
    final originalList = List<Todo>.from(_todos[date]!);
    
    // Adjust newIndex if moving down (Flutter ReorderableListView quirk)
    int adjustedNewIndex = newIndex;
    if (oldIndex < newIndex) {
      adjustedNewIndex -= 1;
    }
    
    if (oldIndex == adjustedNewIndex) return;

    final movedTodo = originalList[oldIndex];

    // Optimistic Update (Synchronous)
    final newList = List<Todo>.from(originalList);
    newList.removeAt(oldIndex);
    newList.insert(adjustedNewIndex, movedTodo);
    
    // Update position numbers locally (1-based)
    for (int i = 0; i < newList.length; i++) {
      newList[i] = newList[i].copyWith(position: i + 1);
    }

    _todos[date] = newList;
    notifyListeners(); // Immediate UI update

    // Asynchronous Sync
    _syncReorder(date, movedTodo, adjustedNewIndex, newList, originalList);
  }

  Future<void> _syncReorder(String date, Todo movedTodo, int newIndex, List<Todo> newList, List<Todo> originalList) async {
    try {
      await _checkOnlineStatus();
      if (!_isOnline) {
        throw Exception('Cannot reorder todos while offline');
      }

      // Call API for the single moved item
      // Position is 1-based index
      final position = newIndex;
      
      if (movedTodo.isVirtual && movedTodo.recurringTodoId != null) {
        await _todoApi.updateVirtualTodoPosition(
          recurringTodoId: movedTodo.recurringTodoId!,
          instanceDate: movedTodo.instanceDate,
          position: position,
        );
      } else {
        await _todoApi.updateTodoPosition(
          id: movedTodo.id!,
          position: position,
        );
      }
      
      // Update Cache with optimistic state
      await _databaseService.saveTodosForDate(date, newList);
    } catch (e) {
      // Rollback
      _todos[date] = originalList;
      notifyListeners();
      _setError('Failed to reorder todos: $e');
    }
  }

  // Refresh todos (force reload from backend)
  Future<void> refresh() async {
    await _checkOnlineStatus();
    await loadTodos(force: true);
    await loadRecurringTodos();
  }
}
