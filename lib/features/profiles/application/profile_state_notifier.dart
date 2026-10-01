import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_state_provider.dart';
import '../data/profile_repository.dart';
import '../models/profile.dart';

class ProfileStateNotifier extends StateNotifier<AsyncValue<Profile?>> {
  ProfileStateNotifier(this.ref) : super(const AsyncValue.loading()) {
    _load();
  }

  static const _noChange = Object();

  final Ref ref;

  Future<void> _load() async {
    final userId = ref.read(authUserIdProvider);
    if (userId == null) {
      state = const AsyncValue.data(null);
      return;
    }

    try {
      final profile = await ref
          .read(profileRepositoryProvider)
          .getCurrentProfile(userId);
      state = AsyncValue.data(profile);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  Future<void> refresh() => _load();

  void applyLocalProfileUpdate({
    Object? firstName = _noChange,
    Object? lastName = _noChange,
    Object? bio = _noChange,
    Object? avatarUrl = _noChange,
    Object? coverUrl = _noChange,
    Object? profileColor = _noChange,
    Object? themeColor = _noChange,
  }) {
    final current = state.valueOrNull;
    if (current == null) {
      return;
    }

    var updated = current;
    if (!identical(firstName, _noChange)) {
      final firstNameValue = firstName as String?;
      updated = updated.copyWith(
        firstName: (firstNameValue?.trim().isEmpty == true)
            ? null
            : firstNameValue?.trim(),
      );
    }
    if (!identical(lastName, _noChange)) {
      final lastNameValue = lastName as String?;
      updated = updated.copyWith(
        lastName: (lastNameValue?.trim().isEmpty == true)
            ? null
            : lastNameValue?.trim(),
      );
    }
    if (!identical(bio, _noChange)) {
      final bioValue = bio as String?;
      updated = updated.copyWith(
        bio: (bioValue?.trim().isEmpty == true) ? null : bioValue?.trim(),
      );
    }
    if (!identical(avatarUrl, _noChange)) {
      final avatarUrlValue = avatarUrl as String?;
      updated = updated.copyWith(
        avatarUrl: (avatarUrlValue?.trim().isEmpty == true)
            ? null
            : avatarUrlValue?.trim(),
      );
    }
    if (!identical(coverUrl, _noChange)) {
      final coverUrlValue = coverUrl as String?;
      updated = updated.copyWith(
        coverUrl: (coverUrlValue?.trim().isEmpty == true)
            ? null
            : coverUrlValue?.trim(),
      );
    }
    if (!identical(profileColor, _noChange)) {
      final profileColorValue = profileColor as String?;
      updated = updated.copyWith(
        profileColor: (profileColorValue?.trim().isEmpty == true)
            ? null
            : profileColorValue?.trim(),
      );
    }
    if (!identical(themeColor, _noChange)) {
      final themeColorValue = themeColor as String?;
      updated = updated.copyWith(
        themeColor: (themeColorValue?.trim().isEmpty == true)
            ? null
            : themeColorValue?.trim(),
      );
    }

    state = AsyncValue.data(updated);
  }

  void saveProfileOptimistic({
    required String userId,
    String? firstName,
    String? lastName,
    String? bio,
    String? avatarUrl,
    String? coverUrl,
    String? profileColor,
    String? themeColor,
  }) {
    final previous = state.valueOrNull;

    applyLocalProfileUpdate(
      firstName: firstName,
      lastName: lastName,
      bio: bio,
      avatarUrl: avatarUrl,
      coverUrl: coverUrl,
      profileColor: profileColor,
      themeColor: themeColor,
    );

    unawaited(
      ref
          .read(profileRepositoryProvider)
          .updateProfileFields(
            userId: userId,
            firstName: firstName,
            lastName: lastName,
            bio: bio,
            avatarUrl: avatarUrl,
            coverUrl: coverUrl,
            profileColor: profileColor,
            themeColor: themeColor,
          )
          .catchError((_) {
            if (previous != null) {
              state = AsyncValue.data(previous);
            }
          }),
    );
  }
}

final profileStateProvider =
    StateNotifierProvider.autoDispose<
      ProfileStateNotifier,
      AsyncValue<Profile?>
    >((ref) {
      final keepAliveLink = ref.keepAlive();
      Timer? disposeTimer;

      ref.onCancel(() {
        disposeTimer = Timer(const Duration(minutes: 5), keepAliveLink.close);
      });

      ref.onResume(() {
        disposeTimer?.cancel();
        disposeTimer = null;
      });

      ref.onDispose(() {
        disposeTimer?.cancel();
      });

      return ProfileStateNotifier(ref);
    });
