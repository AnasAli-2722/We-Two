import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'chat_models.dart';
import 'duo_state_notifier.dart';
import '../data/chat_repository.dart';

final messageStreamProvider = StreamProvider.autoDispose<List<ChatMessage>>((
  ref,
) {
  final duoState = ref.watch(duoStateProvider).value;
  final currentUserId = Supabase.instance.client.auth.currentUser?.id;
  final activePartnerId = duoState?.activePartnerId;

  if (currentUserId == null || activePartnerId == null) {
    return const Stream<List<ChatMessage>>.empty();
  }

  return ref
      .watch(chatRepositoryProvider)
      .watchMessages(currentUserId: currentUserId, partnerId: activePartnerId)
      .handleError((error) {
        debugPrint('Stream Error: $error');
      })
      .map(
        (rows) =>
            rows.map(ChatMessage.fromMap).toList(growable: false)
              ..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
      );
});
