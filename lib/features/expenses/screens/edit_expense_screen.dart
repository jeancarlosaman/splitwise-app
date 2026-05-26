import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/expenses_provider.dart';
import '../../groups/providers/groups_provider.dart';
import '../../../shared/repositories/expenses_repository.dart';
import '../../../shared/repositories/supabase_client.dart';
import '../../../shared/widgets/loading_overlay.dart';
import '../../../shared/widgets/user_avatar.dart';
import '../../../shared/widgets/amount_input.dart';
import '../../../core/theme.dart';
import '../../../core/utils/currency_utils.dart';
import '../../../core/constants.dart';

class EditExpenseScreen extends ConsumerStatefulWidget {
  final String groupId;
  final String expenseId;

  const EditExpenseScreen({
    super.key,
    required this.groupId,
    required this.expenseId,
  });

  @override
  ConsumerState<EditExpenseScreen> createState() => _EditExpenseScreenState();
}

class _EditExpenseScreenState extends ConsumerState<EditExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();

  String _currency = AppConstants.defaultCurrency;
  String? _paidByUserId;
  String _splitType = 'equal';
  final Set<String> _participantIds = {};
  bool _isLoading = false;
  bool _initialised = false;

  @override
  void dispose() {
    _descCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _initialise() async {
    if (_initialised) return;
    _initialised = true;

    final expense = ref
        .read(groupExpensesProvider(widget.groupId))
        .value
        ?.firstWhere((e) => e.id == widget.expenseId, orElse: () => throw '');
    if (expense == null) return;

    _descCtrl.text = expense.description;
    _amountCtrl.text = expense.amount.toStringAsFixed(2);
    _currency = expense.currency;
    _paidByUserId = expense.paidBy;
    _splitType = expense.splitType;

    // Load existing participants
    final repo = ref.read(expensesRepositoryProvider);
    final participants = await repo.getParticipants(widget.expenseId);
    setState(() {
      _participantIds.addAll(participants.map((p) => p.userId));
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_paidByUserId == null) return;
    if (_participantIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least one participant')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final repo = ref.read(expensesRepositoryProvider);
      final amount = double.parse(_amountCtrl.text);

      // Update expense fields via Supabase
      await supabase.from('expenses').update({
        'description': _descCtrl.text.trim(),
        'amount': amount,
        'currency': _currency,
        'paid_by': _paidByUserId,
        'split_type': _splitType,
      }).eq('id', widget.expenseId);

      // Replace participants
      await supabase
          .from('expense_participants')
          .delete()
          .eq('expense_id', widget.expenseId);

      final share = double.parse(
          (amount / _participantIds.length).toStringAsFixed(2));
      await supabase.from('expense_participants').insert(
            _participantIds
                .map((id) => {
                      'expense_id': widget.expenseId,
                      'user_id': id,
                      'share_amount': share,
                    })
                .toList(),
          );

      ref.invalidate(groupExpensesProvider(widget.groupId));

      if (mounted) {
        context.pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Expense updated!'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final membersAsync = ref.watch(groupMembersProvider(widget.groupId));
    final members = membersAsync.value ?? [];

    return FutureBuilder(
      future: _initialise(),
      builder: (context, _) => LoadingOverlay(
        isLoading: _isLoading,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Edit Expense'),
            actions: [
              TextButton(
                onPressed: _isLoading ? null : _save,
                child: const Text('Save',
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primary)),
              ),
            ],
          ),
          body: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                AmountInput(controller: _amountCtrl, currency: _currency),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _currency,
                  decoration:
                      const InputDecoration(labelText: 'Currency'),
                  items: CurrencyUtils.supportedCurrencies
                      .map((c) =>
                          DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (v) => setState(() => _currency = v!),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _descCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    prefixIcon:
                        Icon(Icons.description_outlined),
                  ),
                  validator: (v) =>
                      v != null && v.trim().isNotEmpty
                          ? null
                          : 'Enter a description',
                ),
                const SizedBox(height: 20),
                Text('Paid by',
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: members.map((m) {
                    final selected = _paidByUserId == m.user.id;
                    return ChoiceChip(
                      avatar: UserAvatar(user: m.user, radius: 12),
                      label: Text(m.user.displayName),
                      selected: selected,
                      onSelected: (_) =>
                          setState(() => _paidByUserId = m.user.id),
                      selectedColor:
                          AppTheme.primary.withOpacity(0.15),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),
                Text('Split with',
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: members.map((m) {
                    final selected =
                        _participantIds.contains(m.user.id);
                    return FilterChip(
                      avatar: UserAvatar(user: m.user, radius: 12),
                      label: Text(m.user.displayName),
                      selected: selected,
                      selectedColor:
                          AppTheme.primary.withOpacity(0.15),
                      onSelected: (v) => setState(() {
                        v
                            ? _participantIds.add(m.user.id)
                            : _participantIds.remove(m.user.id);
                      }),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 32),
                GradientButton(
                  label: 'Save Changes',
                  icon: Icons.check_rounded,
                  onPressed: _isLoading ? null : _save,
                  isLoading: _isLoading,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
