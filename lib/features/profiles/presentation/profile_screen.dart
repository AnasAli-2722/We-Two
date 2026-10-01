/*
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../core/theme/theme_utils.dart';
import '../../../core/widgets/shimmer_skeleton.dart';
import '../application/profile_state_notifier.dart';
import '../data/profile_repository.dart';
import '../models/profile.dart';
import 'edit_profile_screen.dart';
import 'settings_screen.dart';

final _activePartnerProvider = FutureProvider.autoDispose<Profile?>((ref) async {
  final profile = ref.watch(profileStateProvider).valueOrNull;
  final partnerId = profile?.activePartnerId;
  if (partnerId == null || partnerId.isEmpty) {
    return null;
  }

  return ref.watch(profileRepositoryProvider).getProfileById(partnerId);
});

final _profileByIdProvider = FutureProvider.autoDispose.family<Profile?, String>((
  ref,
  userId,
) async {
  return ref.watch(profileRepositoryProvider).getProfileById(userId);
});

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key, this.userId});

  final String? userId;

  String _displayName(Profile? profile) {
    if (profile?.firstName?.trim().isNotEmpty == true) {
      final firstName = profile!.firstName!.trim();
      final lastName = profile.lastName?.trim();
      if (lastName != null && lastName.isNotEmpty) {
        return '$firstName $lastName';
      }
      return firstName;
    return 'No name set';
  }

  String _joinedDateText() {
    final createdAt = Supabase.instance.client.auth.currentUser?.createdAt;
    if (createdAt == null || createdAt.trim().isEmpty) {
      return 'Not available';
    final parsed = DateTime.tryParse(createdAt);
    if (parsed == null) {
      return 'Not available';
    final month = switch (parsed.month) {
      1 => 'Jan',
      2 => 'Feb',
      3 => 'Mar',
  4 => 'Apr',
  5 => 'May',
  6 => 'Jun',
  7 => 'Jul',
  8 => 'Aug',
  9 => 'Sep',
  10 => 'Oct',
  11 => 'Nov',
  _ => 'Dec',
    return '$month ${parsed.day}, ${parsed.year}';
  }

  Future<void> _openEditProfile(
    BuildContext context,
    WidgetRef ref,
    Profile? profile,
  ) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => EditProfileScreen(profile: profile)),
    );
    if (result == true && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Profile updated')));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
  final currentUserId = Supabase.instance.client.auth.currentUser?.id;
  final viewingOwnProfile = userId == null || userId == currentUserId;
  final profileAsync = viewingOwnProfile
    ? ref.watch(profileStateProvider)
    : ref.watch(_profileByIdProvider(userId!));
  ref.watch(_activePartnerProvider);
    return profileAsync.when(
      loading: () => Theme(
        data: generateProfileTheme(null),
        child: const Scaffold(body: Center(child: CircularProgressIndicator())),
      ),
      error: (error, stackTrace) => Theme(
        data: generateProfileTheme(null),
        child: const Scaffold(
          body: Center(
            child: Text(
              'Unable to load profile',
              style: TextStyle(color: Colors.white70),
            ),
          ),
        ),
      ),
      data: (profile) {
        final displayName = _displayName(profile);
  final usernameLine = '@${profile?.username ?? 'unknown'}';
  final joinedDate = viewingOwnProfile ? _joinedDateText() : '—';
  final parsedColor = _parseHexColor(
          profile?.profileColor ?? profile?.themeColor,
        );
        final hasCover =
      profile?.coverUrl != null && profile!.coverUrl!.trim().isNotEmpty;
    final bioText = profile?.bio?.trim().isNotEmpty == true
      ? profile!.bio!.trim()
      : 'No bio yet.';

    return Theme(
          data: generateProfileTheme(parsedColor),
          child: Builder(
            builder: (context) {
              final localTheme = Theme.of(context);
              final primary = localTheme.primaryColor;
              final cardColor = localTheme.cardColor;

              return Scaffold(
                extendBodyBehindAppBar: true,
                body: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            height: 195,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: hasCover ? cardColor : primary,
                            ),
              child: hasCover
                ? ClipRect(
                  child: SizedBox.expand(
                                      child: CachedNetworkImage(
                                        imageUrl: profile.coverUrl!,
                                        fit: BoxFit.cover,
                    alignment: Alignment.center,
                    placeholder: (context, imageUrl) =>
                      const ShimmerSkeleton(
                                              child: ColoredBox(
                                                color: Colors.white,
                                              ),
                                            ),
                    errorWidget:
                      (context, error, stackTrace) =>
                        const Center(
                                                  child: Icon(
                                                    Icons.broken_image_outlined,
                                                    color: Colors.white54,
                                                  ),
                                                ),
                                              ),
                                            )
            : null,
          ),
          Positioned(
                            top: MediaQuery.paddingOf(context).top + 6,
                            right: 8,
                            child: IconButton(
                              onPressed: () async {
                                await HapticFeedback.selectionClick();
                                if (!context.mounted) {
                                  return;
                                }
                                await Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => const SettingsScreen(),
                                  ),
                                );
                              },
                              icon: const Icon(
                                Icons.settings_outlined,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          Positioned(
                            left: 16,
                            bottom: -50,
                            child: Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: localTheme.scaffoldBackgroundColor,
                                  width: 6,
                                ),
                              ),
                              child: CircleAvatar(
                                radius: 44,
                                backgroundColor: cardColor,
                                backgroundImage:
                  profile?.avatarUrl != null &&
                    profile!.avatarUrl!.isNotEmpty
                  ? CachedNetworkImageProvider(
                                        profile.avatarUrl!,
                                      )
                                    : null,
                child:
                  profile?.avatarUrl == null ||
                    profile.avatarUrl!.isEmpty
                  ? const Icon(
                    Icons.person_rounded,
                    size: 40,
                                        color: Colors.white70,
                                      )
                                    : null,
                              ),
                            ),
                          ),
                        ],
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 58),
                            Text(
                              displayName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              usernameLine,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 16),
                            if (viewingOwnProfile) ...[
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    elevation: 0,
                                    shadowColor: Colors.transparent,
                                    backgroundColor: primary,
                                    foregroundColor: Colors.black,
                                    shape: const StadiumBorder(),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 13,
                                    ),
                                  ),
                  onPressed: () =>
                    _openEditProfile(context, ref, profile),
                  child: const Text('Edit Profile'),
                                ),
                              ),
                              const SizedBox(height: 8),
                            ],
                            _DiscordInfoCard(
                              title: 'BIO',
                              cardSurface: cardColor,
                              secondaryText: Colors.white70,
                              child: Text(
                                bioText,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  height: 1.35,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            _DiscordInfoCard(
                              title: 'MEMBER SINCE',
                              cardSurface: cardColor,
                              secondaryText: Colors.white70,
                              child: Text(
                                joinedDate,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
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

class _DiscordInfoCard extends StatelessWidget {
  const _DiscordInfoCard({
    required this.title,
    required this.cardSurface,
    required this.secondaryText,
    required this.child,
  });

  final String title;
  final Color cardSurface;
  final Color secondaryText;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: cardSurface,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: secondaryText,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}
*/

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/theme_utils.dart';
import '../../../core/widgets/shimmer_skeleton.dart';
import '../application/profile_state_notifier.dart';
import '../data/profile_repository.dart';
import '../models/profile.dart';

