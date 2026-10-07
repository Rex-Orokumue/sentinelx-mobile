import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/core/auth/onboarding_gate.dart';
import 'package:sentinelx_mobile/router/auth_redirect.dart';

void main() {
  AuthGateSnapshot gate({
    bool isLoading = false,
    bool isSignedIn = true,
    OnboardingGate onboardingGate = OnboardingGate.none,
  }) => AuthGateSnapshot(
    isLoading: isLoading,
    isSignedIn: isSignedIn,
    onboardingGate: onboardingGate,
  );

  test('fails open while loading, regardless of destination', () {
    expect(
      evaluateAuthRedirect(
        gate(isLoading: true, onboardingGate: OnboardingGate.username),
        '/tournaments/t1',
      ),
      isNull,
    );
  });

  test('no redirect for a signed-out visitor (no login wall in this app)', () {
    expect(
      evaluateAuthRedirect(
        gate(isSignedIn: false, onboardingGate: OnboardingGate.username),
        '/account',
      ),
      isNull,
    );
  });

  test(
    'a signed-in user who needs a username is sent to onboarding from any other route',
    () {
      expect(
        evaluateAuthRedirect(
          gate(onboardingGate: OnboardingGate.username),
          '/tournaments/t1',
        ),
        '/onboarding/username',
      );
      expect(
        evaluateAuthRedirect(
          gate(onboardingGate: OnboardingGate.username),
          '/account',
        ),
        '/onboarding/username',
      );
    },
  );

  test(
    'no redirect loop: already on /onboarding/username with the gate open',
    () {
      expect(
        evaluateAuthRedirect(
          gate(onboardingGate: OnboardingGate.username),
          '/onboarding/username',
        ),
        isNull,
      );
    },
  );

  test(
    'a signed-in user who needs a profile is sent to profile onboarding without a loop',
    () {
      expect(
        evaluateAuthRedirect(
          gate(onboardingGate: OnboardingGate.profile),
          '/account',
        ),
        '/onboarding/profile',
      );
      expect(
        evaluateAuthRedirect(
          gate(onboardingGate: OnboardingGate.profile),
          '/onboarding/profile',
        ),
        isNull,
      );
    },
  );

  test(
    'username onboarding stays reachable while the later profile gate is open',
    () {
      expect(
        evaluateAuthRedirect(
          gate(onboardingGate: OnboardingGate.profile),
          '/onboarding/username',
        ),
        isNull,
      );
    },
  );

  test(
    'exempt routes stay reachable even when the gate says username is needed',
    () {
      expect(
        evaluateAuthRedirect(
          gate(onboardingGate: OnboardingGate.username),
          '/debug',
        ),
        isNull,
      );
      expect(
        evaluateAuthRedirect(
          gate(onboardingGate: OnboardingGate.username),
          '/reset-password',
        ),
        isNull,
      );
    },
  );

  test(
    'an already-onboarded user is redirected away from the onboarding screen',
    () {
      expect(evaluateAuthRedirect(gate(), '/onboarding/username'), '/');
      expect(evaluateAuthRedirect(gate(), '/onboarding/profile'), '/');
    },
  );

  test('an already-onboarded user browsing anywhere else is left alone', () {
    expect(evaluateAuthRedirect(gate(), '/tournaments/t1'), isNull);
  });

  test(
    'an incomplete-profile push target gates first and is deliberately dropped after completion',
    () {
      expect(
        evaluateAuthRedirect(
          gate(onboardingGate: OnboardingGate.profile),
          '/notifications',
        ),
        '/onboarding/profile',
      );
      expect(
        evaluateAuthRedirect(gate(), '/onboarding/profile'),
        '/',
        reason:
            'profile completion goes Home; the original push target is not retained',
      );
    },
  );

  group('phone gate', () {
    test('every route redirects to /onboarding/phone while gated', () {
      final g = gate(onboardingGate: OnboardingGate.phone);
      expect(evaluateAuthRedirect(g, '/'), '/onboarding/phone');
      expect(evaluateAuthRedirect(g, '/tournaments'), '/onboarding/phone');
      expect(evaluateAuthRedirect(g, '/account/phone'), '/onboarding/phone');
    });
    test('the gate screen itself and the always-exempt routes are reachable', () {
      final g = gate(onboardingGate: OnboardingGate.phone);
      expect(evaluateAuthRedirect(g, '/onboarding/phone'), isNull);
      expect(evaluateAuthRedirect(g, '/reset-password'), isNull);
    });
    test('a verified or non-gated user opening /onboarding/phone is sent home', () {
      expect(evaluateAuthRedirect(gate(), '/onboarding/phone'), '/');
    });
    test('a user who still needs a username is not sent to the phone screen first', () {
      expect(evaluateAuthRedirect(gate(onboardingGate: OnboardingGate.username), '/onboarding/phone'), '/onboarding/username');
    });
    test('a signed-out visitor is never redirected to it', () {
      expect(evaluateAuthRedirect(gate(isSignedIn: false, onboardingGate: OnboardingGate.phone), '/'), isNull);
    });
  });
}
