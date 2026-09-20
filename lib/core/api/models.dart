class MeProfile {
  const MeProfile({
    required this.username,
    required this.displayName,
    required this.avatarUrl,
    required this.whatsappNumber,
    required this.country,
    required this.locale,
    required this.membershipTier,
    required this.kycVerified,
    required this.deletionRequestedAt,
  });

  factory MeProfile.fromJson(Map<String, dynamic> j) => MeProfile(
        username: j['username'] as String?,
        displayName: j['displayName'] as String?,
        avatarUrl: j['avatarUrl'] as String?,
        whatsappNumber: j['whatsappNumber'] as String?,
        country: j['country'] as String?,
        locale: j['locale'] as String?,
        membershipTier: j['membershipTier'] as String?,
        kycVerified: j['kycVerified'] as bool,
        deletionRequestedAt: j['deletionRequestedAt'] as String?,
      );

  final String? username;
  final String? displayName;
  final String? avatarUrl;
  final String? whatsappNumber;
  final String? country;
  final String? locale;
  final String? membershipTier;
  final bool kycVerified;
  final String? deletionRequestedAt;
}

class MeResponse {
  const MeResponse({
    required this.id,
    required this.email,
    required this.roles,
    required this.isStaff,
    required this.isAdmin,
    required this.profile,
  });

  factory MeResponse.fromJson(Map<String, dynamic> j) => MeResponse(
        id: j['id'] as String,
        email: j['email'] as String?,
        roles: (j['roles'] as List<dynamic>).cast<String>(),
        isStaff: j['isStaff'] as bool,
        isAdmin: j['isAdmin'] as bool,
        profile: j['profile'] == null ? null : MeProfile.fromJson(j['profile'] as Map<String, dynamic>),
      );

  final String id;
  final String? email;
  final List<String> roles;
  final bool isStaff;
  final bool isAdmin;
  final MeProfile? profile;
}
