class LaterListTodo {
  final int id;
  final String text;
  final bool isCompleted;
  final DateTime? completedAt;
  final int position;

  LaterListTodo({
    required this.id,
    required this.text,
    required this.isCompleted,
    this.completedAt,
    required this.position,
  });

  factory LaterListTodo.fromJson(Map<String, dynamic> json) {
    return LaterListTodo(
      id: json['id'] as int,
      text: json['text'] as String,
      isCompleted: json['isCompleted'] as bool,
      completedAt: json['completedAt'] != null
          ? DateTime.parse(json['completedAt'] as String)
          : null,
      position: json['position'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'text': text,
      'isCompleted': isCompleted,
      'completedAt': completedAt?.toIso8601String(),
      'position': position,
    };
  }

  LaterListTodo copyWith({
    int? id,
    String? text,
    bool? isCompleted,
    DateTime? completedAt,
    int? position,
  }) {
    return LaterListTodo(
      id: id ?? this.id,
      text: text ?? this.text,
      isCompleted: isCompleted ?? this.isCompleted,
      completedAt: completedAt ?? this.completedAt,
      position: position ?? this.position,
    );
  }
}
