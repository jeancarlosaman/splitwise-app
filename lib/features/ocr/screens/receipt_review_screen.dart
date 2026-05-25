import 'package:flutter/material.dart';

import '../receipt_parser.dart';
import '../../groups/models/group_member.dart';
import '../../expenses/models/receipt_item.dart';
import '../../../core/utils/currency_utils.dart';

/// Shows the parsed receipt items for the user to review, select, and
/// optionally assign to group members.  Returns a [ParsedReceipt] with
/// [selectedItems] populated when the user confirms.
class ReceiptReviewScreen extends StatefulWidget {
  const ReceiptReviewScreen({
    super.key,
    required this.parsed,
    required this.members,
  });

  final ParsedReceipt parsed;
  final List<GroupMember> members;

  @override
  State<ReceiptReviewScreen> createState() => _ReceiptReviewScreenState();
}

class _ReceiptReviewScreenState extends State<ReceiptReviewScreen> {
  late List<ReceiptItem> _items;
  late double? _manualTotal;

  @override
  void initState() {
    super.initState();
    // All items start selected
    _items = widget.parsed.items
        .map((item) => item.copyWith(isSelected: true))
        .toList();
    _manualTotal = widget.parsed.total;
  }

  double get _selectedTotal =>
      _items.where((i) => i.isSelected).fold(0.0, (acc, i) => acc + i.price);

  void _toggleItem(int index, bool? selected) {
    setState(() {
      _items[index] = _items[index].copyWith(isSelected: selected ?? false);
    });
  }

  void _assignMember(int index, String userId, bool add) {
    final item    = _items[index];
    final current = List<String>.from(item.assignedTo);
    if (add) {
      if (!current.contains(userId)) current.add(userId);
    } else {
      current.remove(userId);
    }
    setState(() {
      _items[index] = item.copyWith(assignedTo: current);
    });
  }

  void _confirm() {
    final selected = _items.where((i) => i.isSelected).toList();
    final result = widget.parsed.copyWith(
      selectedItems: selected,
      total: _manualTotal ?? _selectedTotal,
    );
    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Review Receipt'),
        actions: [
          TextButton(
            onPressed: _confirm,
            child: const Text('Use'),
          ),
        ],
      ),
      body: Column(
        children: [
          // Merchant header
          if (widget.parsed.merchant != null)
            Container(
              width: double.infinity,
              color: cs.primaryContainer,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: [
                  const Icon(Icons.storefront_outlined, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.parsed.merchant!,
                      style: tt.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: cs.onPrimaryContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Items list
          Expanded(
            child: _items.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_off_rounded,
                            size: 48,
                            color: cs.onSurfaceVariant.withValues(alpha: 0.5)),
                        const SizedBox(height: 12),
                        Text(
                          'No items detected.\nTry a clearer photo.',
                          textAlign: TextAlign.center,
                          style: tt.bodyMedium
                              ?.copyWith(color: cs.onSurfaceVariant),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    itemCount: _items.length,
                    separatorBuilder: (_, __) =>
                        const Divider(height: 1, indent: 16),
                    itemBuilder: (context, index) =>
                        _ItemRow(
                          item:     _items[index],
                          members:  widget.members,
                          onToggle: (val) => _toggleItem(index, val),
                          onAssign: (uid, add) =>
                              _assignMember(index, uid, add),
                        ),
                  ),
          ),

          // Total footer
          Container(
            decoration: BoxDecoration(
              color: cs.surface,
              border: Border(top: BorderSide(color: cs.outlineVariant)),
            ),
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Selected items total',
                          style: tt.bodySmall
                              ?.copyWith(color: cs.onSurfaceVariant)),
                      Text(
                        CurrencyUtils.formatCompact(_selectedTotal, 'EUR'),
                        style: tt.titleLarge
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      if (widget.parsed.total != null &&
                          (_selectedTotal - widget.parsed.total!).abs() > 0.01)
                        Text(
                          'Receipt total: ${CurrencyUtils.formatCompact(widget.parsed.total!, 'EUR')}',
                          style: tt.bodySmall
                              ?.copyWith(color: cs.onSurfaceVariant),
                        ),
                    ],
                  ),
                ),
                FilledButton.icon(
                  onPressed: _items.any((i) => i.isSelected) ? _confirm : null,
                  icon: const Icon(Icons.check_rounded),
                  label: const Text('Use These Items'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({
    required this.item,
    required this.members,
    required this.onToggle,
    required this.onAssign,
  });

  final ReceiptItem item;
  final List<GroupMember> members;
  final ValueChanged<bool?> onToggle;
  final void Function(String userId, bool add) onAssign;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: item.isSelected ? 1.0 : 0.45,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Column(
          children: [
            CheckboxListTile(
              value:    item.isSelected,
              onChanged: onToggle,
              title: Text(
                item.name,
                style: tt.bodyMedium?.copyWith(
                  decoration: item.isSelected ? null : TextDecoration.lineThrough,
                ),
              ),
              secondary: Text(
                CurrencyUtils.formatCompact(item.price, 'EUR'),
                style: tt.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: item.isSelected ? cs.primary : cs.onSurfaceVariant,
                ),
              ),
              controlAffinity: ListTileControlAffinity.leading,
              dense: true,
            ),

            // Member assignment chips (only shown if item is selected)
            if (item.isSelected && members.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 48, right: 16, bottom: 6),
                child: Wrap(
                  spacing: 6,
                  children: [
                    Text(
                      'For:',
                      style: tt.labelSmall
                          ?.copyWith(color: cs.onSurfaceVariant),
                    ),
                    ...members.map((m) {
                      final assigned = item.assignedTo.contains(m.user.id);
                      return FilterChip(
                        label: Text(
                          m.user.displayName ??
                              m.user.email.split('@').first,
                          style: const TextStyle(fontSize: 11),
                        ),
                        selected:  assigned,
                        onSelected: (val) => onAssign(m.user.id, val),
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      );
                    }),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
