import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme_engine.dart';
import '../../auth/application/auth_state_provider.dart';
import '../../chat/application/duo_state_notifier.dart';
import '../../chat/presentation/chat_screen.dart';
import '../../chat/presentation/contact_sheet.dart';
import '../../profiles/data/profile_repository.dart';
import 'duo_app_bar.dart';

final _myAvatarProvider = FutureProvider<String?>((ref) async {
  final userId = ref.watch(authUserIdProvider);
  if (userId == null) {
    return null;
  }

  final profile = await ref
      .watch(profileRepositoryProvider)
      .getCurrentProfile(userId);
  return profile?.avatarUrl;
});

class FindPartnerScreen extends ConsumerWidget {
  const FindPartnerScreen({super.key});

  Future<void> _openContactSelector(BuildContext context, WidgetRef ref) async {
    final currentUserId = ref.read(authUserIdProvider);
    if (currentUserId == null) {
      return;
    }
    final theme = Theme.of(context);
    final appColors = theme.extension<WeTwoThemeColors>();
    final background = appColors?.background ?? theme.scaffoldBackgroundColor;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: background,
      isScrollControlled: true,
      builder: (context) => ContactSheet(currentUserId: currentUserId),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final duoStateAsync = ref.watch(duoStateProvider);
    final avatarAsync = ref.watch(_myAvatarProvider);
    final theme = Theme.of(context);
    final appColors = theme.extension<WeTwoThemeColors>();
    final accent = appColors?.accent ?? theme.colorScheme.primary;
    final surface = appColors?.surface ?? theme.colorScheme.surface;
    final background = appColors?.background ?? theme.scaffoldBackgroundColor;

    return duoStateAsync.when(
      loading: () => Scaffold(
        backgroundColor: background,
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (error, stackTrace) => Scaffold(
        backgroundColor: background,
        appBar: DuoAppBar(
          avatarUrl: avatarAsync.valueOrNull,
          onPeopleTap: () => _openContactSelector(context, ref),
        ),
        body: Center(
          child: Text(
            'Unable to load duo state',
            style: TextStyle(color: accent),
          ),
        ),
      ),
      data: (duoState) {
        final activePartnerId = duoState.activePartnerId;
        if (activePartnerId == null || activePartnerId.isEmpty) {
          return Scaffold(
            backgroundColor: background,
            appBar: DuoAppBar(
              avatarUrl: avatarAsync.valueOrNull,
              onPeopleTap: () => _openContactSelector(context, ref),
            ),
            body: Column(
              children: [
                Expanded(
                  child: Center(
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: 1),
                      duration: const Duration(milliseconds: 260),
                      curve: Curves.easeOut,
                      builder: (context, value, child) {
                        return Opacity(
                          opacity: value,
                          child: Transform.scale(
                            scale: 0.96 + (0.04 * value),
                            child: child,
                          ),
                        );
                      },
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 24),
                        padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
                        decoration: BoxDecoration(
                          color: surface,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.08),
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircleAvatar(
                              radius: 26,
                              backgroundColor: accent.withValues(alpha: 0.18),
                              child: Icon(
                                Icons.people_alt_outlined,
                                color: accent,
                                size: 26,
                              ),
                            ),
                            const SizedBox(height: 14),
                            const Text(
                              'Add friends to start chatting',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Search users, send requests, and choose your active duo.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white54,
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.only(
                    bottom: 24 + MediaQuery.paddingOf(context).bottom + 66,
                  ),
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(160, 48),
                      backgroundColor: accent,
                      foregroundColor: Colors.black,
                      shape: const StadiumBorder(),
                    ),
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      context.go('/discovery');
                    },
                    child: const Text('Find Friends'),
                  ),
                ),
              ],
            ),
          );
        }

        return const ChatScreen();
      },
    );
  }
}
