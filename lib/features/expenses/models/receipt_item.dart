class ReceiptItem {
  final String? id;
  final String? expenseId;
  final String name;
  final double price;
  final List<String> assignedTo; // user IDs

  const ReceiptItem({
    this.id,
    this.expenseId,
    required this.name,
    required this.price,
    this.assignedTo = const [],
  });

  factory ReceiptItem.fromJson(Map<String, dynamic> json) => ReceiptItem(
        id: json['id'] as String?,
        expenseId: json['expense_id'] as String?,
        name: json['name'] as String,
        price: (json['price'] as num).toDouble(),
        assignedTo: (json['assigned_to'] as List<dynamic>?)
                ?.map((e) => e as String)
                .toList() ??
            [],
      );

  ReceiptItem copyWith({
    String? name,
    double? price,
    List<String>? assignedTo,
  }) =>
      ReceiptItem(
        id: id,
        expenseId: expenseId,
        name: name ?? this.name,
        price: price ?? this.price,
        assignedTo: assignedTo ?? this.assignedTo,
      );
}
