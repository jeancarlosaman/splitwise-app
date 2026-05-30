import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/repositories/supabase_client.dart';
import '../../balances/providers/balances_provider.dart';
import '../../balances/screens/settle_all_screen.dart';
import '../../expenses/providers/expenses_provider.dart';
import '../../groups/providers/groups_provider.dart';
import '../../profile/screens/profile_screen.dart';
import '../../stats/screens/stats_screen.dart';
import 'auth_provider.dart';

/// Watches Supabase's auth stream and wipes every user-scoped Riverpod cache
/// when the authenticated user changes (sign in, sign out, account swap).
///
/// Without this, signing out and back in as a different user leaves the
/// previous account's groups, profile, balances, etc. visible until each
/// provider happens to refetch — which can be never, since most read once
/// on screen mount.
///
/// Watched by the root [App] widget at startup so it stays alive for the
/// whole app lifecycle.
final authResetProvider = Provider<AuthReset>((ref) {
  return AuthReset(ref);
});

class AuthReset {
  final Ref _ref;
  late final StreamSubscription<AuthState> _sub;
  String? _lastUserId;

  AuthReset(this._ref) {
    _lastUserId = supabase.auth.currentUser?.id;
    _sub = supabase.auth.onAuthStateChange.listen(_onAuth);
    _ref.onDispose(_sub.cancel);
  }

  void _onAuth(AuthState state) {
    final newId = state.session?.user.id;
    if (newId == _lastUserId) {
      // Same user (e.g. token refresh) — nothing to invalidate.
      return;
    }
    debugPrint(
        '[AuthReset] user changed: ${_lastUserId ?? "<none>"} -> ${newId ?? "<none>"} — invalidating user-scoped providers');
    _lastUserId = newId;
    _invalidateAll();
  }

  /// Drops every cached AsyncData that depends on the current user. The
  /// next read on each provider runs the build function again from scratch,
  /// which pulls fresh data for whoever is now signed in (or returns null
  /// if no one is).
  ///
  /// Add new user-scoped providers to this list as the app grows. Family
  /// providers are invalidated by their root — that drops every cached
  /// argument variant.
  void _invalidateAll() {
    // Auth-derived
    _ref.invalidate(currentUserProvider);
    _ref.invalidate(currentProfileProvider);

    // Groups
    _ref.invalidate(groupsProvider);
    _ref.invalidate(personalGroupProvider);
    _ref.invalidate(groupMembersProvider);

    // Expenses + balances
    _ref.invalidate(groupExpensesProvider);
    _ref.invalidate(groupBalancesProvider);

    // Cross-group aggregates
    _ref.invalidate(allSettlementsProvider);
    _ref.invalidate(spendingByGroupProvider);
  }
}
