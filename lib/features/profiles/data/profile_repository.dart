import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/providers.dart';
import '../models/profile.dart';

class ProfileRepository {
  ProfileRepository(this._client);

  final SupabaseClient _client;

  Future<Profile?> getCurrentProfile(String userId) async {
    final response = await _client
        .from('profiles')
        .select()
        .eq('id', userId)
        .maybeSingle();
    if (response == null) {
      return null;
    }

    return Profile.fromMap(Map<String, dynamic>.from(response as Map));
  }

  Future<Profile?> getProfileById(String profileId) async {
    final response = await _client
        .from('profiles')
        .select()
        .eq('id', profileId)
        .maybeSingle();
    if (response == null) {
      return null;
    }

    return Profile.fromMap(Map<String, dynamic>.from(response as Map));
  }

  Future<List<Profile>> listContacts(String userId) async {
    final Set<String> partnerIds = <String>{};

    final acceptedRows = await _client
        .from('partner_requests')
        .select('from_user_id, to_user_id')
        .eq('status', 'accepted')
        .or('from_user_id.eq.$userId,to_user_id.eq.$userId');

    for (final row in (acceptedRows as List<dynamic>)) {
      final map = Map<String, dynamic>.from(row as Map);
      final fromUserId = map['from_user_id'] as String?;
      final toUserId = map['to_user_id'] as String?;

      if (fromUserId == userId && toUserId != null) {
        partnerIds.add(toUserId);
      }
      if (toUserId == userId && fromUserId != null) {
        partnerIds.add(fromUserId);
      }
    }

    final profileRow = await _client
        .from('profiles')
        .select('active_partner_id')
        .eq('id', userId)
        .maybeSingle();
    final activePartnerId = profileRow == null
        ? null
        : profileRow['active_partner_id'] as String?;
    if (activePartnerId != null && activePartnerId.isNotEmpty) {
      partnerIds.add(activePartnerId);
    }

    if (partnerIds.isEmpty) {
      return const [];
    }

    final response = await _client
        .from('profiles')
        .select()
        .inFilter('id', partnerIds.toList(growable: false))
        .order('username');

    return (response as List<dynamic>)
        .map((item) => Profile.fromMap(Map<String, dynamic>.from(item as Map)))
        .toList(growable: false);
  }

  Future<void> updateActivePartner({
    required String userId,
    required String partnerId,
  }) async {
    await _client
        .from('profiles')
        .update(<String, dynamic>{'active_partner_id': partnerId})
        .eq('id', userId);
  }

  Future<void> updateFcmToken({
    required String userId,
    required String token,
  }) async {
    await _client
        .from('profiles')
        .update(<String, dynamic>{'fcm_token': token})
        .eq('id', userId);
  }

  Future<String> uploadAvatar({
    required String userId,
    required Uint8List bytes,
    required String originalFileName,
  }) async {
    await _client.storage
        .from('avatars')
        .uploadBinary(
          userId,
          bytes,
          fileOptions: FileOptions(
            upsert: true,
            contentType: _contentTypeFor(originalFileName),
          ),
        );

    return _client.storage.from('avatars').getPublicUrl(userId);
  }

  Future<String> uploadCover({
    required String userId,
    required Uint8List bytes,
    required String originalFileName,
  }) async {
    await _client.storage
        .from('covers')
        .uploadBinary(
          userId,
          bytes,
          fileOptions: FileOptions(
            upsert: true,
            contentType: _contentTypeFor(originalFileName),
          ),
        );

    return _client.storage.from('covers').getPublicUrl(userId);
  }

  Future<void> updateProfileFields({
    required String userId,
    String? firstName,
    String? lastName,
    String? bio,
    String? avatarUrl,
    String? coverUrl,
    String? profileColor,
    String? themeColor,
  }) async {
    await _client
        .from('profiles')
        .update(<String, dynamic>{
          if (firstName != null) 'first_name': firstName.trim(),
          if (lastName != null)
            'last_name': lastName.trim().isEmpty ? null : lastName.trim(),
          if (bio != null) 'bio': bio.trim().isEmpty ? null : bio.trim(),
          if (avatarUrl != null)
            'avatar_url': avatarUrl.trim().isEmpty ? null : avatarUrl.trim(),
          if (coverUrl != null)
            'cover_url': coverUrl.trim().isEmpty ? null : coverUrl.trim(),
          if (profileColor != null)
            'profile_color': profileColor.trim().isEmpty
                ? null
                : profileColor.trim(),
          if (themeColor != null)
            'theme_color': themeColor.trim().isEmpty ? null : themeColor.trim(),
        })
        .eq('id', userId);
  }

  Future<void> completeProfile({
    required String userId,
    required String fullName,
    required String username,
    String? avatarUrl,
  }) async {
    final normalizedFullName = fullName.trim();
    final normalizedUsername = username.trim();

    final parts = normalizedFullName
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList(growable: false);

    final firstName = parts.isEmpty ? '' : parts.first;
    final lastName = parts.length <= 1 ? null : parts.skip(1).join(' ');

    await _client.from('profiles').upsert(<String, dynamic>{
      'id': userId,
      'username': normalizedUsername,
      'first_name': firstName,
      'last_name': lastName,
      ...?avatarUrl == null ? null : <String, dynamic>{'avatar_url': avatarUrl},
    });
  }

  Future<bool> isUsernameAvailable({
    required String username,
    required String userId,
  }) async {
    final normalizedUsername = username.trim();
    if (normalizedUsername.isEmpty) {
      return false;
    }

    final existing = await _client
        .from('profiles')
        .select('id')
        .eq('username', normalizedUsername)
        .neq('id', userId)
        .maybeSingle();

    return existing == null;
  }

  String _contentTypeFor(String fileName) {
    final extension = fileName.toLowerCase().split('.').last;

    switch (extension) {
      case 'gif':
        return 'image/gif';
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'heic':
        return 'image/heic';
      case 'jpg':
      case 'jpeg':
      default:
        return 'image/jpeg';
    }
  }
}

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository(ref.watch(supabaseClientProvider));
});
