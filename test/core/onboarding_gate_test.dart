import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/core/api/models.dart';
import 'package:sentinelx_mobile/core/auth/onboarding_gate.dart';
import 'package:sentinelx_mobile/core/config/remote_config.dart';

MeResponse _me({String? username, String? profileCompletedAt}) => MeResponse(
      id: 'u',
      email: 'a@b.com',
      roles: const [],
      isStaff: false,
      isAdmin: false,
      profile: username == null
          ? null
          : MeProfile(
              username: username,
              displayName: username,
              avatarUrl: null,
              whatsappNumber: null,
              country: null,
              locale: 'en',
              membershipTier: null,
              kycVerified: false,
              deletionRequestedAt: null,
              profileCompletedAt: profileCompletedAt,
            ),
    );

RemoteConfig _config({bool enforcePhone = false}) => RemoteConfig.fromJson({
      'minSupportedAppVersion': '0.0.0',
      'latestAppVersion': '1.0.0',
      'maintenance': null,
      'siteUrl': 'https://sentinelxesports.com.ng',
      'coins': {'coinsPerNaira': 2, 'nairaPerCoin': 0.5, 'coinsPerEntry': 1000, 'coinsHalfEntry': 500},
      'enforcePhoneVerification': enforcePhone,
      'whatsappCommunityUrl': null,
      'features': <String, bool>{},
    });

void main() {
  test('signed out: no gate', () {
    expect(resolveOnboardingGate(null, _config()), OnboardingGate.none);
  });
  test('no username yet: username gate', () {
    expect(resolveOnboardingGate(_me(username: null), _config()), OnboardingGate.username);
  });
  test('has a username, phone gate off, incomplete profile: profile gate', () {
    expect(resolveOnboardingGate(_me(username: 'ada'), _config()), OnboardingGate.profile);
  });
  test('has a username, phone gate on: phone gate', () {
    expect(resolveOnboardingGate(_me(username: 'ada'), _config(enforcePhone: true)), OnboardingGate.phone);
  });
  test('config not loaded yet: never demands phone (open by default, matches AppGate’s own null-config fail-open)', () {
    expect(resolveOnboardingGate(_me(username: 'ada'), null), OnboardingGate.profile);
  });
  test('completed profile clears the final gate', () {
    expect(
      resolveOnboardingGate(_me(username: 'ada', profileCompletedAt: '2026-10-03T15:47:47Z'), _config()),
      OnboardingGate.none,
    );
  });
}
