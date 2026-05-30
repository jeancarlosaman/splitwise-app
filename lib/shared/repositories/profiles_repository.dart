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
    // For revolut/bizum, pass the empty string to CLEAR (we normalize to null
    // in the DB so the AppUser parser returns null too).
    Object? revolutTag = _unset,
    Object? bizumPhone = _unset,
  }) async {
    final updates = <String, dynamic>{
      if (displayName != null) 'display_name': displayName,
      if (avatarUrl != null) 'avatar_url': avatarUrl,
    };
    if (!identical(revolutTag, _unset)) {
      final s = (revolutTag as String?)?.trim();
      updates['revolut_tag'] = (s == null || s.isEmpty) ? null : s;
    }
    if (!identical(bizumPhone, _unset)) {
      final s = (bizumPhone as String?)?.trim();
      updates['bizum_phone'] = (s == null || s.isEmpty) ? null : s;
    }
    if (updates.isEmpty) return;
    await supabase.from('profiles').update(updates).eq('id', userId);
  }
}

// Sentinel so callers can distinguish "don't touch this field" from
// "set this field to null". Without it, a nullable named param can't tell
// the difference between "I want to clear it" and "I didn't pass anything".
const Object _unset = Object();
