class Todo {
  final int? id;
  final String text;
  final String assignedDate; // YYYY-MM-DD format
  final String instanceDate; // YYYY-MM-DD format
  final int position;
  final int? recurringTodoId;
  final bool isCompleted;
  final DateTime? completedAt;
  final bool isRolledOver;
  final bool isVirtual;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Todo({
    this.id,
    required this.text,
    required this.assignedDate,
    required this.instanceDate,
    required this.position,
    this.recurringTodoId,
    required this.isCompleted,
    this.completedAt,
    required this.isRolledOver,
    required this.isVirtual,
    this.createdAt,
    this.updatedAt,
  });

  factory Todo.fromJson(Map<String, dynamic> json) {
    return Todo(
      id: json['id'] as int?,
      text: json['text'] as String,
      assignedDate: json['assignedDate'] as String,
      instanceDate: json['instanceDate'] as String,
      position: json['position'] as int,
      recurringTodoId: json['recurringTodoId'] as int?,
      isCompleted: json['isCompleted'] as bool,
      completedAt: json['completedAt'] != null
          ? DateTime.parse(json['completedAt'] as String)
          : null,
      isRolledOver: json['isRolledOver'] as bool,
      isVirtual: json['isVirtual'] as bool,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'text': text,
      'assignedDate': assignedDate,
      'instanceDate': instanceDate,
      'position': position,
      'recurringTodoId': recurringTodoId,
      'isCompleted': isCompleted,
      'completedAt': completedAt?.toIso8601String(),
      'isRolledOver': isRolledOver,
      'isVirtual': isVirtual,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  Todo copyWith({
    int? id,
    String? text,
    String? assignedDate,
    String? instanceDate,
    int? position,
    int? recurringTodoId,
    bool? isCompleted,
    DateTime? completedAt,
    bool? isRolledOver,
    bool? isVirtual,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Todo(
      id: id ?? this.id,
      text: text ?? this.text,
      assignedDate: assignedDate ?? this.assignedDate,
      instanceDate: instanceDate ?? this.instanceDate,
      position: position ?? this.position,
      recurringTodoId: recurringTodoId ?? this.recurringTodoId,
      isCompleted: isCompleted ?? this.isCompleted,
      completedAt: completedAt ?? this.completedAt,
      isRolledOver: isRolledOver ?? this.isRolledOver,
      isVirtual: isVirtual ?? this.isVirtual,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
