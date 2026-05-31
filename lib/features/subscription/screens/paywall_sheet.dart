import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme.dart';
import '../../profile/screens/profile_screen.dart';
import '../quota_service.dart';

/// Bottom sheet shown when:
///   - the user hits the free quota for a feature, OR
///   - the user explicitly taps "Upgrade" from the profile screen.
///
/// Lists the Pro perks, shows the €2.99/mo price, and (for now) calls the
/// dev_upgrade_to_pro RPC so the gating flow can be tested end-to-end.
/// Replace the Subscribe handler with a RevenueCat call once IAP is wired up.
Future<void> showPaywallSheet({
  required BuildContext context,
  required WidgetRef ref,
  QuotaFeature? triggeredBy,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppTheme.ink,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    builder: (_) => _PaywallSheet(triggeredBy: triggeredBy),
  );
}

class _PaywallSheet extends ConsumerStatefulWidget {
  final QuotaFeature? triggeredBy;
  const _PaywallSheet({this.triggeredBy});

  @override
  ConsumerState<_PaywallSheet> createState() => _PaywallSheetState();
}

class _PaywallSheetState extends ConsumerState<_PaywallSheet> {
  bool _busy = false;

  Future<void> _subscribe() async {
    setState(() => _busy = true);
    try {
      await ref.read(quotaServiceProvider).devUpgrade();
      ref.invalidate(currentProfileProvider);
      for (final f in QuotaFeature.values) {
        ref.invalidate(quotaStateProvider(f));
      }
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: AppTheme.mintTint,
        content: const Text("You're now on SplitWise Pro",
            style: TextStyle(color: AppTheme.textPrimary)),
      ));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Subscription failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final trigger = widget.triggeredBy;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                    color: AppTheme.borderStrong,
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 22),

            // ── Hero: gradient logo + Pro badge ────────────────────────
            Center(
              child: Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  gradient: AppTheme.mintGradient,
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: const [
                    BoxShadow(
                        color: AppTheme.mintGlow,
                        blurRadius: 28,
                        offset: Offset(0, 10))
                  ],
                ),
                child: const Center(
                    child: Icon(Icons.bolt_rounded,
                        color: Color(0xFF052E1F), size: 38)),
              ),
            ),
            const SizedBox(height: 18),
            const Center(
              child: Text('SplitWise Pro',
                  style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.6)),
            ),
            const SizedBox(height: 6),
            Center(
              child: Text(
                trigger != null
                    ? "You've used your free ${trigger.displayPlural} this month."
                    : 'Unlock unlimited AI for split bills.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 14,
                    height: 1.4),
              ),
            ),

            const SizedBox(height: 26),

            // ── Benefits ───────────────────────────────────────────────
            const _Benefit(
                icon: Icons.receipt_long_rounded,
                title: 'Unlimited receipt scans',
                subtitle:
                    'OCR every receipt all month, no caps.'),
            const _Benefit(
                icon: Icons.mic_rounded,
                title: 'Unlimited voice notes',
                subtitle:
                    'AI-parsed expenses by voice — no monthly limit.'),
            const _Benefit(
                icon: Icons.auto_awesome_rounded,
                title: 'Future AI features',
                subtitle:
                    'Anything new we add to the AI pipeline is included.'),
            const _Benefit(
                icon: Icons.support_agent_rounded,
                title: 'Priority support',
                subtitle:
                    'Help when you need it, before the free queue.'),

            const SizedBox(height: 22),

            // ── Price + CTA ────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              decoration: BoxDecoration(
                gradient: AppTheme.mintTintGradient,
                borderRadius: const BorderRadius.all(AppTheme.radiusLg),
                border: Border.all(
                    color: AppTheme.mint.withValues(alpha: 0.3), width: 1),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppTheme.mint,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text('MONTHLY',
                            style: TextStyle(
                                color: Color(0xFF052E1F),
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1)),
                      ),
                      const Spacer(),
                      Text(
                        '€2.99',
                        style: AppTheme.moneyStyle(
                            fontSize: 26,
                            weight: FontWeight.w800,
                            color: AppTheme.textPrimary,
                            letterSpacing: -0.5),
                      ),
                      const SizedBox(width: 4),
                      const Padding(
                        padding: EdgeInsets.only(bottom: 4),
                        child: Text('/ mo',
                            style: TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 13,
                                fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 50,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.mint,
                        foregroundColor: const Color(0xFF052E1F),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: _busy ? null : _subscribe,
                      child: _busy
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Color(0xFF052E1F)))
                          : const Text('Start Pro',
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.1)),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),
            Center(
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Maybe later',
                    style: TextStyle(
                        color: AppTheme.textTertiary,
                        fontWeight: FontWeight.w600)),
              ),
            ),
            const SizedBox(height: 4),
            const Center(
              child: Text(
                'Test mode — no real payment is processed.',
                style: TextStyle(
                    color: AppTheme.textTertiary,
                    fontSize: 11,
                    fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Benefit extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  const _Benefit(
      {required this.icon, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppTheme.mintTint,
              borderRadius: BorderRadius.circular(11),
              border:
                  Border.all(color: AppTheme.mint.withValues(alpha: 0.3)),
            ),
            child: Icon(icon, color: AppTheme.mint, size: 19),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                        height: 1.35)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
