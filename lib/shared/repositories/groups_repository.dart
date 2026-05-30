import '../../features/groups/models/group.dart';
import '../../features/groups/models/group_member.dart';
import '../../features/auth/models/app_user.dart';
import 'supabase_client.dart';

class GroupsRepository {
  Future<List<ExpenseGroup>> getGroups() async {
    final userId = supabase.auth.currentUser!.id;
    // Get group IDs the user belongs to
    final memberRows = await supabase
        .from('group_members')
        .select('group_id')
        .eq('user_id', userId);

    final groupIds =
        (memberRows as List).map((e) => e['group_id'] as String).toList();
    if (groupIds.isEmpty) return [];

    final data = await supabase
        .from('expense_groups')
        .select()
        .inFilter('id', groupIds)
        .order('created_at', ascending: false);

    return (data as List).map((e) => ExpenseGroup.fromJson(e)).toList();
  }

  Future<ExpenseGroup> createGroup({
    required String name,
    required String emoji,
    bool isPersonal = false,
  }) async {
    final userId = supabase.auth.currentUser!.id;
    final data = await supabase
        .from('expense_groups')
        .insert({
          'name': name,
          'emoji': emoji,
          'created_by': userId,
          'is_personal': isPersonal,
        })
        .select()
        .single();

    final group = ExpenseGroup.fromJson(data);

    // Add creator as member
    await supabase.from('group_members').insert({
      'group_id': group.id,
      'user_id': userId,
    });

    return group;
  }

  /// Returns the user's auto-created personal group, creating it on first call.
  Future<ExpenseGroup> getOrCreatePersonalGroup() async {
    final userId = supabase.auth.currentUser!.id;
    final existing = await supabase
        .from('expense_groups')
        .select()
        .eq('created_by', userId)
        .eq('is_personal', true)
        .maybeSingle();

    if (existing != null) {
      return ExpenseGroup.fromJson(existing);
    }
    return createGroup(name: 'Personal', emoji: '👤', isPersonal: true);
  }

  Future<List<GroupMember>> getGroupMembers(String groupId) async {
    final data = await supabase
        .from('group_members')
        .select('*, profiles(*)')
        .eq('group_id', groupId);

    return (data as List).map((e) {
      final profile = e['profiles'] as Map<String, dynamic>;
      return GroupMember(
        id: e['id'] as String,
        groupId: groupId,
        user: AppUser.fromJson(profile),
        joinedAt: DateTime.parse(e['joined_at'] as String),
      );
    }).toList();
  }

  Future<void> addMemberByEmail({
    required String groupId,
    required String email,
  }) async {
    final profileData = await supabase
        .from('profiles')
        .select('id')
        .eq('email', email)
        .maybeSingle();

    if (profileData == null) {
      throw Exception('No user found with email $email');
    }

    await supabase.from('group_members').insert({
      'group_id': groupId,
      'user_id': profileData['id'],
    });
  }

  Future<void> leaveGroup(String groupId) async {
    final userId = supabase.auth.currentUser!.id;
    await supabase
        .from('group_members')
        .delete()
        .eq('group_id', groupId)
        .eq('user_id', userId);
  }

  /// Joins a group by its 8-character code. Returns the group ID, or throws
  /// 'invalid_code' if the code doesn't match any non-personal group.
  Future<String> joinByCode(String code) async {
    final normalized = code.trim().toUpperCase();
    if (normalized.isEmpty) {
      throw Exception('Empty code');
    }
    final result = await supabase
        .rpc('join_group_by_code', params: {'p_code': normalized});
    if (result is String) return result;
    throw Exception('Unexpected response: $result');
  }
}
