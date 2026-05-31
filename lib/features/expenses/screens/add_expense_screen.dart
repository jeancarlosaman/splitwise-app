import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/expenses_provider.dart';
import '../models/expense_category.dart';
import '../models/expense_participant.dart';
import '../models/receipt_item.dart';
import '../../groups/providers/groups_provider.dart';
import '../../groups/models/group_member.dart';
import '../../ocr/receipt_scanner.dart';
import '../../ocr/screens/receipt_review_screen.dart';
import '../../voice/voice_recorder.dart';
import '../../voice/ai_expense_parser.dart';
import '../../subscription/quota_service.dart';
import '../../subscription/screens/paywall_sheet.dart';
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

  /// Selected category — only shown in the form for personal expenses.
  /// Defaults to `other` so the user can save without picking one.
  ExpenseCategory _category = ExpenseCategory.other;

  /// Per-participant amount entries used when _splitType == 'by_amount'.
  /// Keyed by userId — value is the raw text the user typed (we parse on submit).
  final Map<String, TextEditingController> _customAmountCtrls = {};

  final _scanner = ReceiptScanner();
  final _voice = VoiceRecorder();
  bool _isListening = false;
  String _voiceTranscript = '';

  @override
  void initState() {
    super.initState();
    _voice.initialize();
    _paidByUserId = supabase.auth.currentUser?.id;

    // For personal groups, auto-include the current user as the sole
    // participant so submit doesn't fail the "select at least one" check.
    // The form will hide the split UI in this case (see build()).
    final myId = supabase.auth.currentUser?.id;
    if (myId != null) _participantIds.add(myId);
  }

  /// True if the group we're adding to is the user's auto-created personal
  /// group. Read off the groups cache rather than refetched — by the time
  /// we get here, groupsProvider is populated (we navigated from there).
  bool _isPersonalGroup(WidgetRef ref) {
    final groups = ref.watch(groupsProvider).value ?? const [];
    for (final g in groups) {
      if (g.id == widget.groupId) return g.isPersonal;
    }
    return false;
  }

  @override
  void dispose() {
    _descCtrl.dispose();
    _amountCtrl.dispose();
    _scanner.dispose();
    _voice.dispose();
    for (final c in _customAmountCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  /// Ensures there's a controller for every selected participant when the
  /// "By amount" split mode is active. Called any time the participant set
  /// or amount changes so the UI stays consistent.
  TextEditingController _amountCtrlFor(String userId) {
    return _customAmountCtrls.putIfAbsent(
        userId, () => TextEditingController());
  }

  /// Sum of all currently-entered custom amounts (used for live validation).
  double get _customAmountsSum {
    double total = 0;
    for (final id in _participantIds) {
      final raw = _customAmountCtrls[id]?.text ?? '';
      final v = double.tryParse(raw.replaceAll(',', '.'));
      if (v != null) total += v;
    }
    return total;
  }

  // ── OCR flow ──────────────────────────────────────────────────────────────
  Future<void> _scanReceipt({bool fromGallery = false}) async {
    // Quota check BEFORE prompting the camera — no point making the user
    // capture an image we're about to refuse to process.
    final quota = ref.read(quotaServiceProvider);
    final preCheck = await quota.check(QuotaFeature.ocrScan);
    if (!preCheck.canUse && mounted) {
      await showPaywallSheet(
          context: context, ref: ref, triggeredBy: QuotaFeature.ocrScan);
      return;
    }

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

      // Successful scan — log usage so the quota counter updates.
      await quota.record(QuotaFeature.ocrScan);
      ref.invalidate(quotaStateProvider(QuotaFeature.ocrScan));

      final members = ref.read(groupMembersProvider(widget.groupId)).value ?? [];

      // Use Navigator.push so we get the result back
      final result = await Navigator.of(context).push<List<ReceiptItem>>(
        MaterialPageRoute(
          builder: (_) => ReceiptReviewScreen(
            items: parsed.items,
            members: members,
            detectedTotal: parsed.total,
            rawOcrText: parsed.rawText,
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
      final transcript = await _voice.stopListening();
      setState(() => _isListening = false);
      await _applyVoiceResultWithAi(transcript);
    } else {
      final ok = await _voice.initialize(
        onError: (msg) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Mic error: $msg')));
            setState(() => _isListening = false);
          }
        },
      );
      if (!ok) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(
                  'Speech recognition not available. ${_voice.lastError.isNotEmpty ? "(${_voice.lastError})" : "Check mic + speech recognition permissions in iOS Settings."}')));
        }
        return;
      }
      setState(() {
        _isListening = true;
        _voiceTranscript = '';
      });
      await _voice.startListening(
        onResult: (text, _) => setState(() => _voiceTranscript = text),
      );
    }
  }

  Future<void> _applyVoiceResultWithAi(String transcript) async {
    // Quota check BEFORE the (paid) Claude API call.
    final quota = ref.read(quotaServiceProvider);
    final preCheck = await quota.check(QuotaFeature.voiceParse);
    if (!preCheck.canUse && mounted) {
      await showPaywallSheet(
          context: context, ref: ref, triggeredBy: QuotaFeature.voiceParse);
      return;
    }

    if (transcript.trim().isEmpty) {
      if (mounted) {
        // Give the user actionable diagnostics instead of just "no speech".
        final heardAudio = _voice.peakSoundLevel > 0;
        final locale = _voice.localeId ?? 'unknown';
        final errMsg = _voice.lastError;
        final reason = errMsg.isNotEmpty
            ? errMsg
            : heardAudio
                ? 'Heard audio but couldn\'t transcribe (locale: $locale). Try speaking more clearly or check that this locale is downloaded in iOS Settings > General > Keyboard > Dictation.'
                : 'No audio detected. Check mic permission in Settings > SplitWise.';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(reason),
          duration: const Duration(seconds: 6),
        ));
      }
      return;
    }

    setState(() => _isLoading = true);
    final members = ref.read(groupMembersProvider(widget.groupId)).value ?? [];
    final currentUser = supabase.auth.currentUser;
    final speakerName = members
            .firstWhere(
              (m) => m.user.id == currentUser?.id,
              orElse: () => members.isNotEmpty
                  ? members.first
                  : throw StateError('no members'),
            )
            .user
            .displayName;

    final parsed = await AiExpenseParser.parse(
      transcript: transcript,
      memberNames: members.map((m) => m.user.displayName).toList(),
      speakerName: speakerName,
      defaultCurrency: _currency,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    // Always keep the transcript visible so the user can see what was heard.
    _voiceTranscript = transcript;

    // Count this against the quota — even isEmpty AI responses count, because
    // they still cost a Claude API call.
    await quota.record(QuotaFeature.voiceParse);
    ref.invalidate(quotaStateProvider(QuotaFeature.voiceParse));

    if (parsed.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
            '${parsed.note ?? "Couldn\'t extract expense info"}\nHeard: "$transcript"'),
        duration: const Duration(seconds: 6),
      ));
      setState(() {});
      return;
    }

    // Track what the AI actually filled vs left blank so we can tell the user.
    final filled = <String>[];
    final missed = <String>[];

    if (parsed.amount != null) {
      _amountCtrl.text = parsed.amount!.toStringAsFixed(2);
      filled.add('amount');
    } else {
      missed.add('amount');
    }
    if (parsed.description != null && parsed.description!.isNotEmpty) {
      _descCtrl.text = parsed.description!;
      filled.add('description');
    }
    if (parsed.currency != null && parsed.currency!.length == 3) {
      _currency = parsed.currency!.toUpperCase();
    }

    // Resolve payer.
    if (parsed.payerName != null) {
      if (parsed.payerName!.toLowerCase() == 'me') {
        _paidByUserId = currentUser?.id;
        filled.add('payer (you)');
      } else {
        final match = _findMember(members, parsed.payerName!);
        if (match != null) {
          _paidByUserId = match.user.id;
          filled.add('payer (${match.user.displayName})');
        } else {
          missed.add('payer "${parsed.payerName}" (not in group)');
        }
      }
    }

    // Resolve participants. Empty list from AI = split with everyone.
    if (parsed.splitWithNames.isNotEmpty) {
      _participantIds.clear();
      final unmatched = <String>[];
      for (final name in parsed.splitWithNames) {
        final match = _findMember(members, name);
        if (match != null) {
          _participantIds.add(match.user.id);
        } else {
          unmatched.add(name);
        }
      }
      if (_participantIds.isNotEmpty) {
        filled.add('split (${_participantIds.length} people)');
      }
      if (unmatched.isNotEmpty) {
        missed.add('split with ${unmatched.join(", ")} (not in group)');
      }
    }

    if (parsed.splitMode == 'equal' || parsed.splitMode.isEmpty) {
      _splitType = 'equal';
    } else {
      // Non-equal modes aren't wired up to the UI yet — fall back to equal
      // but warn the user.
      _splitType = 'equal';
    }

    setState(() {});

    // Build a useful confirmation that shows what got filled and what didn't.
    final summary = StringBuffer();
    if (filled.isNotEmpty) summary.write('Filled: ${filled.join(", ")}.');
    if (missed.isNotEmpty) {
      if (summary.isNotEmpty) summary.write(' ');
      summary.write('Missing: ${missed.join(", ")}.');
    }
    if (parsed.note != null && parsed.note!.isNotEmpty) {
      if (summary.isNotEmpty) summary.write(' ');
      summary.write(parsed.note!);
    }
    if (summary.isEmpty) summary.write('Filled from voice.');

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('$summary\nHeard: "$transcript"'),
      duration: const Duration(seconds: 6),
    ));
  }

  GroupMember? _findMember(List<GroupMember> members, String spokenName) {
    final needle = spokenName.toLowerCase().trim();
    if (needle.isEmpty) return null;
    // Exact match first, then contains.
    for (final m in members) {
      if (m.user.displayName.toLowerCase() == needle) return m;
    }
    for (final m in members) {
      if (m.user.displayName.toLowerCase().contains(needle)) return m;
    }
    return null;
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
        // Only persist a category for personal expenses — shared expenses
        // don't surface it in the UI (yet), so leaving the column null
        // keeps the data clean.
        category: _isPersonalGroup(ref) ? _category.code : null,
      );

      final List<ExpenseParticipant> participants;
      if (_splitType == 'equal') {
        // Equal split, with a rounding-residual correction on the first
        // participant so the shares always sum to the exact amount (the
        // DB trigger rejects mismatches).
        final perRaw = amount / _participantIds.length;
        final per = double.parse(perRaw.toStringAsFixed(2));
        final ids = _participantIds.toList();
        final residual =
            double.parse((amount - per * ids.length).toStringAsFixed(2));
        participants = [
          for (int i = 0; i < ids.length; i++)
            ExpenseParticipant(
              id: '',
              expenseId: expense.id,
              userId: ids[i],
              shareAmount: i == 0 ? per + residual : per,
            ),
        ];
      } else if (_splitType == 'by_amount') {
        // Per-participant exact amounts. Validate sum == total first so we
        // give a clear error instead of letting the DB constraint do it.
        final shares = <String, double>{};
        for (final id in _participantIds) {
          final raw = _customAmountCtrls[id]?.text ?? '';
          final v = double.tryParse(raw.replaceAll(',', '.'));
          if (v == null || v < 0) {
            throw Exception(
                'Enter a valid amount for every participant (or remove them)');
          }
          shares[id] = double.parse(v.toStringAsFixed(2));
        }
        final sum = shares.values.fold<double>(0, (a, b) => a + b);
        if ((sum - amount).abs() > 0.01) {
          throw Exception(
              'Shares add up to ${sum.toStringAsFixed(2)} but the total is ${amount.toStringAsFixed(2)}');
        }
        participants = shares.entries
            .map((e) => ExpenseParticipant(
                id: '',
                expenseId: expense.id,
                userId: e.key,
                shareAmount: e.value))
            .toList();
      } else {
        // by_item — derive shares from receipt-item assignments.
        final shareMap = <String, double>{};
        for (final item in _receiptItems) {
          if (item.assignedTo.isEmpty) {
            final per = item.price / _participantIds.length;
            for (final id in _participantIds) {
              shareMap[id] = (shareMap[id] ?? 0) + per;
            }
          } else {
            final per = item.price / item.assignedTo.length;
            for (final id in item.assignedTo) {
              shareMap[id] = (shareMap[id] ?? 0) + per;
            }
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
          title: Text(_isPersonalGroup(ref) ? 'Log Expense' : 'Add Expense'),
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

            // ── Category (personal only) ─────────────────────
            // Shared expenses don't surface a category in the UI yet, so we
            // only show this picker for personal logging — feeds the
            // Categories tab in the personal group.
            if (_isPersonalGroup(ref)) ...[
              _SectionLabel(label: 'Category'),
              const SizedBox(height: 10),
              _CategoryPicker(
                value: _category,
                onChanged: (c) => setState(() => _category = c),
              ),
              const SizedBox(height: 24),
            ],

            // For personal groups (only the user is a member), "who paid",
            // "split type" and "split with" are meaningless — hide them and
            // submit silently with paid_by = me / participant = me.
            if (!_isPersonalGroup(ref)) ...[

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
                ButtonSegment(value: 'by_amount', label: Text('By Amount'),
                    icon: Icon(Icons.tune_rounded, size: 16)),
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
            if (_splitType == 'by_amount')
              _ByAmountParticipants(
                members: members,
                participantIds: _participantIds,
                amountCtrlFor: _amountCtrlFor,
                totalCtrl: _amountCtrl,
                currency: _currency,
                onToggle: (userId) {
                  setState(() {
                    if (_participantIds.contains(userId)) {
                      _participantIds.remove(userId);
                    } else {
                      _participantIds.add(userId);
                    }
                  });
                },
                onAmountChanged: () => setState(() {}),
                runningSum: _customAmountsSum,
              )
            else
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

            ], // end !_isPersonalGroup block

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

// ── Category picker (personal expenses) ───────────────────────────────────
class _CategoryPicker extends StatelessWidget {
  final ExpenseCategory value;
  final ValueChanged<ExpenseCategory> onChanged;
  const _CategoryPicker({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: ExpenseCategory.values.map((c) {
        final selected = c == value;
        return Material(
          color: selected
              ? c.color.withValues(alpha: 0.18)
              : AppTheme.surface,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => onChanged(c),
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: selected
                        ? c.color.withValues(alpha: 0.6)
                        : AppTheme.border,
                    width: 1),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(c.emoji, style: const TextStyle(fontSize: 16)),
                  const SizedBox(width: 8),
                  Text(c.label,
                      style: TextStyle(
                          color: selected
                              ? AppTheme.textPrimary
                              : AppTheme.textSecondary,
                          fontWeight: FontWeight.w600,
                          fontSize: 13)),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ── By-amount participant list ────────────────────────────────────────────
/// Stack of rows: avatar + name + amount input. When the total controller
/// changes (user retypes the expense amount), the green "remaining" pill
/// updates live so the user can see how much is still unaccounted for.
class _ByAmountParticipants extends StatelessWidget {
  final List<GroupMember> members;
  final Set<String> participantIds;
  final TextEditingController Function(String userId) amountCtrlFor;
  final TextEditingController totalCtrl;
  final String currency;
  final void Function(String userId) onToggle;
  final VoidCallback onAmountChanged;
  final double runningSum;

  const _ByAmountParticipants({
    required this.members,
    required this.participantIds,
    required this.amountCtrlFor,
    required this.totalCtrl,
    required this.currency,
    required this.onToggle,
    required this.onAmountChanged,
    required this.runningSum,
  });

  @override
  Widget build(BuildContext context) {
    final total = double.tryParse(totalCtrl.text.replaceAll(',', '.')) ?? 0;
    final remaining = total - runningSum;
    final exact = remaining.abs() < 0.01;
    final over = remaining < -0.01;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Sum / remaining banner
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: exact
                ? const Color(0xFF0A1F18)
                : over
                    ? const Color(0xFF1F0A0A)
                    : AppTheme.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: exact
                    ? AppTheme.green.withValues(alpha: 0.4)
                    : over
                        ? AppTheme.negative.withValues(alpha: 0.4)
                        : AppTheme.border,
                width: 1),
          ),
          child: Row(
            children: [
              Icon(
                exact
                    ? Icons.check_circle_rounded
                    : over
                        ? Icons.warning_amber_rounded
                        : Icons.calculate_rounded,
                size: 16,
                color: exact
                    ? AppTheme.green
                    : over
                        ? AppTheme.negative
                        : AppTheme.textSecondary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  exact
                      ? 'Splits add up to the total'
                      : over
                          ? '${CurrencyUtils.format(remaining.abs(), currency: currency)} over total'
                          : '${CurrencyUtils.format(remaining, currency: currency)} left to assign',
                  style: TextStyle(
                    color: exact
                        ? AppTheme.green
                        : over
                            ? AppTheme.negative
                            : AppTheme.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                CurrencyUtils.format(runningSum, currency: currency),
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Text(' / ',
                  style: TextStyle(color: AppTheme.textSecondary)),
              Text(
                CurrencyUtils.format(total, currency: currency),
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Per-member rows
        ...members.map((m) {
          final selected = participantIds.contains(m.user.id);
          final ctrl = amountCtrlFor(m.user.id);
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: selected ? AppTheme.surface : AppTheme.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: selected
                        ? AppTheme.green.withValues(alpha: 0.35)
                        : AppTheme.border,
                    width: 1),
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => onToggle(m.user.id),
                    behavior: HitTestBehavior.opaque,
                    child: Row(
                      children: [
                        Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            color: selected
                                ? AppTheme.green
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(7),
                            border: Border.all(
                                color: selected
                                    ? AppTheme.green
                                    : AppTheme.border,
                                width: 1.5),
                          ),
                          child: selected
                              ? const Icon(Icons.check_rounded,
                                  size: 14, color: Colors.black)
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Text(m.user.displayName,
                            style: const TextStyle(
                                color: AppTheme.textPrimary,
                                fontWeight: FontWeight.w600,
                                fontSize: 14)),
                      ],
                    ),
                  ),
                  const Spacer(),
                  SizedBox(
                    width: 120,
                    child: TextField(
                      controller: ctrl,
                      enabled: selected,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      textAlign: TextAlign.right,
                      onChanged: (_) => onAmountChanged(),
                      style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 14),
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: selected ? '0.00' : '—',
                        hintStyle:
                            const TextStyle(color: AppTheme.textSecondary),
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        filled: true,
                        fillColor: AppTheme.surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(
                              color: AppTheme.border, width: 0.5),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(
                              color: AppTheme.border, width: 0.5),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(
                              color: AppTheme.green, width: 1.5),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),

        // Quick-action: split the remainder equally between selected
        if (!exact && participantIds.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                icon: const Icon(Icons.balance_rounded, size: 16),
                label: const Text('Split remainder equally'),
                onPressed: () {
                  final per = remaining / participantIds.length;
                  for (final id in participantIds) {
                    final c = amountCtrlFor(id);
                    final current = double.tryParse(
                            c.text.replaceAll(',', '.')) ??
                        0;
                    c.text = (current + per).toStringAsFixed(2);
                  }
                  onAmountChanged();
                },
              ),
            ),
          ),
      ],
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
