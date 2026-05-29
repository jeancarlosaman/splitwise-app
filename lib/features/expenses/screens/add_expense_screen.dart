import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/expenses_provider.dart';
import '../models/expense_participant.dart';
import '../models/receipt_item.dart';
import '../../groups/providers/groups_provider.dart';
import '../../groups/models/group_member.dart';
import '../../ocr/receipt_scanner.dart';
import '../../ocr/screens/receipt_review_screen.dart';
import '../../voice/voice_recorder.dart';
import '../../voice/expense_nlp_parser.dart';
import '../../../shared/repositories/supabase_client.dart';
import '../../../shared/repositories/expenses_repository.dart';
import '../../../shared/widgets/loading_overlay.dart';
import '../../../shared/widgets/user_avatar.dart';
import '../../../shared/widgets/amount_input.dart';
import '../../../core/utils/currency_utils.dart';
import '../../../core/constants.dart';
import '../../../core/theme.dart';

class AddExpenseScreen extends ConsumerStatefulWidget {
  final String groupId;
  const AddExpenseScreen({super.key, required this.groupId});

  @override
  ConsumerState<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends ConsumerState<AddExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();

  String _currency = AppConstants.defaultCurrency;
  String? _paidByUserId;
  String _splitType = 'equal';
  final Set<String> _participantIds = {};
  List<ReceiptItem> _receiptItems = [];
  bool _isLoading = false;

  final _scanner = ReceiptScanner();
  final _voice = VoiceRecorder();
  bool _isListening = false;
  String _voiceTranscript = '';

  @override
  void initState() {
    super.initState();
    _voice.initialize();
    _paidByUserId = supabase.auth.currentUser?.id;
  }

  @override
  void dispose() {
    _descCtrl.dispose();
    _amountCtrl.dispose();
    _scanner.dispose();
    _voice.dispose();
    super.dispose();
  }

  // ── OCR flow ──────────────────────────────────────────────────────────────
  Future<void> _scanReceipt({bool fromGallery = false}) async {
    setState(() => _isLoading = true);
    try {
      final parsed = fromGallery
          ? await _scanner.scanFromGallery()
          : await _scanner.scanFromCamera();
      if (parsed == null || !mounted) return;

      if (parsed.items.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('No items detected — try a clearer photo.')));
        return;
      }

      final members = ref.read(groupMembersProvider(widget.groupId)).value ?? [];

      // Use Navigator.push so we get the result back
      final result = await Navigator.of(context).push<List<ReceiptItem>>(
        MaterialPageRoute(
          builder: (_) => ReceiptReviewScreen(
            items: parsed.items,
            members: members,
            detectedTotal: parsed.total,
          ),
        ),
      );

