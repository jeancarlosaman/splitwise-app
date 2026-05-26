import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/app_user.dart';
import '../../../shared/repositories/supabase_client.dart';

// ── Router change notifier (triggers GoRouter redirect on auth change) ──────
class AuthChangeNotifier extends ChangeNotifier {
  AuthChangeNotifier() {
    supabase.auth.onAuthStateChange.listen((_) => notifyListeners());
  }
}

final authChangeNotifierProvider = Provider<AuthChangeNotifier>(
  (ref) => AuthChangeNotifier(),
);

// ── Current Supabase session ─────────────────────────────────────────────────
final sessionProvider = StreamProvider<Session?>((ref) {
  return supabase.auth.onAuthStateChange
      .map((event) => event.session);
});

// ── Current logged-in AppUser ────────────────────────────────────────────────
final currentUserProvider = FutureProvider<AppUser?>((ref) async {
  final user = supabase.auth.currentUser;
  if (user == null) return null;

  final data = await supabase
      .from('profiles')
      .select()
      .eq('id', user.id)
      .maybeSingle();

  if (data == null) return null;
  return AppUser.fromJson(data);
});

// ── Auth notifier (sign in / sign up / sign out) ─────────────────────────────
class AuthNotifier extends StateNotifier<AsyncValue<void>> {
  AuthNotifier() : super(const AsyncData(null));

  Future<void> signIn({required String email, required String password}) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await supabase.auth.signInWithPassword(email: email, password: password);
    });
  }

  Future<void> signUp({required String email, required String password}) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await supabase.auth.signUp(email: email, password: password);
    });
  }

  Future<void> signOut() async {
    await supabase.auth.signOut();
  }
}

final authNotifierProvider =
    StateNotifierProvider<AuthNotifier, AsyncValue<void>>(
  (ref) => AuthNotifier(),
);
