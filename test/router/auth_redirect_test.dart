import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/core/auth/onboarding_gate.dart';
import 'package:sentinelx_mobile/router/auth_redirect.dart';

void main() {
  AuthGateSnapshot gate({bool isLoading = false, bool isSignedIn = true, OnboardingGate onboardingGate = OnboardingGate.none}) =>
      AuthGateSnapshot(isLoading: isLoading, isSignedIn: isSignedIn, onboardingGate: onboardingGate);

  test('fails open while loading, regardless of destination', () {
    expect(evaluateAuthRedirect(gate(isLoading: true, onboardingGate: OnboardingGate.username), '/tournaments/t1'), isNull);
  });

  test('no redirect for a signed-out visitor (no login wall in this app)', () {
    expect(evaluateAuthRedirect(gate(isSignedIn: false, onboardingGate: OnboardingGate.username), '/account'), isNull);
  });

  test('a signed-in user who needs a username is sent to onboarding from any other route', () {
    expect(evaluateAuthRedirect(gate(onboardingGate: OnboardingGate.username), '/tournaments/t1'), '/onboarding/username');
    expect(evaluateAuthRedirect(gate(onboardingGate: OnboardingGate.username), '/account'), '/onboarding/username');
  });

  test('no redirect loop: already on /onboarding/username with the gate open', () {
    expect(evaluateAuthRedirect(gate(onboardingGate: OnboardingGate.username), '/onboarding/username'), isNull);
  });

  test('exempt routes stay reachable even when the gate says username is needed', () {
    expect(evaluateAuthRedirect(gate(onboardingGate: OnboardingGate.username), '/debug'), isNull);
    expect(evaluateAuthRedirect(gate(onboardingGate: OnboardingGate.username), '/reset-password'), isNull);
  });

  test('an already-onboarded user is redirected away from the onboarding screen', () {
    expect(evaluateAuthRedirect(gate(), '/onboarding/username'), '/');
  });

  test('an already-onboarded user browsing anywhere else is left alone', () {
    expect(evaluateAuthRedirect(gate(), '/tournaments/t1'), isNull);
  });
}
