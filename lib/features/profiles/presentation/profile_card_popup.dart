import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/theme_utils.dart';
import '../../auth/application/auth_state_provider.dart';
import '../../chat/application/duo_state_notifier.dart';
import '../../people/application/discovery_notifier.dart';
import '../../people/application/friends_provider.dart';
import '../../people/data/people_repository.dart';
import '../../profiles/application/profile_state_notifier.dart';
import '../../profiles/data/profile_repository.dart';
import '../../profiles/models/profile.dart';
import 'profile_screen.dart';

Future<void> showProfileCardPopup(BuildContext context, String userId) {
  return showDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierColor: const Color(0xCC0D0D12),
    builder: (context) {
      return _ProfileCardPopupSheet(userId: userId);
    },
  );
}

final _popupProfileProvider = FutureProvider.family<Profile?, String>((
  ref,
  userId,
) {
  return ref.watch(profileRepositoryProvider).getProfileById(userId);
});

class _ProfileCardPopupSheet extends ConsumerStatefulWidget {
  const _ProfileCardPopupSheet({required this.userId});

  final String userId;

  @override
  ConsumerState<_ProfileCardPopupSheet> createState() =>
      _ProfileCardPopupSheetState();
}

class _ProfileCardPopupSheetState
    extends ConsumerState<_ProfileCardPopupSheet> {
  bool _isActionLoading = false;
  bool? _isFriend;
  bool _isRequestPending = false;

  @override
  void initState() {
    super.initState();
    _refreshFriendStatus();
  }

  Future<void> _refreshFriendStatus() async {
    final currentUserId = ref.read(authUserIdProvider);
    if (currentUserId == null || currentUserId == widget.userId) {
      if (mounted) {
        setState(() => _isFriend = false);
      }
      return;
    }

    final isFriend = await ref
        .read(peopleRepositoryProvider)
        .areFriends(currentUserId: currentUserId, otherUserId: widget.userId);
    final outgoingPendingIds = await ref
        .read(peopleRepositoryProvider)
        .getOutgoingPendingRequestUserIds(currentUserId);
    final isRequestPending =
        !isFriend && outgoingPendingIds.contains(widget.userId);

    if (!mounted) {
      return;
    }
    setState(() {
      _isFriend = isFriend;
      _isRequestPending = isRequestPending;
    });
  }

  Future<void> _handleFriendAction() async {
    final currentUserId = ref.read(authUserIdProvider);
    if (currentUserId == null || _isActionLoading) {
      return;
    }

    setState(() => _isActionLoading = true);
    try {
      final repo = ref.read(peopleRepositoryProvider);
      if (_isFriend == true) {
        await repo.unfriend(
          currentUserId: currentUserId,
          otherUserId: widget.userId,
        );
        _isRequestPending = false;
      } else {
        await repo.sendPartnerRequest(
          fromUserId: currentUserId,
          toUserId: widget.userId,
        );
        _isRequestPending = true;
      }
      ref.invalidate(friendsProvider);
      ref.invalidate(outgoingPendingRequestUserIdsProvider);
      ref.invalidate(duoStateProvider);
      ref.invalidate(profileStateProvider);
      await _refreshFriendStatus();
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to complete this action.')),
      );
    } finally {
      if (mounted) {
        setState(() => _isActionLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(_popupProfileProvider(widget.userId));

    return profileAsync.when(
      loading: () => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 340),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1F22),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Center(child: CircularProgressIndicator()),
        ),
      ),
      error: (error, stackTrace) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 340),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1F22),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Text(
            'Unable to load profile card',
            style: TextStyle(color: Colors.white70),
          ),
        ),
      ),
      data: (profile) {
        if (profile == null) {
          return Dialog(
            backgroundColor: Colors.transparent,
            elevation: 0,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 340),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1F22),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Text(
                'Profile not found',
                style: TextStyle(color: Colors.white70),
              ),
            ),
          );
        }

        final parsedColor = _parseHexColor(profile.profileColor);
        final displayName = _displayName(profile);
        final username = profile.username.trim().isEmpty
            ? 'unknown'
            : profile.username.trim();
        final coverAvailable =
            profile.coverUrl != null && profile.coverUrl!.trim().isNotEmpty;
        final aboutText = profile.bio?.trim();
        final hasAbout = aboutText != null && aboutText.isNotEmpty;

        return Theme(
          data: generateProfileTheme(parsedColor),
          child: Builder(
            builder: (context) {
              final localTheme = Theme.of(context);
              final dialogBg =
                  localTheme.dialogTheme.backgroundColor ??
                  localTheme.cardColor;
              return Dialog(
                backgroundColor: Colors.transparent,
                elevation: 0,
                insetPadding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 24,
                ),
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 340),
                  decoration: BoxDecoration(
                    color: dialogBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: localTheme.primaryColor.withValues(alpha: 0.35),
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        height: 152,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Container(
                              height: 120,
                              width: double.infinity,
                              color: coverAvailable
                                  ? null
                                  : localTheme.scaffoldBackgroundColor,
                              child: coverAvailable
                                  ? CachedNetworkImage(
                                      imageUrl: profile.coverUrl!,
                                      fit: BoxFit.cover,
                                    )
                                  : null,
                            ),
                            Positioned(
                              left: 16,
                              bottom: 0,
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: dialogBg,
                                  shape: BoxShape.circle,
                                ),
                                child: CircleAvatar(
                                  radius: 40,
                                  backgroundColor: localTheme.cardColor,
                                  backgroundImage:
                                      profile.avatarUrl != null &&
                                          profile.avatarUrl!.trim().isNotEmpty
                                      ? CachedNetworkImageProvider(
                                          profile.avatarUrl!,
                                        )
                                      : null,
                                  child:
                                      profile.avatarUrl == null ||
                                          profile.avatarUrl!.trim().isEmpty
                                      ? const Icon(
                                          Icons.person_rounded,
                                          size: 36,
                                          color: Colors.white70,
                                        )
                                      : null,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            InkWell(
                              borderRadius: BorderRadius.circular(10),
                              onTap: () {
                                final navigator = Navigator.of(context);
                                navigator.pop();
                                navigator.push(
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        ProfileScreen(userId: profile.id),
                                  ),
                                );
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 2,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      displayName,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 22,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '@$username',
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 14,
                                      ),
                                    ),
                                    if (hasAbout) ...[
                                      const SizedBox(height: 8),
                                      Text(
                                        aboutText,
                                        style: const TextStyle(
                                          color: Colors.white70,
                                          fontSize: 13,
                                          height: 1.35,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                            if (ref.read(authUserIdProvider) != profile.id) ...[
                              const SizedBox(height: 12),
                              Divider(
                                color: Colors.white.withValues(alpha: 0.16),
                                height: 1,
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: FilledButton(
                                  onPressed: _isActionLoading
                                      ? null
                                      : (_isFriend == true ||
                                            !_isRequestPending)
                                      ? _handleFriendAction
                                      : null,
                                  style: FilledButton.styleFrom(
                                    backgroundColor: localTheme.primaryColor,
                                    foregroundColor: Colors.black,
                                  ),
                                  child: _isActionLoading
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : Text(
                                          _isFriend == true
                                              ? 'Unfriend'
                                              : (_isRequestPending
                                                    ? 'Request Sent'
                                                    : 'Add Friend'),
                                        ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  String _displayName(Profile profile) {
    if (profile.fullName.isNotEmpty) {
      return profile.fullName;
    }
    return profile.username.trim().isEmpty ? 'Unknown user' : profile.username;
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
