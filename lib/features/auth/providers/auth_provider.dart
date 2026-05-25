import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/repositories/supabase_client.dart';
import '../models/app_user.dart';

// ─────────────────────────────────────────
// Auth state stream — tracks Supabase session
// ─────────────────────────────────────────

/// Emits the current [User] (or null) whenever auth state changes.
final authStateProvider = StreamProvider<User?>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return client.auth.onAuthStateChange.map((event) => event.session?.user);
});

/// Convenience: the current user's ID (or null).
final currentUserIdProvider = Provider<String?>((ref) {
  return ref.watch(authStateProvider).valueOrNull?.id;
});

// ─────────────────────────────────────────
// ChangeNotifier that GoRouter can listen to
// ─────────────────────────────────────────

class AuthChangeNotifier extends ChangeNotifier {
  AuthChangeNotifier() {
    _subscription = Supabase.instance.client.auth.onAuthStateChange
        .listen((_) => notifyListeners());
  }

  late final StreamSubscription _subscription;

  bool get isAuthenticated =>
      Supabase.instance.client.auth.currentUser != null;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

final authChangeNotifierProvider = Provider<AuthChangeNotifier>((ref) {
  final notifier = AuthChangeNotifier();
  ref.onDispose(notifier.dispose);
  return notifier;
});

// ─────────────────────────────────────────
// Auth actions (sign in, sign up, sign out)
// ─────────────────────────────────────────

class AuthNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref
          .read(supabaseClientProvider)
          .auth
          .signInWithPassword(email: email.trim(), password: password);
    });
  }

  Future<void> signUp({
    required String email,
    required String password,
    required String displayName,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(supabaseClientProvider).auth.signUp(
        email: email.trim(),
        password: password,
        data: {'display_name': displayName.trim()},
      );
    });
  }

  Future<void> signOut() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(supabaseClientProvider).auth.signOut();
    });
  }
}

final authNotifierProvider =
    AsyncNotifierProvider<AuthNotifier, void>(AuthNotifier.new);

// ─────────────────────────────────────────
// Current user profile
// ─────────────────────────────────────────

final currentUserProfileProvider = FutureProvider<AppUser?>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return null;

  final data = await ref
      .read(supabaseClientProvider)
      .from('profiles')
      .select()
      .eq('id', userId)
      .maybeSingle();

  if (data == null) return null;
  return AppUser.fromJson(data);
});
