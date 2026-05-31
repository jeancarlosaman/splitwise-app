import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme.dart';
import '../../../shared/repositories/profiles_repository.dart';
import '../../../shared/repositories/supabase_client.dart';
import '../../auth/models/app_user.dart';
import '../../auth/providers/auth_provider.dart';
import '../../subscription/quota_service.dart';
import '../../subscription/screens/paywall_sheet.dart';

/// Loads the current user's full profile (including payment tags). We can't
/// rely on supabase.auth.currentUser here because that only has the auth row,
/// not our public.profiles columns.
final currentProfileProvider = FutureProvider<AppUser?>((ref) async {
  final user = supabase.auth.currentUser;
  if (user == null) return null;
  return ProfilesRepository().getProfile(user.id);
});

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _nameCtrl = TextEditingController();
  final _revolutCtrl = TextEditingController();
  final _bizumCtrl = TextEditingController();
  bool _saving = false;
  bool _loaded = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _revolutCtrl.dispose();
    _bizumCtrl.dispose();
    super.dispose();
  }

  void _populateOnce(AppUser u) {
    if (_loaded) return;
    _nameCtrl.text = u.displayName;
    _revolutCtrl.text = u.revolutTag ?? '';
    _bizumCtrl.text = u.bizumPhone ?? '';
    _loaded = true;
  }

  Future<void> _save() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;
    setState(() => _saving = true);
    try {
      await ProfilesRepository().updateProfile(
        userId: userId,
        displayName: _nameCtrl.text.trim().isEmpty ? null : _nameCtrl.text.trim(),
        revolutTag: _normalizeRevolut(_revolutCtrl.text),
        bizumPhone: _bizumCtrl.text.trim(),
      );
      ref.invalidate(currentProfileProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: AppTheme.greenSubtle,
          content: const Text('Profile saved',
              style: TextStyle(color: AppTheme.textPrimary)),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Save failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// Strip "@", spaces, and any "revolut.me/" prefix the user may have pasted.
  String _normalizeRevolut(String raw) {
    var s = raw.trim();
    if (s.isEmpty) return '';
    s = s.replaceAll(RegExp(r'^https?://(www\.)?revolut\.me/', caseSensitive: false), '');
    s = s.replaceAll(RegExp(r'^@'), '');
    return s.trim();
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(currentProfileProvider);

    return Scaffold(
      backgroundColor: AppTheme.black,
      appBar: AppBar(
        backgroundColor: AppTheme.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded,
              color: AppTheme.textPrimary),
          onPressed: () => context.pop(),
        ),
        title: const Text('Profile',
            style: TextStyle(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w800,
                fontSize: 20)),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded,
                color: AppTheme.textSecondary),
            onPressed: () =>
                ref.read(authNotifierProvider.notifier).signOut(),
            tooltip: 'Sign out',
          ),
        ],
      ),
      body: profileAsync.when(
        loading: () => const Center(
            child: CircularProgressIndicator(color: AppTheme.green)),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (user) {
          if (user == null) return const Center(child: Text('Not signed in'));
          _populateOnce(user);
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
            children: [
              // ── Subscription card at the top — it's the highest-value
              //     piece of info on this screen. ─────────────────────────
              _SubscriptionCard(user: user),
              const SizedBox(height: 28),

              _SectionHeader(label: 'Account'),
              const SizedBox(height: 10),
              _LabeledField(
                label: 'Display name',
                child: TextField(
                  controller: _nameCtrl,
                  style: const TextStyle(color: AppTheme.textPrimary),
                  decoration: _inputDecoration(),
                ),
              ),
              const SizedBox(height: 8),
              _LabeledField(
                label: 'Email',
                child: Text(user.email,
                    style: const TextStyle(
                        color: AppTheme.textSecondary, fontSize: 15)),
              ),

              const SizedBox(height: 28),
              _SectionHeader(label: 'Payment methods'),
              const SizedBox(height: 4),
              const Padding(
                padding: EdgeInsets.fromLTRB(2, 2, 2, 14),
                child: Text(
                  'When other group members owe you, they can pay using these. '
                  'Revolut opens with the amount pre-filled; Bizum gets shown as '
                  'a copyable phone number.',
                  style: TextStyle(
                      color: AppTheme.textSecondary, fontSize: 13),
                ),
              ),

              _LabeledField(
                label: 'Revolut tag',
                hint: 'Your revolut.me username (without @)',
                child: TextField(
                  controller: _revolutCtrl,
                  style: const TextStyle(color: AppTheme.textPrimary),
                  decoration: _inputDecoration(prefix: 'revolut.me/'),
                ),
              ),

              const SizedBox(height: 12),

              _LabeledField(
                label: 'Bizum phone',
                hint: 'E.g. +34600000000 (Spain only)',
                child: TextField(
                  controller: _bizumCtrl,
                  style: const TextStyle(color: AppTheme.textPrimary),
                  keyboardType: TextInputType.phone,
                  decoration: _inputDecoration(),
                ),
              ),

              const SizedBox(height: 32),

              SizedBox(
                height: 50,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.green,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              color: Colors.black, strokeWidth: 2))
                      : const Text('Save',
                          style: TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 16)),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  InputDecoration _inputDecoration({String? prefix}) => InputDecoration(
        filled: true,
        fillColor: AppTheme.surface,
        prefixText: prefix,
        prefixStyle: const TextStyle(
            color: AppTheme.textSecondary, fontWeight: FontWeight.w600),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppTheme.border, width: 0.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppTheme.border, width: 0.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppTheme.green, width: 1),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      );
}

