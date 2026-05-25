import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../auth/providers/auth_provider.dart';
import '../../groups/models/group_member.dart';
import '../../groups/providers/groups_provider.dart';
import '../../ocr/receipt_scanner.dart';
import '../../ocr/receipt_parser.dart';
import '../../ocr/screens/receipt_review_screen.dart';
import '../../voice/voice_recorder.dart';
import '../../voice/expense_nlp_parser.dart';
import '../models/receipt_item.dart';
import '../providers/expenses_provider.dart';
import '../../../core/constants.dart';
import '../../../core/utils/currency_utils.dart';
import '../../../shared/widgets/amount_input.dart';
import '../../../shared/widgets/loading_overlay.dart';
import '../../../shared/widgets/user_avatar.dart';

class AddExpenseScreen extends ConsumerStatefulWidget {
  const AddExpenseScreen({super.key, required this.groupId});

  final String groupId;

  @override
  ConsumerState<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends ConsumerState<AddExpenseScreen> {
  final _formKey      = GlobalKey<FormState>();
  final _descCtrl     = TextEditingController();
  final _amountCtrl   = TextEditingController();

  String   _currency    = AppConstants.defaultCurrency;
  String   _splitType   = AppConstants.splitEqual;
  bool     _isLoading   = false;
  File?    _receiptImage;

  // Whom paid & who splits
  String?               _paidByUserId;
  Set<String>           _selectedParticipantIds = {};
  List<GroupMember>     _members = [];

  // OCR-sourced items (shown as optional checklist)
  List<ReceiptItem>     _receiptItems = [];

  // Voice recorder state
  bool   _isRecording   = false;
  String _voiceStatus   = '';

  late final VoiceRecorder _voiceRecorder;

  @override
  void initState() {
    super.initState();
    _voiceRecorder = VoiceRecorder();
    _initMembers();
  }

  Future<void> _initMembers() async {
    final membersAsync = ref.read(groupMembersProvider(widget.groupId));
    final members = membersAsync.valueOrNull ?? [];
    final currentUserId = ref.read(currentUserIdProvider);

    setState(() {
      _members = members;
      _paidByUserId = currentUserId;
      _selectedParticipantIds = members.map((m) => m.user.id).toSet();
    });
  }

  @override
  void dispose() {
    _descCtrl.dispose();
    _amountCtrl.dispose();
    _voiceRecorder.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────
  // OCR Flow
  // ─────────────────────────────────────────

  Future<void> _launchOcrFlow() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
    );
    if (pickedFile == null || !mounted) return;

    setState(() => _isLoading = true);

    try {
      final imageFile = File(pickedFile.path);
      final rawText   = await ReceiptScanner.scanImage(imageFile);
      final parsed    = ReceiptParser.parse(rawText);

      if (!mounted) return;
      setState(() => _isLoading = false);

      // Navigate to review screen
      final approved = await Navigator.of(context).push<ParsedReceipt>(
        MaterialPageRoute(
          builder: (_) => ReceiptReviewScreen(
            parsed:  parsed,
            members: _members,
          ),
        ),
      );

      if (approved == null || !mounted) return;

      // Pre-fill form
      setState(() {
        _receiptImage = imageFile;
        if (approved.total != null && _amountCtrl.text.isEmpty) {
          _amountCtrl.text =
              approved.total!.toStringAsFixed(2).replaceAll('.', ',');
        }
        if (approved.merchant != null && _descCtrl.text.isEmpty) {
          _descCtrl.text = approved.merchant!;
        }
        _receiptItems = approved.selectedItems;
        _splitType    = AppConstants.splitByItem;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('OCR failed: $e')),
        );
      }
    }
  }

  // ─────────────────────────────────────────
  // Voice Flow
  // ─────────────────────────────────────────

  Future<void> _toggleVoiceRecording() async {
    if (_isRecording) {
      setState(() {
        _isRecording = false;
        _voiceStatus = 'Processing…';
      });
      final transcript = await _voiceRecorder.stopListening();
      if (transcript.isEmpty) {
        setState(() => _voiceStatus = 'Nothing heard. Try again.');
        return;
      }

      final parsed = ExpenseNlpParser.parse(
        transcript: transcript,
        members: _members,
      );

      setState(() {
        _voiceStatus = 'Understood: "$transcript"';
        if (parsed.amount != null) {
          _amountCtrl.text =
              parsed.amount!.toStringAsFixed(2).replaceAll('.', ',');
        }
        if (parsed.description != null && _descCtrl.text.isEmpty) {
          _descCtrl.text = parsed.description!;
        }
        if (parsed.payerUserId != null) {
          _paidByUserId = parsed.payerUserId;
        }
        if (parsed.participantUserIds.isNotEmpty) {
          _selectedParticipantIds = Set.from(parsed.participantUserIds);
        }
      });
    } else {
      final available = await _voiceRecorder.initialize();
      if (!available) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Microphone not available')),
        );
        return;
      }
      setState(() {
        _isRecording = true;
        _voiceStatus = 'Listening…';
      });
      await _voiceRecorder.startListening();
    }
  }

  // ─────────────────────────────────────────
  // Submit
  // ─────────────────────────────────────────

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_paidByUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select who paid')),
      );
      return;
    }
    if (_selectedParticipantIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least one participant')),
      );
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _isLoading = true);

    try {
      final rawAmount = _amountCtrl.text.replaceAll(',', '.');
      final amount    = double.parse(rawAmount);
      final createdBy = ref.read(currentUserIdProvider)!;

      // Compute share amounts
      List<({String userId, double shareAmount})> participants;

      if (_splitType == AppConstants.splitByItem && _receiptItems.isNotEmpty) {
        // By-item: sum each person's assigned items
        final totals = <String, double>{};
        for (final item in _receiptItems.where((i) => i.isSelected)) {
          if (item.assignedTo.isEmpty) {
            // Distribute equally among selected participants
            final each = item.price / _selectedParticipantIds.length;
            for (final id in _selectedParticipantIds) {
              totals[id] = (totals[id] ?? 0) + each;
            }
          } else {
            final each = item.price / item.assignedTo.length;
            for (final id in item.assignedTo) {
              totals[id] = (totals[id] ?? 0) + each;
            }
          }
        }
        participants = totals.entries
            .map((e) => (userId: e.key, shareAmount: e.value))
            .toList();
      } else {
        // Equal split
        final share = amount / _selectedParticipantIds.length;
        participants = _selectedParticipantIds
            .map((id) => (
                  userId:      id,
                  shareAmount: (share * 100).round() / 100,
                ))
            .toList();
      }

      await ref.read(groupExpensesProvider(widget.groupId).notifier).addExpense(
            description:     _descCtrl.text.trim(),
            amount:          amount,
            currency:        _currency,
            paidByUserId:    _paidByUserId!,
            createdByUserId: createdBy,
            splitType:       _splitType,
            participants:    participants,
            receiptImage:    _receiptImage,
            receiptItems:    _receiptItems.where((i) => i.isSelected).toList(),
          );

      if (mounted) context.pop();
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save expense: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  // ─────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final membersAsync = ref.watch(groupMembersProvider(widget.groupId));
    final cs = Theme.of(context).colorScheme;

    // Sync members when loaded
    membersAsync.whenData((members) {
      if (_members.isEmpty && members.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _initMembers());
      }
    });

    return LoadingOverlay(
      isLoading: _isLoading,
      message: 'Saving expense…',
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Add Expense'),
          actions: [
            // OCR button
            IconButton(
              icon: const Icon(Icons.document_scanner_outlined),
              tooltip: 'Scan receipt',
              onPressed: _launchOcrFlow,
            ),
            // Voice button
            IconButton(
              icon: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: _isRecording
                    ? const Icon(Icons.stop_circle_outlined, key: ValueKey('stop'))
                    : const Icon(Icons.mic_outlined, key: ValueKey('mic')),
              ),
              tooltip: _isRecording ? 'Stop recording' : 'Voice entry',
              onPressed: _toggleVoiceRecording,
            ),
          ],
        ),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              // Voice status banner
              if (_voiceStatus.isNotEmpty)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.only(bottom: 16),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: _isRecording
                        ? cs.errorContainer
                        : cs.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _isRecording
                            ? Icons.graphic_eq_rounded
                            : Icons.check_circle_outline_rounded,
                        color: _isRecording
                            ? cs.onErrorContainer
                            : cs.onPrimaryContainer,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _voiceStatus,
                          style: TextStyle(
                            color: _isRecording
                                ? cs.onErrorContainer
                                : cs.onPrimaryContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // Description
              TextFormField(
                controller: _descCtrl,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  hintText: 'e.g. Dinner at Trattoria, Groceries',
                  prefixIcon: Icon(Icons.edit_outlined),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Enter a description';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Amount + currency row
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: AmountInput(
                      controller: _amountCtrl,
                      currency: _currency,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: CurrencySelector(
                      value: _currency,
                      onChanged: (v) {
                        if (v != null) setState(() => _currency = v);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Paid by
              Text('Paid by', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              membersAsync.when(
                loading: () => const CircularProgressIndicator(),
                error: (_, __) => const Text('Failed to load members'),
                data: (members) => Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: members.map((m) {
                    final selected = _paidByUserId == m.user.id;
                    return ChoiceChip(
                      avatar: UserAvatar(user: m.user, radius: 12),
                      label: Text(m.user.name),
                      selected: selected,
                      onSelected: (_) =>
                          setState(() => _paidByUserId = m.user.id),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 20),

              // Participants
              Text('Split with', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              membersAsync.when(
                loading: () => const CircularProgressIndicator(),
                error: (_, __) => const Text('Failed to load members'),
                data: (members) => Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: members.map((m) {
                    final selected = _selectedParticipantIds.contains(m.user.id);
                    return FilterChip(
                      avatar: UserAvatar(user: m.user, radius: 12),
                      label: Text(m.user.name),
                      selected: selected,
                      onSelected: (val) {
                        setState(() {
                          if (val) {
                            _selectedParticipantIds.add(m.user.id);
                          } else {
                            _selectedParticipantIds.remove(m.user.id);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 20),

              // Split type
              Text('Split type', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(
                    value: 'equal',
                    label: Text('Equal'),
                    icon: Icon(Icons.balance_rounded, size: 16),
                  ),
                  ButtonSegment(
                    value: 'by_item',
                    label: Text('By item'),
                    icon: Icon(Icons.list_alt_rounded, size: 16),
                  ),
                  ButtonSegment(
                    value: 'custom',
                    label: Text('Custom'),
                    icon: Icon(Icons.tune_rounded, size: 16),
                  ),
                ],
                selected: {_splitType},
                onSelectionChanged: (s) =>
                    setState(() => _splitType = s.first),
              ),
              const SizedBox(height: 20),

              // Receipt image preview
              if (_receiptImage != null) ...[
                Text('Receipt', style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(
                    _receiptImage!,
                    height: 160,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // OCR items checklist
              if (_receiptItems.isNotEmpty) ...[
                Text(
                  'Receipt Items',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: 4),
                ..._receiptItems.asMap().entries.map(
                  (entry) {
                    final i    = entry.key;
                    final item = entry.value;
                    return CheckboxListTile(
                      value: item.isSelected,
                      onChanged: (val) => setState(() {
                        _receiptItems[i] =
                            item.copyWith(isSelected: val ?? false);
                      }),
                      title: Text(item.name),
                      secondary: Text(
                        CurrencyUtils.formatCompact(item.price, _currency),
                        style:
                            const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      dense: true,
                      controlAffinity: ListTileControlAffinity.leading,
                    );
                  },
                ),
                const SizedBox(height: 8),
              ],

              const SizedBox(height: 16),

              FilledButton.icon(
                onPressed: _isLoading ? null : _submit,
                icon: const Icon(Icons.save_rounded),
                label: const Text('Save Expense'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
