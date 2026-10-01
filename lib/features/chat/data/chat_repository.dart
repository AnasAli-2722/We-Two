import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/providers.dart';

class ChatRepository {
  ChatRepository(this._client);

  final SupabaseClient _client;

  Stream<List<Map<String, dynamic>>> watchMessages({
    required String currentUserId,
    required String partnerId,
  }) {
    final sentByCurrentUserStream = _client
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('sender_id', currentUserId)
        .order('created_at', ascending: false)
        .map(
          (rows) => rows.cast<Map<String, dynamic>>().toList(growable: false),
        );

    final receivedByCurrentUserStream = _client
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('receiver_id', currentUserId)
        .order('created_at', ascending: false)
        .map(
          (rows) => rows.cast<Map<String, dynamic>>().toList(growable: false),
        );

    return Stream.multi((controller) {
      List<Map<String, dynamic>> sentRows = const [];
      List<Map<String, dynamic>> receivedRows = const [];

      void emit() {
        final mergedById = <String, Map<String, dynamic>>{};

        for (final row in [...sentRows, ...receivedRows]) {
          final senderId = row['sender_id'] as String?;
          final receiverId = row['receiver_id'] as String?;
          final sentByCurrentUser =
              senderId == currentUserId && receiverId == partnerId;
          final sentByPartner =
              senderId == partnerId && receiverId == currentUserId;
          if (!sentByCurrentUser && !sentByPartner) {
            continue;
          }

          final id = row['id']?.toString();
          if (id == null || id.isEmpty) {
            continue;
          }
          mergedById[id] = row;
        }

        final result = mergedById.values.toList(growable: false)
          ..sort((a, b) {
            final left = DateTime.tryParse((a['created_at'] ?? '').toString());
            final right = DateTime.tryParse((b['created_at'] ?? '').toString());
            if (left == null && right == null) {
              return 0;
            }
            if (left == null) {
              return 1;
            }
            if (right == null) {
              return -1;
            }
            return right.compareTo(left);
          });

        controller.add(result);
      }

      final sentSub = sentByCurrentUserStream.listen((rows) {
        sentRows = rows;
        emit();
      }, onError: controller.addError);

      final receivedSub = receivedByCurrentUserStream.listen((rows) {
        receivedRows = rows;
        emit();
      }, onError: controller.addError);

      controller.onCancel = () async {
        await sentSub.cancel();
        await receivedSub.cancel();
      };
    });
  }

  Future<void> sendMessage({
    required String senderId,
    required String receiverId,
    required String content,
    String? replyToId,
    DateTime? createdAt,
  }) async {
    await _client.from('messages').insert(<String, dynamic>{
      'sender_id': senderId,
      'receiver_id': receiverId,
      'content': content,
      'created_at': (createdAt ?? DateTime.now()).toUtc().toIso8601String(),
      if (replyToId != null && replyToId.isNotEmpty) 'reply_to_id': replyToId,
    });
  }
}

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  return ChatRepository(ref.watch(supabaseClientProvider));
});
