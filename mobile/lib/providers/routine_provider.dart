import 'package:flutter/foundation.dart';
import '../models/routine.dart';
import '../services/routine_api.dart';
import '../services/websocket_service.dart';

class RoutineProvider extends ChangeNotifier {
  final RoutineApi _routineApi;
  final WebSocketService _websocketService;

  List<Routine> _routines = [];
  final Map<int, RoutineDetail> _routineDetails = {};
  final Map<int, RoutineCompletion> _activeExecutions = {};
  List<PendingRoutinePrompt> _pendingPrompts = [];
  final Map<int, RoutineAnalytics> _analytics = {};
  int? _currentRoutineId;
  bool _showAnalytics = false;
  bool _isLoading = false;
  String? _error;

  DateTime _lastMutationTime = DateTime.fromMillisecondsSinceEpoch(0);
  VoidCallback? _wsUnsubscribe;

  RoutineProvider({
    required RoutineApi routineApi,
    required WebSocketService websocketService,
  })  : _routineApi = routineApi,
        _websocketService = websocketService {
    _initWebSocketListener();
  }

  // Getters
  List<Routine> get routines => _routines;
  int? get currentRoutineId => _currentRoutineId;
  bool get showAnalytics => _showAnalytics;
  bool get isLoading => _isLoading;
  String? get error => _error;
  List<PendingRoutinePrompt> get pendingPrompts => _pendingPrompts;

  RoutineDetail? getRoutineDetail(int routineId) => _routineDetails[routineId];
  RoutineCompletion? getActiveExecution(int routineId) => _activeExecutions[routineId];
  RoutineAnalytics? getAnalytics(int routineId) => _analytics[routineId];

  void setCurrentRoutineId(int? routineId) {
    _currentRoutineId = routineId;
    _showAnalytics = false;
    notifyListeners();
  }

