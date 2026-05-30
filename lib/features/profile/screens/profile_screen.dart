import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme.dart';
import '../../../shared/repositories/profiles_repository.dart';
import '../../../shared/repositories/supabase_client.dart';
import '../../auth/models/app_user.dart';
import '../../auth/providers/auth_provider.dart';

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
