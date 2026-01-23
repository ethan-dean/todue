import '../models/routine.dart';
import 'api_service.dart';

class RoutineApi {
  final ApiService _apiService;

  static RoutineApi get instance => routineApi;

  RoutineApi(this._apiService);

  // ==================== Routine CRUD ====================

  Future<List<Routine>> getAllRoutines() async {
    final response = await _apiService.get('/routines');
    final List<dynamic> data = response.data as List<dynamic>;
    return data.map((json) => Routine.fromJson(json as Map<String, dynamic>)).toList();
  }

  Future<RoutineDetail> getRoutineDetail({required int routineId}) async {
    final response = await _apiService.get('/routines/$routineId');
    return RoutineDetail.fromJson(response.data as Map<String, dynamic>);
  }

  Future<Routine> createRoutine({required String name}) async {
    final response = await _apiService.post(
      '/routines',
      data: {'name': name},
    );
    return Routine.fromJson(response.data as Map<String, dynamic>);
  }

  Future<Routine> updateRoutineName({
    required int routineId,
    required String name,
  }) async {
    final response = await _apiService.put(
      '/routines/$routineId/name',
      data: {'name': name},
    );
    return Routine.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> deleteRoutine({required int routineId}) async {
    await _apiService.delete('/routines/$routineId');
  }

  // ==================== Step CRUD ====================

  Future<RoutineStep> createStep({
    required int routineId,
    required String text,
    String? notes,
    int? position,
  }) async {
    final Map<String, dynamic> data = {'text': text};
    if (notes != null) data['notes'] = notes;
    if (position != null) data['position'] = position;

    final response = await _apiService.post(
      '/routines/$routineId/steps',
      data: data,
    );
    return RoutineStep.fromJson(response.data as Map<String, dynamic>);
  }

  Future<RoutineStep> updateStepText({
    required int routineId,
    required int stepId,
    required String text,
  }) async {
    final response = await _apiService.put(
      '/routines/$routineId/steps/$stepId/text',
      data: {'text': text},
    );
    return RoutineStep.fromJson(response.data as Map<String, dynamic>);
  }

  Future<RoutineStep> updateStepNotes({
    required int routineId,
    required int stepId,
    String? notes,
  }) async {
    final response = await _apiService.put(
      '/routines/$routineId/steps/$stepId/notes',
      data: {'notes': notes},
    );
    return RoutineStep.fromJson(response.data as Map<String, dynamic>);
  }

  Future<RoutineStep> updateStepPosition({
    required int routineId,
    required int stepId,
    required int position,
  }) async {
    final response = await _apiService.put(
      '/routines/$routineId/steps/$stepId/position',
      data: {'position': position},
    );
    return RoutineStep.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> deleteStep({
    required int routineId,
    required int stepId,
  }) async {
    await _apiService.delete('/routines/$routineId/steps/$stepId');
  }

  // ==================== Schedules ====================

  Future<List<RoutineSchedule>> setSchedules({
    required int routineId,
    required List<ScheduleEntry> schedules,
  }) async {
    final response = await _apiService.put(
      '/routines/$routineId/schedules',
      data: {'schedules': schedules.map((s) => s.toJson()).toList()},
    );
    final List<dynamic> data = response.data as List<dynamic>;
    return data.map((json) => RoutineSchedule.fromJson(json as Map<String, dynamic>)).toList();
  }

  // ==================== Prompts ====================

  Future<List<PendingRoutinePrompt>> getPendingPrompts() async {
    final response = await _apiService.get('/routines/prompts/pending');
    final List<dynamic> data = response.data as List<dynamic>;
    return data.map((json) => PendingRoutinePrompt.fromJson(json as Map<String, dynamic>)).toList();
  }

  Future<void> dismissPrompt({required int routineId}) async {
    await _apiService.post('/routines/prompts/$routineId/dismiss');
  }

  Future<RoutineCompletion> quickCompleteRoutine({required int routineId, List<int>? completedStepIds}) async {
    final Map<String, dynamic>? data = completedStepIds != null ? {'completedStepIds': completedStepIds} : null;
    final response = await _apiService.post('/routines/$routineId/quick-complete', data: data);
    return RoutineCompletion.fromJson(response.data as Map<String, dynamic>);
  }

  // ==================== Execution ====================

  Future<RoutineCompletion> startRoutine({required int routineId}) async {
    final response = await _apiService.post('/routines/$routineId/start');
    return RoutineCompletion.fromJson(response.data as Map<String, dynamic>);
  }

  Future<RoutineCompletion?> getActiveExecution({required int routineId}) async {
    final response = await _apiService.get('/routines/$routineId/active');
    if (response.statusCode == 204) return null;
    return RoutineCompletion.fromJson(response.data as Map<String, dynamic>);
  }

  Future<RoutineStepCompletion> completeStep({
    required int completionId,
    required int stepId,
    required String action,  // 'complete' or 'skip'
    String? notes,
  }) async {
    final Map<String, dynamic> data = {'action': action};
    if (notes != null) data['notes'] = notes;

    final response = await _apiService.post(
      '/routines/executions/$completionId/steps/$stepId',
      data: data,
    );
    return RoutineStepCompletion.fromJson(response.data as Map<String, dynamic>);
  }

  Future<RoutineCompletion> finishExecution({required int completionId}) async {
    final response = await _apiService.post('/routines/executions/$completionId/finish');
    return RoutineCompletion.fromJson(response.data as Map<String, dynamic>);
  }

  Future<RoutineCompletion> abandonExecution({required int completionId}) async {
    final response = await _apiService.post('/routines/executions/$completionId/abandon');
    return RoutineCompletion.fromJson(response.data as Map<String, dynamic>);
  }

  // ==================== Analytics ====================

  Future<RoutineAnalytics> getAnalytics({
    required int routineId,
    required String startDate,
    required String endDate,
  }) async {
    final response = await _apiService.get(
      '/routines/$routineId/analytics?startDate=$startDate&endDate=$endDate',
    );
    return RoutineAnalytics.fromJson(response.data as Map<String, dynamic>);
  }

  Future<List<RoutineHistory>> getHistory({
    required int routineId,
    required String startDate,
    required String endDate,
  }) async {
    final response = await _apiService.get(
      '/routines/$routineId/history?startDate=$startDate&endDate=$endDate',
    );
    final List<dynamic> data = response.data as List<dynamic>;
    return data.map((json) => RoutineHistory.fromJson(json as Map<String, dynamic>)).toList();
  }
}

// Singleton instance
final routineApi = RoutineApi(apiService);
