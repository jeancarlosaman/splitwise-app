import '../../auth/models/app_user.dart';

class GroupMember {
  const GroupMember({
    required this.id,
    required this.groupId,
    required this.user,
    required this.joinedAt,
  });

  final String id;
  final String groupId;
  final AppUser user;
  final DateTime joinedAt;

  factory GroupMember.fromJson(Map<String, dynamic> json) {
    final profileJson = json['profiles'] as Map<String, dynamic>?;
    late AppUser user;

    if (profileJson != null) {
      user = AppUser.fromJson(profileJson);
    } else {
      // Fallback: construct a minimal user from the top-level user_id
      user = AppUser(
        id:        json['user_id'] as String,
        email:     '',
        createdAt: DateTime.now(),
      );
    }

    return GroupMember(
      id:       json['id'] as String,
      groupId:  json['group_id'] as String,
      user:     user,
      joinedAt: DateTime.parse(json['joined_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'id':        id,
        'group_id':  groupId,
        'user_id':   user.id,
        'joined_at': joinedAt.toIso8601String(),
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is GroupMember && other.id == id);

  @override
  int get hashCode => id.hashCode;
}
