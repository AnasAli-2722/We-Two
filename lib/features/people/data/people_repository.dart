import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/app_error_reporter.dart';
import '../../../core/providers.dart';
import '../../profiles/models/profile.dart';
import '../models/discovery_user.dart';
import '../models/partner_request.dart';

enum PeopleActionErrorCode {
  duplicate,
  stale,
  unauthorized,
  validation,
  unknown,
}

class PeopleActionException implements Exception {
  const PeopleActionException({required this.code, required this.message});

  final PeopleActionErrorCode code;
  final String message;

  @override
  String toString() => message;
}

class PeopleRepository {
  PeopleRepository(this._client);

  final SupabaseClient _client;

  Future<String?> getActivePartnerId(String userId) async {
    final row = await _client
        .from('profiles')
        .select('active_partner_id')
        .eq('id', userId)
        .maybeSingle();

    if (row == null) {
      return null;
    }

    return row['active_partner_id'] as String?;
  }

  Future<List<DiscoveryUser>> searchUsers({
    required String currentUserId,
    required String searchText,
  }) async {
    final query = searchText.trim();
    if (query.isEmpty) {
      return const [];
    }

    final rows = await _client
        .from('profiles')
        .select('id, username, avatar_url')
        .ilike('username', '%$query%')
        .neq('id', currentUserId)
        .limit(30);

    return (rows as List<dynamic>)
        .map(
          (item) =>
              DiscoveryUser.fromMap(Map<String, dynamic>.from(item as Map)),
        )
        .toList(growable: false);
  }

  Future<void> sendPartnerRequest({
    required String fromUserId,
    required String toUserId,
  }) async {
    if (fromUserId == toUserId) {
      throw const PeopleActionException(
        code: PeopleActionErrorCode.validation,
        message: 'You cannot send a request to yourself.',
      );
    }

    try {
      await _client.rpc(
        'send_partner_request',
        params: <String, dynamic>{
          'p_from_user_id': fromUserId,
          'p_to_user_id': toUserId,
        },
      );
    } on PostgrestException catch (error, stackTrace) {
      AppErrorReporter.report(
        error,
        stackTrace: stackTrace,
        feature: 'people',
        operation: 'sendPartnerRequest.rpc',
        context: <String, Object?>{
          'fromUserId': fromUserId,
          'toUserId': toUserId,
          'code': error.code,
          'message': error.message,
        },
      );
      throw _mapRpcException(error);
    }
  }

  Future<bool> areFriends({
    required String currentUserId,
    required String otherUserId,
  }) async {
    final rows = await _client
        .from('partner_requests')
        .select('id')
        .eq('status', 'accepted')
        .or(
          'and(from_user_id.eq.$currentUserId,to_user_id.eq.$otherUserId),and(from_user_id.eq.$otherUserId,to_user_id.eq.$currentUserId)',
        )
        .limit(1);

    return (rows as List<dynamic>).isNotEmpty;
  }

  Future<void> unfriend({
    required String currentUserId,
    required String otherUserId,
  }) async {
    await _client
        .from('partner_requests')
        .delete()
        .eq('status', 'accepted')
        .or(
          'and(from_user_id.eq.$currentUserId,to_user_id.eq.$otherUserId),and(from_user_id.eq.$otherUserId,to_user_id.eq.$currentUserId)',
        );

    await _client
        .from('profiles')
        .update(<String, dynamic>{'active_partner_id': null})
        .eq('id', currentUserId)
        .eq('active_partner_id', otherUserId);

    await _client
        .from('profiles')
        .update(<String, dynamic>{'active_partner_id': null})
        .eq('id', otherUserId)
        .eq('active_partner_id', currentUserId);
  }

  Future<List<Profile>> listAcceptedFriends(String userId) async {
    final rows = await _client
        .from('partner_requests')
        .select('from_user_id, to_user_id')
        .eq('status', 'accepted')
        .or('from_user_id.eq.$userId,to_user_id.eq.$userId');

    final Set<String> friendIds = <String>{};
    for (final row in (rows as List<dynamic>)) {
      final map = Map<String, dynamic>.from(row as Map);
      final fromUserId = map['from_user_id'] as String?;
      final toUserId = map['to_user_id'] as String?;

      if (fromUserId == userId && toUserId != null) {
        friendIds.add(toUserId);
      }
      if (toUserId == userId && fromUserId != null) {
        friendIds.add(fromUserId);
      }
    }

    if (friendIds.isEmpty) {
      return const [];
    }

    final profiles = await _client
        .from('profiles')
        .select()
        .inFilter('id', friendIds.toList(growable: false))
        .order('username');

    return (profiles as List<dynamic>)
        .map((item) => Profile.fromMap(Map<String, dynamic>.from(item as Map)))
        .toList(growable: false);
  }

