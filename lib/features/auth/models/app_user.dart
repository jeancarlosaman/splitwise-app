/// Represents a user profile row from the `profiles` table.
class AppUser {
  const AppUser({
    required this.id,
    required this.email,
    this.displayName,
    this.avatarUrl,
    required this.createdAt,
  });

  final String id;
  final String email;
  final String? displayName;
  final String? avatarUrl;
  final DateTime createdAt;

  /// The best available label for this user.
  String get name => displayName?.isNotEmpty == true ? displayName! : email;

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id:          json['id'] as String,
      email:       json['email'] as String,
      displayName: json['display_name'] as String?,
      avatarUrl:   json['avatar_url'] as String?,
      createdAt:   DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'id':           id,
        'email':        email,
        'display_name': displayName,
        'avatar_url':   avatarUrl,
        'created_at':   createdAt.toIso8601String(),
      };

  AppUser copyWith({
    String? id,
    String? email,
    String? displayName,
    String? avatarUrl,
    DateTime? createdAt,
  }) {
    return AppUser(
      id:          id          ?? this.id,
      email:       email       ?? this.email,
      displayName: displayName ?? this.displayName,
      avatarUrl:   avatarUrl   ?? this.avatarUrl,
      createdAt:   createdAt   ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is AppUser && other.id == id);

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'AppUser(id: $id, email: $email, name: $displayName)';
}
