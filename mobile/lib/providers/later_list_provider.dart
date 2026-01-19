import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/later_list.dart';
import '../models/later_list_todo.dart';
import '../services/later_list_api.dart';
import '../services/websocket_service.dart';

class LaterListProvider extends ChangeNotifier {
  final LaterListApi _laterListApi;
  final WebSocketService _websocketService;

  List<LaterList> _lists = [];
  final Map<int, List<LaterListTodo>> _todos = {};
  int? _currentListId;
  bool _isLoading = false;
  String? _error;

  StreamSubscription? _websocketSubscription;

  LaterListProvider({
    required LaterListApi laterListApi,
    required WebSocketService websocketService,
  })  : _laterListApi = laterListApi,
        _websocketService = websocketService {
    _initWebSocketListener();
  }

  // Getters
  List<LaterList> get lists => _lists;
  int? get currentListId => _currentListId;
  bool get isLoading => _isLoading;
  String? get error => _error;

  List<LaterListTodo> getTodosForList(int listId) {
    final todos = _todos[listId] ?? [];
    return List.from(todos)..sort((a, b) => a.position.compareTo(b.position));
  }

  void _initWebSocketListener() {
    _websocketSubscription = _websocketService.messageStream.listen((message) {
      if (message.type == WebSocketMessageType.LATER_LIST_CHANGED) {
        _handleWebSocketMessage(message.data);
      }
    });
  }

  void _handleWebSocketMessage(dynamic data) {
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
    if (!silent) {
      _isLoading = true;
      notifyListeners();
    }
    _error = null;

    try {
      _lists = await _laterListApi.getAllLists();
      notifyListeners();
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
    _error = null;
    try {
      final newList = await _laterListApi.createList(listName: listName);
      _lists = [..._lists, newList]..sort((a, b) => a.listName.compareTo(b.listName));
      notifyListeners();
      return newList;
    } catch (e) {
      _error = e.toString();
      debugPrint('Failed to create list: $e');
      notifyListeners();
      return null;
    }
  }

  Future<bool> updateListName(int listId, String newName) async {
    // Optimistic update
    final oldLists = List<LaterList>.from(_lists);
    _lists = _lists.map((l) => l.id == listId ? l.copyWith(listName: newName) : l).toList()
      ..sort((a, b) => a.listName.compareTo(b.listName));
    notifyListeners();

    try {
      await _laterListApi.updateListName(listId: listId, listName: newName);
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
    if (!silent) {
      _isLoading = true;
      notifyListeners();
    }
    _error = null;

    try {
      final todos = await _laterListApi.getTodosForList(listId: listId);
      _todos[listId] = todos;
      notifyListeners();
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

  Future<bool> createTodo(int listId, String text) async {
    _error = null;
    try {
      final newTodo = await _laterListApi.createTodo(listId: listId, text: text);
      final currentTodos = List<LaterListTodo>.from(_todos[listId] ?? []);
      _todos[listId] = [...currentTodos, newTodo];
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      debugPrint('Failed to create todo: $e');
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateTodoText(int listId, int todoId, String text) async {
    // Optimistic update
    final currentTodos = List<LaterListTodo>.from(_todos[listId] ?? []);
    _todos[listId] = currentTodos.map((t) => t.id == todoId ? t.copyWith(text: text) : t).toList();
    notifyListeners();

    try {
      await _laterListApi.updateTodoText(listId: listId, todoId: todoId, text: text);
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
    // Optimistic update
    final currentTodos = List<LaterListTodo>.from(_todos[listId] ?? []);
    _todos[listId] = currentTodos.where((t) => t.id != todoId).toList();
    notifyListeners();

    try {
      await _laterListApi.deleteTodo(listId: listId, todoId: todoId);
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
    _websocketSubscription?.cancel();
    super.dispose();
  }
}
