enum RecurrenceType {
  DAILY,
  WEEKLY,
  BIWEEKLY,
  MONTHLY,
  YEARLY,
}

class RecurringTodo {
  final int id;
  final String text;
  final RecurrenceType recurrenceType;
  final String startDate; // YYYY-MM-DD format
  final String? endDate; // YYYY-MM-DD format
  final DateTime createdAt;
  final DateTime updatedAt;

  RecurringTodo({
    required this.id,
    required this.text,
    required this.recurrenceType,
    required this.startDate,
    this.endDate,
    required this.createdAt,
    required this.updatedAt,
  });

  factory RecurringTodo.fromJson(Map<String, dynamic> json) {
    return RecurringTodo(
      id: json['id'] as int,
      text: json['text'] as String,
      recurrenceType: RecurrenceType.values.firstWhere(
        (e) => e.name == json['recurrenceType'],
      ),
      startDate: json['startDate'] as String,
      endDate: json['endDate'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'text': text,
      'recurrenceType': recurrenceType.name,
      'startDate': startDate,
      'endDate': endDate,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  RecurringTodo copyWith({
    int? id,
    String? text,
    RecurrenceType? recurrenceType,
    String? startDate,
    String? endDate,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return RecurringTodo(
      id: id ?? this.id,
      text: text ?? this.text,
      recurrenceType: recurrenceType ?? this.recurrenceType,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
