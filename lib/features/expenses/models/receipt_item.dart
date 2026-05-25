class ReceiptItem {
  const ReceiptItem({
    required this.id,
    required this.expenseId,
    required this.name,
    required this.price,
    this.assignedTo = const [],
    this.isSelected = true,
  });

  final String id;
  final String expenseId;
  final String name;
  final double price;

  /// User IDs assigned to this item.
  final List<String> assignedTo;

  /// UI-only: whether this item is selected for inclusion.
  final bool isSelected;

  factory ReceiptItem.fromJson(Map<String, dynamic> json) {
    final rawAssigned = json['assigned_to'];
    List<String> assigned = [];
    if (rawAssigned is List) {
      assigned = rawAssigned.map((e) => e as String).toList();
    }

    return ReceiptItem(
      id:         json['id'] as String? ?? '',
      expenseId:  json['expense_id'] as String? ?? '',
      name:       json['name'] as String,
      price:      (json['price'] as num).toDouble(),
      assignedTo: assigned,
    );
  }

  /// Construct a parsed (not yet saved) item from OCR.
  factory ReceiptItem.parsed({
    required String name,
    required double price,
  }) {
    return ReceiptItem(
      id:        '',
      expenseId: '',
      name:      name,
      price:     price,
    );
  }

  Map<String, dynamic> toJson() => {
        'expense_id':  expenseId,
        'name':        name,
        'price':       price,
        'assigned_to': assignedTo,
      };

  ReceiptItem copyWith({
    String? id,
    String? expenseId,
    String? name,
    double? price,
    List<String>? assignedTo,
    bool? isSelected,
  }) {
    return ReceiptItem(
      id:         id         ?? this.id,
      expenseId:  expenseId  ?? this.expenseId,
      name:       name       ?? this.name,
      price:      price      ?? this.price,
      assignedTo: assignedTo ?? this.assignedTo,
      isSelected: isSelected ?? this.isSelected,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is ReceiptItem && other.id == id);

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'ReceiptItem(name: $name, price: $price)';
}
