import '../api/models.dart';
import '../config/remote_config.dart';

enum OnboardingGate { username, phone, none }

// Mirrors the web's resolveOnboardingGate (lib/onboarding/gate.ts) exactly,
// including the phone gate's kill-switch: enforcePhoneVerification is read
// from /config, never hard-coded, and is false in every environment today
// (see this plan's tripwire — no onboarding-phone screen exists yet).
OnboardingGate resolveOnboardingGate(MeResponse? me, RemoteConfig? config) {
  if (me == null) return OnboardingGate.none;
  if (me.profile?.username == null) return OnboardingGate.username;
  // phoneVerifiedAt isn't in MeResponse yet (not needed until the flag flips)
  // — this branch is unreachable while enforcePhoneVerification is false.
  if (config?.enforcePhoneVerification ?? false) return OnboardingGate.phone;
  return OnboardingGate.none;
}
