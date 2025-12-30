import '../models/todo.dart';
import 'api_service.dart';

class TodoApi {
  final ApiService _apiService;

  TodoApi(this._apiService);

  /// Get todos for a specific date
  Future<List<Todo>> getTodosForDate({required String date}) async {
    final response = await _apiService.get(
      '/todos',
      queryParameters: {'date': date},
    );

    final List<dynamic> data = response.data as List<dynamic>;
    return data.map((json) => Todo.fromJson(json as Map<String, dynamic>)).toList();
  }

  /// Get todos for a date range
  Future<List<Todo>> getTodosForDateRange({
    required String startDate,
    required String endDate,
  }) async {
    final response = await _apiService.get(
      '/todos',
      queryParameters: {
        'start_date': startDate,
        'end_date': endDate,
      },
    );

    final List<dynamic> data = response.data as List<dynamic>;
    return data.map((json) => Todo.fromJson(json as Map<String, dynamic>)).toList();
  }

  /// Create a new todo
  Future<Todo> createTodo({
    required String text,
    required String assignedDate,
  }) async {
    final response = await _apiService.post(
      '/todos',
      data: {
        'text': text,
        'assignedDate': assignedDate,
      },
    );

    return Todo.fromJson(response.data as Map<String, dynamic>);
  }

  /// Update todo text
  Future<Todo> updateTodoText({
    required int id,
    required String text,
  }) async {
    final response = await _apiService.put(
      '/todos/$id/text',
      data: {
        'text': text,
      },
    );

    return Todo.fromJson(response.data as Map<String, dynamic>);
  }

  /// Update todo position
  Future<Todo> updateTodoPosition({
    required int id,
    required int position,
  }) async {
    final response = await _apiService.put(
      '/todos/$id/position',
      data: {
        'position': position,
      },
    );

    return Todo.fromJson(response.data as Map<String, dynamic>);
  }

  /// Complete a todo
  Future<Todo> completeTodo({required int id}) async {
    final response = await _apiService.post('/todos/$id/complete');
    return Todo.fromJson(response.data as Map<String, dynamic>);
  }

  /// Delete a todo
  Future<void> deleteTodo({
    required int id,
    bool? deleteAllFuture,
  }) async {
    await _apiService.delete(
      '/todos/$id',
      queryParameters: deleteAllFuture != null && deleteAllFuture
          ? {'deleteAllFuture': 'true'}
          : null,
    );
  }

  // Virtual Todo Operations

  /// Complete a virtual todo
  Future<Todo> completeVirtualTodo({
    required int recurringTodoId,
    required String instanceDate,
  }) async {
    final response = await _apiService.post(
      '/todos/virtual/complete',
      data: {
        'recurringTodoId': recurringTodoId,
        'instanceDate': instanceDate,
      },
    );

    return Todo.fromJson(response.data as Map<String, dynamic>);
  }

  /// Update virtual todo text
  Future<Todo> updateVirtualTodoText({
    required int recurringTodoId,
    required String instanceDate,
    required String text,
  }) async {
    final response = await _apiService.post(
      '/todos/virtual/update-text',
      data: {
        'recurringTodoId': recurringTodoId,
        'instanceDate': instanceDate,
      },
      queryParameters: {
        'text': text,
      },
    );

    return Todo.fromJson(response.data as Map<String, dynamic>);
  }

  /// Update virtual todo position
  Future<Todo> updateVirtualTodoPosition({
    required int recurringTodoId,
    required String instanceDate,
    required int position,
  }) async {
    final response = await _apiService.post(
      '/todos/virtual/update-position',
      data: {
        'recurringTodoId': recurringTodoId,
        'instanceDate': instanceDate,
      },
      queryParameters: {
        'position': position.toString(),
      },
    );

    return Todo.fromJson(response.data as Map<String, dynamic>);
  }

  /// Delete a virtual todo
  Future<void> deleteVirtualTodo({
    required int recurringTodoId,
    required String instanceDate,
    bool? deleteAllFuture,
  }) async {
    final params = {
      'recurringTodoId': recurringTodoId.toString(),
      'instanceDate': instanceDate,
    };

    if (deleteAllFuture != null && deleteAllFuture) {
      params['deleteAllFuture'] = 'true';
    }

    await _apiService.delete(
      '/todos/virtual',
      queryParameters: params,
    );
  }
}

// Singleton instance
final todoApi = TodoApi(apiService);
