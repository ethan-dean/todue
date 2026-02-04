import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../models/todo.dart';
import '../services/todo_api.dart';
import '../services/database_service.dart';
import '../services/websocket_service.dart';

class TodoProvider extends ChangeNotifier {
  final TodoApi _todoApi;
  final DatabaseService _databaseService;
  final WebSocketService _websocketService;

  // State
  Map<String, List<Todo>> _todos = {};
  Set<String> _loadedDates = {};  // Tracks dates that have been loaded from API
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;
  String? _error;
  bool _isOnline = true;
  VoidCallback? _wsUnsubscribe;
  int _pendingMutationCount = 0;

  /// Decrement the pending mutation counter after a delay.
  /// The delay ensures the counter stays elevated through the window where
  /// the afterCommit WebSocket message arrives and triggers a refetch.
  /// Without this, the HTTP response decrements the counter before the
  /// WS-triggered loadTodos runs, letting stale data through.
  void _decrementPendingMutations() {
    Future.delayed(const Duration(milliseconds: 500), () {
      _pendingMutationCount--;
    });
  }

  // Getters
  Map<String, List<Todo>> get todos => _todos;
  DateTime get selectedDate => _selectedDate;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isOnline => _isOnline;

  // Check if the selected date has been loaded from API
  bool get isSelectedDateLoaded => _loadedDates.contains(_formatDate(_selectedDate));

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
    // Subscribe to todo-related WebSocket message types
    _wsUnsubscribe = _websocketService.subscribe(
      [WebSocketMessageType.TODOS_CHANGED, WebSocketMessageType.RECURRING_CHANGED],
      _handleWebSocketMessage,
    );

    // Check online status and load initial data
    await _checkOnlineStatus();
    await loadTodos(force: true);

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

      // Save each day to DB and update RAM
      for (final entry in groupedTodos.entries) {
        // Update RAM
        // We only update if we don't have pending mutations for this date (simple check)
        // Since prefetch happens on load, this is usually safe.
        // We overwrite whatever is there because this is "Fresh" data from API.
        _todos[entry.key] = entry.value;
        _loadedDates.add(entry.key);  // Mark as loaded from API

        await _databaseService.saveTodosForDate(entry.key, entry.value);
      }
      
