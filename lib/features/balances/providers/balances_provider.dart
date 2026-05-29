import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/balance.dart';
import '../../expenses/providers/expenses_provider.dart';

final groupBalancesProvider =
    FutureProviderFamily<GroupBalances, String>((ref, groupId) async {
  final repo = ref.read(expensesRepositoryProvider);
  final raw = await repo.computeBalances(groupId);
  return GroupBalances.compute(raw);
});
