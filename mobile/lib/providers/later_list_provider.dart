import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import '../models/later_list.dart';
import '../models/later_list_todo.dart';
import '../services/later_list_api.dart';
import '../services/database_service.dart';
import '../services/websocket_service.dart';

class LaterListProvider extends ChangeNotifier {
  final LaterListApi _laterListApi;
  final WebSocketService _websocketService;
  final DatabaseService _databaseService;

  List<LaterList> _lists = [];
  final Map<int, List<LaterListTodo>> _todos = {};
  int? _currentListId;
  bool _isLoading = false;
  String? _error;

  // Mutation tracking to prevent stale API responses from overwriting optimistic updates
  DateTime _lastMutationTime = DateTime.fromMillisecondsSinceEpoch(0);
  bool _isOnline = true;

  VoidCallback? _wsUnsubscribe;

  LaterListProvider({
    required LaterListApi laterListApi,
    required WebSocketService websocketService,
    required DatabaseService databaseService,
  })  : _laterListApi = laterListApi,
        _websocketService = websocketService,
        _databaseService = databaseService {
    _initWebSocketListener();
  }

  // Getters
  List<LaterList> get lists => _lists;
  int? get currentListId => _currentListId;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isOnline => _isOnline;

  /// Check connectivity status
  Future<void> _checkOnlineStatus() async {
    final result = await Connectivity().checkConnectivity();
    _isOnline = !result.contains(ConnectivityResult.none);
  }

  List<LaterListTodo> getTodosForList(int listId) {
    final todos = _todos[listId] ?? [];
    return List.from(todos)..sort((a, b) => a.position.compareTo(b.position));
  }

  void _initWebSocketListener() {
    // Subscribe only to later list message type
    _wsUnsubscribe = _websocketService.subscribe(
      [WebSocketMessageType.LATER_LIST_CHANGED],
      _handleWebSocketMessage,
    );
  }

  // Handle WebSocket messages - only receives LATER_LIST_CHANGED
  void _handleWebSocketMessage(WebSocketMessage message) {
    debugPrint('LaterListProvider WebSocket message: ${message.type}');

    final data = message.data;
    if (data is! Map<String, dynamic>) return;

    final listId = data['listId'] as int?;
    final action = data['action'] as String?;

    Future.delayed(const Duration(milliseconds: 300), () {
      switch (action) {
        case 'LIST_CREATED':
        case 'LIST_UPDATED':
        case 'LIST_DELETED':
          loadLists(silent: true);
          break;
        case 'TODOS_UPDATED':
          if (listId != null && _currentListId == listId) {
            loadTodosForList(listId, silent: true);
          }
          break;
      }
    });
  }

  // ==================== List Operations ====================

