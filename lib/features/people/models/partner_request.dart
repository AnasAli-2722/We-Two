class PartnerRequest {
  const PartnerRequest({
    required this.id,
    required this.fromUserId,
    required this.username,
    this.avatarUrl,
  });

  final String id;
  final String fromUserId;
  final String username;
  final String? avatarUrl;

  factory PartnerRequest.fromMap(Map<String, dynamic> map) {
    final fromProfileRaw = map['from_profile'];
    final fromProfile = fromProfileRaw is List && fromProfileRaw.isNotEmpty
        ? Map<String, dynamic>.from(fromProfileRaw.first as Map)
        : fromProfileRaw is Map
        ? Map<String, dynamic>.from(fromProfileRaw)
        : <String, dynamic>{};

    return PartnerRequest(
      id: map['id'] as String,
      fromUserId: map['from_user_id'] as String,
      username: (fromProfile['username'] as String?)?.trim().isNotEmpty == true
          ? fromProfile['username'] as String
          : 'Unknown',
      avatarUrl: fromProfile['avatar_url'] as String?,
    );
  }
}
