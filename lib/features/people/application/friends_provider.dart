import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_state_provider.dart';
import '../../profiles/data/profile_repository.dart';
import '../../profiles/models/profile.dart';

final friendsProvider = FutureProvider.autoDispose<List<Profile>>((ref) async {
  final userId = ref.watch(authUserIdProvider);
  if (userId == null) {
    return const [];
  }

  return ref.watch(profileRepositoryProvider).listContacts(userId);
});
