import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_state_provider.dart';
import '../../profiles/data/profile_repository.dart';
import 'chat_models.dart';

class DuoStateNotifier extends AsyncNotifier<DuoState> {
  @override
  Future<DuoState> build() async {
    final userId = ref.watch(authUserIdProvider);
    if (userId == null) {
      return DuoState.empty;
    }

    final profile = await ref
        .watch(profileRepositoryProvider)
        .getCurrentProfile(userId);
    return DuoState(
      currentUserId: userId,
      activePartnerId: profile?.activePartnerId,
    );
  }

  Future<void> setActivePartner(String partnerId) async {
    final currentState = state.valueOrNull;
    final currentUserId = currentState?.currentUserId;
    if (currentUserId == null) {
      return;
    }

    final previousState = currentState;
    state = AsyncValue.data(
      DuoState(currentUserId: currentUserId, activePartnerId: partnerId),
    );

    try {
      await ref
          .read(profileRepositoryProvider)
          .updateActivePartner(userId: currentUserId, partnerId: partnerId);
    } catch (_) {
      state = AsyncValue.data(previousState ?? DuoState.empty);
      rethrow;
    }

    ref.invalidateSelf();
  }
}

final duoStateProvider = AsyncNotifierProvider<DuoStateNotifier, DuoState>(
  DuoStateNotifier.new,
);