  void toggleShowAnalytics() {
    _showAnalytics = !_showAnalytics;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  void _initWebSocketListener() {
    _wsUnsubscribe = _websocketService.subscribe(
      [WebSocketMessageType.ROUTINE_CHANGED],
      _handleWebSocketMessage,
    );
  }

  void _handleWebSocketMessage(WebSocketMessage message) {
    debugPrint('RoutineProvider WebSocket message: ${message.type}');

    final data = message.data;
    if (data is! Map<String, dynamic>) return;

    final routineId = data['routineId'] as int?;
    final action = data['action'] as String?;
    final messageTime = DateTime.now();

    Future.delayed(const Duration(milliseconds: 300), () {
      // Skip if we recently made a mutation (this is our own change echoing back)
      if (messageTime.isBefore(_lastMutationTime.add(const Duration(milliseconds: 500)))) {
        return;
      }

      switch (action) {
        case 'ROUTINE_CREATED':
        case 'ROUTINE_UPDATED':
        case 'ROUTINE_DELETED':
          loadRoutines(silent: true);
          if (routineId != null && _currentRoutineId == routineId) {
            loadRoutineDetail(routineId, silent: true);
          }
          break;
        case 'EXECUTION_STARTED':
        case 'EXECUTION_COMPLETED':
        case 'EXECUTION_ABANDONED':
        case 'STEP_COMPLETED':
          if (routineId != null) {
            loadActiveExecution(routineId);
          }
          break;
      }
    });
  }

  // ==================== Routine CRUD ====================

  Future<void> loadRoutines({bool silent = false}) async {
    final fetchStartTime = DateTime.now();

    if (!silent) {
      _isLoading = true;
      notifyListeners();
    }
    _error = null;

    try {
      final fetchedRoutines = await _routineApi.getAllRoutines();

      if (_lastMutationTime.isAfter(fetchStartTime)) {
        debugPrint('Discarding stale fetch for routines');
        return;
      }

      _routines = fetchedRoutines;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      debugPrint('Failed to load routines: $e');
      notifyListeners();
    } finally {
      if (!silent) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  Future<void> loadRoutineDetail(int routineId, {bool silent = false}) async {
    final fetchStartTime = DateTime.now();

    if (!silent) {
      _isLoading = true;
      notifyListeners();
    }
    _error = null;

    try {
      final detail = await _routineApi.getRoutineDetail(routineId: routineId);

      if (_lastMutationTime.isAfter(fetchStartTime)) return;

      _routineDetails[routineId] = detail;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      debugPrint('Failed to load routine detail: $e');
      notifyListeners();
    } finally {
      if (!silent) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  Future<Routine?> createRoutine(String name) async {
    _lastMutationTime = DateTime.now();
    _error = null;

    try {
      final newRoutine = await _routineApi.createRoutine(name: name);
      _routines = [..._routines, newRoutine]..sort((a, b) => a.name.compareTo(b.name));
      notifyListeners();
      return newRoutine;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return null;
    }
  }

  Future<bool> updateRoutineName(int routineId, String newName) async {
    _lastMutationTime = DateTime.now();
    _error = null;

    // Optimistic update
    _routines = _routines
        .map((r) => r.id == routineId ? r.copyWith(name: newName) : r)
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    if (_routineDetails.containsKey(routineId)) {
      _routineDetails[routineId] = _routineDetails[routineId]!.copyWith(name: newName);
    }
    notifyListeners();

    try {
      await _routineApi.updateRoutineName(routineId: routineId, name: newName);
      return true;
    } catch (e) {
      await loadRoutines(silent: true);
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteRoutine(int routineId) async {
    _lastMutationTime = DateTime.now();
    _error = null;

    // Optimistic update
    _routines = _routines.where((r) => r.id != routineId).toList();
    _routineDetails.remove(routineId);
    notifyListeners();

    try {
      await _routineApi.deleteRoutine(routineId: routineId);
      if (_currentRoutineId == routineId) {
        _currentRoutineId = null;
      }
      return true;
    } catch (e) {
      await loadRoutines(silent: true);
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  // ==================== Step CRUD ====================

  Future<bool> createStep(int routineId, String text, {String? notes}) async {
    _lastMutationTime = DateTime.now();
    _error = null;

    try {
      final newStep = await _routineApi.createStep(
        routineId: routineId,
        text: text,
        notes: notes,
      );

      if (_routineDetails.containsKey(routineId)) {
        final detail = _routineDetails[routineId]!;
        _routineDetails[routineId] = detail.copyWith(
          steps: [...detail.steps, newStep]..sort((a, b) => a.position.compareTo(b.position)),
        );
      }

      _routines = _routines
          .map((r) => r.id == routineId ? r.copyWith(stepCount: r.stepCount + 1) : r)
          .toList();

      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateStepText(int routineId, int stepId, String text) async {
    _lastMutationTime = DateTime.now();
    _error = null;

    // Optimistic update
    if (_routineDetails.containsKey(routineId)) {
      final detail = _routineDetails[routineId]!;
      _routineDetails[routineId] = detail.copyWith(
        steps: detail.steps.map((s) => s.id == stepId ? s.copyWith(text: text) : s).toList(),
      );
      notifyListeners();
    }

    try {
      await _routineApi.updateStepText(routineId: routineId, stepId: stepId, text: text);
      return true;
    } catch (e) {
      await loadRoutineDetail(routineId, silent: true);
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateStepNotes(int routineId, int stepId, String? notes) async {
    _lastMutationTime = DateTime.now();
    _error = null;

    // Optimistic update
    if (_routineDetails.containsKey(routineId)) {
      final detail = _routineDetails[routineId]!;
      _routineDetails[routineId] = detail.copyWith(
        steps: detail.steps.map((s) => s.id == stepId ? s.copyWith(notes: notes) : s).toList(),
      );
      notifyListeners();
    }

    try {
      await _routineApi.updateStepNotes(routineId: routineId, stepId: stepId, notes: notes);
      return true;
    } catch (e) {
      await loadRoutineDetail(routineId, silent: true);
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateStepPosition(int routineId, int stepId, int newPosition) async {
    _lastMutationTime = DateTime.now();
    _error = null;

    // Optimistic update
    if (_routineDetails.containsKey(routineId)) {
      final detail = _routineDetails[routineId]!;
      final steps = List<RoutineStep>.from(detail.steps)..sort((a, b) => a.position.compareTo(b.position));
      final oldIndex = steps.indexWhere((s) => s.id == stepId);

      if (oldIndex != -1 && oldIndex != newPosition) {
        final movedStep = steps.removeAt(oldIndex);
        steps.insert(newPosition, movedStep);

        final reorderedSteps = steps.asMap().entries.map((e) {
          return e.value.copyWith(position: e.key + 1);
        }).toList();

        _routineDetails[routineId] = detail.copyWith(steps: reorderedSteps);
        notifyListeners();
      }
    }

    try {
      await _routineApi.updateStepPosition(routineId: routineId, stepId: stepId, position: newPosition);
      return true;
    } catch (e) {
      await loadRoutineDetail(routineId, silent: true);
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteStep(int routineId, int stepId) async {
    _lastMutationTime = DateTime.now();
    _error = null;

    // Optimistic update
    if (_routineDetails.containsKey(routineId)) {
      final detail = _routineDetails[routineId]!;
      _routineDetails[routineId] = detail.copyWith(
        steps: detail.steps.where((s) => s.id != stepId).toList(),
      );
    }
    _routines = _routines
        .map((r) => r.id == routineId ? r.copyWith(stepCount: (r.stepCount - 1).clamp(0, r.stepCount)) : r)
        .toList();
    notifyListeners();

    try {
      await _routineApi.deleteStep(routineId: routineId, stepId: stepId);
      return true;
    } catch (e) {
      await loadRoutineDetail(routineId, silent: true);
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  // ==================== Schedules ====================

  Future<bool> setSchedules(int routineId, List<ScheduleEntry> schedules) async {
    _lastMutationTime = DateTime.now();
    _error = null;

    try {
      final newSchedules = await _routineApi.setSchedules(routineId: routineId, schedules: schedules);

      if (_routineDetails.containsKey(routineId)) {
        _routineDetails[routineId] = _routineDetails[routineId]!.copyWith(schedules: newSchedules);
        notifyListeners();
      }
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  // ==================== Prompts ====================

  Future<void> loadPendingPrompts() async {
    final fetchStartTime = DateTime.now();
    try {
      final prompts = await _routineApi.getPendingPrompts();
      // Skip if a mutation happened after this fetch started
      if (fetchStartTime.isBefore(_lastMutationTime)) return;
      _pendingPrompts = prompts;
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to load pending prompts: $e');
    }
  }

  Future<bool> dismissPrompt(int routineId) async {
    _error = null;

    try {
      await _routineApi.dismissPrompt(routineId: routineId);
      _pendingPrompts = _pendingPrompts.where((p) => p.routineId != routineId).toList();
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> quickCompleteRoutine(int routineId, {List<int>? completedStepIds}) async {
    _lastMutationTime = DateTime.now();
    _error = null;

    try {
      await _routineApi.quickCompleteRoutine(routineId: routineId, completedStepIds: completedStepIds);
      _pendingPrompts = _pendingPrompts.where((p) => p.routineId != routineId).toList();
      _activeExecutions.remove(routineId);
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  // ==================== Execution ====================

  Future<RoutineCompletion?> startRoutine(int routineId) async {
    _lastMutationTime = DateTime.now();
    _error = null;

    try {
      final completion = await _routineApi.startRoutine(routineId: routineId);
      _activeExecutions[routineId] = completion;
      _pendingPrompts = _pendingPrompts.where((p) => p.routineId != routineId).toList();
      notifyListeners();
      return completion;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return null;
    }
  }

  Future<void> loadActiveExecution(int routineId) async {
    final fetchStartTime = DateTime.now();
    try {
      final execution = await _routineApi.getActiveExecution(routineId: routineId);
      // Skip if a mutation happened after this fetch started
      if (fetchStartTime.isBefore(_lastMutationTime)) return;
      if (execution != null) {
        _activeExecutions[routineId] = execution;
      } else {
        _activeExecutions.remove(routineId);
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to load active execution: $e');
    }
  }

  Future<bool> completeStep(int completionId, int stepId, String action) async {
    _lastMutationTime = DateTime.now();
    _error = null;

    // Find routineId
    int? routineId;
    _activeExecutions.forEach((rId, exec) {
      if (exec.id == completionId) routineId = rId;
    });

    // Optimistic update
    if (routineId != null && _activeExecutions.containsKey(routineId)) {
      final execution = _activeExecutions[routineId]!;
      final updatedStepCompletions = execution.stepCompletions.map((sc) {
        if (sc.stepId == stepId) {
          return sc.copyWith(
            status: action == 'complete'
                ? RoutineStepCompletionStatus.completed
                : RoutineStepCompletionStatus.skipped,
            completedAt: DateTime.now(),
          );
        }
        return sc;
      }).toList();

      final completedCount = updatedStepCompletions
          .where((sc) => sc.status == RoutineStepCompletionStatus.completed)
          .length;
      final skippedCount = updatedStepCompletions
          .where((sc) => sc.status == RoutineStepCompletionStatus.skipped)
          .length;

      _activeExecutions[routineId!] = execution.copyWith(
        stepCompletions: updatedStepCompletions,
        completedSteps: completedCount,
        skippedSteps: skippedCount,
      );
      notifyListeners();
    }

    try {
      await _routineApi.completeStep(
        completionId: completionId,
        stepId: stepId,
        action: action,
      );
      return true;
    } catch (e) {
      if (routineId != null) {
        await loadActiveExecution(routineId!);
      }
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> finishExecution(int completionId) async {
    _lastMutationTime = DateTime.now();
    _error = null;

    // Find routineId
    int? routineId;
    RoutineCompletion? previousExecution;
    _activeExecutions.forEach((rId, exec) {
      if (exec.id == completionId) {
        routineId = rId;
        previousExecution = exec;
      }
    });

    // Optimistic update
    if (routineId != null) {
      _activeExecutions.remove(routineId);
      notifyListeners();
    }

    try {
      await _routineApi.finishExecution(completionId: completionId);
      return true;
    } catch (e) {
      // Rollback on error
      if (routineId != null && previousExecution != null) {
        _activeExecutions[routineId!] = previousExecution!;
      }
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> abandonExecution(int completionId) async {
    _lastMutationTime = DateTime.now();
    _error = null;

    // Find routineId
    int? routineId;
    RoutineCompletion? previousExecution;
    _activeExecutions.forEach((rId, exec) {
      if (exec.id == completionId) {
        routineId = rId;
        previousExecution = exec;
      }
    });

    // Optimistic update
    if (routineId != null) {
      _activeExecutions.remove(routineId);
      notifyListeners();
    }

    try {
      await _routineApi.abandonExecution(completionId: completionId);
      return true;
    } catch (e) {
      // Rollback on error
      if (routineId != null && previousExecution != null) {
        _activeExecutions[routineId!] = previousExecution!;
      }
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  // ==================== Analytics ====================

  Future<void> loadAnalytics(int routineId, String startDate, String endDate) async {
    _error = null;

    try {
      final data = await _routineApi.getAnalytics(
        routineId: routineId,
        startDate: startDate,
        endDate: endDate,
      );
      _analytics[routineId] = data;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      debugPrint('Failed to load analytics: $e');
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _wsUnsubscribe?.call();
    super.dispose();
  }
}
