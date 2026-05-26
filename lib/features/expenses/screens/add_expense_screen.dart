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

  // OCR
  final _scanner = ReceiptScanner();

  // Voice
  final _voice = VoiceRecorder();
  bool _isListening = false;
  String _voiceTranscript = '';

  @override
  void initState() {
    super.initState();
    _voice.initialize();
    // Default payer = current user
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

  // ── OCR flow ─────────────────────────────────────────────────────────────
  Future<void> _scanReceipt({bool fromGallery = false}) async {
    setState(() => _isLoading = true);
    try {
      final parsed = fromGallery
          ? await _scanner.scanFromGallery()
          : await _scanner.scanFromCamera();
      if (parsed == null || !mounted) return;

      if (parsed.items.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Could not detect any items. Try a clearer photo.')),
        );
        return;
      }

      final members = ref.read(groupMembersProvider(widget.groupId)).value ?? [];
      final result = await Navigator.push<List<ReceiptItem>>(
        context,
        MaterialPageRoute(
          builder: (_) => ReceiptReviewScreen(
            items: parsed.items,
            members: members,
            detectedTotal: parsed.total,
          ),
        ),
      );

      if (result != null && result.isNotEmpty) {
        final total =
            result.fold(0.0, (sum, item) => sum + item.price);
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
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Speech recognition not available')),
          );
        }
        return;
      }
      setState(() {
        _isListening = true;
        _voiceTranscript = '';
      });
      await _voice.startListening(
        onResult: (text) => setState(() => _voiceTranscript = text),
      );
    }
  }

  void _applyVoiceResult(String transcript) {
    if (transcript.isEmpty) return;
    final parsed = ExpenseNlpParser.parse(transcript);

    if (parsed.amount != null) {
      _amountCtrl.text = parsed.amount!.toStringAsFixed(2);
    }
    if (parsed.description != null && _descCtrl.text.isEmpty) {
      _descCtrl.text = parsed.description!;
    }

    // Payer resolution
    if (parsed.payerName == 'me') {
      setState(() => _paidByUserId = supabase.auth.currentUser?.id);
    } else if (parsed.payerName != null) {
      final members =
          ref.read(groupMembersProvider(widget.groupId)).value ?? [];
      final match = members.where((m) =>
          m.user.displayName
              .toLowerCase()
              .contains(parsed.payerName!.toLowerCase()));
      if (match.isNotEmpty) {
        setState(() => _paidByUserId = match.first.user.id);
      }
    }

    // Participants from split names
    if (parsed.splitWithNames.isNotEmpty) {
      final members =
          ref.read(groupMembersProvider(widget.groupId)).value ?? [];
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Got it! "${transcript.substring(0, transcript.length.clamp(0, 60))}…"'),
          duration: const Duration(seconds: 3),
        ),
      );
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
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Select at least one participant')));
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

      // Build participants
      final List<ExpenseParticipant> participants;
      if (_splitType == 'equal') {
        final share =
            double.parse((amount / _participantIds.length).toStringAsFixed(2));
        participants = _participantIds
            .map((id) => ExpenseParticipant(
                  id: '',
                  expenseId: expense.id,
                  userId: id,
                  shareAmount: share,
                ))
            .toList();
      } else {
        // by_item: derive shares from receipt items
        final shareMap = <String, double>{};
        for (final item in _receiptItems) {
          if (item.assignedTo.isEmpty) {
            // split equally among all participants
            final perPerson = item.price / _participantIds.length;
            for (final id in _participantIds) {
              shareMap[id] = (shareMap[id] ?? 0) + perPerson;
            }
          } else {
            final perPerson = item.price / item.assignedTo.length;
            for (final id in item.assignedTo) {
              shareMap[id] = (shareMap[id] ?? 0) + perPerson;
            }
          }
        }
        participants = shareMap.entries
            .map((e) => ExpenseParticipant(
                  id: '',
                  expenseId: expense.id,
                  userId: e.key,
                  shareAmount:
                      double.parse(e.value.toStringAsFixed(2)),
                ))
            .toList();
      }

      await repo.addParticipants(expense.id, participants);

      if (_receiptItems.isNotEmpty) {
        await repo.addReceiptItems(expense.id, _receiptItems);
      }

      // Refresh expense list
      ref.invalidate(groupExpensesProvider(widget.groupId));

      if (mounted) {
        context.pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Expense added!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final membersAsync = ref.watch(groupMembersProvider(widget.groupId));
    final members = membersAsync.value ?? [];

    return LoadingOverlay(
      isLoading: _isLoading,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Add Expense'),
          actions: [
            // OCR button
            IconButton(
              icon: const Icon(Icons.document_scanner_outlined),
              tooltip: 'Scan receipt',
              onPressed: () => _showScanOptions(),
            ),
            // Voice button
            IconButton(
              icon: Icon(
                _isListening ? Icons.mic : Icons.mic_none,
                color: _isListening ? Colors.red : null,
              ),
              tooltip: _isListening ? 'Stop recording' : 'Voice input',
              onPressed: _toggleVoice,
            ),
          ],
        ),
        body: membersAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
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

  void _showScanOptions() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Take a photo'),
              onTap: () {
                Navigator.pop(ctx);
                _scanReceipt();
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () {
                Navigator.pop(ctx);
                _scanReceipt(fromGallery: true);
              },
            ),
          ],
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
            // Voice transcript preview
            if (_isListening || _voiceTranscript.isNotEmpty) ...[
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _isListening
                      ? Colors.red.shade50
                      : Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      _isListening ? Icons.mic : Icons.mic_none,
                      color: _isListening ? Colors.red : null,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _isListening
                            ? (_voiceTranscript.isEmpty
                                ? 'Listening…'
                                : _voiceTranscript)
                            : _voiceTranscript,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Amount
            AmountInput(
                controller: _amountCtrl, currency: _currency),
            const SizedBox(height: 8),

            // Currency selector
            DropdownButtonFormField<String>(
              value: _currency,
              decoration: const InputDecoration(labelText: 'Currency'),
              items: CurrencyUtils.supportedCurrencies
                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: (v) => setState(() => _currency = v!),
            ),
            const SizedBox(height: 16),

            // Description
            TextFormField(
              controller: _descCtrl,
              decoration: const InputDecoration(
                labelText: 'Description',
                prefixIcon: Icon(Icons.description_outlined),
              ),
              validator: (v) =>
                  v != null && v.trim().isNotEmpty ? null : 'Enter a description',
            ),
            const SizedBox(height: 16),

            // Paid by
            Text('Paid by',
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: members.map((m) {
                final selected = _paidByUserId == m.user.id;
                return ChoiceChip(
                  avatar: UserAvatar(user: m.user, radius: 12),
                  label: Text(m.user.displayName),
                  selected: selected,
                  onSelected: (_) =>
                      setState(() => _paidByUserId = m.user.id),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // Split type
            Text('Split type',
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                    value: 'equal',
                    label: Text('Equal'),
                    icon: Icon(Icons.people_outline)),
                ButtonSegment(
                    value: 'by_item',
                    label: Text('By Item'),
                    icon: Icon(Icons.receipt_long_outlined)),
              ],
              selected: {_splitType},
              onSelectionChanged: (s) =>
                  setState(() => _splitType = s.first),
            ),
            const SizedBox(height: 16),

            // Participants
            Text('Split with',
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: members.map((m) {
                final selected = _participantIds.contains(m.user.id);
                return FilterChip(
                  avatar: UserAvatar(user: m.user, radius: 12),
                  label: Text(m.user.displayName),
                  selected: selected,
                  onSelected: (v) => setState(() {
                    v
                        ? _participantIds.add(m.user.id)
                        : _participantIds.remove(m.user.id);
                  }),
                );
              }).toList(),
            ),

            // Receipt items preview (if OCR was used)
            if (_receiptItems.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text('Receipt Items',
                  style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              ..._receiptItems.map((item) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    leading: const Icon(Icons.check_circle_outline,
                        color: Colors.green),
                    title: Text(item.name),
                    trailing: Text(
                        CurrencyUtils.format(item.price,
                            currency: _currency),
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                  )),
            ],

            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }
}
