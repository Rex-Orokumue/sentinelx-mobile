import '../core/auth/onboarding_gate.dart';

class AuthGateSnapshot {
  const AuthGateSnapshot({required this.isLoading, required this.isSignedIn, required this.onboardingGate});
  final bool isLoading;
  final bool isSignedIn;
  final OnboardingGate onboardingGate;
}

// Routes that must stay reachable even while the gate says a username is
// needed, so a mid-flow user is never redirect-looped:
// - /onboarding/username itself (the destination)
// - /debug (dev sign-in tool, exists only when debugTools is true)
// - /reset-password (a recovery link establishes a session locally via
//   verifyOtp before the user has necessarily finished onboarding)
const _alwaysGateExempt = {'/debug', '/reset-password'};
const _onboardingRoutes = {'/onboarding/username', '/onboarding/profile'};

/// The single place the router's onboarding enforcement is decided. Pure and
/// synchronous so it is unit-testable without GoRouter or Riverpod; see
/// buildAppRouter's `authGate` param for how a live snapshot is supplied.
String? evaluateAuthRedirect(AuthGateSnapshot gate, String location) {
  if (gate.isLoading || !gate.isSignedIn) return null;
  if (_alwaysGateExempt.contains(location)) return null;
  if (gate.onboardingGate == OnboardingGate.username) {
    if (location == '/onboarding/username') return null;
    return '/onboarding/username';
  }
  if (gate.onboardingGate == OnboardingGate.profile) {
    if (_onboardingRoutes.contains(location)) return null;
    return '/onboarding/profile';
  }
  if (_onboardingRoutes.contains(location)) return '/';
  return null;
}
