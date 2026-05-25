import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/groups/models/group.dart';
import '../../features/groups/models/group_member.dart';
import '../../features/auth/models/app_user.dart';
import 'supabase_client.dart';

class GroupsRepository {
  const GroupsRepository(this._client);

  final SupabaseClient _client;

  /// Returns all groups the current user belongs to.
  Future<List<ExpenseGroup>> fetchMyGroups() async {
    final userId = _client.auth.currentUser!.id;
    final data = await _client
        .from('expense_groups')
        .select('''
          *,
          group_members!inner(user_id)
        ''')
        .eq('group_members.user_id', userId)
        .order('created_at', ascending: false);

    return (data as List).map((e) => ExpenseGroup.fromJson(e)).toList();
  }

  /// Fetches a single group by [groupId].
  Future<ExpenseGroup> fetchGroup(String groupId) async {
    final data = await _client
        .from('expense_groups')
        .select()
        .eq('id', groupId)
        .single();
    return ExpenseGroup.fromJson(data);
  }

  /// Creates a new group and adds the creator as a member.
  Future<ExpenseGroup> createGroup({
    required String name,
    required String emoji,
    required String createdBy,
  }) async {
    // Insert group
    final groupData = await _client
        .from('expense_groups')
        .insert({
          'name': name,
          'emoji': emoji,
          'created_by': createdBy,
        })
        .select()
        .single();

    final group = ExpenseGroup.fromJson(groupData);

    // Add creator as member
    await _client.from('group_members').insert({
      'group_id': group.id,
      'user_id': createdBy,
    });

    return group;
  }

  /// Fetches all members of [groupId] with their profile info.
  Future<List<GroupMember>> fetchMembers(String groupId) async {
    final data = await _client
        .from('group_members')
        .select('''
          *,
          profiles(*)
        ''')
        .eq('group_id', groupId);

    return (data as List).map((e) => GroupMember.fromJson(e)).toList();
  }

  /// Invites a user (by email) to [groupId].
  /// Returns null if the user was not found.
  Future<GroupMember?> inviteMemberByEmail({
    required String groupId,
    required String email,
  }) async {
    // Look up the profile by email
    final profileData = await _client
        .from('profiles')
        .select()
        .eq('email', email.toLowerCase().trim())
        .maybeSingle();

    if (profileData == null) return null;

    final userId = profileData['id'] as String;

    // Check if already a member
    final existing = await _client
        .from('group_members')
        .select()
        .eq('group_id', groupId)
        .eq('user_id', userId)
        .maybeSingle();

    if (existing != null) {
      // Already a member — return existing
      return GroupMember(
        id: existing['id'] as String,
        groupId: groupId,
        user: AppUser.fromJson(profileData),
        joinedAt: DateTime.parse(existing['joined_at'] as String),
      );
    }

    final memberData = await _client
        .from('group_members')
        .insert({
          'group_id': groupId,
          'user_id': userId,
        })
        .select('''
          *,
          profiles(*)
        ''')
        .single();

    return GroupMember.fromJson(memberData);
  }

  /// Removes a member from a group.
  Future<void> removeMember({
    required String groupId,
    required String userId,
  }) async {
    await _client
        .from('group_members')
        .delete()
        .eq('group_id', groupId)
        .eq('user_id', userId);
  }
}

final groupsRepositoryProvider = Provider<GroupsRepository>((ref) {
  return GroupsRepository(ref.watch(supabaseClientProvider));
});
