# Code Review Handoff

**Date:** 2026-09-23  
**Audience:** Claude and other implementation agents  
**Scope:** Read-only review of the Flutter mobile repository  
**Code changed during review:** No

## Overall assessment

The project is on the right architectural track. Its strongest foundations are:

- Riverpod owns application dependencies and feature providers.
- Server-side business rules remain in the web backend rather than being
  duplicated in Dart.
- Mobile mutations use the versioned `/api/mobile/v1` API instead of direct
  PostgREST writes.
- The API client is checked against a pinned OpenAPI contract.
- The temporary direct-Supabase tournament slice is explicitly documented and
  contained.
- The test suite is substantial for the current project size: the repository
  contains 122 `test`/`testWidgets` declarations across 37 Dart test files.

The architecture should be continued, not rewritten. Phase 1 should not be
treated as release-ready until the lifecycle and navigation findings below are
addressed.

## Priority findings

### 1. Make onboarding and authentication routing global

**Severity:** Major

The master design calls for router-level authentication and onboarding guards,
but the current router redirect only resolves incoming web links. Username
onboarding is checked only while `HomeScreen` builds.

Relevant code:

- `lib/router/app_router.dart:26`
- `lib/features/home/home_screen.dart:17-26`
- `lib/core/auth/auth_providers.dart:13-17`
- `lib/core/auth/onboarding_gate.dart:10-16`

Consequences:

- A signed-in user without a username can navigate or deep-link directly to a
  tournament, Account, or another route without completing onboarding.
- `OnboardingGate.phone` is calculated but no navigation path handles it. The
  existing kill-switch must remain off until a phone-onboarding screen ships.
- Authentication restrictions are not expressed consistently at the routing
  boundary.

Recommended direction:

- Move auth/onboarding enforcement into router refresh/redirect behavior.
- Define the signed-out public-route allowlist explicitly.
- Preserve the current fail-open behavior while `/me` or remote config is still
  loading; avoid redirect loops and premature redirects.
- Keep `/onboarding/username` accessible to the user who needs it and redirect
  an already-onboarded user away from it.

Acceptance tests should cover initial launch, auth-state changes, direct deep
links, signed-out public routes, and redirect-loop prevention.

### 2. Preserve the meaning of each email-link type

**Severity:** Major

`handleEmailLink` maps several OTP types to the single `verified` outcome. The
incoming-link handler then sends every successful non-recovery result to
`/onboarding/username`.

Relevant code:

- `lib/core/auth/email_link_handler.dart:10-33`
- `lib/core/routing/incoming_links.dart:20-35`

This incorrectly routes an existing user who confirms an email-address change
to username onboarding. Invite and magic-link behavior also needs an explicit
decision rather than inheriting signup behavior.

Recommended direction:

- Preserve the verified OTP type in `EmailLinkResult`, or return distinct
  outcomes for signup, email change, invite, and magic link.
- After verification, use the global onboarding gate to choose the destination
  from the user's actual profile instead of assuming that every verified link
  belongs to a new account.
- Add behavioral tests for every supported OTP type, verification failure, and
  missing query parameters. Existing tests currently cover mostly path
  recognition and the low-level verifier.

### 3. Make `/session/start` truly once per authenticated session

**Severity:** Major

`sessionStartedProvider` watches `sessionProvider`. Supabase auth-state events,
including token refreshes or duplicate initial-session emissions, can invalidate
the future and call the side-effecting endpoint again. The provider is also
activated only when Home is built.

Relevant code:

- `lib/core/providers.dart:19-23`
- `lib/features/home/home_providers.dart:10-17`
- `lib/features/home/home_screen.dart:17`

This endpoint represents login semantics, including daily-login effects,
pending-deletion handling, and restriction checks. Its lifecycle should not be
coupled to a particular screen.

Recommended direction:

- Trigger it from authenticated-session orchestration, not from Home rendering.
- Deduplicate by stable session/user identity and reset that state on sign-out.
- Confirm the backend endpoint is idempotent, but do not rely on idempotency as
  the only client-side lifecycle control.
- Define how a restriction, suspension, or pending-deletion response affects
  routing and user-visible state.

Tests should simulate initial-session duplication, token refresh, sign-out and
sign-in, and navigation that never visits Home.

### 4. Normalize asynchronous auth error handling

**Severity:** Major

Several user-initiated requests can throw outside the screen's handled error
path:

