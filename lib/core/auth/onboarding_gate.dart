import '../api/models.dart';
import '../config/remote_config.dart';

enum OnboardingGate { username, phone, profile, none }

// Mirrors the web's resolveOnboardingGate (lib/onboarding/gate.ts) exactly,
// including the phone gate's kill-switch: enforcePhoneVerification is read
// from /config, never hard-coded, and is false in every environment today.
// The owner flips it only after an app version containing /onboarding/phone
// (this build) has been released.
OnboardingGate resolveOnboardingGate(MeResponse? me, RemoteConfig? config) {
  if (me == null) return OnboardingGate.none;
  if (me.profile?.username == null) return OnboardingGate.username;
  // Same order as the web: username, then phone (only when enforced AND not yet verified), then profile.
  // phoneVerifiedAt comes from /me; a server too old to send it reads as unverified, which is harmless
  // while enforcePhoneVerification is false (the only state shipped today).
  if ((config?.enforcePhoneVerification ?? false) && me.profile?.phoneVerifiedAt == null) return OnboardingGate.phone;
  if (me.profile?.profileCompletedAt == null) return OnboardingGate.profile;
  return OnboardingGate.none;
}
