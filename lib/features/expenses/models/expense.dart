class Expense {
  final String id;
  final String groupId;
  final String description;
  final double amount;
  final String currency;
  final String paidBy;
  final String? paidByName; // denormalized from join
  final String? createdBy;
  final String splitType;
  final String? receiptUrl;
  final DateTime createdAt;

  const Expense({
    required this.id,
    required this.groupId,
    required this.description,
    required this.amount,
    required this.currency,
    required this.paidBy,
    this.paidByName,
    this.createdBy,
    required this.splitType,
    this.receiptUrl,
    required this.createdAt,
  });

  factory Expense.fromJson(Map<String, dynamic> json) {
    final paidByProfile = json['paid_by_profile'] as Map<String, dynamic>?;
    return Expense(
      id: json['id'] as String,
      groupId: json['group_id'] as String,
      description: json['description'] as String,
      amount: (json['amount'] as num).toDouble(),
      currency: (json['currency'] as String?) ?? 'EUR',
      paidBy: json['paid_by'] as String,
      paidByName: paidByProfile?['display_name'] as String?,
      createdBy: json['created_by'] as String?,
      splitType: (json['split_type'] as String?) ?? 'equal',
      receiptUrl: json['receipt_url'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