final _activePartnerProvider = FutureProvider.autoDispose<Profile?>((
  ref,
) async {
  final profile = ref.watch(profileStateProvider).valueOrNull;
  final partnerId = profile?.activePartnerId;
  if (partnerId == null || partnerId.isEmpty) {
    return null;
  }

  return ref.watch(profileRepositoryProvider).getProfileById(partnerId);
});

final _profileByIdProvider = FutureProvider.autoDispose
    .family<Profile?, String>((ref, userId) async {
      return ref.watch(profileRepositoryProvider).getProfileById(userId);
    });

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key, this.userId});

  final String? userId;

  String _displayName(Profile? profile) {
    if (profile?.firstName?.trim().isNotEmpty == true) {
      final firstName = profile!.firstName!.trim();
      final lastName = profile.lastName?.trim();
      if (lastName != null && lastName.isNotEmpty) {
        return '$firstName $lastName';
      }
      return firstName;
    }
    return 'No name set';
  }

  String _joinedDateText() {
    final createdAt = Supabase.instance.client.auth.currentUser?.createdAt;
    if (createdAt == null || createdAt.trim().isEmpty) {
      return 'Not available';
    }

    final parsed = DateTime.tryParse(createdAt);
    if (parsed == null) {
      return 'Not available';
    }

    final month = switch (parsed.month) {
      1 => 'Jan',
      2 => 'Feb',
      3 => 'Mar',
      4 => 'Apr',
      5 => 'May',
      6 => 'Jun',
      7 => 'Jul',
      8 => 'Aug',
      9 => 'Sep',
      10 => 'Oct',
      11 => 'Nov',
      _ => 'Dec',
    };
    return '$month ${parsed.day}, ${parsed.year}';
  }

  Future<void> _openEditProfile(
    BuildContext context,
    WidgetRef ref,
    Profile? profile,
  ) async {
    final result = await context.push<bool>('/edit_profile', extra: profile);
    if (result == true && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Profile updated')));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    final viewingOwnProfile = userId == null || userId == currentUserId;
    final profileAsync = viewingOwnProfile
        ? ref.watch(profileStateProvider)
        : ref.watch(_profileByIdProvider(userId!));
    ref.watch(_activePartnerProvider);

    return profileAsync.when(
      loading: () => Theme(
        data: generateProfileTheme(null),
        child: const Scaffold(body: Center(child: CircularProgressIndicator())),
      ),
      error: (error, stackTrace) => Theme(
        data: generateProfileTheme(null),
        child: const Scaffold(
          body: Center(
            child: Text(
              'Unable to load profile',
              style: TextStyle(color: Colors.white70),
            ),
          ),
        ),
      ),
      data: (profile) {
        final displayName = _displayName(profile);
        final usernameLine = '@${profile?.username ?? 'unknown'}';
        final joinedDate = viewingOwnProfile ? _joinedDateText() : '—';
        final parsedColor = _parseHexColor(
          profile?.profileColor ?? profile?.themeColor,
        );
        final hasCover =
            profile?.coverUrl != null && profile!.coverUrl!.trim().isNotEmpty;
        final bioText = profile?.bio?.trim().isNotEmpty == true
            ? profile!.bio!.trim()
            : 'No bio yet.';

        return Theme(
          data: generateProfileTheme(parsedColor),
          child: Builder(
            builder: (context) {
              final localTheme = Theme.of(context);
              final primary = localTheme.primaryColor;
              final cardColor = localTheme.cardColor;

              return Scaffold(
                extendBodyBehindAppBar: true,
                body: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            height: 195,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: hasCover ? cardColor : primary,
                            ),
                            child: hasCover
                                ? ClipRect(
                                    child: SizedBox.expand(
                                      child: CachedNetworkImage(
                                        imageUrl: profile.coverUrl!,
                                        fit: BoxFit.cover,
                                        alignment: Alignment.center,
                                        placeholder: (context, imageUrl) =>
                                            const ShimmerSkeleton(
                                              child: ColoredBox(
                                                color: Colors.white,
                                              ),
                                            ),
                                        errorWidget:
                                            (context, error, stackTrace) =>
                                                const Center(
                                                  child: Icon(
                                                    Icons.broken_image_outlined,
                                                    color: Colors.white54,
                                                  ),
                                                ),
                                      ),
                                    ),
                                  )
                                : null,
                          ),
                          if (Navigator.of(context).canPop())
                            Positioned(
                              top: MediaQuery.paddingOf(context).top + 6,
                              left: 8,
                              child: IconButton(
                                onPressed: () {
                                  Navigator.of(context).maybePop();
                                },
                                icon: const Icon(
                                  Icons.arrow_back_rounded,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          if (viewingOwnProfile)
                            Positioned(
                              top: MediaQuery.paddingOf(context).top + 6,
                              right: 8,
                              child: IconButton(
                                onPressed: () async {
                                  await HapticFeedback.selectionClick();
                                  if (!context.mounted) {
                                    return;
                                  }
                                  await context.push('/settings');
                                },
                                icon: const Icon(
                                  Icons.settings_outlined,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          Positioned(
                            left: 16,
                            bottom: -50,
                            child: Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: localTheme.scaffoldBackgroundColor,
                                  width: 6,
                                ),
                              ),
                              child: CircleAvatar(
                                radius: 44,
                                backgroundColor: cardColor,
                                backgroundImage:
                                    (profile?.avatarUrl?.isNotEmpty ?? false)
                                    ? CachedNetworkImageProvider(
                                        profile!.avatarUrl!,
                                      )
                                    : null,
                                child:
                                    !(profile?.avatarUrl?.isNotEmpty ?? false)
                                    ? const Icon(
                                        Icons.person_rounded,
                                        size: 40,
                                        color: Colors.white70,
                                      )
                                    : null,
                              ),
                            ),
                          ),
                        ],
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 58),
                            Text(
                              displayName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              usernameLine,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 16),
                            if (viewingOwnProfile) ...[
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    elevation: 0,
                                    shadowColor: Colors.transparent,
                                    backgroundColor: primary,
                                    foregroundColor: Colors.black,
                                    shape: const StadiumBorder(),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 13,
                                    ),
                                  ),
                                  onPressed: () =>
                                      _openEditProfile(context, ref, profile),
                                  child: const Text('Edit Profile'),
                                ),
                              ),
                              const SizedBox(height: 8),
                            ],
                            _DiscordInfoCard(
                              title: 'BIO',
                              cardSurface: cardColor,
                              secondaryText: Colors.white70,
                              child: Text(
                                bioText,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  height: 1.35,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            _DiscordInfoCard(
                              title: 'MEMBER SINCE',
                              cardSurface: cardColor,
                              secondaryText: Colors.white70,
                              child: Text(
                                joinedDate,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
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

class _DiscordInfoCard extends StatelessWidget {
  const _DiscordInfoCard({
    required this.title,
    required this.cardSurface,
    required this.secondaryText,
    required this.child,
  });

  final String title;
  final Color cardSurface;
  final Color secondaryText;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: cardSurface,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: secondaryText,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

/*
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../core/theme/theme_utils.dart';
import '../../../core/widgets/shimmer_skeleton.dart';

import '../application/profile_state_notifier.dart';
import '../data/profile_repository.dart';
import '../models/profile.dart';
import 'edit_profile_screen.dart';
import 'settings_screen.dart';

final _activePartnerProvider = FutureProvider.autoDispose<Profile?>((
  ref,
) async {
  final profile = ref.watch(profileStateProvider).valueOrNull;
  final partnerId = profile?.activePartnerId;
  if (partnerId == null || partnerId.isEmpty) {
    return null;
  }

  return ref.watch(profileRepositoryProvider).getProfileById(partnerId);
});

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key, this.userId});

  final String? userId;

  String _displayName(Profile? profile) {
    if (profile?.firstName?.trim().isNotEmpty == true) {
      final firstName = profile!.firstName!.trim();
      final lastName = profile.lastName?.trim();
      if (lastName != null && lastName.isNotEmpty) {
        return '$firstName $lastName';
      }
      return firstName;
    }
    return 'No name set';
  }

  String _joinedDateText() {
    final createdAt = Supabase.instance.client.auth.currentUser?.createdAt;
    if (createdAt == null || createdAt.trim().isEmpty) {
      return 'Not available';
    }

    final parsed = DateTime.tryParse(createdAt);
    if (parsed == null) {
      return 'Not available';
    }

    final month = switch (parsed.month) {
      1 => 'Jan',
      2 => 'Feb',
      3 => 'Mar',
      4 => 'Apr',
      5 => 'May',
      6 => 'Jun',
      7 => 'Jul',
      8 => 'Aug',
      9 => 'Sep',
      10 => 'Oct',
      11 => 'Nov',
      _ => 'Dec',
    };
    return '$month ${parsed.day}, ${parsed.year}';
  }

  Future<void> _openEditProfile(
    BuildContext context,
    WidgetRef ref,
    Profile? profile,
  ) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => EditProfileScreen(profile: profile)),
    );
    if (result == true) {
      await ref.read(profileStateProvider.notifier).refresh();
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Profile updated')));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    final viewingOwnProfile = userId == null || userId == currentUserId;
    final profileAsync = viewingOwnProfile
        ? ref.watch(profileStateProvider)
        : ref.watch(_profileByIdProvider(userId!));
    ref.watch(_activePartnerProvider);
    return profileAsync.when(
      loading: () => Theme(
        data: generateProfileTheme(null),
        child: const Scaffold(body: Center(child: CircularProgressIndicator())),
      ),
      error: (error, stackTrace) => Theme(
        data: generateProfileTheme(null),
        child: const Scaffold(
          body: Center(
            child: Text(
              'Unable to load profile',
              style: TextStyle(color: Colors.white70),
            ),
          ),
        ),
      ),
      data: (profile) {
        final displayName = _displayName(profile);
        final usernameLine = '@${profile?.username ?? 'unknown'}';
        final joinedDate = viewingOwnProfile ? _joinedDateText() : '—';
        final parsedColor = _parseHexColor(
          profile?.profileColor ?? profile?.themeColor,
        );
        final hasCover =
            profile?.coverUrl != null && profile!.coverUrl!.trim().isNotEmpty;
        final bioText = profile?.bio?.trim().isNotEmpty == true
            ? profile!.bio!.trim()
            : 'No bio yet.';

        return Theme(
          data: generateProfileTheme(parsedColor),
          child: Builder(
            builder: (context) {
              final localTheme = Theme.of(context);
              final primary = localTheme.primaryColor;
              final cardColor = localTheme.cardColor;

              return Scaffold(
                extendBodyBehindAppBar: true,
                body: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        height: 195,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: hasCover ? cardColor : primary,
                        ),
                        child: hasCover
                            ? ClipRect(
                                child: SizedBox.expand(
                                  child: CachedNetworkImage(
                                    imageUrl: profile.coverUrl!,
                                    fit: BoxFit.cover,
                                    alignment: Alignment.center,
                                    placeholder: (context, imageUrl) =>
                                        const ShimmerSkeleton(
                                          child: ColoredBox(
                                            color: Colors.white,
                                          ),
                                        ),
                                    errorWidget: (context, error, stackTrace) =>
                                        const Center(
                                          child: Icon(
                                            Icons.broken_image_outlined,
                                            color: Colors.white54,
                                          ),
                                        ),
                                  ),
                                ),
                              )
                            : null,
                      ),
                      Positioned(
                        top: MediaQuery.paddingOf(context).top + 6,
                        right: 8,
                        child: IconButton(
                          onPressed: () async {
                            await HapticFeedback.selectionClick();
                            if (!context.mounted) {
                              return;
                            }
                            await Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const SettingsScreen(),
                              ),
                            );
                          },
                          icon: const Icon(
                            Icons.settings_outlined,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      Positioned(
                        left: 16,
                        bottom: -50,
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: localTheme.scaffoldBackgroundColor,
                              width: 6,
                            ),
                          ),
                          child: CircleAvatar(
                            radius: 44,
                            backgroundColor: const Color(0xFF2B2D31),
                            backgroundImage:
                                profile?.avatarUrl != null &&
                                    profile!.avatarUrl!.isNotEmpty
                                ? CachedNetworkImageProvider(profile.avatarUrl!)
                                : null,
                            child:
                                profile?.avatarUrl == null ||
                                    profile!.avatarUrl!.isEmpty
                                ? const Icon(
                                    Icons.person_rounded,
                                    size: 40,
                                    color: Colors.white70,
                                  )
                                : null,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 58),
                        Text(
                          displayName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          usernameLine,
                          style: const TextStyle(
                            color: secondaryText,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (viewingOwnProfile) ...[
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                elevation: 0,
                                shadowColor: Colors.transparent,
                                backgroundColor: primary,
                                foregroundColor: Colors.black,
                                shape: const StadiumBorder(),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 13,
                                ),
                              ),
                              onPressed: () =>
                                  _openEditProfile(context, ref, profile),
                              child: const Text('Edit Profile'),
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],
                        _DiscordInfoCard(
                          title: 'BIO',
                          cardSurface: cardColor,
                          secondaryText: Colors.white70,
                          child: Text(
                            bioText,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              height: 1.35,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        _DiscordInfoCard(
                          title: 'MEMBER SINCE',
                          cardSurface: cardColor,
                          secondaryText: Colors.white70,
                          child: Text(
                            joinedDate,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      );
                    },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

final _profileByIdProvider = FutureProvider.autoDispose
    .family<Profile?, String>((ref, userId) async {
      return ref.watch(profileRepositoryProvider).getProfileById(userId);
    });

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
  return Color(int.tryParse(value, radix: 16) ?? 0xFF202225);
}

class _DiscordInfoCard extends StatelessWidget {
  const _DiscordInfoCard({
    required this.title,
    required this.cardSurface,
    required this.secondaryText,
    required this.child,
  });

  final String title;
  final Color cardSurface;
  final Color secondaryText;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: cardSurface,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: secondaryText,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}
*/
