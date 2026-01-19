class LaterList {
  final int id;
  final String listName;

  LaterList({
    required this.id,
    required this.listName,
  });

  factory LaterList.fromJson(Map<String, dynamic> json) {
    return LaterList(
      id: json['id'] as int,
      listName: json['listName'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'listName': listName,
    };
  }

  LaterList copyWith({
    int? id,
    String? listName,
  }) {
    return LaterList(
      id: id ?? this.id,
      listName: listName ?? this.listName,
    );
  }
}
