import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_state_provider.dart';
import '../data/people_repository.dart';

class ActiveDuoNotifier extends AsyncNotifier<String?> {
  @override
  Future<String?> build() async {
    final userId = ref.watch(authUserIdProvider);
    if (userId == null) {
      return null;
    }

    return ref.watch(peopleRepositoryProvider).getActivePartnerId(userId);
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }
}

final activeDuoProvider = AsyncNotifierProvider<ActiveDuoNotifier, String?>(
  ActiveDuoNotifier.new,
);
