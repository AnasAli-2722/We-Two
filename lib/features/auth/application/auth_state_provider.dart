import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/providers.dart';
import '../../profiles/data/profile_repository.dart';
import '../data/auth_repository.dart';

final authSessionProvider = StreamProvider<Session?>((ref) {
  if (!ref.watch(supabaseConfiguredProvider)) {
    return Stream<Session?>.value(null);
  }

  return ref.watch(authRepositoryProvider).authStateChanges();
});

final authUserIdProvider = Provider<String?>((ref) {
  return ref.watch(authSessionProvider).valueOrNull?.user.id;
});

enum AuthGate { unauthenticated, profileSetupRequired, authenticated }

final authGateProvider = FutureProvider<AuthGate>((ref) async {
  final session = await ref.watch(authSessionProvider.future);
  if (session == null) {
    return AuthGate.unauthenticated;
  }

  final user = session.user;
  final isVerified =
      user.emailConfirmedAt != null || user.phoneConfirmedAt != null;
  if (!isVerified) {
    return AuthGate.unauthenticated;
  }

  final profile = await ref
      .watch(profileRepositoryProvider)
      .getCurrentProfile(session.user.id);

  if (profile == null || profile.needsProfileSetup) {
    return AuthGate.profileSetupRequired;
  }

  return AuthGate.authenticated;
});
