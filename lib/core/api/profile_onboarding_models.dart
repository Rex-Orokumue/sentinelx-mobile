class ProfileOnboardingInput {
  const ProfileOnboardingInput({
    required this.country,
    required this.whatsapp,
    required this.consentWhatsappUpdates,
    required this.gameInterests,
  });

  final String country;
  final String whatsapp;
  final bool consentWhatsappUpdates;
  final List<String> gameInterests;

  Map<String, Object?> toJson() => {
    'country': country,
    'whatsapp': whatsapp,
    'consentWhatsappUpdates': consentWhatsappUpdates,
    'gameInterests': gameInterests,
  };
}

class ProfileOnboardingResult {
  const ProfileOnboardingResult({required this.profileCompletedAt});

  factory ProfileOnboardingResult.fromJson(Map<String, dynamic> json) =>
      ProfileOnboardingResult(
        profileCompletedAt: json['profileCompletedAt'] as String,
      );

  final String profileCompletedAt;
}
