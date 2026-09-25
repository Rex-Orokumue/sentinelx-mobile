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
const _onboardingExempt = {'/onboarding/username', '/debug', '/reset-password'};

/// The single place the router's onboarding enforcement is decided. Pure and
/// synchronous so it is unit-testable without GoRouter or Riverpod; see
/// buildAppRouter's `authGate` param for how a live snapshot is supplied.
String? evaluateAuthRedirect(AuthGateSnapshot gate, String location) {
  if (gate.isLoading || !gate.isSignedIn) return null;
  final onOnboarding = location == '/onboarding/username';
  if (gate.onboardingGate == OnboardingGate.username) {
    if (onOnboarding || _onboardingExempt.contains(location)) return null;
    return '/onboarding/username';
  }
  if (onOnboarding) return '/';
  return null;
}
