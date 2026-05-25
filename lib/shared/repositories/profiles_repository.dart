import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/auth/models/app_user.dart';
import 'supabase_client.dart';

class ProfilesRepository {
  const ProfilesRepository(this._client);

  final SupabaseClient _client;

  /// Fetches a single profile by [userId].
  Future<AppUser?> fetchProfile(String userId) async {
    final data = await _client
        .from('profiles')
        .select()
        .eq('id', userId)
        .maybeSingle();
    if (data == null) return null;
    return AppUser.fromJson(data);
  }

  /// Fetches multiple profiles by their ids.
  Future<List<AppUser>> fetchProfiles(List<String> userIds) async {
    if (userIds.isEmpty) return [];
    final data = await _client
        .from('profiles')
        .select()
        .inFilter('id', userIds);
    return (data as List).map((e) => AppUser.fromJson(e)).toList();
  }

  /// Looks up a profile by [email]. Returns null if not found.
  Future<AppUser?> fetchProfileByEmail(String email) async {
    final data = await _client
        .from('profiles')
        .select()
        .eq('email', email.toLowerCase().trim())
        .maybeSingle();
    if (data == null) return null;
    return AppUser.fromJson(data);
  }

  /// Updates the current user's display name.
  Future<void> updateDisplayName(String userId, String displayName) async {
    await _client
        .from('profiles')
        .update({'display_name': displayName})
        .eq('id', userId);
  }

  /// Updates avatar URL.
  Future<void> updateAvatarUrl(String userId, String avatarUrl) async {
    await _client
        .from('profiles')
        .update({'avatar_url': avatarUrl})
        .eq('id', userId);
  }
}

final profilesRepositoryProvider = Provider<ProfilesRepository>((ref) {
  return ProfilesRepository(ref.watch(supabaseClientProvider));
});
