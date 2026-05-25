import '../../auth/models/app_user.dart';

class ExpenseParticipant {
  const ExpenseParticipant({
    required this.id,
    required this.expenseId,
    required this.userId,
    required this.shareAmount,
    this.user,
  });

  final String id;
  final String expenseId;
  final String userId;
  final double shareAmount;
  final AppUser? user;

  factory ExpenseParticipant.fromJson(Map<String, dynamic> json) {
    final profileJson = json['profiles'] as Map<String, dynamic>?;
    return ExpenseParticipant(
      id:          json['id'] as String,
      expenseId:   json['expense_id'] as String,
      userId:      json['user_id'] as String,
      shareAmount: (json['share_amount'] as num).toDouble(),
      user:        profileJson != null ? AppUser.fromJson(profileJson) : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id':           id,
        'expense_id':   expenseId,
        'user_id':      userId,
        'share_amount': shareAmount,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ExpenseParticipant && other.id == id);

  @override
  int get hashCode => id.hashCode;
}
