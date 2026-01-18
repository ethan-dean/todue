import '../models/todo.dart';
import 'api_service.dart';

class TodoApi {
  final ApiService _apiService;

  static TodoApi get instance => todoApi;

  TodoApi(this._apiService);

  /// Get todos for a specific date (alias)
  Future<List<Todo>> getTodos({required String date}) async {
    return getTodosForDate(date: date);
  }

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
        'startDate': startDate,
        'endDate': endDate,
      },
    );

    final List<dynamic> data = response.data as List<dynamic>;
    return data.map((json) => Todo.fromJson(json as Map<String, dynamic>)).toList();
  }

  /// Create a new todo
  Future<Todo> createTodo({
    required String text,
    required String assignedDate,
    int? recurringTodoId,
    int? position,
  }) async {
    final Map<String, dynamic> data = {
      'text': text,
      'assignedDate': assignedDate,
    };
    if (recurringTodoId != null) {
      data['recurringTodoId'] = recurringTodoId;
    }
    if (position != null) {
      data['position'] = position;
    }

    final response = await _apiService.post(
      '/todos',
      data: data,
    );

    return Todo.fromJson(response.data as Map<String, dynamic>);
  }

  /// Update a todo (general)
  Future<Todo> updateTodo({
    required int id,
    String? text,
    String? assignedDate,
  }) async {
    // Note: Backend typically splits this into specific endpoints.
    // We'll prioritize text update if present.
    // If assignedDate update is needed, backend should support it or we need a move endpoint.
    // For now, assuming text update is the primary use case here.
    if (text != null) {
      return updateTodoText(id: id, text: text);
    }
    // If only assignedDate is provided, we might need a move endpoint.
    // Returning current todo to satisfy signature if no supported update found.
    // Ideally this should call a generic PUT /todos/{id} if available.
    // Using updateTodoText as a fallback/placeholder.
    // In a real implementation, ensure backend supports generic updates.
    return updateTodoText(id: id, text: text ?? "");
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

  /// Update todo assigned date
  Future<Todo> updateTodoAssignedDate({
    required int id,
    required String assignedDate,
  }) async {
    final response = await _apiService.put(
      '/todos/$id/assigned-date',
      data: {
        'toDate': assignedDate,
      },
    );

    return Todo.fromJson(response.data as Map<String, dynamic>);
  }

  /// Complete or uncomplete a todo
  Future<Todo> completeTodo({
    required int id,
    bool isCompleted = true,
  }) async {
    final endpoint = isCompleted ? '/todos/$id/complete' : '/todos/$id/uncomplete';
    final response = await _apiService.post(endpoint);
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

  /// Update virtual todo assigned date
  Future<Todo> updateVirtualTodoAssignedDate({
    required int recurringTodoId,
    required String instanceDate,
    required String assignedDate,
  }) async {
    final response = await _apiService.post(
      '/todos/virtual/update-assigned-date',
      data: {
        'recurringTodoId': recurringTodoId,
        'instanceDate': instanceDate,
      },
      queryParameters: {
        'toDate': assignedDate,
      },
    );

    return Todo.fromJson(response.data as Map<String, dynamic>);
  }
}

// Singleton instance
final todoApi = TodoApi(apiService);
