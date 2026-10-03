import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/core/api/profile_onboarding_models.dart';

void main() {
  test(
    'ProfileOnboardingInput emits every required field and preserves false consent',
    () {
      const input = ProfileOnboardingInput(
        country: 'Nigeria',
        whatsapp: '0801 234 5678',
        consentWhatsappUpdates: false,
        gameInterests: ['74db07fa-e711-4e78-a982-2863a45137f1'],
      );

      expect(input.toJson(), {
        'country': 'Nigeria',
        'whatsapp': '0801 234 5678',
        'consentWhatsappUpdates': false,
        'gameInterests': ['74db07fa-e711-4e78-a982-2863a45137f1'],
      });
    },
  );

  test(
    'ProfileOnboardingResult parses the server-owned completion timestamp',
    () {
      final result = ProfileOnboardingResult.fromJson({
        'profileCompletedAt': '2026-10-03T15:47:47.857216+00:00',
      });

      expect(result.profileCompletedAt, '2026-10-03T15:47:47.857216+00:00');
    },
  );
}
