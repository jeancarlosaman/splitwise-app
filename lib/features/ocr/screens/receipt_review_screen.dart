import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../expenses/models/receipt_item.dart';
import '../../groups/models/group_member.dart';
import '../../../core/utils/currency_utils.dart';
import '../../../core/theme.dart';
import '../../../shared/widgets/user_avatar.dart';

class ReceiptReviewScreen extends StatefulWidget {
  final List<ReceiptItem> items;
  final List<GroupMember> members;
  final double? detectedTotal;

  /// Raw OCR text from ML Kit. Shown in a debug panel at the bottom of
  /// the review screen so the user can paste it back when item-name
  /// extraction misbehaves, which is the only reliable way to fix parser
  /// edge cases without owning the actual receipt photo.
  final String rawOcrText;

  const ReceiptReviewScreen({
    super.key,
    required this.items,
    required this.members,
    this.detectedTotal,
    this.rawOcrText = '',
  });

  @override
  State<ReceiptReviewScreen> createState() => _ReceiptReviewScreenState();
}

class _ReceiptReviewScreenState extends State<ReceiptReviewScreen> {
  late List<ReceiptItem> _items;
  late List<bool> _included;

  @override
  void initState() {
    super.initState();
    _items = List.from(widget.items);
    _included = List.filled(widget.items.length, true);
  }

  double get _selectedTotal => [
        for (var i = 0; i < _items.length; i++)
          if (_included[i]) _items[i].price,
      ].fold<double>(0.0, (a, b) => a + b);

  int get _selectedCount => _included.where((v) => v).length;

  /// Inline rename for items whose OCR'd name came out as "Item" or wrong.
  /// Opens a small dialog with the current name pre-filled.
  Future<void> _renameItem(int idx) async {
    final ctrl = TextEditingController(text: _items[idx].name);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.ink,
        title: const Text('Rename item',
            style: TextStyle(color: AppTheme.textPrimary)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: const TextStyle(color: AppTheme.textPrimary),
          decoration: const InputDecoration(
              hintText: 'Item name', prefixIcon: Icon(Icons.label_outline)),
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text),
              child: const Text('Save')),
        ],
      ),
    );
    if (result != null && result.trim().isNotEmpty && mounted) {
      setState(() {
        _items[idx] = _items[idx].copyWith(name: result.trim());
      });
    }
  }

  void _toggleMember(int idx, String userId) {
    setState(() {
      final current = List<String>.from(_items[idx].assignedTo);
      current.contains(userId) ? current.remove(userId) : current.add(userId);
      _items[idx] = _items[idx].copyWith(assignedTo: current);
    });
  }

  // Safe helper — returns empty string if member not found
  String _namesFor(int idx) {
    return _items[idx]
        .assignedTo
        .map((id) {
          try {
            return widget.members.firstWhere((m) => m.user.id == id).user.displayName;
          } catch (_) {
            return null;
          }
        })
        .whereType<String>()
        .join(', ');
  }

  void _showAssignSheet(int idx) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.fromLTRB(
              20, 16, 20, MediaQuery.of(ctx).viewInsets.bottom + 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 36, height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // Item name + price
              Row(
                children: [
                  Expanded(
                    child: Text(_items[idx].name,
                      style: const TextStyle(color: AppTheme.textPrimary,
                          fontWeight: FontWeight.w700, fontSize: 17)),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppTheme.greenSubtle,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.green.withOpacity(0.3)),
                    ),
                    child: Text(CurrencyUtils.format(_items[idx].price),
                      style: const TextStyle(color: AppTheme.green,
                          fontWeight: FontWeight.w700, fontSize: 15)),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Text('Assign to members:',
                style: TextStyle(color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w600, fontSize: 13)),
              const SizedBox(height: 12),
              if (widget.members.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text('No members in this group yet.',
                      style: TextStyle(color: AppTheme.textSecondary)),
                )
              else
                ...widget.members.map((m) {
                  final assigned = _items[idx].assignedTo.contains(m.user.id);
                  return Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () {
                        _toggleMember(idx, m.user.id);
                        setSheet(() {});
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                        child: Row(
                          children: [
                            UserAvatar(user: m.user, radius: 20),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(m.user.displayName,
                                style: const TextStyle(color: AppTheme.textPrimary,
                                    fontWeight: FontWeight.w500, fontSize: 15)),
                            ),
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              width: 26, height: 26,
                              decoration: BoxDecoration(
                                color: assigned ? AppTheme.green : Colors.transparent,
                                border: Border.all(
                                  color: assigned ? AppTheme.green : AppTheme.border,
                                  width: 1.5,
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: assigned
                                  ? const Icon(Icons.check_rounded, color: Colors.black, size: 16)
                                  : null,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Done'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirm() {
    final result = [
      for (var i = 0; i < _items.length; i++)
        if (_included[i]) _items[i],
    ];
    Navigator.pop(context, result);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.black,
      appBar: AppBar(
        title: const Text('Review Receipt'),
        actions: [
          if (widget.detectedTotal != null)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppTheme.greenSubtle,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.green.withOpacity(0.3)),
                  ),
                  child: Text(
                    'Total: ${CurrencyUtils.format(widget.detectedTotal!)}',
                    style: const TextStyle(color: AppTheme.green,
                        fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // ── Summary banner ──────────────────────────────────
          Container(
            margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: AppTheme.greenSubtle,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppTheme.green.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.receipt_long_rounded, color: AppTheme.green, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '$_selectedCount item${_selectedCount == 1 ? '' : 's'} selected',
                    style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14),
                  ),
                ),
                Text(
                  CurrencyUtils.format(_selectedTotal),
                  style: const TextStyle(color: AppTheme.green,
                      fontWeight: FontWeight.w800, fontSize: 20),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),

          // ── Hint ────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
            child: Row(
              children: [
                const Icon(Icons.touch_app_rounded, size: 14, color: AppTheme.textSecondary),
                const SizedBox(width: 6),
                const Text('Tap an item to assign it to members',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
              ],
            ),
          ),

          // ── Items list ───────────────────────────────────────
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
              itemCount: _items.length,
              itemBuilder: (context, i) {
                final item = _items[i];
                final included = _included[i];
                final assignedNames = _namesFor(i);

                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Material(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: included ? () => _showAssignSheet(i) : null,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: included ? AppTheme.border : AppTheme.border.withOpacity(0.3),
                            width: 0.5,
                          ),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        child: Row(
                          children: [
                            // Checkbox
                            GestureDetector(
                              onTap: () => setState(() => _included[i] = !included),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                width: 26, height: 26,
                                decoration: BoxDecoration(
                                  color: included ? AppTheme.green : Colors.transparent,
                                  border: Border.all(
                                    color: included ? AppTheme.green : AppTheme.border,
                                    width: 1.5,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: included
                                    ? const Icon(Icons.check_rounded, color: Colors.black, size: 16)
                                    : null,
                              ),
                            ),
                            const SizedBox(width: 14),
                            // Name (tap to rename) + assignees
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onTap: included
                                        ? () => _renameItem(i)
                                        : null,
                                    child: Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            item.name,
                                            style: TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 15,
                                              color: included
                                                  ? AppTheme.textPrimary
                                                  : AppTheme.textSecondary,
                                              decoration: included
                                                  ? null
                                                  : TextDecoration.lineThrough,
                                              decorationColor:
                                                  AppTheme.textSecondary,
                                            ),
                                          ),
                                        ),
                                        if (included) ...[
                                          const SizedBox(width: 6),
                                          Icon(Icons.edit_rounded,
                                              size: 13,
                                              color: AppTheme.textSecondary
                                                  .withValues(alpha: 0.5)),
                                        ],
                                      ],
                                    ),
                                  ),
                                  if (included && assignedNames.isNotEmpty) ...[
                                    const SizedBox(height: 3),
                                    Text(assignedNames,
                                      style: const TextStyle(
                                          fontSize: 12, color: AppTheme.green)),
                                  ] else if (included && widget.members.isNotEmpty) ...[
                                    const SizedBox(height: 3),
                                    const Text('Tap to assign →',
                                      style: TextStyle(
                                          fontSize: 12, color: AppTheme.textSecondary)),
                                  ],
                                ],
                              ),
                            ),
                            // Price
                            Text(
                              CurrencyUtils.format(item.price),
                              style: TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 15,
                                color: included ? AppTheme.green : AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // ── Debug: show raw OCR text so the user can paste it back when
          //         item-name extraction misses. Foldable so it doesn't take
          //         up space until you tap to expand. ─────────────────────
          if (widget.rawOcrText.isNotEmpty)
            _OcrDebugPanel(rawText: widget.rawOcrText),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: GradientButton(
            label: 'Use $_selectedCount Items  ·  ${CurrencyUtils.format(_selectedTotal)}',
            icon: Icons.check_rounded,
            onPressed: _selectedCount > 0 ? _confirm : null,
          ),
        ),
      ),
    );
  }
}

