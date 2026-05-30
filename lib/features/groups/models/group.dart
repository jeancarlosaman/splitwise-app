class ExpenseGroup {
  final String id;
  final String name;
  final String emoji;
  final String? createdBy;
  final DateTime createdAt;

  /// True for the auto-created single-user "Personal" group used to track
  /// expenses the user makes alone. Hidden from the normal group list and
  /// surfaced as a special tile.
  final bool isPersonal;

  const ExpenseGroup({
    required this.id,
    required this.name,
    required this.emoji,
    this.createdBy,
    required this.createdAt,
    this.isPersonal = false,
  });

  factory ExpenseGroup.fromJson(Map<String, dynamic> json) => ExpenseGroup(
        id: json['id'] as String,
        name: json['name'] as String,
        emoji: (json['emoji'] as String?) ?? '💰',
        createdBy: json['created_by'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
        isPersonal: (json['is_personal'] as bool?) ?? false,
      );
}
