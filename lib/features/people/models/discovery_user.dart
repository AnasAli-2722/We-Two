class DiscoveryUser {
  const DiscoveryUser({
    required this.id,
    required this.username,
    this.avatarUrl,
  });

  final String id;
  final String username;
  final String? avatarUrl;

  factory DiscoveryUser.fromMap(Map<String, dynamic> map) {
    return DiscoveryUser(
      id: map['id'] as String,
      username: (map['username'] as String?)?.trim().isNotEmpty == true
          ? map['username'] as String
          : 'Unknown',
      avatarUrl: map['avatar_url'] as String?,
    );
  }
}