/// Expandable panel at the bottom of the review screen showing the raw
/// ML Kit OCR text. Hidden by default. Tap to expand, then "Copy" to grab
/// the text — paste it back in chat so we can improve the parser for the
/// specific receipt format that's failing.
class _OcrDebugPanel extends StatefulWidget {
  final String rawText;
  const _OcrDebugPanel({required this.rawText});

  @override
  State<_OcrDebugPanel> createState() => _OcrDebugPanelState();
}

class _OcrDebugPanelState extends State<_OcrDebugPanel> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => setState(() => _open = !_open),
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  const Icon(Icons.bug_report_outlined,
                      color: AppTheme.textSecondary, size: 16),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text('Raw OCR text (debug)',
                        style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600)),
                  ),
                  if (_open)
                    GestureDetector(
                      onTap: () async {
                        await Clipboard.setData(
                            ClipboardData(text: widget.rawText));
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('OCR text copied'),
                                  duration: Duration(seconds: 2)));
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.greenSubtle,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.copy_rounded,
                                color: AppTheme.green, size: 12),
                            SizedBox(width: 4),
                            Text('Copy',
                                style: TextStyle(
                                    color: AppTheme.green,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(width: 6),
                  Icon(
                      _open
                          ? Icons.expand_less_rounded
                          : Icons.expand_more_rounded,
                      color: AppTheme.textSecondary,
                      size: 18),
                ],
              ),
            ),
          ),
          if (_open)
            Container(
              constraints: const BoxConstraints(maxHeight: 200),
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
              child: SingleChildScrollView(
                child: SelectableText(
                  widget.rawText,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 11,
                    fontFamily: 'monospace',
                    height: 1.4,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