- `lib/features/auth/forgot_password_screen.dart:19-23`
- `lib/features/auth/reset_password_screen.dart:20-27`
- `lib/features/auth/login_screen.dart:50-57`
- `lib/features/auth/google_sign_in_button.dart:21-30`
- `lib/core/auth/auth_repository.dart:84-101`

Examples:

- Forgot-password failure leaves `_loading` true and produces no user-visible
  error.
- Reset and resend failures can escape as unhandled asynchronous exceptions.
- Google SDK initialization/authentication errors happen outside the
  repository's `AuthApiException` catch, while the widget catches only the
  application's `AuthException`.
- Account sign-out starts an unawaited future with no failure state.

Recommended direction:

- Translate expected SDK/API failures into the app's stable error-code model at
  the repository boundary.
- Give every submitting screen a `try`/`catch`/`finally` path that restores its
  loading state and presents localized, non-technical feedback.
- Do not display raw backend or platform exception text to users.
- Add failure-path widget tests, not only successful submission tests.

### 5. Fix widget lifecycle safety

**Severity:** Major for async lifecycle; Minor for controller cleanup

Login, signup, Google sign-in, and username onboarding call `setState` inside
error handlers without first checking `mounted`. Navigating away during a slow
request can therefore cause `setState() called after dispose()`.

Relevant examples:

- `lib/features/auth/login_screen.dart:43-46`
- `lib/features/auth/signup_screen.dart:61-65`
- `lib/features/auth/google_sign_in_button.dart:24-29`
- `lib/features/onboarding/onboarding_username_screen.dart:33-38`

Most auth and onboarding screens also create `TextEditingController`s without
disposing them. `DebugSignInScreen` already demonstrates the expected disposal
pattern.

Recommended direction:

- Check `mounted` after every awaited operation before accessing widget state,
  calling callbacks tied to the widget, or calling `setState`.
- Add `dispose()` methods for all owned controllers.
- Add a widget test that starts a pending request, removes the screen, completes
  the request, and asserts that no framework exception occurs.

## Secondary findings

### Localization drift

The repository says visible copy should come from ARB files, but navigation,
Account, some Home content, coming-soon screens, and several errors are still
hard-coded. Examples include `lib/router/app_router.dart:65-69` and
`lib/features/account/account_screen.dart:19-38`.

Move this copy into localization resources as the affected screens are touched.
Avoid a broad unrelated rewrite if the work would obscure the lifecycle fixes.

### Incoming-link listener ownership

`listenForIncomingLinks` does not retain/cancel its subscription and ignores
errors from asynchronous link handling:

- `lib/core/routing/incoming_links.dart:42-47`

Give the listener explicit application-lifecycle ownership and report or handle
stream/verification failures without producing unhandled futures.

### User-facing raw errors

Home currently renders `Failed to load: $e` in
`lib/features/home/home_screen.dart:44`. Replace raw exception output with
localized user-safe copy, while sending technical details to the existing error
reporter.

### API decoding resilience

`ApiClient._send` maps Dio transport errors and documented error envelopes, but
model-cast failures escape as raw runtime type errors. Decide whether malformed
successful responses should become a stable `bad_response` `ApiException`, and
test that behavior.

## Suggested implementation order

1. Add failing tests for global route gates and email-link destinations.
2. Implement router-level auth/onboarding orchestration.
3. Correct OTP outcome handling and route through the global gate.
4. Move and deduplicate `/session/start` at the session lifecycle boundary.
5. Add auth failure-path tests and normalize repository/UI error handling.
6. Fix `mounted` checks and controller disposal.
7. Address localization and listener ownership in the files touched above.
8. Run the complete analyzer and test suite, then perform device-level App Link
   checks for signup confirmation, recovery, and email change.

## Verification limitation from this review

`flutter analyze`, `flutter test`, and even `flutter --version` were attempted
from PowerShell. The Flutter CLI hung without emitting output and had to be
interrupted, so this review does **not** claim that analysis or tests currently
pass. Diagnose the local Flutter toolchain/lock condition before relying on the
repository's local-only quality gate.

## Worktree caution

At review time, these pre-existing user-owned modifications were present:

- `docs/superpowers/specs/2026-09-18-flutter-mobile-app-master-design.md`
- `macos/Flutter/GeneratedPluginRegistrant.swift`

Do not overwrite, revert, or fold those changes into lifecycle fixes without
first establishing their intent.

