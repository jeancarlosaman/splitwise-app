import '../../auth/models/app_user.dart';

class GroupMember {
  final String id;
  final String groupId;
  final AppUser user;
  final DateTime joinedAt;

  const GroupMember({
    required this.id,
    required this.groupId,
    required this.user,
    required this.joinedAt,
  });
}
