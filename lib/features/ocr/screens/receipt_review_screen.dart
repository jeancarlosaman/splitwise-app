import 'package:flutter/material.dart';

import '../../expenses/models/receipt_item.dart';
import '../../groups/models/group_member.dart';
import '../../../core/utils/currency_utils.dart';
import '../../../core/theme.dart';
import '../../../shared/widgets/user_avatar.dart';

/// Redesigned receipt review: clean card list, slide-up member assignment.
class ReceiptReviewScreen extends StatefulWidget {
  final List<ReceiptItem> items;
  final List<GroupMember> members;
  final double? detectedTotal;

  const ReceiptReviewScreen({
    super.key,
    required this.items,
    required this.members,
    this.detectedTotal,
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
          if (_included[i]) _items[i].price
      ].fold(0.0, (a, b) => a + b);

  int get _selectedCount => _included.where((v) => v).length;

  void _toggleMember(int idx, String userId) {
    setState(() {
      final current = List<String>.from(_items[idx].assignedTo);
      current.contains(userId)
          ? current.remove(userId)
          : current.add(userId);
      _items[idx] = _items[idx].copyWith(assignedTo: current);
    });
  }

  void _showAssignSheet(int idx) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _items[idx].name,
                style: const TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 17),
              ),
              Text(
                CurrencyUtils.format(_items[idx].price),
                style: const TextStyle(
                    color: AppTheme.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 15),
              ),
              const SizedBox(height: 16),
              const Text('Assign to:',
                  style: TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 13)),
              const SizedBox(height: 12),
              ...widget.members.map((m) {
                final assigned =
                    _items[idx].assignedTo.contains(m.user.id);
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: UserAvatar(user: m.user, radius: 20),
                  title: Text(m.user.displayName,
                      style: const TextStyle(fontWeight: FontWeight.w500)),
                  trailing: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      gradient: assigned
                          ? AppTheme.primaryGradient
                          : null,
                      border: assigned
                          ? null
                          : Border.all(color: Colors.grey.shade400),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: assigned
                        ? const Icon(Icons.check_rounded,
                            color: Colors.white, size: 16)
                        : null,
                  ),
                  onTap: () {
                    _toggleMember(idx, m.user.id);
                    setSheet(() {});
                  },
                );
              }),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.primary),
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
        if (_included[i]) _items[i]
    ];
    Navigator.pop(context, result);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('Receipt')),
      body: Column(
        children: [
          // ── Summary banner ────────────────────────────────────
          Container(
            margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primary.withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                const Icon(Icons.receipt_long_rounded,
                    color: Colors.white70, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '$_selectedCount item${_selectedCount == 1 ? '' : 's'} selected',
                    style: const TextStyle(
                        color: Colors.white70, fontSize: 14),
                  ),
                ),
                Text(
                  CurrencyUtils.format(_selectedTotal),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 20,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // ── Hint ─────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: Row(
              children: [
                Icon(Icons.touch_app_rounded,
                    size: 14,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.4)),
                const SizedBox(width: 6),
                Text(
                  'Tap an item to assign it to members',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withOpacity(0.4),
                      ),
                ),
              ],
            ),
          ),

          // ── Items list ────────────────────────────────────────
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
              itemCount: _items.length,
              itemBuilder: (context, i) {
                final item = _items[i];
                final included = _included[i];
                final assignedNames = item.assignedTo
                    .map((id) => widget.members
                        .firstWhere((m) => m.user.id == id,
                            orElse: () => throw '')
                        .user
                        .displayName)
                    .join(', ');

                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Material(
                    color: isDark ? AppTheme.cardDark : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: included ? () => _showAssignSheet(i) : null,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        child: Row(
                          children: [
                            // Checkbox
                            GestureDetector(
                              onTap: () =>
                                  setState(() => _included[i] = !included),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                width: 26,
                                height: 26,
                                decoration: BoxDecoration(
                                  gradient: included
                                      ? AppTheme.primaryGradient
                                      : null,
                                  border: included
                                      ? null
                                      : Border.all(
                                          color: Colors.grey.shade400,
                                          width: 1.5),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: included
                                    ? const Icon(Icons.check_rounded,
                                        color: Colors.white, size: 16)
                                    : null,
                              ),
                            ),
                            const SizedBox(width: 14),
                            // Name + assignees
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.name,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 15,
                                      decoration: included
                                          ? null
                                          : TextDecoration.lineThrough,
                                      color: included
                                          ? null
                                          : Theme.of(context)
                                              .colorScheme
                                              .onSurface
                                              .withOpacity(0.4),
                                    ),
                                  ),
                                  if (included &&
                                      assignedNames.isNotEmpty) ...[
                                    const SizedBox(height: 3),
                                    Text(
                                      assignedNames,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: AppTheme.primary
                                            .withOpacity(0.8),
                                      ),
                                    ),
                                  ] else if (included &&
                                      widget.members.isNotEmpty) ...[
                                    const SizedBox(height: 3),
                                    Text(
                                      'Tap to assign →',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface
                                            .withOpacity(0.35),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            // Price
                            Text(
                              CurrencyUtils.format(item.price),
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                                color: included
                                    ? AppTheme.primary
                                    : Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withOpacity(0.3),
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
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: GradientButton(
            label:
                'Use $_selectedCount Items  ·  ${CurrencyUtils.format(_selectedTotal)}',
            icon: Icons.check_rounded,
            onPressed: _selectedCount > 0 ? _confirm : null,
          ),
        ),
      ),
    );
  }
}
