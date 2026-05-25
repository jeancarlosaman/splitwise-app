import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/theme.dart';
import 'features/auth/providers/auth_provider.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/auth/screens/register_screen.dart';
import 'features/groups/screens/groups_list_screen.dart';
import 'features/groups/screens/create_group_screen.dart';
import 'features/groups/screens/group_detail_screen.dart';
import 'features/expenses/screens/add_expense_screen.dart';
import 'features/expenses/screens/expense_detail_screen.dart';
import 'features/balances/screens/balances_screen.dart';

// ─────────────────────────────────────────
// Router
// ─────────────────────────────────────────

final routerProvider = Provider<GoRouter>((ref) {
  final authNotifier = ref.watch(authChangeNotifierProvider);

  return GoRouter(
    refreshListenable: authNotifier,
    initialLocation:   '/groups',
    redirect: (context, state) {
      final isAuthenticated = authNotifier.isAuthenticated;
      final loc = state.matchedLocation;

      final isAuthRoute =
          loc == '/login' || loc == '/register';

      if (!isAuthenticated && !isAuthRoute) return '/login';
      if (isAuthenticated && isAuthRoute) return '/groups';
      return null;
    },
    routes: [
      // ── Auth ──
      GoRoute(
        path:    '/login',
        builder: (_, __) => const LoginScreen(),
      ),
      GoRoute(
        path:    '/register',
        builder: (_, __) => const RegisterScreen(),
      ),

      // ── Groups ──
      GoRoute(
        path:    '/groups',
        builder: (_, __) => const GroupsListScreen(),
        routes: [
          GoRoute(
            path:    'create',
            builder: (_, __) => const CreateGroupScreen(),
          ),
          GoRoute(
            path: ':groupId',
            builder: (_, state) => GroupDetailScreen(
              groupId: state.pathParameters['groupId']!,
            ),
            routes: [
              GoRoute(
                path: 'add-expense',
                builder: (_, state) => AddExpenseScreen(
                  groupId: state.pathParameters['groupId']!,
                ),
              ),
              GoRoute(
                path: 'balances',
                builder: (_, state) => BalancesScreen(
                  groupId: state.pathParameters['groupId']!,
                ),
              ),
              GoRoute(
                path: 'expense/:expenseId',
                builder: (_, state) => ExpenseDetailScreen(
                  expenseId: state.pathParameters['expenseId']!,
                ),
              ),
            ],
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Text('Page not found: ${state.error}'),
      ),
    ),
  );
});

// ─────────────────────────────────────────
// Root Widget
// ─────────────────────────────────────────

class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title:           'SplitWise',
      theme:           AppTheme.light,
      darkTheme:       AppTheme.dark,
      themeMode:       ThemeMode.system,
      routerConfig:    router,
      debugShowCheckedModeBanner: false,
    );
  }
}
