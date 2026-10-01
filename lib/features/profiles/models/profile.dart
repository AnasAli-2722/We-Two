class Profile {
  const Profile({
    required this.id,
    required this.username,
    this.activePartnerId,
    this.profileColor,
    this.firstName,
    this.lastName,
    this.birthday,
    this.avatarUrl,
    this.coverUrl,
    this.themeColor,
    this.bio,
  });

  final String id;
  final String username;
  final String? activePartnerId;
  final String? profileColor;
  final String? firstName;
  final String? lastName;
  final DateTime? birthday;
  final String? avatarUrl;
  final String? coverUrl;
  final String? themeColor;
  final String? bio;

  static const _noChange = Object();

  Profile copyWith({
    String? username,
    Object? activePartnerId = _noChange,
    Object? profileColor = _noChange,
    Object? firstName = _noChange,
    Object? lastName = _noChange,
    Object? birthday = _noChange,
    Object? avatarUrl = _noChange,
    Object? coverUrl = _noChange,
    Object? themeColor = _noChange,
    Object? bio = _noChange,
  }) {
    return Profile(
      id: id,
      username: username ?? this.username,
      activePartnerId: identical(activePartnerId, _noChange)
          ? this.activePartnerId
          : activePartnerId as String?,
      profileColor: identical(profileColor, _noChange)
          ? this.profileColor
          : profileColor as String?,
      firstName: identical(firstName, _noChange)
          ? this.firstName
          : firstName as String?,
      lastName: identical(lastName, _noChange)
          ? this.lastName
          : lastName as String?,
      birthday: identical(birthday, _noChange)
          ? this.birthday
          : birthday as DateTime?,
      avatarUrl: identical(avatarUrl, _noChange)
          ? this.avatarUrl
          : avatarUrl as String?,
      coverUrl: identical(coverUrl, _noChange)
          ? this.coverUrl
          : coverUrl as String?,
      themeColor: identical(themeColor, _noChange)
          ? this.themeColor
          : themeColor as String?,
      bio: identical(bio, _noChange) ? this.bio : bio as String?,
    );
  }

  String get fullName {
    final first = firstName?.trim() ?? '';
    final last = lastName?.trim() ?? '';
    if (first.isEmpty && last.isEmpty) {
      return '';
    }
    if (last.isEmpty) {
      return first;
    }
    if (first.isEmpty) {
      return last;
    }
    return '$first $last';
  }

  bool get needsProfileSetup {
    final hasUsername = username.trim().isNotEmpty;
    final hasFullName = fullName.isNotEmpty;
    return !hasUsername || !hasFullName;
  }

  factory Profile.fromMap(Map<String, dynamic> map) {
    final rawUsername = map['username'] as String?;
    final rawBirthday = map['birthday'] as String?;

    return Profile(
      id: map['id'] as String,
      username: rawUsername?.trim() ?? '',
      activePartnerId: map['active_partner_id'] as String?,
      profileColor:
          (map['profile_color'] as String?) ?? (map['theme_color'] as String?),
      firstName: map['first_name'] as String?,
      lastName: map['last_name'] as String?,
      birthday: rawBirthday == null || rawBirthday.isEmpty
          ? null
          : DateTime.tryParse(rawBirthday),
      avatarUrl: map['avatar_url'] as String?,
      coverUrl: map['cover_url'] as String?,
      themeColor: map['theme_color'] as String?,
      bio: map['bio'] as String?,
    );
  }
}
