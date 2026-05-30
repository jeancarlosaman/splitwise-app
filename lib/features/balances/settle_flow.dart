import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../core/utils/currency_utils.dart';
import '../auth/models/app_user.dart';
import '../expenses/providers/expenses_provider.dart';
import '../groups/providers/groups_provider.dart';
import '../../shared/repositories/expenses_repository.dart';
import '../../shared/repositories/profiles_repository.dart';
import 'providers/balances_provider.dart';

/// Entry point: shows a bottom sheet with payment options for paying [toUserId]
/// the [amount]. If the recipient has a Revolut tag, offers a deep link. Always
/// offers an "Already paid - just record it" fallback.
///
/// After the user pays via Revolut and returns to the app, prompts them to
/// confirm so we only record the settlement on real payments (not back-outs).
Future<void> showSettleSheet({
  required BuildContext context,
  required WidgetRef ref,
  required String groupId,
  required String fromUserId,
  required String toUserId,
  required String fromName,
  required String toName,
  required double amount,
}) async {
  // Fetch the payee's profile to see what payment methods they have.
  // We do this synchronously inside the bottom sheet so the user sees the
  // available options without an extra hop.
  AppUser? payee;
  try {
    payee = await ProfilesRepository().getProfile(toUserId);
  } catch (_) {
    payee = null;
  }
  if (!context.mounted) return;

  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppTheme.surface,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    isScrollControlled: true,
    builder: (sheetCtx) => _SettleSheet(
      payee: payee,
      fromUserId: fromUserId,
      toUserId: toUserId,
      fromName: fromName,
      toName: toName,
      amount: amount,
      groupId: groupId,
      parentRef: ref,
    ),
  );
}

class _SettleSheet extends StatelessWidget {
  final AppUser? payee;
  final String fromUserId, toUserId, fromName, toName, groupId;
  final double amount;
  final WidgetRef parentRef;

  const _SettleSheet({
    required this.payee,
    required this.fromUserId,
    required this.toUserId,
    required this.fromName,
    required this.toName,
    required this.amount,
    required this.groupId,
    required this.parentRef,
  });

  @override
  Widget build(BuildContext context) {
    final hasRevolut =
        payee?.revolutTag != null && payee!.revolutTag!.isNotEmpty;
    final hasBizum =
        payee?.bizumPhone != null && payee!.bizumPhone!.isNotEmpty;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Pay $toName',
              style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              CurrencyUtils.format(amount,
                  currency: AppConstants.defaultCurrency),
              style: const TextStyle(
                  color: AppTheme.green,
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5),
            ),
            const SizedBox(height: 20),

            if (hasRevolut)
              _PayOption(
                icon: Icons.account_balance_rounded,
                label: 'Pay via Revolut',
                sublabel: '@${payee!.revolutTag}',
                accent: const Color(0xFF0075EB),
                onTap: () => _payViaRevolut(context),
              ),

            if (hasBizum)
              _PayOption(
                icon: Icons.phone_iphone_rounded,
                label: 'Bizum',
                sublabel: payee!.bizumPhone!,
                accent: const Color(0xFF2EBE94),
                trailing: IconButton(
                  icon: const Icon(Icons.copy_rounded,
                      size: 18, color: AppTheme.textSecondary),
                  onPressed: () {
                    Clipboard.setData(
                        ClipboardData(text: payee!.bizumPhone!));
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('Phone copied'),
                      duration: Duration(seconds: 2),
                    ));
                  },
                ),
                onTap: () {
                  Clipboard.setData(ClipboardData(text: payee!.bizumPhone!));
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text(
                        'Phone copied — open Bizum from your bank app to send'),
                    duration: Duration(seconds: 3),
                  ));
                },
              ),

            if (!hasRevolut && !hasBizum)
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 8, 4, 12),
                child: Text(
                  '$toName hasn\'t set up Revolut or Bizum yet. You can still record the payment manually below.',
                  style: const TextStyle(
                      color: AppTheme.textSecondary, fontSize: 13),
                ),
              ),

            const Divider(color: AppTheme.border, height: 32),

            _PayOption(
              icon: Icons.check_circle_outline_rounded,
              label: 'Already paid — just record it',
              sublabel: 'Mark this debt as settled',
              accent: AppTheme.green,
              onTap: () async {
                Navigator.pop(context);
                await _recordSettlement(context);
              },
            ),

            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel',
                  style: TextStyle(color: AppTheme.textSecondary)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _payViaRevolut(BuildContext context) async {
    final tag = payee!.revolutTag!;
    final uri = Uri.parse(
        'https://revolut.me/$tag?amount=${amount.toStringAsFixed(2)}&currency=${AppConstants.defaultCurrency}');

    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content:
                Text('Could not open Revolut. Tag: revolut.me/$tag')));
      }
      return;
    }
    if (!context.mounted) return;
    Navigator.pop(context); // close the sheet — we're about to prompt

    // When the user returns to our app, ask whether the payment actually
    // happened. Defer the prompt with a tiny delay so it lands AFTER the app
    // resumes (otherwise iOS swallows the dialog while the previous app is
    // still active).
    Future.delayed(const Duration(milliseconds: 300), () async {
      if (!context.mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppTheme.surface,
          title: const Text('Did the payment go through?',
              style: TextStyle(color: AppTheme.textPrimary)),
          content: Text(
            'If you paid $toName ${CurrencyUtils.format(amount, currency: AppConstants.defaultCurrency)} '
            'via Revolut, mark it as settled.',
            style: const TextStyle(color: AppTheme.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Not yet'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.green,
                  foregroundColor: Colors.black),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Yes, mark paid'),
            ),
          ],
        ),
      );
      if (confirmed == true && context.mounted) {
        await _recordSettlement(context);
      }
    });
  }

  Future<void> _recordSettlement(BuildContext context) async {
    try {
      await parentRef.read(expensesRepositoryProvider).recordSettlement(
            groupId: groupId,
            fromUserId: fromUserId,
            toUserId: toUserId,
            amount: amount,
            currency: AppConstants.defaultCurrency,
            fromName: fromName,
            toName: toName,
          );
      parentRef.invalidate(groupBalancesProvider(groupId));
      parentRef.invalidate(groupExpensesProvider(groupId));
      // Personal vs shared totals on the stats screen depend on group spending,
      // which doesn't change — but refresh the groups list in case other UI
      // depends on it.
      parentRef.invalidate(groupsProvider);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: AppTheme.greenSubtle,
          content: Text('Marked $fromName → $toName as paid',
              style: const TextStyle(color: AppTheme.textPrimary)),
        ));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Couldn\'t record settlement: $e')));
      }
    }
  }
}

class _PayOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final String sublabel;
  final Color accent;
  final VoidCallback onTap;
  final Widget? trailing;

  const _PayOption({
    required this.icon,
    required this.label,
    required this.sublabel,
    required this.accent,
    required this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: accent.withValues(alpha: 0.3), width: 1),
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: accent, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label,
                          style: const TextStyle(
                              color: AppTheme.textPrimary,
                              fontWeight: FontWeight.w700,
                              fontSize: 15)),
                      const SizedBox(height: 2),
                      Text(sublabel,
                          style: const TextStyle(
                              color: AppTheme.textSecondary, fontSize: 12)),
                    ],
                  ),
                ),
                trailing ??
                    const Icon(Icons.chevron_right_rounded,
                        color: AppTheme.textSecondary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
