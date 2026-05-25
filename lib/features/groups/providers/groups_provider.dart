import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/repositories/groups_repository.dart';
import '../models/group.dart';
import '../models/group_member.dart';

// ─────────────────────────────────────────
// Groups list
// ─────────────────────────────────────────

class GroupsNotifier extends AsyncNotifier<List<ExpenseGroup>> {
  @override
  Future<List<ExpenseGroup>> build() async {
    return ref.read(groupsRepositoryProvider).fetchMyGroups();
  }

  Future<ExpenseGroup> createGroup({
    required String name,
    required String emoji,
    required String createdBy,
  }) async {
    final group = await ref.read(groupsRepositoryProvider).createGroup(
          name:      name,
          emoji:     emoji,
          createdBy: createdBy,
        );
    // Prepend to list
    state = AsyncData([group, ...?state.valueOrNull]);
    return group;
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(groupsRepositoryProvider).fetchMyGroups(),
    );
  }
}

final groupsNotifierProvider =
    AsyncNotifierProvider<GroupsNotifier, List<ExpenseGroup>>(
  GroupsNotifier.new,
);

// ─────────────────────────────────────────
// Single group
// ─────────────────────────────────────────

final groupProvider =
    FutureProvider.family<ExpenseGroup, String>((ref, groupId) async {
  return ref.read(groupsRepositoryProvider).fetchGroup(groupId);
});

// ─────────────────────────────────────────
// Group members
// ─────────────────────────────────────────

class GroupMembersNotifier
    extends FamilyAsyncNotifier<List<GroupMember>, String> {
  @override
  Future<List<GroupMember>> build(String groupId) async {
    return ref.read(groupsRepositoryProvider).fetchMembers(groupId);
  }

  Future<GroupMember?> inviteByEmail(String email) async {
    final member = await ref
        .read(groupsRepositoryProvider)
        .inviteMemberByEmail(groupId: arg, email: email);

    if (member != null) {
      state = AsyncData([...?state.valueOrNull, member]);
    }
    return member;
  }

  Future<void> removeMember(String userId) async {
    await ref
        .read(groupsRepositoryProvider)
        .removeMember(groupId: arg, userId: userId);
    state = AsyncData(
      (state.valueOrNull ?? []).where((m) => m.user.id != userId).toList(),
    );
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(groupsRepositoryProvider).fetchMembers(arg),
    );
  }
}

final groupMembersProvider = AsyncNotifierProviderFamily<
    GroupMembersNotifier, List<GroupMember>, String>(
  GroupMembersNotifier.new,
);
