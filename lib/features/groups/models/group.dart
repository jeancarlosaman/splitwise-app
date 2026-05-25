class ExpenseGroup {
  const ExpenseGroup({
    required this.id,
    required this.name,
    required this.emoji,
    this.createdBy,
    required this.createdAt,
  });

  final String id;
  final String name;
  final String emoji;
  final String? createdBy;
  final DateTime createdAt;

  factory ExpenseGroup.fromJson(Map<String, dynamic> json) {
    return ExpenseGroup(
      id:        json['id'] as String,
      name:      json['name'] as String,
      emoji:     json['emoji'] as String? ?? '💰',
      createdBy: json['created_by'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'id':         id,
        'name':       name,
        'emoji':      emoji,
        'created_by': createdBy,
        'created_at': createdAt.toIso8601String(),
      };

  ExpenseGroup copyWith({
    String? id,
    String? name,
    String? emoji,
    String? createdBy,
    DateTime? createdAt,
  }) {
    return ExpenseGroup(
      id:        id        ?? this.id,
      name:      name      ?? this.name,
      emoji:     emoji     ?? this.emoji,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is ExpenseGroup && other.id == id);

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'ExpenseGroup(id: $id, name: $name)';
}
