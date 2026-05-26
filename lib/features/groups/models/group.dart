class ExpenseGroup {
  final String id;
  final String name;
  final String emoji;
  final String? createdBy;
  final DateTime createdAt;

  const ExpenseGroup({
    required this.id,
    required this.name,
    required this.emoji,
    this.createdBy,
    required this.createdAt,
  });

  factory ExpenseGroup.fromJson(Map<String, dynamic> json) => ExpenseGroup(
        id: json['id'] as String,
        name: json['name'] as String,
        emoji: (json['emoji'] as String?) ?? '💰',
        createdBy: json['created_by'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}
