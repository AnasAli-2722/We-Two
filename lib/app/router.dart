import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/providers.dart';
import '../features/auth/application/auth_state_provider.dart';
import '../features/auth/presentation/sign_in_screen.dart';
import '../features/people/presentation/discovery_screen.dart';
import '../features/people/presentation/find_partner_screen.dart';
import '../features/profiles/models/profile.dart';
import '../features/profiles/presentation/edit_profile_screen.dart';
import '../features/profiles/presentation/profile_screen.dart';
import '../features/profiles/presentation/profile_setup_screen.dart';
import '../features/profiles/presentation/settings_screen.dart';
import 'auth_gate_screen.dart';
import 'scaffold_with_nav_bar.dart';
import 'setup_required_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final isConfigured = ref.watch(supabaseConfiguredProvider);
  final authGateAsync = ref.watch(authGateProvider);

  return GoRouter(
    initialLocation: isConfigured ? '/gate' : '/setup',
    routes: [
      GoRoute(path: '/', redirect: (context, state) => '/chat'),
      GoRoute(
        path: '/setup',
        builder: (context, state) => const SetupRequiredScreen(),
      ),
      GoRoute(
        path: '/gate',
        builder: (context, state) => const AuthGateScreen(),
      ),
      GoRoute(path: '/auth', builder: (context, state) => const AuthScreen()),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/edit_profile',
        builder: (context, state) {
          final profile = state.extra is Profile
              ? state.extra as Profile
              : null;
          return EditProfileScreen(profile: profile);
        },
      ),
      GoRoute(
        path: '/profile_setup',
        builder: (context, state) => const ProfileSetupScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return ScaffoldWithNavBar(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/chat',
                builder: (context, state) => const FindPartnerScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/discovery',
                builder: (context, state) => const DiscoveryScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                builder: (context, state) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
    redirect: (context, state) {
      final path = state.uri.path;

      if (!isConfigured) {
        return path == '/setup' ? null : '/setup';
      }

      if (authGateAsync.isLoading) {
        return path == '/gate' ? null : '/gate';
      }

      final gate = authGateAsync.valueOrNull ?? AuthGate.unauthenticated;

      if (gate == AuthGate.unauthenticated) {
        return path == '/auth' ? null : '/auth';
      }

      if (gate == AuthGate.profileSetupRequired) {
        return path == '/profile_setup' ? null : '/profile_setup';
      }

      if (path == '/auth' ||
          path == '/setup' ||
          path == '/profile_setup' ||
          path == '/gate') {
        return '/chat';
      }

      return null;
    },
  );
});
