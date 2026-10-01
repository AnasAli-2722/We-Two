import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme_engine.dart';
import '../../../core/widgets/empty_state_widget.dart';
import '../../../core/widgets/shimmer_skeleton.dart';
import '../../profiles/presentation/profile_card_popup.dart';
import '../application/discovery_notifier.dart';
import '../application/friends_provider.dart';
import 'requests_modal.dart';

class DiscoveryScreen extends ConsumerStatefulWidget {
  const DiscoveryScreen({super.key});

  @override
  ConsumerState<DiscoveryScreen> createState() => _DiscoveryScreenState();
}

class _DiscoveryScreenState extends ConsumerState<DiscoveryScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _openRequests() async {
    unawaited(HapticFeedback.selectionClick());
    final notifier = ref.read(discoveryStateProvider.notifier);
    unawaited(notifier.markRequestsSeen());
    final theme = Theme.of(context);
    final appColors = theme.extension<WeTwoThemeColors>();
    final background = appColors?.background ?? theme.scaffoldBackgroundColor;

    if (!context.mounted) {
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: background,
      showDragHandle: true,
      builder: (context) => const RequestsModal(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(discoveryStateProvider);
    final notifier = ref.read(discoveryStateProvider.notifier);
    final searchAsync = ref.watch(searchUsersProvider(state.query));
    final unseenCountAsync = ref.watch(unseenRequestsCountProvider);
    final outgoingPendingAsync = ref.watch(
      outgoingPendingRequestUserIdsProvider,
    );
    final friendsAsync = ref.watch(friendsProvider);
    final theme = Theme.of(context);
    final appColors = theme.extension<WeTwoThemeColors>();
    final accent = appColors?.accent ?? theme.colorScheme.primary;
    final surface = appColors?.surface ?? theme.colorScheme.surface;
    final background = appColors?.background ?? theme.scaffoldBackgroundColor;

    return Scaffold(
      backgroundColor: background,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.fromLTRB(12, 6, 12, 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              decoration: BoxDecoration(
                color: surface,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.28),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () {
                      final navigator = Navigator.of(context);
                      if (navigator.canPop()) {
                        navigator.pop();
                        return;
                      }
                      context.go('/chat');
                    },
                    tooltip: 'Back to chat',
                    icon: const Icon(
                      Icons.arrow_back_rounded,
                      color: Colors.white,
                    ),
                  ),
                  const Expanded(
                    child: Text(
                      'Friends',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _openRequests,
                    tooltip: 'Open requests',
                    icon: const Icon(
                      Icons.mail_outline_rounded,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Column(
                children: [
                  TextField(
                    controller: _searchController,
                    style: const TextStyle(color: Colors.white),
                    onChanged: notifier.setQuery,
                    decoration: InputDecoration(
                      hintText: 'Search by username...',
                      hintStyle: const TextStyle(color: Colors.white38),
                      filled: true,
                      fillColor: surface,
                      suffixIcon: const Icon(
                        Icons.search_rounded,
                        color: Colors.white54,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: BorderSide(
                          color: Colors.white.withValues(alpha: 0.08),
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: BorderSide(
                          color: Colors.white.withValues(alpha: 0.08),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: BorderSide(color: accent, width: 1.2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            shape: const StadiumBorder(),
                            backgroundColor: surface,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            side: BorderSide(
                              color: Colors.white.withValues(alpha: 0.08),
                            ),
                          ),
                          onPressed: _openRequests,
                          child: const Text('Requests'),
                        ),
                        if ((unseenCountAsync.valueOrNull ?? 0) > 0)
                          const Positioned(
                            right: -2,
                            top: -2,
                            child: _RedDotBadge(),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Your Friends',
                      style: TextStyle(
                        color: accent,
                        fontSize: 14,
                        letterSpacing: 0.2,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: state.query.trim().isEmpty
                  ? friendsAsync.when(
                      loading: () => const _FriendsShimmer(),
                      error: (error, stackTrace) => const Center(
                        child: Text(
                          'Unable to load friends',
                          style: TextStyle(color: Colors.white54),
                        ),
                      ),
                      data: (friends) {
                        if (friends.isEmpty) {
                          return const Center(
                            child: EmptyStateWidget(
                              icon: Icons.diversity_1_outlined,
                              title: "It's quiet here",
                              subtitle:
                                  'Search for your partner above to start connecting.',
                            ),
                          );
                        }

                        return ListView.builder(
                          padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                          itemCount: friends.length,
                          itemBuilder: (context, index) {
                            final friend = friends[index];
                            final borderColor =
                                _parseHexColor(
                                  friend.profileColor,
                                )?.withValues(alpha: 0.7) ??
                                Colors.white.withValues(alpha: 0.08);

                            return Card(
                              elevation: 0,
                              margin: const EdgeInsets.only(bottom: 12),
                              color: surface,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                                side: BorderSide(color: borderColor),
                              ),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(20),
                                onTap: () =>
                                    showProfileCardPopup(context, friend.id),
                                child: Padding(
                                  padding: const EdgeInsets.all(14),
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 28,
                                        backgroundColor: surface,
                                        backgroundImage:
                                            friend.avatarUrl != null &&
                                                friend.avatarUrl!.isNotEmpty
                                            ? CachedNetworkImageProvider(
                                                friend.avatarUrl!,
                                              )
                                            : null,
                                        child:
                                            friend.avatarUrl == null ||
                                                friend.avatarUrl!.isEmpty
                                            ? Icon(
                                                Icons.person,
                                                size: 24,
                                                color: accent,
                                              )
                                            : null,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              friend.fullName.isEmpty
                                                  ? friend.username
                                                  : friend.fullName,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.w700,
                                                fontSize: 16,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              '@${friend.username}',
                                              style: const TextStyle(
                                                color: Colors.white60,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        );
                      },
                    )
                  : searchAsync.when(
                      loading: () => const _DiscoveryResultsShimmer(),
                      error: (error, stackTrace) => Center(
                        child: Text(
                          'Failed to search users',
                          style: TextStyle(color: accent),
                        ),
                      ),
                      data: (results) {
                        if (results.isEmpty) {
                          return const Center(
                            child: EmptyStateWidget(
                              icon: Icons.search_off_rounded,
                              title: 'No users found',
                              subtitle:
                                  'Try searching for a different username.',
                            ),
                          );
                        }

                        return ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: results.length,
                          itemBuilder: (context, index) {
                            final user = results[index];
                            final outgoingPendingIds =
                                outgoingPendingAsync.valueOrNull ??
                                const <String>{};
                            final requestAlreadyPending = outgoingPendingIds
                                .contains(user.id);
                            final isSendingThisUser = state.isSendingRequestTo(
                              user.id,
                            );
                            final canSendRequest =
                                !requestAlreadyPending &&
                                !isSendingThisUser &&
                                !state.isActionLoading;

                            return TweenAnimationBuilder<double>(
                              tween: Tween(begin: 0, end: 1),
                              duration: Duration(
                                milliseconds: 180 + (index * 35),
                              ),
                              curve: Curves.easeOut,
                              builder: (context, value, child) {
                                return Opacity(
                                  opacity: value,
                                  child: Transform.translate(
                                    offset: Offset(0, (1 - value) * 10),
                                    child: child,
                                  ),
                                );
                              },
                              child: Card(
                                elevation: 0,
                                margin: const EdgeInsets.only(bottom: 10),
                                color: surface,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                  side: BorderSide(
                                    color: Colors.white.withValues(alpha: 0.08),
                                  ),
                                ),
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 4,
                                  ),
                                  leading: CircleAvatar(
                                    radius: 22,
                                    backgroundColor: surface,
                                    backgroundImage:
                                        user.avatarUrl != null &&
                                            user.avatarUrl!.isNotEmpty
                                        ? CachedNetworkImageProvider(
                                            user.avatarUrl!,
                                          )
                                        : null,
                                    child:
                                        user.avatarUrl == null ||
                                            user.avatarUrl!.isEmpty
                                        ? const Icon(
                                            Icons.person,
                                            color: Colors.white70,
                                          )
                                        : null,
                                  ),
                                  title: Text(
                                    user.username,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  trailing: IconButton.filledTonal(
                                    style: IconButton.styleFrom(
                                      backgroundColor: accent.withValues(
                                        alpha: 0.24,
                                      ),
                                      foregroundColor: accent,
                                    ),
                                    onPressed: !canSendRequest
                                        ? null
                                        : () async {
                                            await HapticFeedback.lightImpact();
                                            await notifier.sendRequest(user.id);
                                            if (!context.mounted) {
                                              return;
                                            }
                                            final error = ref
                                                .read(discoveryStateProvider)
                                                .errorMessage;
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  error ?? 'Request sent',
                                                ),
                                              ),
                                            );
                                          },
                                    icon: isSendingThisUser
                                        ? const SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : Icon(
                                            requestAlreadyPending
                                                ? Icons.schedule_rounded
                                                : Icons
                                                      .person_add_alt_1_rounded,
                                          ),
                                  ),
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FriendsShimmer extends StatelessWidget {
  const _FriendsShimmer();

  @override
  Widget build(BuildContext context) {
    return ShimmerSkeleton(
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
        itemCount: 5,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) => Container(
          height: 84,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
        ),
      ),
    );
  }
}

Color? _parseHexColor(String? input) {
  if (input == null || input.trim().isEmpty) {
    return null;
  }
  var value = input.trim().replaceAll('#', '');
  if (value.length == 6) {
    value = 'FF$value';
  }
  if (value.length != 8) {
    return null;
  }
  final parsed = int.tryParse(value, radix: 16);
  if (parsed == null) {
    return null;
  }
  return Color(parsed);
}

class _DiscoveryResultsShimmer extends StatelessWidget {
  const _DiscoveryResultsShimmer();

  @override
  Widget build(BuildContext context) {
    return ShimmerSkeleton(
      child: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: 6,
        separatorBuilder: (context, index) => const SizedBox(height: 10),
        itemBuilder: (context, index) => Container(
          height: 74,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
    );
  }
}

class _RedDotBadge extends StatelessWidget {
  const _RedDotBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10,
      height: 10,
      decoration: const BoxDecoration(
        color: Colors.red,
        shape: BoxShape.circle,
      ),
    );
  }
}