// ── Subscription card ─────────────────────────────────────────────────────
class _SubscriptionCard extends ConsumerWidget {
  final AppUser user;
  const _SubscriptionCard({required this.user});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPro = user.isPro;
    final ocrQuota = ref.watch(quotaStateProvider(QuotaFeature.ocrScan));
    final voiceQuota = ref.watch(quotaStateProvider(QuotaFeature.voiceParse));

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 14, 16),
      decoration: BoxDecoration(
        gradient: isPro
            ? AppTheme.mintTintGradient
            : AppTheme.cardGradient,
        borderRadius: const BorderRadius.all(AppTheme.radiusLg),
        border: Border.all(
            color: isPro
                ? AppTheme.mint.withValues(alpha: 0.35)
                : AppTheme.border,
            width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: AppTheme.mintGradient,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: isPro
                      ? const [
                          BoxShadow(
                              color: AppTheme.mintGlow,
                              blurRadius: 18,
                              offset: Offset(0, 6)),
                        ]
                      : null,
                ),
                child: const Icon(Icons.bolt_rounded,
                    color: Color(0xFF052E1F), size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text('SplitWise',
                            style: TextStyle(
                                color: AppTheme.textPrimary,
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.2)),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: isPro
                                ? AppTheme.mint
                                : AppTheme.ink3,
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Text(isPro ? 'PRO' : 'FREE',
                              style: TextStyle(
                                  color: isPro
                                      ? const Color(0xFF052E1F)
                                      : AppTheme.textSecondary,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.2)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isPro
                          ? 'Unlimited AI · €2.99 / mo'
                          : '5 scans + 5 voice notes per month',
                      style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
              if (!isPro)
                Material(
                  color: AppTheme.mint,
                  borderRadius: BorderRadius.circular(10),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () =>
                        showPaywallSheet(context: context, ref: ref),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      child: const Text('Upgrade',
                          style: TextStyle(
                              color: Color(0xFF052E1F),
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                              letterSpacing: -0.1)),
                    ),
                  ),
                )
              else
                _SubscriptionMenuButton(),
            ],
          ),

          // Usage rows — only shown for free users (pro is unlimited).
          if (!isPro) ...[
            const SizedBox(height: 16),
            _UsageRow(
              icon: Icons.receipt_long_rounded,
              label: 'Receipt scans',
              quota: ocrQuota.value,
              feature: QuotaFeature.ocrScan,
            ),
            const SizedBox(height: 10),
            _UsageRow(
              icon: Icons.mic_rounded,
              label: 'Voice notes',
              quota: voiceQuota.value,
              feature: QuotaFeature.voiceParse,
            ),
          ],
        ],
      ),
    );
  }
}

class _UsageRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final QuotaState? quota;
  final QuotaFeature feature;
  const _UsageRow({
    required this.icon,
    required this.label,
    required this.quota,
    required this.feature,
  });

  @override
  Widget build(BuildContext context) {
    final used = quota?.usedThisMonth ?? 0;
    final limit = feature.monthlyLimit;
    final pct = limit == 0 ? 0.0 : (used / limit).clamp(0.0, 1.0);
    final exceeded = used >= limit;
    final barColor = exceeded ? AppTheme.negative : AppTheme.mint;

    return Row(
      children: [
        Icon(icon, color: AppTheme.textSecondary, size: 16),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(label,
                      style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
                  const Spacer(),
                  Text('$used / $limit',
                      style: TextStyle(
                          color: exceeded
                              ? AppTheme.negative
                              : AppTheme.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w700)),
                ],
              ),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: pct,
                  minHeight: 4,
                  backgroundColor: AppTheme.ink3,
                  valueColor: AlwaysStoppedAnimation(barColor),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SubscriptionMenuButton extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return IconButton(
      icon: const Icon(Icons.more_horiz_rounded,
          color: AppTheme.textSecondary),
      onPressed: () async {
        final action = await showModalBottomSheet<String>(
          context: context,
          backgroundColor: AppTheme.ink,
          shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
          builder: (ctx) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 8),
                Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                        color: AppTheme.borderStrong,
                        borderRadius: BorderRadius.circular(2))),
                const SizedBox(height: 16),
                ListTile(
                  leading: const Icon(Icons.cancel_rounded,
                      color: AppTheme.negative),
                  title: const Text('Cancel Pro (test)',
                      style: TextStyle(color: AppTheme.textPrimary)),
                  subtitle: const Text(
                      'Returns to the free tier — for testing the gating flow.',
                      style: TextStyle(color: AppTheme.textTertiary)),
                  onTap: () => Navigator.pop(ctx, 'downgrade'),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
        if (action == 'downgrade') {
          await ref.read(quotaServiceProvider).devDowngrade();
          ref.invalidate(currentProfileProvider);
          for (final f in QuotaFeature.values) {
            ref.invalidate(quotaStateProvider(f));
          }
        }
      },
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(label.toUpperCase(),
        style: const TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 1));
  }
}

class _LabeledField extends StatelessWidget {
  final String label;
  final String? hint;
  final Widget child;
  const _LabeledField({required this.label, this.hint, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w600)),
        if (hint != null) ...[
          const SizedBox(height: 2),
          Text(hint!,
              style: const TextStyle(
                  color: AppTheme.textSecondary, fontSize: 12)),
        ],
        const SizedBox(height: 8),
        child,
      ],
    );
  }
}
