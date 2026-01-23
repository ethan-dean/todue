class Routine {
  final int id;
  final String name;
  final int stepCount;

  Routine({
    required this.id,
    required this.name,
    required this.stepCount,
  });

  factory Routine.fromJson(Map<String, dynamic> json) {
    return Routine(
      id: json['id'] as int,
      name: json['name'] as String,
      stepCount: json['stepCount'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'stepCount': stepCount,
    };
  }

  Routine copyWith({
    int? id,
    String? name,
    int? stepCount,
  }) {
    return Routine(
      id: id ?? this.id,
      name: name ?? this.name,
      stepCount: stepCount ?? this.stepCount,
    );
  }
}

class RoutineStep {
  final int id;
  final String text;
  final String? notes;
  final int position;

  RoutineStep({
    required this.id,
    required this.text,
    this.notes,
    required this.position,
  });

  factory RoutineStep.fromJson(Map<String, dynamic> json) {
    return RoutineStep(
      id: json['id'] as int,
      text: json['text'] as String,
      notes: json['notes'] as String?,
      position: json['position'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'text': text,
      'notes': notes,
      'position': position,
    };
  }

  RoutineStep copyWith({
    int? id,
    String? text,
    String? notes,
    int? position,
  }) {
    return RoutineStep(
      id: id ?? this.id,
      text: text ?? this.text,
      notes: notes ?? this.notes,
      position: position ?? this.position,
    );
  }
}

class RoutineSchedule {
  final int id;
  final int dayOfWeek;  // 0=Sunday through 6=Saturday
  final String? promptTime;  // HH:mm:ss format or null

  RoutineSchedule({
    required this.id,
    required this.dayOfWeek,
    this.promptTime,
  });

  factory RoutineSchedule.fromJson(Map<String, dynamic> json) {
    return RoutineSchedule(
      id: json['id'] as int,
      dayOfWeek: json['dayOfWeek'] as int,
      promptTime: json['promptTime'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'dayOfWeek': dayOfWeek,
      'promptTime': promptTime,
    };
  }
}

class RoutineDetail {
  final int id;
  final String name;
  final List<RoutineStep> steps;
  final List<RoutineSchedule> schedules;

  RoutineDetail({
    required this.id,
    required this.name,
    required this.steps,
    required this.schedules,
  });

  factory RoutineDetail.fromJson(Map<String, dynamic> json) {
    return RoutineDetail(
      id: json['id'] as int,
      name: json['name'] as String,
      steps: (json['steps'] as List<dynamic>)
          .map((e) => RoutineStep.fromJson(e as Map<String, dynamic>))
          .toList(),
      schedules: (json['schedules'] as List<dynamic>)
          .map((e) => RoutineSchedule.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  RoutineDetail copyWith({
    int? id,
    String? name,
    List<RoutineStep>? steps,
    List<RoutineSchedule>? schedules,
  }) {
    return RoutineDetail(
      id: id ?? this.id,
      name: name ?? this.name,
      steps: steps ?? this.steps,
      schedules: schedules ?? this.schedules,
    );
  }
}

enum RoutineCompletionStatus {
  inProgress,
  completed,
  abandoned;

  static RoutineCompletionStatus fromString(String status) {
    switch (status) {
      case 'IN_PROGRESS':
        return RoutineCompletionStatus.inProgress;
      case 'COMPLETED':
        return RoutineCompletionStatus.completed;
      case 'ABANDONED':
        return RoutineCompletionStatus.abandoned;
      default:
        return RoutineCompletionStatus.inProgress;
    }
  }

  String toJson() {
    switch (this) {
      case RoutineCompletionStatus.inProgress:
        return 'IN_PROGRESS';
      case RoutineCompletionStatus.completed:
        return 'COMPLETED';
      case RoutineCompletionStatus.abandoned:
        return 'ABANDONED';
    }
  }
}

enum RoutineStepCompletionStatus {
  pending,
  completed,
  skipped;

  static RoutineStepCompletionStatus fromString(String status) {
    switch (status) {
      case 'PENDING':
        return RoutineStepCompletionStatus.pending;
      case 'COMPLETED':
        return RoutineStepCompletionStatus.completed;
      case 'SKIPPED':
        return RoutineStepCompletionStatus.skipped;
      default:
        return RoutineStepCompletionStatus.pending;
    }
  }

  String toJson() {
    switch (this) {
      case RoutineStepCompletionStatus.pending:
        return 'PENDING';
      case RoutineStepCompletionStatus.completed:
        return 'COMPLETED';
      case RoutineStepCompletionStatus.skipped:
        return 'SKIPPED';
    }
  }
}

class RoutineStepCompletion {
  final int id;
  final int stepId;
  final String stepText;
  final String? stepNotes;
  final int stepPosition;
  final RoutineStepCompletionStatus status;
  final DateTime? completedAt;
  final String? notes;

  RoutineStepCompletion({
    required this.id,
    required this.stepId,
    required this.stepText,
    this.stepNotes,
    required this.stepPosition,
    required this.status,
    this.completedAt,
    this.notes,
  });

  factory RoutineStepCompletion.fromJson(Map<String, dynamic> json) {
    return RoutineStepCompletion(
      id: json['id'] as int,
      stepId: json['stepId'] as int,
      stepText: json['stepText'] as String,
      stepNotes: json['stepNotes'] as String?,
      stepPosition: json['stepPosition'] as int,
      status: RoutineStepCompletionStatus.fromString(json['status'] as String),
      completedAt: json['completedAt'] != null
          ? DateTime.parse(json['completedAt'] as String)
          : null,
      notes: json['notes'] as String?,
    );
  }

  RoutineStepCompletion copyWith({
    int? id,
    int? stepId,
    String? stepText,
    String? stepNotes,
    int? stepPosition,
    RoutineStepCompletionStatus? status,
    DateTime? completedAt,
    String? notes,
  }) {
    return RoutineStepCompletion(
      id: id ?? this.id,
      stepId: stepId ?? this.stepId,
      stepText: stepText ?? this.stepText,
      stepNotes: stepNotes ?? this.stepNotes,
      stepPosition: stepPosition ?? this.stepPosition,
      status: status ?? this.status,
      completedAt: completedAt ?? this.completedAt,
      notes: notes ?? this.notes,
    );
  }
}

class RoutineCompletion {
  final int id;
  final int routineId;
  final String routineName;
  final DateTime date;
  final DateTime startedAt;
  final DateTime? completedAt;
  final RoutineCompletionStatus status;
  final List<RoutineStepCompletion> stepCompletions;
  final int totalSteps;
  final int completedSteps;
  final int skippedSteps;

  RoutineCompletion({
    required this.id,
    required this.routineId,
    required this.routineName,
    required this.date,
    required this.startedAt,
    this.completedAt,
    required this.status,
    required this.stepCompletions,
    required this.totalSteps,
    required this.completedSteps,
    required this.skippedSteps,
  });

  factory RoutineCompletion.fromJson(Map<String, dynamic> json) {
    return RoutineCompletion(
      id: json['id'] as int,
      routineId: json['routineId'] as int,
      routineName: json['routineName'] as String,
      date: DateTime.parse(json['date'] as String),
      startedAt: DateTime.parse(json['startedAt'] as String),
      completedAt: json['completedAt'] != null
          ? DateTime.parse(json['completedAt'] as String)
          : null,
      status: RoutineCompletionStatus.fromString(json['status'] as String),
      stepCompletions: (json['stepCompletions'] as List<dynamic>)
          .map((e) => RoutineStepCompletion.fromJson(e as Map<String, dynamic>))
          .toList(),
      totalSteps: json['totalSteps'] as int,
      completedSteps: json['completedSteps'] as int,
      skippedSteps: json['skippedSteps'] as int,
    );
  }

  RoutineCompletion copyWith({
    int? id,
    int? routineId,
    String? routineName,
    DateTime? date,
    DateTime? startedAt,
    DateTime? completedAt,
    RoutineCompletionStatus? status,
    List<RoutineStepCompletion>? stepCompletions,
    int? totalSteps,
    int? completedSteps,
    int? skippedSteps,
  }) {
    return RoutineCompletion(
      id: id ?? this.id,
      routineId: routineId ?? this.routineId,
      routineName: routineName ?? this.routineName,
      date: date ?? this.date,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      status: status ?? this.status,
      stepCompletions: stepCompletions ?? this.stepCompletions,
      totalSteps: totalSteps ?? this.totalSteps,
      completedSteps: completedSteps ?? this.completedSteps,
      skippedSteps: skippedSteps ?? this.skippedSteps,
    );
  }
}

class PendingRoutinePrompt {
  final int routineId;
  final String routineName;
  final int stepCount;
  final String? scheduledTime;  // HH:mm:ss format

  PendingRoutinePrompt({
    required this.routineId,
    required this.routineName,
    required this.stepCount,
    this.scheduledTime,
  });

  factory PendingRoutinePrompt.fromJson(Map<String, dynamic> json) {
    return PendingRoutinePrompt(
      routineId: json['routineId'] as int,
      routineName: json['routineName'] as String,
      stepCount: json['stepCount'] as int,
      scheduledTime: json['scheduledTime'] as String?,
    );
  }
}

class RoutineStepAnalytics {
  final int stepId;
  final String stepText;
  final int completedCount;
  final int skippedCount;
  final double completionRate;

  RoutineStepAnalytics({
    required this.stepId,
    required this.stepText,
    required this.completedCount,
    required this.skippedCount,
    required this.completionRate,
  });

  factory RoutineStepAnalytics.fromJson(Map<String, dynamic> json) {
    return RoutineStepAnalytics(
      stepId: json['stepId'] as int,
      stepText: json['stepText'] as String,
      completedCount: json['completedCount'] as int,
      skippedCount: json['skippedCount'] as int,
      completionRate: (json['completionRate'] as num).toDouble(),
    );
  }
}

class RoutineAnalytics {
  final int routineId;
  final String routineName;
  final Map<String, String> calendarData;  // date -> status
  final int currentStreak;
  final int longestStreak;
  final double completionRate;
  final int totalCompletions;
  final int totalAbandoned;
  final List<RoutineStepAnalytics> stepAnalytics;

  RoutineAnalytics({
    required this.routineId,
    required this.routineName,
    required this.calendarData,
    required this.currentStreak,
    required this.longestStreak,
    required this.completionRate,
    required this.totalCompletions,
    required this.totalAbandoned,
    required this.stepAnalytics,
  });

  factory RoutineAnalytics.fromJson(Map<String, dynamic> json) {
    return RoutineAnalytics(
      routineId: json['routineId'] as int,
      routineName: json['routineName'] as String,
      calendarData: Map<String, String>.from(json['calendarData'] as Map),
      currentStreak: json['currentStreak'] as int,
      longestStreak: json['longestStreak'] as int,
      completionRate: (json['completionRate'] as num).toDouble(),
      totalCompletions: json['totalCompletions'] as int,
      totalAbandoned: json['totalAbandoned'] as int,
      stepAnalytics: (json['stepAnalytics'] as List<dynamic>)
          .map((e) => RoutineStepAnalytics.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class RoutineHistory {
  final int id;
  final DateTime date;
  final DateTime startedAt;
  final DateTime? completedAt;
  final RoutineCompletionStatus status;
  final int totalSteps;
  final int completedSteps;
  final int skippedSteps;

  RoutineHistory({
    required this.id,
    required this.date,
    required this.startedAt,
    this.completedAt,
    required this.status,
    required this.totalSteps,
    required this.completedSteps,
    required this.skippedSteps,
  });

  factory RoutineHistory.fromJson(Map<String, dynamic> json) {
    return RoutineHistory(
      id: json['id'] as int,
      date: DateTime.parse(json['date'] as String),
      startedAt: DateTime.parse(json['startedAt'] as String),
      completedAt: json['completedAt'] != null
          ? DateTime.parse(json['completedAt'] as String)
          : null,
      status: RoutineCompletionStatus.fromString(json['status'] as String),
      totalSteps: json['totalSteps'] as int,
      completedSteps: json['completedSteps'] as int,
      skippedSteps: json['skippedSteps'] as int,
    );
  }
}

class ScheduleEntry {
  final int dayOfWeek;
  final String? promptTime;

  ScheduleEntry({
    required this.dayOfWeek,
    this.promptTime,
  });

  Map<String, dynamic> toJson() {
    return {
      'dayOfWeek': dayOfWeek,
      'promptTime': promptTime,
    };
  }
}
