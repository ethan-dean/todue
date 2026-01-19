import '../models/later_list.dart';
import '../models/later_list_todo.dart';
import 'api_service.dart';

class LaterListApi {
  final ApiService _apiService;

  static LaterListApi get instance => laterListApi;

  LaterListApi(this._apiService);

  // ==================== List Operations ====================

  Future<List<LaterList>> getAllLists() async {
    final response = await _apiService.get('/later-lists');
    final List<dynamic> data = response.data as List<dynamic>;
    return data.map((json) => LaterList.fromJson(json as Map<String, dynamic>)).toList();
  }

  Future<LaterList> createList({required String listName}) async {
    final response = await _apiService.post(
      '/later-lists',
      data: {'listName': listName},
    );
    return LaterList.fromJson(response.data as Map<String, dynamic>);
  }

  Future<LaterList> updateListName({
    required int listId,
    required String listName,
  }) async {
    final response = await _apiService.put(
      '/later-lists/$listId/name',
      data: {'listName': listName},
    );
    return LaterList.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> deleteList({required int listId}) async {
    await _apiService.delete('/later-lists/$listId');
  }

  // ==================== Todo Operations ====================

  Future<List<LaterListTodo>> getTodosForList({required int listId}) async {
    final response = await _apiService.get('/later-lists/$listId/todos');
    final List<dynamic> data = response.data as List<dynamic>;
    return data.map((json) => LaterListTodo.fromJson(json as Map<String, dynamic>)).toList();
  }

  Future<LaterListTodo> createTodo({
    required int listId,
    required String text,
    int? position,
  }) async {
    final Map<String, dynamic> data = {'text': text};
    if (position != null) {
      data['position'] = position;
    }
    final response = await _apiService.post(
      '/later-lists/$listId/todos',
      data: data,
    );
    return LaterListTodo.fromJson(response.data as Map<String, dynamic>);
  }

  Future<LaterListTodo> updateTodoText({
    required int listId,
    required int todoId,
    required String text,
  }) async {
    final response = await _apiService.put(
      '/later-lists/$listId/todos/$todoId/text',
      data: {'text': text},
    );
    return LaterListTodo.fromJson(response.data as Map<String, dynamic>);
  }

  Future<LaterListTodo> updateTodoPosition({
    required int listId,
    required int todoId,
    required int position,
  }) async {
    final response = await _apiService.put(
      '/later-lists/$listId/todos/$todoId/position',
      data: {'position': position},
    );
    return LaterListTodo.fromJson(response.data as Map<String, dynamic>);
  }

  Future<LaterListTodo> completeTodo({
    required int listId,
    required int todoId,
  }) async {
    final response = await _apiService.post(
      '/later-lists/$listId/todos/$todoId/complete',
    );
    return LaterListTodo.fromJson(response.data as Map<String, dynamic>);
  }

  Future<LaterListTodo> uncompleteTodo({
    required int listId,
    required int todoId,
  }) async {
    final response = await _apiService.post(
      '/later-lists/$listId/todos/$todoId/uncomplete',
    );
    return LaterListTodo.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> deleteTodo({
    required int listId,
    required int todoId,
  }) async {
    await _apiService.delete('/later-lists/$listId/todos/$todoId');
  }
}

// Singleton instance
final laterListApi = LaterListApi(apiService);
