class User {
  final int id;
  final String email;
  final String timezone;
  final DateTime createdAt;
  final DateTime? lastRolloverDate;
  final DateTime updatedAt;

  User({
    required this.id,
    required this.email,
    required this.timezone,
    required this.createdAt,
    this.lastRolloverDate,
    required this.updatedAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as int,
      email: json['email'] as String,
      timezone: json['timezone'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      lastRolloverDate: json['lastRolloverDate'] != null
          ? DateTime.parse(json['lastRolloverDate'] as String)
          : null,
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'timezone': timezone,
      'createdAt': createdAt.toIso8601String(),
      'lastRolloverDate': lastRolloverDate?.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  User copyWith({
    int? id,
    String? email,
    String? timezone,
    DateTime? createdAt,
    DateTime? lastRolloverDate,
    DateTime? updatedAt,
  }) {
    return User(
      id: id ?? this.id,
      email: email ?? this.email,
      timezone: timezone ?? this.timezone,
      createdAt: createdAt ?? this.createdAt,
      lastRolloverDate: lastRolloverDate ?? this.lastRolloverDate,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