  Future<List<PartnerRequest>> getPendingRequests(String userId) async {
    final rows = await _client
        .from('partner_requests')
        .select('id, from_user_id')
        .eq('to_user_id', userId)
        .eq('status', 'pending')
        .order('created_at', ascending: false);

    final requestMaps = (rows as List<dynamic>)
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList(growable: false);

    if (requestMaps.isEmpty) {
      return const [];
    }

    final fromUserIds = requestMaps
        .map((row) => row['from_user_id'] as String?)
        .whereType<String>()
        .toSet()
        .toList(growable: false);

    Map<String, Map<String, dynamic>> profilesById =
        <String, Map<String, dynamic>>{};

    if (fromUserIds.isNotEmpty) {
      try {
        final profileRows = await _client
            .from('profiles')
            .select('id, username, avatar_url')
            .inFilter('id', fromUserIds);

        profilesById = {
          for (final raw in (profileRows as List<dynamic>))
            (raw as Map<String, dynamic>)['id'] as String:
                Map<String, dynamic>.from(raw),
        };
      } catch (error, stackTrace) {
        AppErrorReporter.report(
          error,
          stackTrace: stackTrace,
          feature: 'people',
          operation: 'getPendingRequests.profilesLookup',
          context: <String, Object?>{'userId': userId},
        );
      }
    }

    return requestMaps
        .map((row) {
          final fromUserId = row['from_user_id'] as String;
          final profile = profilesById[fromUserId];

          return PartnerRequest(
            id: row['id'] as String,
            fromUserId: fromUserId,
            username:
                ((profile?['username'] as String?)?.trim().isNotEmpty ?? false)
                ? profile!['username'] as String
                : 'Unknown',
            avatarUrl: profile?['avatar_url'] as String?,
          );
        })
        .toList(growable: false);
  }

  Future<Set<String>> getOutgoingPendingRequestUserIds(String userId) async {
    final rows = await _client
        .from('partner_requests')
        .select('to_user_id')
        .eq('from_user_id', userId)
        .eq('status', 'pending');

    final ids = <String>{};
    for (final item in (rows as List<dynamic>)) {
      final map = Map<String, dynamic>.from(item as Map);
      final toUserId = map['to_user_id'] as String?;
      if (toUserId != null && toUserId.isNotEmpty) {
        ids.add(toUserId);
      }
    }
    return ids;
  }

  Future<void> respondToRequest({
    required String requestId,
    required bool accept,
    required String currentUserId,
  }) async {
    try {
      await _client.rpc(
        'respond_partner_request',
        params: <String, dynamic>{
          'p_request_id': requestId,
          'p_accept': accept,
          'p_current_user_id': currentUserId,
        },
      );
    } on PostgrestException catch (error, stackTrace) {
      AppErrorReporter.report(
        error,
        stackTrace: stackTrace,
        feature: 'people',
        operation: 'respondToRequest.rpc',
        context: <String, Object?>{
          'requestId': requestId,
          'accept': accept,
          'currentUserId': currentUserId,
        },
      );
      throw _mapRpcException(error);
    }
  }

  PeopleActionException _mapRpcException(PostgrestException error) {
    final code = error.code?.trim();
    final rawMessage = error.message.trim();
    final message = rawMessage.toLowerCase();

    if (code == '23505' || message.contains('duplicate')) {
      return const PeopleActionException(
        code: PeopleActionErrorCode.duplicate,
        message: 'Request already exists.',
      );
    }

    if (message.contains('not found') ||
        message.contains('already handled') ||
        message.contains('no rows')) {
      return const PeopleActionException(
        code: PeopleActionErrorCode.stale,
        message: 'This request is no longer available.',
      );
    }

    if (code == '42501' || message.contains('permission denied')) {
      return const PeopleActionException(
        code: PeopleActionErrorCode.unauthorized,
        message: 'You are not allowed to do this action.',
      );
    }

    if (message.contains('invalid') || message.contains('cannot')) {
      return PeopleActionException(
        code: PeopleActionErrorCode.validation,
        message: rawMessage.isEmpty ? 'Action is invalid.' : rawMessage,
      );
    }

    return PeopleActionException(
      code: PeopleActionErrorCode.unknown,
      message: rawMessage.isEmpty ? 'Unable to complete request.' : rawMessage,
    );
  }

  Future<int> getUnseenRequestsCount(String userId) async {
    try {
      final rows = await _client
          .from('partner_requests')
          .select('id')
          .eq('to_user_id', userId)
          .eq('status', 'pending')
          .eq('is_seen', false);
      return (rows as List<dynamic>).length;
    } catch (_) {
      return 0;
    }
  }

  Future<void> markRequestsSeen(String userId) async {
    try {
      await _client
          .from('partner_requests')
          .update(<String, dynamic>{'is_seen': true})
          .eq('to_user_id', userId)
          .eq('status', 'pending')
          .eq('is_seen', false);
    } catch (_) {
      // ignore schema differences
    }
  }
}

final peopleRepositoryProvider = Provider<PeopleRepository>((ref) {
  return PeopleRepository(ref.watch(supabaseClientProvider));
});
