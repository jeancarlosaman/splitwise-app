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
final personalGroupProvider =
    FutureProvider<ExpenseGroup>((ref) async {
  return ref.read(groupsRepositoryProvider).getOrCreatePersonalGroup();
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
