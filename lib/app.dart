import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/theme.dart';
import 'features/auth/providers/auth_provider.dart';
import 'features/auth/providers/auth_reset.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/auth/screens/register_screen.dart';
import 'features/groups/screens/groups_list_screen.dart';
import 'features/groups/screens/create_group_screen.dart';
import 'features/groups/screens/group_detail_screen.dart';
import 'features/expenses/screens/expense_list_screen.dart';
import 'features/expenses/screens/add_expense_screen.dart';
import 'features/expenses/screens/expense_detail_screen.dart';
import 'features/expenses/screens/edit_expense_screen.dart';
import 'features/balances/screens/balances_screen.dart';
import 'features/balances/screens/settle_all_screen.dart';
import 'features/stats/screens/stats_screen.dart';
import 'features/profile/screens/profile_screen.dart';
import 'shared/repositories/supabase_client.dart';

class App extends ConsumerStatefulWidget {
  const App({super.key});

  @override
  ConsumerState<App> createState() => _AppState();
}

class _AppState extends ConsumerState<App> {
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    final notifier = ref.read(authChangeNotifierProvider);
    _router = GoRouter(
      refreshListenable: notifier,
      redirect: (context, state) {
        final isLoggedIn = supabase.auth.currentUser != null;
        final isAuthRoute = state.matchedLocation == '/login' ||
            state.matchedLocation == '/register';
        if (!isLoggedIn && !isAuthRoute) return '/login';
        if (isLoggedIn && isAuthRoute) return '/';
        return null;
      },
      routes: [
        GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
        GoRoute(path: '/register', builder: (_, __) => const RegisterScreen()),
        GoRoute(path: '/', builder: (_, __) => const GroupsListScreen()),
        GoRoute(
            path: '/groups/create',
            builder: (_, __) => const CreateGroupScreen()),
        GoRoute(
          path: '/groups/:groupId',
          builder: (_, state) =>
              GroupDetailScreen(groupId: state.pathParameters['groupId']!),
        ),
        GoRoute(
          path: '/groups/:groupId/expenses',
          builder: (_, state) =>
              ExpenseListScreen(groupId: state.pathParameters['groupId']!),
        ),
        GoRoute(
          path: '/groups/:groupId/add-expense',
          builder: (_, state) =>
              AddExpenseScreen(groupId: state.pathParameters['groupId']!),
        ),
        GoRoute(
          path: '/groups/:groupId/expenses/:expenseId',
          builder: (_, state) => ExpenseDetailScreen(
            groupId: state.pathParameters['groupId']!,
            expenseId: state.pathParameters['expenseId']!,
          ),
        ),
        // Edit expense route
        GoRoute(
          path: '/groups/:groupId/expenses/:expenseId/edit',
          builder: (_, state) => EditExpenseScreen(
            groupId: state.pathParameters['groupId']!,
            expenseId: state.pathParameters['expenseId']!,
          ),
        ),
        GoRoute(
          path: '/groups/:groupId/balances',
          builder: (_, state) =>
              BalancesScreen(groupId: state.pathParameters['groupId']!),
        ),
        GoRoute(path: '/stats', builder: (_, __) => const StatsScreen()),
        GoRoute(path: '/profile', builder: (_, __) => const ProfileScreen()),
        GoRoute(path: '/settle', builder: (_, __) => const SettleAllScreen()),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // Mount the auth-reset hook for the app's lifetime so user-scoped
    // providers get invalidated whenever the signed-in user changes.
    // Doing this in build() means the hook stays alive as long as App is
    // in the tree (i.e. always, after the first frame).
    ref.watch(authResetProvider);

    return MaterialApp.router(
      title: 'SplitWise',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      routerConfig: _router,
      debugShowCheckedModeBanner: false,
    );
  }
}