      if (result != null && result.isNotEmpty && mounted) {
        final total = result.fold<double>(0.0, (sum, item) => sum + item.price);
        setState(() {
          _receiptItems = result;
          _amountCtrl.text = total.toStringAsFixed(2);
          _splitType = 'by_item';
          if (parsed.merchant != null && _descCtrl.text.isEmpty) {
            _descCtrl.text = parsed.merchant!;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('OCR error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Voice flow ────────────────────────────────────────────────────────────
  Future<void> _toggleVoice() async {
    if (_isListening) {
      await _voice.stopListening();
      setState(() => _isListening = false);
      _applyVoiceResult(_voiceTranscript);
    } else {
      final ok = await _voice.initialize();
      if (!ok) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Speech recognition not available')));
        return;
      }
      setState(() { _isListening = true; _voiceTranscript = ''; });
      await _voice.startListening(
          onResult: (text) => setState(() => _voiceTranscript = text));
    }
  }

  void _applyVoiceResult(String transcript) {
    if (transcript.isEmpty) return;
    final parsed = ExpenseNlpParser.parse(transcript);
    if (parsed.amount != null) _amountCtrl.text = parsed.amount!.toStringAsFixed(2);
    if (parsed.description != null && _descCtrl.text.isEmpty) _descCtrl.text = parsed.description!;
    if (parsed.payerName == 'me') {
      setState(() => _paidByUserId = supabase.auth.currentUser?.id);
    } else if (parsed.payerName != null) {
      final members = ref.read(groupMembersProvider(widget.groupId)).value ?? [];
      final match = members.where((m) =>
          m.user.displayName.toLowerCase().contains(parsed.payerName!.toLowerCase()));
      if (match.isNotEmpty) setState(() => _paidByUserId = match.first.user.id);
    }
    if (parsed.splitWithNames.isNotEmpty) {
      final members = ref.read(groupMembersProvider(widget.groupId)).value ?? [];
      for (final name in parsed.splitWithNames) {
        for (final m in members) {
          if (m.user.displayName.toLowerCase().contains(name.toLowerCase())) {
            _participantIds.add(m.user.id);
          }
        }
      }
      setState(() {});
    }
    if (mounted && parsed.hasData) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Got it! "${transcript.substring(0, transcript.length.clamp(0, 60))}…"'),
        duration: const Duration(seconds: 3),
      ));
    }
  }

  // ── Submit ────────────────────────────────────────────────────────────────
  Future<void> _submit(List<GroupMember> members) async {
    if (!_formKey.currentState!.validate()) return;
    if (_paidByUserId == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Select who paid')));
      return;
    }
    if (_participantIds.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Select at least one participant')));
      return;
    }

    setState(() => _isLoading = true);
    try {
      final repo = ref.read(expensesRepositoryProvider);
      final amount = double.parse(_amountCtrl.text);

      final expense = await repo.createExpense(
        groupId: widget.groupId,
        description: _descCtrl.text.trim(),
        amount: amount,
        currency: _currency,
        paidBy: _paidByUserId!,
        splitType: _splitType,
      );

      final List<ExpenseParticipant> participants;
      if (_splitType == 'equal') {
        final share = double.parse((amount / _participantIds.length).toStringAsFixed(2));
        participants = _participantIds.map((id) => ExpenseParticipant(
          id: '', expenseId: expense.id, userId: id, shareAmount: share)).toList();
      } else {
        final shareMap = <String, double>{};
        for (final item in _receiptItems) {
          if (item.assignedTo.isEmpty) {
            final per = item.price / _participantIds.length;
            for (final id in _participantIds) shareMap[id] = (shareMap[id] ?? 0) + per;
          } else {
            final per = item.price / item.assignedTo.length;
            for (final id in item.assignedTo) shareMap[id] = (shareMap[id] ?? 0) + per;
          }
        }
        participants = shareMap.entries.map((e) => ExpenseParticipant(
          id: '', expenseId: expense.id, userId: e.key,
          shareAmount: double.parse(e.value.toStringAsFixed(2)))).toList();
      }

      await repo.addParticipants(expense.id, participants);
      if (_receiptItems.isNotEmpty) await repo.addReceiptItems(expense.id, _receiptItems);
      ref.invalidate(groupExpensesProvider(widget.groupId));

      if (mounted) {
        context.pop();
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Expense added!')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showScanOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 36, height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(color: AppTheme.border,
                    borderRadius: BorderRadius.circular(2))),
              _SheetTile(
                icon: Icons.camera_alt_outlined,
                title: 'Take a photo',
                onTap: () { Navigator.pop(ctx); _scanReceipt(); },
              ),
              _SheetTile(
                icon: Icons.photo_library_outlined,
                title: 'Choose from gallery',
                onTap: () { Navigator.pop(ctx); _scanReceipt(fromGallery: true); },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final membersAsync = ref.watch(groupMembersProvider(widget.groupId));
    final members = membersAsync.value ?? [];

    return LoadingOverlay(
      isLoading: _isLoading,
      child: Scaffold(
        backgroundColor: AppTheme.black,
        appBar: AppBar(
          title: const Text('Add Expense'),
          actions: [
            IconButton(
              icon: const Icon(Icons.document_scanner_outlined),
              tooltip: 'Scan receipt',
              onPressed: _showScanOptions,
            ),
            IconButton(
              icon: Icon(
                _isListening ? Icons.mic_rounded : Icons.mic_none_rounded,
                color: _isListening ? AppTheme.negative : null,
              ),
              tooltip: _isListening ? 'Stop recording' : 'Voice input',
              onPressed: _toggleVoice,
            ),
          ],
        ),
        body: membersAsync.when(
          loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.green)),
          error: (e, _) => Center(child: Text('$e')),
          data: (members) => _buildForm(members),
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: ElevatedButton(
              onPressed: _isLoading ? null : () => _submit(members),
              child: const Text('Save Expense'),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildForm(List<GroupMember> members) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ── Voice transcript ─────────────────────────────
            if (_isListening || _voiceTranscript.isNotEmpty) ...[
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _isListening
                      ? AppTheme.negative.withOpacity(0.1)
                      : AppTheme.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: _isListening
                        ? AppTheme.negative.withOpacity(0.4)
                        : AppTheme.border,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(_isListening ? Icons.mic_rounded : Icons.mic_none_rounded,
                      color: _isListening ? AppTheme.negative : AppTheme.textSecondary,
                      size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _isListening
                            ? (_voiceTranscript.isEmpty ? 'Listening…' : _voiceTranscript)
                            : _voiceTranscript,
                        style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // ── Amount + currency ────────────────────────────
            Row(children: [
              Expanded(child: AmountInput(controller: _amountCtrl, currency: _currency)),
              const SizedBox(width: 10),
              SizedBox(
                width: 100,
                child: DropdownButtonFormField<String>(
                  value: _currency,
                  decoration: const InputDecoration(labelText: 'Currency',
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14)),
                  items: CurrencyUtils.supportedCurrencies
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (v) => setState(() => _currency = v!),
                ),
              ),
            ]),
            const SizedBox(height: 14),

            // ── Description ──────────────────────────────────
            TextFormField(
              controller: _descCtrl,
              style: const TextStyle(color: AppTheme.textPrimary),
              decoration: const InputDecoration(
                labelText: 'Description',
                prefixIcon: Icon(Icons.description_outlined),
              ),
              validator: (v) =>
                  v != null && v.trim().isNotEmpty ? null : 'Enter a description',
            ),
            const SizedBox(height: 20),

            // ── Paid by ──────────────────────────────────────
            _SectionLabel(label: 'Paid by'),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8, runSpacing: 8,
              children: members.map((m) {
                final selected = _paidByUserId == m.user.id;
                return _MemberChip(
                  member: m, selected: selected,
                  onTap: () => setState(() => _paidByUserId = m.user.id),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),

            // ── Split type ───────────────────────────────────
            _SectionLabel(label: 'Split type'),
            const SizedBox(height: 10),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'equal', label: Text('Equal'),
                    icon: Icon(Icons.people_outline, size: 16)),
                ButtonSegment(value: 'by_item', label: Text('By Item'),
                    icon: Icon(Icons.receipt_long_outlined, size: 16)),
              ],
              selected: {_splitType},
              onSelectionChanged: (s) => setState(() => _splitType = s.first),
            ),
            const SizedBox(height: 20),

            // ── Participants ─────────────────────────────────
            _SectionLabel(label: 'Split with'),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8, runSpacing: 8,
              children: members.map((m) {
                final selected = _participantIds.contains(m.user.id);
                return _MemberChip(
                  member: m, selected: selected,
                  onTap: () => setState(() {
                    selected
                        ? _participantIds.remove(m.user.id)
                        : _participantIds.add(m.user.id);
                  }),
                  checkmark: true,
                );
              }).toList(),
            ),

            // ── Receipt items preview ────────────────────────
            if (_receiptItems.isNotEmpty) ...[
              const SizedBox(height: 24),
              Row(children: [
                _SectionLabel(label: 'Receipt Items'),
                const Spacer(),
                Text('${_receiptItems.length} items',
                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
              ]),
              const SizedBox(height: 10),
              Container(
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.border, width: 0.5),
                ),
                child: Column(
                  children: _receiptItems.asMap().entries.map((entry) {
                    final i = entry.key;
                    final item = entry.value;
                    final isLast = i == _receiptItems.length - 1;
                    return Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          child: Row(
                            children: [
                              const Icon(Icons.check_circle_outline_rounded,
                                  color: AppTheme.green, size: 18),
                              const SizedBox(width: 10),
                              Expanded(child: Text(item.name,
                                  style: const TextStyle(color: AppTheme.textPrimary,
                                      fontSize: 14))),
                              Text(CurrencyUtils.format(item.price, currency: _currency),
                                style: const TextStyle(color: AppTheme.green,
                                    fontWeight: FontWeight.w600, fontSize: 14)),
                            ],
                          ),
                        ),
                        if (!isLast)
                          const Divider(height: 1, indent: 44),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ],

            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }
}

// ── Small helpers ─────────────────────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});
  @override
  Widget build(BuildContext context) => Text(label,
      style: const TextStyle(color: AppTheme.textSecondary,
          fontWeight: FontWeight.w600, fontSize: 13));
}

class _MemberChip extends StatelessWidget {
  final GroupMember member;
  final bool selected;
  final bool checkmark;
  final VoidCallback onTap;
  const _MemberChip({required this.member, required this.selected,
      required this.onTap, this.checkmark = false});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppTheme.greenSubtle : AppTheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppTheme.green.withOpacity(0.5) : AppTheme.border,
            width: selected ? 1.0 : 0.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            UserAvatar(user: member.user, radius: 12),
            const SizedBox(width: 8),
            Text(member.user.displayName,
              style: TextStyle(
                color: selected ? AppTheme.green : AppTheme.textPrimary,
                fontSize: 13, fontWeight: FontWeight.w500,
              )),
            if (checkmark && selected) ...[
              const SizedBox(width: 6),
              const Icon(Icons.check_rounded, color: AppTheme.green, size: 14),
            ],
          ],
        ),
      ),
    );
  }
}

class _SheetTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  const _SheetTile({required this.icon, required this.title, required this.onTap});
  @override
  Widget build(BuildContext context) => ListTile(
    leading: Container(
      width: 40, height: 40,
      decoration: BoxDecoration(
        color: AppTheme.greenSubtle, borderRadius: BorderRadius.circular(12)),
      child: Icon(icon, color: AppTheme.green, size: 20),
    ),
    title: Text(title, style: const TextStyle(color: AppTheme.textPrimary,
        fontWeight: FontWeight.w500)),
    onTap: onTap,
  );
}