      notifyListeners(); // Update UI with prefetched data
      print('Prefetched window: $startStr to $endStr');
    } catch (e) {
      print('Prefetch failed: $e');
    }
  }

  @override
  void dispose() {
    _wsUnsubscribe?.call();
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

  // Handle WebSocket messages - only receives TODOS_CHANGED and RECURRING_CHANGED
  void _handleWebSocketMessage(WebSocketMessage message) async {
    print('TodoProvider WebSocket message: ${message.type}');

    if (message.type == WebSocketMessageType.TODOS_CHANGED) {
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
    } else if (message.type == WebSocketMessageType.RECURRING_CHANGED) {
      // Recurring pattern changed - refetch all loaded dates to update virtual todos
      _todos.keys.toList().forEach((dateStr) {
        try {
          final date = DateTime.parse(dateStr);
          loadTodos(date: date, force: true);
        } catch (e) {
          print('Error reloading date $dateStr: $e');
        }
      });
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

    _setError(null);

    final hasPendingMutations = _pendingMutationCount > 0;

    // 1. Load from Cache (DB) immediately - BUT only if no pending mutations
    // If we have mutations in flight, the DB might be stale compared to our optimistic RAM state.
    // We want to keep showing RAM state until API confirms.
    if (!hasPendingMutations) {
      try {
        final localTodos = await _databaseService.getTodos(date: dateStr);
        if (localTodos.isNotEmpty) {
          _todos[dateStr] = localTodos;
          _loadedDates.add(dateStr);  // Mark as loaded from local cache
          notifyListeners(); // Show cached data instantly
        }
      } catch (e) {
        print('Cache load failed: $e');
      }
    } else {
      print('Skipping DB load due to pending mutations');
    }

    // 2. Fetch from API (Stale-While-Revalidate)
    try {
      final fetchedTodos = await _todoApi.getTodos(date: dateStr);

      // Guard: If mutations are still in flight, their WS-triggered refetches
      // may return data that doesn't reflect those mutations yet
      print('loadTodos guard check: _pendingMutationCount=$_pendingMutationCount for $dateStr');
      if (_pendingMutationCount > 0) {
        print('Discarding stale fetch result ($_pendingMutationCount mutations still in flight)');
        return;
      }

      _todos[dateStr] = fetchedTodos;
      _loadedDates.add(dateStr);  // Mark this date as loaded from API
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
      if (!hasPendingMutations) {
        _setLoading(false);
      }
      notifyListeners();
    }
  }

  // Create a new todo
  Future<void> createTodo({
    required String text,
    DateTime? date,
    int? recurringTodoId,
    int? position,
  }) async {
    _pendingMutationCount++;

    await _checkOnlineStatus();
    if (!_isOnline) {
      throw Exception('Cannot create todo while offline');
    }

    final targetDate = date ?? _selectedDate;
    final dateStr = _formatDate(targetDate);

    // Optimistic Update
    final tempId = -1 * DateTime.now().millisecondsSinceEpoch; // Temporary ID
    
    // Calculate optimistic position
    // If explicit position is requested, use it; otherwise use a high number to append
    int optimisticPos = position ?? 999999;

    final optimisticTodo = Todo(
      id: tempId,
      text: text,
      assignedDate: dateStr,
      instanceDate: dateStr,
      position: optimisticPos, 
      recurringTodoId: recurringTodoId,
      isCompleted: false,
      isRolledOver: false,
      isVirtual: false,
    );

    if (!_todos.containsKey(dateStr)) {
      _todos[dateStr] = [];
    }
    
    // Apply optimistic insert
    if (position != null && position == 1) {
       // Optimistic: Insert at top. Full renumbering happens on server sync to avoid UI jank.
       _todos[dateStr]!.insert(0, optimisticTodo);
    } else {
       _todos[dateStr]!.add(optimisticTodo);
    }
    
    notifyListeners();

    try {
      final serverTodo = await _todoApi.createTodo(
        text: text,
        assignedDate: dateStr,
        recurringTodoId: recurringTodoId,
        position: position,
      );

      // Replace optimistic todo with real one
      final index = _todos[dateStr]!.indexWhere((t) => t.id == tempId);
      if (index != -1) {
        _todos[dateStr]![index] = serverTodo;
      } else {
        _todos[dateStr]!.add(serverTodo);
      }

      await _databaseService.saveTodo(serverTodo);
      notifyListeners();
    } catch (e) {
      _todos[dateStr]!.removeWhere((t) => t.id == tempId);
      notifyListeners();
      _setError('Failed to create todo: $e');
      rethrow;
    } finally {
      _decrementPendingMutations();
    }
  }

  // Update a todo
  Future<void> updateTodo({
    required int? todoId,
    String? text,
    String? assignedDate,
    bool isVirtual = false,
    int? recurringTodoId,
    String? instanceDate,
  }) async {
    _pendingMutationCount++;

    await _checkOnlineStatus();
    if (!_isOnline) {
      throw Exception('Cannot update todo while offline');
    }

    String? foundDateStr;
    int? foundIndex;
    Todo? originalTodo;

    // Find the todo in our local state
    _todos.forEach((key, list) {
      final idx = list.indexWhere((t) => 
        (t.id != null && t.id == todoId) || 
        (isVirtual && t.recurringTodoId == recurringTodoId && t.instanceDate == instanceDate)
      );
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
      // Note: Optimistic date change skipped for simplicity; handled after server response.
    );

    _todos[foundDateStr]![foundIndex!] = optimisticTodo;
    notifyListeners();

    try {
      Todo serverTodo;
      if (isVirtual && recurringTodoId != null && instanceDate != null && text != null) {
        // Updating virtual todo text (orphans it)
        serverTodo = await _todoApi.updateVirtualTodoText(
          recurringTodoId: recurringTodoId,
          instanceDate: instanceDate,
          text: text,
        );
      } else if (todoId != null) {
        // Regular update
        serverTodo = await _todoApi.updateTodo(
          id: todoId,
          text: text,
          assignedDate: assignedDate,
        );
      } else {
         throw Exception("Invalid update parameters");
      }

      // Handle response - check if it moved dates
      if (serverTodo.assignedDate != foundDateStr) {
        _todos[foundDateStr]!.removeWhere((t) => 
            (t.id != null && t.id == todoId) || 
            (isVirtual && t.recurringTodoId == recurringTodoId && t.instanceDate == instanceDate)
        );
        
        if (!_todos.containsKey(serverTodo.assignedDate)) {
          _todos[serverTodo.assignedDate] = [];
        }
        _todos[serverTodo.assignedDate]!.add(serverTodo);
      } else {
        // Update in place
        final idx = _todos[foundDateStr]!.indexWhere((t) => 
            (t.id != null && t.id == todoId) || 
            (isVirtual && t.recurringTodoId == recurringTodoId && t.instanceDate == instanceDate)
        );
        
        if (idx != -1) {
          _todos[foundDateStr]![idx] = serverTodo;
        }
      }
      
      // Sort the target list
      _todos[serverTodo.assignedDate]?.sort((a, b) => a.position.compareTo(b.position));

      await _databaseService.saveTodo(serverTodo);
      notifyListeners();
    } catch (e) {
      // Rollback
      if (foundDateStr != null && foundIndex != null) {
        _todos[foundDateStr!]![foundIndex!] = originalTodo!;
        notifyListeners();
      }
      _setError('Failed to update todo: $e');
      rethrow;
    } finally {
      _decrementPendingMutations();
    }
  }

  // Delete a todo
  Future<void> deleteTodo(
    int? todoId,
    String assignedDate, {
    bool isVirtual = false,
    int? recurringTodoId,
    String? instanceDate,
    bool deleteAllFuture = false,
  }) async {
    _pendingMutationCount++;

    await _checkOnlineStatus();
    if (!_isOnline) {
      throw Exception('Cannot delete todo while offline');
    }

    if (!_todos.containsKey(assignedDate)) return;

    final index = _todos[assignedDate]!.indexWhere((t) =>
        (t.id != null && t.id == todoId) ||
        (isVirtual &&
            t.recurringTodoId == recurringTodoId &&
            t.instanceDate == instanceDate));

    if (index == -1) return;

    // Snapshot for rollback
    final originalTodo = _todos[assignedDate]![index];

    // Optimistic Update
    // If deleting all future, we need to remove from all future dates
    if (deleteAllFuture && recurringTodoId != null && instanceDate != null) {
      _todos.forEach((dateKey, list) {
        if (dateKey.compareTo(instanceDate) >= 0) {
          list.removeWhere((t) => t.recurringTodoId == recurringTodoId);
          // Renumber positions after removal
          for (int i = 0; i < list.length; i++) {
            list[i] = list[i].copyWith(position: i + 1);
          }
        }
      });
    } else {
      _todos[assignedDate]!.removeAt(index);
      // Renumber positions after removal
      final list = _todos[assignedDate]!;
      for (int i = 0; i < list.length; i++) {
        list[i] = list[i].copyWith(position: i + 1);
      }
    }
    notifyListeners();

    try {
      if (isVirtual && recurringTodoId != null && instanceDate != null) {
        await _todoApi.deleteVirtualTodo(
          recurringTodoId: recurringTodoId,
          instanceDate: instanceDate,
          deleteAllFuture: deleteAllFuture,
        );
      } else if (todoId != null) {
        await _todoApi.deleteTodo(
          id: todoId,
          deleteAllFuture: deleteAllFuture,
        );
        // Delete from Cache (only for real todos)
        await _databaseService.deleteTodo(todoId);
      }
    } catch (e) {
      // Rollback (simplified - just putting back the single item for now)
      // A full rollback for "delete all future" is complex, might be better to just reload
      if (deleteAllFuture) {
        await loadTodos(force: true);
      } else {
        _todos[assignedDate]!.insert(index, originalTodo);
      }
      notifyListeners();
      _setError('Failed to delete todo: $e');
      rethrow;
    } finally {
      _decrementPendingMutations();
    }
  }

  // Complete/uncomplete a todo
  Future<void> completeTodo(
    int? todoId,
    String assignedDate,
    bool isCompleted, {
    bool isVirtual = false,
    int? recurringTodoId,
    String? instanceDate,
  }) async {
    _pendingMutationCount++;

    await _checkOnlineStatus();
    if (!_isOnline) {
      throw Exception('Cannot complete todo while offline');
    }

    if (!_todos.containsKey(assignedDate)) return;

    final index = _todos[assignedDate]!.indexWhere((t) =>
        (t.id != null && t.id == todoId) ||
        (isVirtual &&
            t.recurringTodoId == recurringTodoId &&
            t.instanceDate == instanceDate));

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
      Todo serverTodo;
      if (isVirtual && recurringTodoId != null && instanceDate != null && isCompleted) {
        // Completing a virtual todo
        serverTodo = await _todoApi.completeVirtualTodo(
          recurringTodoId: recurringTodoId,
          instanceDate: instanceDate,
        );
      } else if (todoId != null) {
        // Completing/Uncompleting a real todo
        serverTodo = await _todoApi.completeTodo(
          id: todoId,
          isCompleted: isCompleted,
        );
      } else {
        throw Exception('Invalid state for completeTodo');
      }

      // Replace the optimistic todo with the confirmed server state.
      // For virtual items, we match using recurring properties as the server generates the ID.
      final currentList = _todos[assignedDate]!;
      int idx = -1;
      if (todoId != null) {
        idx = currentList.indexWhere((t) => t.id == todoId);
      } else {
        idx = currentList.indexWhere((t) => t.recurringTodoId == recurringTodoId && t.instanceDate == instanceDate);
      }

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
    } finally {
      _decrementPendingMutations();
    }
  }

  // Reorder todos
  void reorderTodos(String date, int oldIndex, int newIndex) {
    _pendingMutationCount++;

    // Check cached online status immediately
    if (!_isOnline) {
      _pendingMutationCount--;
      _setError('Cannot reorder todos while offline');
      notifyListeners(); // Force UI to snap back
      return;
    }

    if (!_todos.containsKey(date)) {
      _pendingMutationCount--;
      return;
    }

    // Snapshot for rollback
    final originalList = List<Todo>.from(_todos[date]!);

    // Adjust newIndex if moving down (Flutter ReorderableListView quirk)
    int adjustedNewIndex = newIndex;
    if (oldIndex < newIndex) {
      adjustedNewIndex -= 1;
    }

    if (oldIndex == adjustedNewIndex) {
      _pendingMutationCount--;
      return;
    }

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
    } finally {
      _decrementPendingMutations();
    }
  }

  // Move todo to another date
  Future<void> moveTodo(Todo todo, DateTime toDate) async {
    _pendingMutationCount++;

    await _checkOnlineStatus();
    if (!_isOnline) {
      throw Exception('Cannot move todo while offline');
    }

    final fromDateStr = todo.assignedDate;
    final toDateStr = _formatDate(toDate);

    if (fromDateStr == toDateStr) return;

    // Snapshot for rollback
    final originalFromList = _todos[fromDateStr] != null ? List<Todo>.from(_todos[fromDateStr]!) : <Todo>[];
    final originalToList = _todos[toDateStr] != null ? List<Todo>.from(_todos[toDateStr]!) : <Todo>[];

    // Optimistic Update
    // 1. Remove from source
    if (_todos.containsKey(fromDateStr)) {
      _todos[fromDateStr]!.removeWhere((t) => t.id == todo.id && 
          (!t.isVirtual || (t.recurringTodoId == todo.recurringTodoId && t.instanceDate == todo.instanceDate)));
    }

    // 2. Add to target (at end of active items)
    if (!_todos.containsKey(toDateStr)) {
      _todos[toDateStr] = [];
    }
    
    final targetList = _todos[toDateStr]!;
    
    // Find insertion index (before first completed)
    int insertIndex = targetList.indexWhere((t) => t.isCompleted);
    if (insertIndex == -1) insertIndex = targetList.length;

    // Create updated todo object
    final movedTodo = todo.copyWith(
      assignedDate: toDateStr,
      // If it was virtual, it becomes real (orphaned) on the new date, so isVirtual=false
      // But we let the backend handle the ID generation. Locally we keep the old ID/data 
      // but treat it as a "Pending" item on the new list.
      isRolledOver: false, // Reset rollover status
      // Position will be set in renumbering loop
    );
    
    targetList.insert(insertIndex, movedTodo);
    
    // Renumber all items in target list
    for (int i = 0; i < targetList.length; i++) {
      targetList[i] = targetList[i].copyWith(position: i + 1);
    }

    notifyListeners();

    try {
      // Call API
      Todo serverTodo;
      if (todo.isVirtual && todo.recurringTodoId != null) {
        serverTodo = await _todoApi.updateVirtualTodoAssignedDate(
          recurringTodoId: todo.recurringTodoId!,
          instanceDate: todo.instanceDate,
          assignedDate: toDateStr,
        );
      } else {
        serverTodo = await _todoApi.updateTodoAssignedDate(
          id: todo.id!,
          assignedDate: toDateStr,
        );
      }

      // Update target list with real server object
      final index = _todos[toDateStr]!.indexWhere((t) => 
          (t.id != null && t.id == todo.id) || 
          (t.isVirtual && t.recurringTodoId == todo.recurringTodoId && t.instanceDate == todo.instanceDate)
      );
      if (index != -1) {
        _todos[toDateStr]![index] = serverTodo;
      }
      
      // Save both lists to DB cache
      await _databaseService.saveTodosForDate(fromDateStr, _todos[fromDateStr] ?? []);
      await _databaseService.saveTodosForDate(toDateStr, _todos[toDateStr]!);

    } catch (e) {
      // Rollback
      _todos[fromDateStr] = originalFromList;
      _todos[toDateStr] = originalToList;
      notifyListeners();
      _setError('Failed to move todo: $e');
      rethrow;
    } finally {
      _decrementPendingMutations();
    }
  }

  // Refresh todos (force reload from backend)
  Future<void> refresh() async {
    await _checkOnlineStatus();
    await loadTodos(force: true);
  }
}
