import '../../auth/models/app_user.dart';

class ExpenseParticipant {
  final String id;
  final String expenseId;
  final String userId;
  final double shareAmount;
  final AppUser? user; // populated from join

  const ExpenseParticipant({
    required this.id,
    required this.expenseId,
    required this.userId,
    required this.shareAmount,
    this.user,
  });

  factory ExpenseParticipant.fromJson(Map<String, dynamic> json) {
    final profile = json['profiles'] as Map<String, dynamic>?;
    return ExpenseParticipant(
      id: json['id'] as String,
      expenseId: json['expense_id'] as String,
      userId: json['user_id'] as String,
      shareAmount: (json['share_amount'] as num).toDouble(),
      user: profile != null ? AppUser.fromJson(profile) : null,
    );
  }
}
