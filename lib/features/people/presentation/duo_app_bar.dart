import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme_engine.dart';
import '../../chat/application/duo_state_notifier.dart';
import '../../profiles/data/profile_repository.dart';
import '../../profiles/models/profile.dart';
import '../../profiles/presentation/profile_card_popup.dart';

final _activePartnerProfileProvider = FutureProvider.autoDispose<Profile?>((
  ref,
) async {
  final duoState = ref.watch(duoStateProvider).valueOrNull;
  final activePartnerId = duoState?.activePartnerId;
  if (activePartnerId == null || activePartnerId.isEmpty) {
    return null;
  }

  return ref
      .watch(profileRepositoryProvider)
      .getCurrentProfile(activePartnerId);
});

class DuoAppBar extends ConsumerWidget implements PreferredSizeWidget {
  const DuoAppBar({
    super.key,
    this.avatarUrl,
    this.fallbackTitle = 'We Two',
    this.onPeopleTap,
    this.showPeopleAction = true,
  });

  final String? avatarUrl;
  final String fallbackTitle;
  final VoidCallback? onPeopleTap;
  final bool showPeopleAction;

  @override
  Size get preferredSize => const Size.fromHeight(78);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final appColors = theme.extension<WeTwoThemeColors>();
    final accent = appColors?.accent ?? theme.colorScheme.primary;
    final surface = appColors?.surface ?? theme.colorScheme.surface;
    final partnerAsync = ref.watch(_activePartnerProfileProvider);

    final partner = partnerAsync.valueOrNull;
    final partnerName = partner?.firstName?.trim().isNotEmpty == true
        ? partner!.firstName!.trim()
        : (partner?.username.trim().isNotEmpty == true
              ? partner!.username.trim()
              : fallbackTitle);
    final resolvedAvatarUrl =
        partner?.avatarUrl != null && partner!.avatarUrl!.isNotEmpty
        ? partner.avatarUrl
        : avatarUrl;

    return SafeArea(
      bottom: false,
      child: Container(
        height: preferredSize.height,
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
            GestureDetector(
              onTap: partner == null
                  ? null
                  : () => showProfileCardPopup(context, partner.id),
              child: CircleAvatar(
                radius: 19,
                backgroundColor: const Color(0xFF252533),
                backgroundImage:
                    resolvedAvatarUrl != null && resolvedAvatarUrl.isNotEmpty
                    ? CachedNetworkImageProvider(resolvedAvatarUrl)
                    : null,
                child: resolvedAvatarUrl == null || resolvedAvatarUrl.isEmpty
                    ? Icon(Icons.person_rounded, color: accent, size: 18)
                    : null,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                partnerName,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (showPeopleAction)
              IconButton(
                onPressed: onPeopleTap,
                icon: Icon(Icons.people_outline_rounded, color: accent),
              ),
          ],
        ),
      ),
    );
  }
}
