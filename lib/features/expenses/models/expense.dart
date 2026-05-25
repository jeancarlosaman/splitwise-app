import '../../auth/models/app_user.dart';
import 'expense_participant.dart';
import 'receipt_item.dart';

class Expense {
  const Expense({
    required this.id,
    required this.groupId,
    required this.description,
    required this.amount,
    required this.currency,
    required this.paidBy,
    required this.createdBy,
    required this.createdAt,
    this.receiptUrl,
    required this.splitType,
    this.paidByProfile,
    this.participants = const [],
    this.receiptItems = const [],
  });

  final String id;
  final String groupId;
  final String description;
  final double amount;
  final String currency;
  final String paidBy;
  final String createdBy;
  final DateTime createdAt;
  final String? receiptUrl;
  final String splitType;

  // Joined data
  final AppUser? paidByProfile;
  final List<ExpenseParticipant> participants;
  final List<ReceiptItem> receiptItems;

  factory Expense.fromJson(Map<String, dynamic> json) {
    final paidByProfileJson =
        json['paid_by_profile'] as Map<String, dynamic>?;

    final participantsRaw = json['expense_participants'] as List<dynamic>?;
    final receiptItemsRaw = json['receipt_items'] as List<dynamic>?;

    return Expense(
      id:             json['id'] as String,
      groupId:        json['group_id'] as String,
      description:    json['description'] as String,
      amount:         (json['amount'] as num).toDouble(),
      currency:       json['currency'] as String? ?? 'EUR',
      paidBy:         json['paid_by'] as String,
      createdBy:      json['created_by'] as String,
      createdAt:      DateTime.parse(json['created_at'] as String),
      receiptUrl:     json['receipt_url'] as String?,
      splitType:      json['split_type'] as String? ?? 'equal',
      paidByProfile:  paidByProfileJson != null
          ? AppUser.fromJson(paidByProfileJson)
          : null,
      participants: participantsRaw
              ?.map((p) =>
                  ExpenseParticipant.fromJson(p as Map<String, dynamic>))
              .toList() ??
          [],
      receiptItems: receiptItemsRaw
              ?.map((r) => ReceiptItem.fromJson(r as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() => {
        'id':          id,
        'group_id':    groupId,
        'description': description,
        'amount':      amount,
        'currency':    currency,
        'paid_by':     paidBy,
        'created_by':  createdBy,
        'created_at':  createdAt.toIso8601String(),
        'receipt_url': receiptUrl,
        'split_type':  splitType,
      };

  Expense copyWith({
    String? id,
    String? groupId,
    String? description,
    double? amount,
    String? currency,
    String? paidBy,
    String? createdBy,
    DateTime? createdAt,
    String? receiptUrl,
    String? splitType,
    AppUser? paidByProfile,
    List<ExpenseParticipant>? participants,
    List<ReceiptItem>? receiptItems,
  }) {
    return Expense(
      id:             id             ?? this.id,
      groupId:        groupId        ?? this.groupId,
      description:    description    ?? this.description,
      amount:         amount         ?? this.amount,
      currency:       currency       ?? this.currency,
      paidBy:         paidBy         ?? this.paidBy,
      createdBy:      createdBy      ?? this.createdBy,
      createdAt:      createdAt      ?? this.createdAt,
      receiptUrl:     receiptUrl     ?? this.receiptUrl,
      splitType:      splitType      ?? this.splitType,
      paidByProfile:  paidByProfile  ?? this.paidByProfile,
      participants:   participants   ?? this.participants,
      receiptItems:   receiptItems   ?? this.receiptItems,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Expense && other.id == id);

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Expense(id: $id, description: $description, amount: $amount)';
}