  Future<void> loadLists({bool silent = false}) async {
    final fetchStartTime = DateTime.now();

    if (!silent) {
      _isLoading = true;
      notifyListeners();
    }
    _error = null;

    try {
      // 1. Load from cache immediately (skip if recent mutation to preserve optimistic updates)
      if (DateTime.now().difference(_lastMutationTime) > const Duration(seconds: 2)) {
        final cachedLists = await _databaseService.getLaterLists();
        if (cachedLists.isNotEmpty) {
          _lists = cachedLists;
          notifyListeners();
        }
      }

      // 2. Fetch from API
      final fetchedLists = await _laterListApi.getAllLists();

      // 3. Guard: discard if mutation occurred during fetch
      if (_lastMutationTime.isAfter(fetchStartTime)) {
        debugPrint('Discarding stale fetch for lists');
        return;
      }

      _lists = fetchedLists;
      notifyListeners();

      // 4. Save to cache
      await _databaseService.saveLaterLists(fetchedLists);
    } catch (e) {
      _error = e.toString();
      debugPrint('Failed to load lists: $e');
      notifyListeners();
    } finally {
      if (!silent) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  Future<LaterList?> createList(String listName) async {
    _lastMutationTime = DateTime.now();
    await _checkOnlineStatus();
    if (!_isOnline) {
      _error = 'Cannot create list while offline';
      notifyListeners();
      return null;
    }

    _error = null;
    try {
      final newList = await _laterListApi.createList(listName: listName);
      _lists = [..._lists, newList]..sort((a, b) => a.listName.compareTo(b.listName));
      notifyListeners();

      // Save to cache
      await _databaseService.saveLaterList(newList);
      return newList;
    } catch (e) {
      _error = e.toString();
      debugPrint('Failed to create list: $e');
      notifyListeners();
      return null;
    }
  }

  Future<bool> updateListName(int listId, String newName) async {
    _lastMutationTime = DateTime.now();
    await _checkOnlineStatus();
    if (!_isOnline) {
      _error = 'Cannot update list while offline';
      notifyListeners();
      return false;
    }

    // Optimistic update
    final oldLists = List<LaterList>.from(_lists);
    _lists = _lists.map((l) => l.id == listId ? l.copyWith(listName: newName) : l).toList()
      ..sort((a, b) => a.listName.compareTo(b.listName));
    notifyListeners();

    try {
      await _laterListApi.updateListName(listId: listId, listName: newName);

      // Save to cache
      await _databaseService.saveLaterLists(_lists);
      return true;
    } catch (e) {
      // Rollback
      _lists = oldLists;
      _error = e.toString();
      debugPrint('Failed to update list name: $e');
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteList(int listId) async {
    _lastMutationTime = DateTime.now();
    await _checkOnlineStatus();
    if (!_isOnline) {
      _error = 'Cannot delete list while offline';
      notifyListeners();
      return false;
    }

    // Optimistic update
    final oldLists = List<LaterList>.from(_lists);
    _lists = _lists.where((l) => l.id != listId).toList();
    _todos.remove(listId);
    notifyListeners();

    try {
      await _laterListApi.deleteList(listId: listId);
      if (_currentListId == listId) {
        _currentListId = null;
      }

      // Delete from cache
      await _databaseService.deleteLaterList(listId);
      await _databaseService.clearLaterListTodos(listId);
      return true;
    } catch (e) {
      // Rollback
      _lists = oldLists;
      _error = e.toString();
      debugPrint('Failed to delete list: $e');
      notifyListeners();
      return false;
    }
  }

  // ==================== Todo Operations ====================

  void setCurrentListId(int? listId) {
    _currentListId = listId;
    if (listId != null && !_todos.containsKey(listId)) {
      loadTodosForList(listId);
    }
    notifyListeners();
  }

  Future<void> loadTodosForList(int listId, {bool silent = false}) async {
    final fetchStartTime = DateTime.now();

    if (!silent) {
      _isLoading = true;
      notifyListeners();
    }
    _error = null;

    try {
      // 1. Load from cache (skip if recent mutation to preserve optimistic updates)
      if (DateTime.now().difference(_lastMutationTime) > const Duration(seconds: 2)) {
        final cachedTodos = await _databaseService.getLaterListTodos(listId);
        if (cachedTodos.isNotEmpty) {
          _todos[listId] = cachedTodos;
          notifyListeners();
        }
      }

      // 2. Fetch from API
      final todos = await _laterListApi.getTodosForList(listId: listId);

      // 3. Guard: discard if mutation occurred during fetch
      if (_lastMutationTime.isAfter(fetchStartTime)) {
        debugPrint('Discarding stale fetch for list $listId');
        return;
      }

      _todos[listId] = todos;
      notifyListeners();

      // 4. Save to cache
      await _databaseService.saveLaterListTodos(todos, listId);
    } catch (e) {
      _error = e.toString();
      debugPrint('Failed to load todos for list: $e');
      notifyListeners();
    } finally {
      if (!silent) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  Future<bool> createTodo(int listId, String text, {int? position}) async {
    _lastMutationTime = DateTime.now();
    await _checkOnlineStatus();
    if (!_isOnline) {
      _error = 'Cannot create todo while offline';
      notifyListeners();
      return false;
    }

    _error = null;
    try {
      final newTodo = await _laterListApi.createTodo(listId: listId, text: text, position: position);
      final currentTodos = List<LaterListTodo>.from(_todos[listId] ?? []);
      if (position != null && position == 1) {
        // Adding at top - insert and re-number positions optimistically
        final sortedList = List<LaterListTodo>.from(currentTodos)..sort((a, b) => a.position.compareTo(b.position));
        for (int i = 0; i < sortedList.length; i++) {
          sortedList[i] = sortedList[i].copyWith(position: i + 2);
        }
        _todos[listId] = [newTodo, ...sortedList];
      } else {
        _todos[listId] = [...currentTodos, newTodo];
      }
      notifyListeners();

      // Save to cache
      await _databaseService.saveLaterListTodo(newTodo, listId);
      return true;
    } catch (e) {
      _error = e.toString();
      debugPrint('Failed to create todo: $e');
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateTodoText(int listId, int todoId, String text) async {
    _lastMutationTime = DateTime.now();
    await _checkOnlineStatus();
    if (!_isOnline) {
      _error = 'Cannot update todo while offline';
      notifyListeners();
      return false;
    }

    // Optimistic update
    final currentTodos = List<LaterListTodo>.from(_todos[listId] ?? []);
    _todos[listId] = currentTodos.map((t) => t.id == todoId ? t.copyWith(text: text) : t).toList();
    notifyListeners();

    try {
      await _laterListApi.updateTodoText(listId: listId, todoId: todoId, text: text);

      // Save to cache
      await _databaseService.saveLaterListTodos(_todos[listId]!, listId);
      return true;
    } catch (e) {
      // Rollback
      _todos[listId] = currentTodos;
      _error = e.toString();
      debugPrint('Failed to update todo text: $e');
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateTodoPosition(int listId, int todoId, int newPosition) async {
    _lastMutationTime = DateTime.now();
    await _checkOnlineStatus();
    if (!_isOnline) {
      _error = 'Cannot update todo position while offline';
      notifyListeners();
      return false;
    }

    // Optimistic update
    final currentTodos = List<LaterListTodo>.from(_todos[listId] ?? []);
    final sortedList = List<LaterListTodo>.from(currentTodos)..sort((a, b) => a.position.compareTo(b.position));

    final oldIndex = sortedList.indexWhere((t) => t.id == todoId);
    if (oldIndex == -1 || oldIndex == newPosition) return true;

    final movedTodo = sortedList.removeAt(oldIndex);
    sortedList.insert(newPosition, movedTodo);

    // Renumber positions
    final reorderedList = <LaterListTodo>[];
    for (int i = 0; i < sortedList.length; i++) {
      reorderedList.add(sortedList[i].copyWith(position: i + 1));
    }
    _todos[listId] = reorderedList;
    notifyListeners();

    try {
      await _laterListApi.updateTodoPosition(listId: listId, todoId: todoId, position: newPosition);

      // Save to cache
      await _databaseService.saveLaterListTodos(_todos[listId]!, listId);
      return true;
    } catch (e) {
      // Rollback
      _todos[listId] = currentTodos;
      _error = e.toString();
      debugPrint('Failed to update todo position: $e');
      notifyListeners();
      return false;
    }
  }

  Future<bool> completeTodo(int listId, int todoId) async {
    _lastMutationTime = DateTime.now();
    await _checkOnlineStatus();
    if (!_isOnline) {
      _error = 'Cannot complete todo while offline';
      notifyListeners();
      return false;
    }

    // Optimistic update
    final currentTodos = List<LaterListTodo>.from(_todos[listId] ?? []);
    final sortedList = List<LaterListTodo>.from(currentTodos)..sort((a, b) => a.position.compareTo(b.position));

    final oldIndex = sortedList.indexWhere((t) => t.id == todoId);
    if (oldIndex == -1) return false;

    // Find first completed index
    int firstCompletedIndex = sortedList.length;
    for (int i = 0; i < sortedList.length; i++) {
      if (sortedList[i].isCompleted) {
        firstCompletedIndex = i;
        break;
      }
    }

    final movedTodo = sortedList.removeAt(oldIndex).copyWith(
      isCompleted: true,
      completedAt: DateTime.now(),
    );
    final newIndex = firstCompletedIndex > oldIndex ? firstCompletedIndex - 1 : firstCompletedIndex;
    sortedList.insert(newIndex, movedTodo);

    // Renumber affected range
    final startIdx = oldIndex < newIndex ? oldIndex : newIndex;
    final endIdx = oldIndex > newIndex ? oldIndex : newIndex;
    for (int i = startIdx; i <= endIdx; i++) {
      sortedList[i] = sortedList[i].copyWith(position: i + 1);
    }
    _todos[listId] = sortedList;
    notifyListeners();

    try {
      await _laterListApi.completeTodo(listId: listId, todoId: todoId);

      // Save to cache
      await _databaseService.saveLaterListTodos(_todos[listId]!, listId);
      return true;
    } catch (e) {
      // Rollback
      _todos[listId] = currentTodos;
      _error = e.toString();
      debugPrint('Failed to complete todo: $e');
      notifyListeners();
      return false;
    }
  }

  Future<bool> uncompleteTodo(int listId, int todoId) async {
    _lastMutationTime = DateTime.now();
    await _checkOnlineStatus();
    if (!_isOnline) {
      _error = 'Cannot uncomplete todo while offline';
      notifyListeners();
      return false;
    }

    // Optimistic update
    final currentTodos = List<LaterListTodo>.from(_todos[listId] ?? []);
    final sortedList = List<LaterListTodo>.from(currentTodos)..sort((a, b) => a.position.compareTo(b.position));

    final oldIndex = sortedList.indexWhere((t) => t.id == todoId);
    if (oldIndex == -1) return false;

    // Find first completed index (excluding current)
    int firstCompletedIndex = sortedList.length;
    for (int i = 0; i < sortedList.length; i++) {
      if (sortedList[i].isCompleted && sortedList[i].id != todoId) {
        firstCompletedIndex = i;
        break;
      }
    }

    final movedTodo = sortedList.removeAt(oldIndex).copyWith(
      isCompleted: false,
    );
    final newIndex = firstCompletedIndex > oldIndex ? firstCompletedIndex - 1 : firstCompletedIndex;
    sortedList.insert(newIndex, movedTodo);

    // Renumber affected range
    final startIdx = oldIndex < newIndex ? oldIndex : newIndex;
    final endIdx = oldIndex > newIndex ? oldIndex : newIndex;
    for (int i = startIdx; i <= endIdx; i++) {
      sortedList[i] = sortedList[i].copyWith(position: i + 1);
    }
    _todos[listId] = sortedList;
    notifyListeners();

    try {
      await _laterListApi.uncompleteTodo(listId: listId, todoId: todoId);

      // Save to cache
      await _databaseService.saveLaterListTodos(_todos[listId]!, listId);
      return true;
    } catch (e) {
      // Rollback
      _todos[listId] = currentTodos;
      _error = e.toString();
      debugPrint('Failed to uncomplete todo: $e');
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteTodo(int listId, int todoId) async {
    _lastMutationTime = DateTime.now();
    await _checkOnlineStatus();
    if (!_isOnline) {
      _error = 'Cannot delete todo while offline';
      notifyListeners();
      return false;
    }

    // Optimistic update
    final currentTodos = List<LaterListTodo>.from(_todos[listId] ?? []);
    _todos[listId] = currentTodos.where((t) => t.id != todoId).toList();
    notifyListeners();

    try {
      await _laterListApi.deleteTodo(listId: listId, todoId: todoId);

      // Delete from cache
      await _databaseService.deleteLaterListTodo(todoId);
      return true;
    } catch (e) {
      // Rollback
      _todos[listId] = currentTodos;
      _error = e.toString();
      debugPrint('Failed to delete todo: $e');
      notifyListeners();
      return false;
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _wsUnsubscribe?.call();
    super.dispose();
  }
}
