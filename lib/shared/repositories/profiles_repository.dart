import '../../features/auth/models/app_user.dart';
import 'supabase_client.dart';

class ProfilesRepository {
  Future<AppUser?> getProfile(String userId) async {
    final data = await supabase
        .from('profiles')
        .select()
        .eq('id', userId)
        .maybeSingle();
    if (data == null) return null;
    return AppUser.fromJson(data);
  }

  Future<List<AppUser>> getProfilesByIds(List<String> ids) async {
    if (ids.isEmpty) return [];
    final data = await supabase
        .from('profiles')
        .select()
        .inFilter('id', ids);
    return (data as List).map((e) => AppUser.fromJson(e)).toList();
  }

  Future<AppUser?> getProfileByEmail(String email) async {
    final data = await supabase
        .from('profiles')
        .select()
        .eq('email', email)
        .maybeSingle();
    if (data == null) return null;
    return AppUser.fromJson(data);
  }

  Future<void> updateProfile({
    required String userId,
    String? displayName,
    String? avatarUrl,
  }) async {
    await supabase.from('profiles').update({
      if (displayName != null) 'display_name': displayName,
      if (avatarUrl != null) 'avatar_url': avatarUrl,
    }).eq('id', userId);
  }
}
