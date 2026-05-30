import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/group.dart';
import '../models/group_member.dart';
import '../../../shared/repositories/groups_repository.dart';

final groupsRepositoryProvider = Provider<GroupsRepository>(
  (ref) => GroupsRepository(),
);

// ── All groups for the current user ──────────────────────────────────────────
final groupsProvider =
    AsyncNotifierProvider<GroupsNotifier, List<ExpenseGroup>>(
  GroupsNotifier.new,
);

/// Only the user's auto-created Personal group. Surfaced separately so it
/// doesn't clutter the main groups list.
///
/// If we had to CREATE the group (first run), also refresh `groupsProvider`
/// so the personal group ID is in the cached list when the user taps it.
/// Without this, the GroupDetailScreen renders blank because `firstWhere`
/// can't find the just-created group.
final personalGroupProvider =
    FutureProvider<ExpenseGroup>((ref) async {
  final repo = ref.read(groupsRepositoryProvider);

  // Cheap check: see what's already in the cache before going to the network.
  final cached = ref.read(groupsProvider).value;
  final cachedPersonal = cached?.where((g) => g.isPersonal).cast<ExpenseGroup?>().firstWhere(
        (g) => g != null,
        orElse: () => null,
      );
  if (cachedPersonal != null) return cachedPersonal;

  final group = await repo.getOrCreatePersonalGroup();
  // Make sure the full groups list reflects this new group.
  Future.microtask(() => ref.read(groupsProvider.notifier).refresh());
  return group;
});

/// All groups EXCEPT the personal one — what to show in the main list.
final sharedGroupsProvider =
    Provider<List<ExpenseGroup>>((ref) {
  return ref.watch(groupsProvider).maybeWhen(
        data: (groups) => groups.where((g) => !g.isPersonal).toList(),
        orElse: () => const [],
      );
});

class GroupsNotifier extends AsyncNotifier<List<ExpenseGroup>> {
  @override
  Future<List<ExpenseGroup>> build() async {
    return ref.read(groupsRepositoryProvider).getGroups();
  }

  Future<ExpenseGroup> createGroup({
    required String name,
    required String emoji,
  }) async {
    final repo = ref.read(groupsRepositoryProvider);
    final group = await repo.createGroup(name: name, emoji: emoji);
    state = AsyncData([group, ...state.value ?? []]);
    return group;
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
        () => ref.read(groupsRepositoryProvider).getGroups());
  }
}

// ── Members of a specific group ───────────────────────────────────────────────
final groupMembersProvider = AsyncNotifierProviderFamily<
    GroupMembersNotifier, List<GroupMember>, String>(
  GroupMembersNotifier.new,
);

class GroupMembersNotifier
    extends FamilyAsyncNotifier<List<GroupMember>, String> {
  @override
  Future<List<GroupMember>> build(String groupId) async {
    return ref.read(groupsRepositoryProvider).getGroupMembers(groupId);
  }

  Future<void> addMemberByEmail(String email) async {
    final repo = ref.read(groupsRepositoryProvider);
    await repo.addMemberByEmail(groupId: arg, email: email);
    state = AsyncData(await repo.getGroupMembers(arg));
  }

  Future<void> refresh() async {
    state = AsyncData(
        await ref.read(groupsRepositoryProvider).getGroupMembers(arg));
  }
}
