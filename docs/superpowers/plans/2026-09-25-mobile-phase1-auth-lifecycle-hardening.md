# Mobile Phase 1 Auth/Lifecycle Hardening Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Close the five "Major" gaps and four secondary gaps raised in the 2026-09-23 code-review handoff
(`docs/agent-handoffs/2026-09-23-code-review-handoff.md`) so Phase 1 is release-ready: a global router-level
auth/onboarding guard, correct email-link OTP routing with owned listener lifecycle, a session-lifecycle trigger
that isn't tied to Home, normalized error handling at both the repository/API boundary and in every auth screen,
`mounted`-safe widget lifecycle, and no raw exception text shown to a user.

**Architecture:** A pure, unit-testable redirect function (`evaluateAuthRedirect`) drives a new `redirect:` branch
in the existing `GoRouter`, refreshed via `ref.listen` on the auth providers already in `lib/core/providers.dart`
— no new state-management approach, no new dependency. `/session/start` and the incoming-link stream each get a
small `Provider`-owned lifecycle object (mirroring the existing `errorReporterProvider` pattern) instead of being
triggered from a screen's `build()`. Every auth screen gets the same three-part fix applied uniformly: a
`mounted`-guarded `try/catch/finally`, a `dispose()` for its controllers, and localized copy for every user-visible
string — no widget introduces a new state-management pattern.

**Tech Stack:** Flutter, Riverpod (manual providers, no codegen), go_router, Supabase Auth (`supabase_flutter`),
`google_sign_in` 7.2.0, Dio.

**Spec:** `docs/agent-handoffs/2026-09-23-code-review-handoff.md` (the review this plan implements). No separate
design spec exists — the review itself is the spec; this plan is the first artifact translating its "Recommended
direction" prose into concrete diffs.

## Global Constraints

- **Work in an isolated worktree** (`git worktree add ..\sentinelx_mobile-auth-hardening -b fix/phase1-auth-lifecycle
  origin/master`) per `AGENTS.md` §"Parallel work" — other agents use this repo concurrently.
- **Hotspot files** (`AGENTS.md`): `lib/core/api/api_client.dart`, `lib/router/app_router.dart`, `api/openapi.json`,
  ARB and generated l10n. Touch them by appended/localized edits only, and **rebase onto `origin/master` before
  your final checks** in every task that touches one of these.
- **Known concurrent collision risk:** `docs/superpowers/plans/2026-09-23-mobile-phase3a-flutter-screens.md` (untracked
  in this checkout as of 2026-09-25, likely being built by another agent in its own worktree) modifies
  `lib/router/app_router.dart` (new sibling routes under the Compete branch — should not conflict with Task 1's
  `redirect:`/`routerProvider` edits) **and** `lib/features/home/home_screen.dart` ("three entry tiles") **and**
  adds tests in `test/features/home_screen_test.dart` that reference `sessionStartedProvider`, which Task 3/6 of
  this plan removes. Before starting Task 6, check whether that plan has merged; if `sessionStartedProvider` is
  gone from your `home_screen_test.dart` baseline already, adjust its new tests instead of reintroducing the
  provider. If it's still in flight, coordinate with the user before merging Task 6.
- **Copy is never hard-coded in widgets** — new strings go in `lib/core/l10n/app_en.arb` **and** `app_fr.arb`
  (currently 1:1, 154 keys each; keep parity). Run `flutter gen-l10n` after every `.arb` edit and commit the
  generated output; never hand-edit `lib/core/l10n/gen/*`.
- **Verify the toolchain before trusting any "tests pass" claim.** The 2026-09-23 review could not get
  `flutter analyze`/`flutter test`/`flutter --version` to complete under PowerShell in this environment (hung,
  had to be interrupted). Before Task 1's first test run, confirm `flutter --version` returns promptly in your
  shell; if it hangs under PowerShell, try the Bash tool / git-bash instead. Do not claim a test run passed
  without seeing it actually exit.
- **American spelling** in new prose/code (existing identifiers stay as-is).
- Verification before every commit: `flutter analyze` (no issues) and `flutter test` (must pass).
- **Out of scope, noted but not fixed here:** `POST /session/start` (web repo, `lib/mobile-api/endpoints/session.ts`)
  awards coins/XP via `recordDailyLogin` (`lib/login/actions.ts`) but is not marked `idempotent: true`, and its
  day-level dedupe is a plain read-then-write with no lock — a genuine (if narrow) double-award race exists
  server-side. This is a **web-repo** change under a different CLAUDE.md rule (§12, money-creating POSTs must use
  the idempotency primitive) and needs its own plan; Task 3 here only fixes the *client's* contribution to the
  race (repeated calls), it does not touch the web repo.

---

## File Structure

| File | Responsibility |
|---|---|
| `lib/router/auth_redirect.dart` (new) | Pure `AuthGateSnapshot` + `evaluateAuthRedirect()` — the router's onboarding-gate decision, unit-testable with no widget/Riverpod dependency. |
| `lib/router/app_router.dart` (modify) | Wire `authGate`/`refreshListenable` into the existing `redirect:` callback; `routerProvider` supplies the real snapshot via `ref.listen`. |
| `lib/core/auth/email_link_handler.dart` (modify) | `EmailLinkOutcome` grows distinct cases per OTP type instead of collapsing to one `verified`. |
| `lib/core/routing/incoming_links.dart` (modify) | Route each distinct outcome correctly; replace the discarded stream subscription with an owned `IncomingLinkListener` lifecycle object. |
| `lib/core/session/session_lifecycle.dart` (new) | `/session/start` fired exactly once per signed-in user id, owned by app lifecycle, not by Home. |
| `lib/features/home/home_providers.dart` (modify) | Remove `sessionStartedProvider` (superseded by `session_lifecycle.dart`). |
| `lib/features/home/home_screen.dart` (modify) | Remove the per-screen onboarding-gate/session-start side effects (now global); replace raw exception text with localized copy + error-reporter call. |
| `lib/core/auth/auth_repository.dart` (modify) | `signInWithGoogle()` translates `GoogleSignInException` into `AuthException` like every other failure mode. |
| `lib/core/api/api_client.dart` (modify) | `_send()` wraps `parse()` so a malformed success body becomes `ApiException(bad_response)` instead of a raw cast error. |
| `lib/features/auth/login_screen.dart`, `signup_screen.dart`, `forgot_password_screen.dart`, `reset_password_screen.dart`, `google_sign_in_button.dart`, `onboarding/onboarding_username_screen.dart`, `account/account_screen.dart` (modify) | `mounted`-guarded error handling, controller `dispose()`, localized copy. |
| `lib/main.dart` (modify) | Read `sessionLifecycleProvider` / the new `incomingLinkListenerProvider` at startup instead of calling `listenForIncomingLinks` directly. |
| `lib/core/l10n/app_en.arb`, `app_fr.arb` (modify) | New keys listed per task; `flutter gen-l10n` regenerates `lib/core/l10n/gen/*`. |

---

### Task 1: Router-level auth/onboarding redirect

**Files:**
- Create: `lib/router/auth_redirect.dart`
- Create: `test/router/auth_redirect_test.dart`
- Modify: `lib/router/app_router.dart:1-31` (imports, `redirect:` callback), `:119-123` (`routerProvider`)
- Modify: `test/router/app_router_test.dart` (append)

**Interfaces:**
- Produces: `class AuthGateSnapshot { final bool isLoading; final bool isSignedIn; final OnboardingGate onboardingGate; const AuthGateSnapshot({required this.isLoading, required this.isSignedIn, required this.onboardingGate}); }`
- Produces: `String? evaluateAuthRedirect(AuthGateSnapshot gate, String location)`
- Produces: `GoRouter buildAppRouter({bool debugTools = false, String initialLocation = '/', AuthGateSnapshot Function()? authGate, Listenable? refreshListenable})` — new optional params, default `null`/no-op so every existing caller (`buildAppRouter()`, `buildAppRouter(initialLocation: '/tournaments')` in `pump_app.dart`) is unaffected.

- [ ] **Step 1: Write the failing unit tests for the pure redirect function**

```dart
// test/router/auth_redirect_test.dart
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
```

- [ ] **Step 2: Run it to confirm it fails**

Run: `flutter test test/router/auth_redirect_test.dart`
Expected: FAIL — `package:sentinelx_mobile/router/auth_redirect.dart` does not exist.

- [ ] **Step 3: Implement the pure redirect function**

```dart
// lib/router/auth_redirect.dart
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
```

- [ ] **Step 4: Run it to confirm it passes**

Run: `flutter test test/router/auth_redirect_test.dart`
Expected: PASS, 7 tests.

- [ ] **Step 5: Wire the snapshot into `buildAppRouter` and `routerProvider`**

In `lib/router/app_router.dart`, add the import and extend the signature/redirect body:

```dart
import 'package:flutter/material.dart'; // already imported — Listenable comes from here
import 'auth_redirect.dart';
```

```dart
GoRouter buildAppRouter({
  bool debugTools = false,
  String initialLocation = '/',
  AuthGateSnapshot Function()? authGate,
  Listenable? refreshListenable,
}) {
  return GoRouter(
    initialLocation: initialLocation,
    refreshListenable: refreshListenable,
    redirect: (context, state) {
      final incoming = state.uri.toString();
      final resolved = resolveWebLink(incoming);
      if (resolved != null && resolved != incoming) return resolved;
      final gate = authGate?.call();
      if (gate != null) {
        final authRedirect = evaluateAuthRedirect(gate, state.matchedLocation);
        if (authRedirect != null) return authRedirect;
      }
      return null;
    },
    routes: [
      // unchanged
```

Replace `routerProvider` at the bottom of the file:

```dart
final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _RouterRefresh();
  ref.listen(sessionProvider, (_, _) => refresh.ping());
  ref.listen(meProvider, (_, _) => refresh.ping());
  final router = buildAppRouter(
    debugTools: ref.watch(appConfigProvider).debugTools,
    authGate: () => AuthGateSnapshot(
      isLoading: ref.read(sessionProvider).isLoading ||
          (ref.read(sessionProvider).value != null && ref.read(meProvider).isLoading),
      isSignedIn: ref.read(meProvider).asData?.value != null,
      onboardingGate: ref.read(onboardingGateProvider),
    ),
    refreshListenable: refresh,
  );
  ref.onDispose(() {
    router.dispose();
    refresh.dispose();
  });
  return router;
});

class _RouterRefresh extends ChangeNotifier {
  void ping() => notifyListeners();
}
```

Add the two new provider imports already used elsewhere in this file's import block: `sessionProvider`/`meProvider`/`onboardingGateProvider` come from `../core/providers.dart` (already imported) and `../core/auth/auth_providers.dart` (new import needed for `onboardingGateProvider`).

- [ ] **Step 6: Add a router-level widget test proving the wiring, not just the pure function**

Append to `test/router/app_router_test.dart`:

```dart
import 'package:sentinelx_mobile/router/auth_redirect.dart';

// ... inside main(), after the existing tests:

testWidgets('a signed-in user needing a username is redirected there on initial load', (tester) async {
  final router = buildAppRouter(
    initialLocation: '/tournaments',
    authGate: () => const AuthGateSnapshot(isLoading: false, isSignedIn: true, onboardingGate: OnboardingGate.username),
  );
  await tester.pumpWidget(MaterialApp.router(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    routerConfig: router,
  ));
  await tester.pumpAndSettle();
  expect(router.routerDelegate.currentConfiguration.uri.toString(), '/onboarding/username');
});
```

(`OnboardingGate` needs `import 'package:sentinelx_mobile/core/auth/onboarding_gate.dart';` added to the test file if not already present via a transitive export — check first with `flutter analyze` in Step 8.)

- [ ] **Step 7: Run the full router test file**

Run: `flutter test test/router/app_router_test.dart test/router/auth_redirect_test.dart`
Expected: PASS, all tests including the pre-existing ones (unaffected since `authGate`/`refreshListenable` default to `null`).

- [ ] **Step 8: Analyze and run the whole suite**

Run: `flutter analyze && flutter test`
Expected: no issues, full suite green (this proves the optional new params didn't break any other `buildAppRouter()` caller, e.g. `test/support/pump_app.dart`).

- [ ] **Step 9: Commit**

```bash
git add lib/router/auth_redirect.dart lib/router/app_router.dart test/router/auth_redirect_test.dart test/router/app_router_test.dart
git commit -m "feat(router): global auth/onboarding redirect guard"
```

---

### Task 2: Preserve email-link OTP outcomes; own the incoming-link listener

**Depends on:** Task 1 (the `emailChanged`/`invited`/`magicLink` outcomes route to `/` and rely on Task 1's global
redirect to promote to onboarding only if actually needed).

**Files:**
- Modify: `lib/core/auth/email_link_handler.dart`
- Modify: `lib/core/routing/incoming_links.dart`
- Modify: `lib/main.dart`
- Modify: `test/core/email_link_handler_test.dart`, `test/core/incoming_links_test.dart` (append)

**Interfaces:**
- Produces: `enum EmailLinkOutcome { signupConfirmed, emailChanged, invited, magicLink, recovery, failed }` (replaces the old 3-value enum)
- Produces: `class IncomingLinkListener { IncomingLinkListener({required GoRouter router, required GoTrueClient auth, required void Function(Object, StackTrace) onError}); void dispose(); }`
- Produces: `final incomingLinkListenerProvider = Provider<IncomingLinkListener>(...)`

- [ ] **Step 1: Write the failing test for the new outcome mapping**

Replace the two now-inaccurate tests in `test/core/email_link_handler_test.dart` (`'a signup confirmation link reports outcome=verified'` and `'a locale-prefixed link (fr/pcm) is still handled'`) with:

```dart
test('a signup confirmation link reports outcome=signupConfirmed', () async {
  final auth = _FakeAuth();
  final result = await handleEmailLink(
    Uri.parse('https://sentinelxesports.com.ng/auth/confirm?token_hash=xyz&type=signup'),
    auth: auth,
  );
  expect(result.outcome, EmailLinkOutcome.signupConfirmed);
});

test('an email-change link (locale-prefixed) reports outcome=emailChanged, not signupConfirmed', () async {
  final auth = _FakeAuth();
  final result = await handleEmailLink(
    Uri.parse('https://sentinelxesports.com.ng/fr/auth/confirm?token_hash=xyz&type=email_change'),
    auth: auth,
  );
  expect(result.outcome, EmailLinkOutcome.emailChanged);
});

test('invite and magic-link types report their own distinct outcomes', () async {
  final auth = _FakeAuth();
  final invite = await handleEmailLink(
    Uri.parse('https://sentinelxesports.com.ng/auth/confirm?token_hash=a&type=invite'), auth: auth,
  );
  expect(invite.outcome, EmailLinkOutcome.invited);
  final magic = await handleEmailLink(
    Uri.parse('https://sentinelxesports.com.ng/auth/confirm?token_hash=b&type=magiclink'), auth: auth,
  );
  expect(magic.outcome, EmailLinkOutcome.magicLink);
});
```

- [ ] **Step 2: Run to confirm it fails**

Run: `flutter test test/core/email_link_handler_test.dart`
Expected: FAIL — `EmailLinkOutcome.signupConfirmed` etc. undefined (enum still has `verified`).

- [ ] **Step 3: Implement the new outcome mapping**

```dart
// lib/core/auth/email_link_handler.dart
import 'package:supabase_flutter/supabase_flutter.dart';

enum EmailLinkOutcome { signupConfirmed, emailChanged, invited, magicLink, recovery, failed }

class EmailLinkResult {
  const EmailLinkResult(this.outcome);
  final EmailLinkOutcome outcome;
}

const _typeMap = {
  'signup': OtpType.signup,
  'recovery': OtpType.recovery,
  'email_change': OtpType.emailChange,
  'invite': OtpType.invite,
  'magiclink': OtpType.magiclink,
};

const _outcomeByType = {
  OtpType.signup: EmailLinkOutcome.signupConfirmed,
  OtpType.recovery: EmailLinkOutcome.recovery,
  OtpType.emailChange: EmailLinkOutcome.emailChanged,
  OtpType.invite: EmailLinkOutcome.invited,
  OtpType.magiclink: EmailLinkOutcome.magicLink,
};

// Handles a claimed https://sentinelxesports.com.ng/auth/confirm App Link.
// Same token_hash+type flow the web route (app/auth/confirm/route.ts) uses —
// verifyOtp establishes a session locally, no code exchange, no fragment.
Future<EmailLinkResult> handleEmailLink(Uri link, {required GoTrueClient auth}) async {
  final tokenHash = link.queryParameters['token_hash'];
  final typeParam = link.queryParameters['type'];
  final type = typeParam == null ? null : _typeMap[typeParam];
  if (tokenHash == null || type == null) return const EmailLinkResult(EmailLinkOutcome.failed);

  try {
    await auth.verifyOTP(type: type, tokenHash: tokenHash);
  } catch (_) {
    return const EmailLinkResult(EmailLinkOutcome.failed);
  }

  return EmailLinkResult(_outcomeByType[type]!);
}
```

- [ ] **Step 4: Run to confirm it passes**

Run: `flutter test test/core/email_link_handler_test.dart`
Expected: PASS.

- [ ] **Step 5: Write the failing test for routing by outcome**

Append to `test/core/incoming_links_test.dart`:

```dart
import 'package:sentinelx_mobile/core/auth/email_link_handler.dart';
import 'package:sentinelx_mobile/router/app_router.dart';

class _FakeAuth implements GoTrueClient {
  @override
  Future<AuthResponse> verifyOTP({
    String? email, String? phone, String? token, required OtpType type,
    String? redirectTo, String? captchaToken, String? tokenHash,
  }) async => AuthResponse();
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// ... inside main(), a new group:

group('handleIncomingLink routes by outcome', () {
  test('signup confirmation goes straight to onboarding/username', () async {
    final router = buildAppRouter();
    await handleIncomingLink(
      Uri.parse('https://sentinelxesports.com.ng/auth/confirm?token_hash=a&type=signup'),
      router: router, auth: _FakeAuth(),
    );
    expect(router.routerDelegate.currentConfiguration.uri.toString(), '/onboarding/username');
  });

  test('an email-change confirmation goes Home, not onboarding', () async {
    final router = buildAppRouter();
    await handleIncomingLink(
      Uri.parse('https://sentinelxesports.com.ng/auth/confirm?token_hash=a&type=email_change'),
      router: router, auth: _FakeAuth(),
    );
    expect(router.routerDelegate.currentConfiguration.uri.toString(), '/');
  });

  test('a recovery link goes to reset-password', () async {
    final router = buildAppRouter();
    await handleIncomingLink(
      Uri.parse('https://sentinelxesports.com.ng/auth/confirm?token_hash=a&type=recovery'),
      router: router, auth: _FakeAuth(),
    );
    expect(router.routerDelegate.currentConfiguration.uri.toString(), '/reset-password');
  });
});
```

- [ ] **Step 6: Run to confirm it fails**

Run: `flutter test test/core/incoming_links_test.dart`
Expected: FAIL — `handleIncomingLink`'s switch is not exhaustive over the new enum (compile error) until Step 7.

- [ ] **Step 7: Update `handleIncomingLink`'s switch and add the owned listener class**

```dart
// lib/core/routing/incoming_links.dart
import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/email_link_handler.dart';
import 'web_links.dart';

const _locales = {'en', 'fr', 'pcm'};

bool isAuthConfirmPath(Uri uri) {
  final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
  if (segments.isNotEmpty && _locales.contains(segments.first)) segments.removeAt(0);
  return segments.join('/') == 'auth/confirm';
}

Future<void> handleIncomingLink(Uri uri, {required GoRouter router, required GoTrueClient auth}) async {
  if (isAuthConfirmPath(uri)) {
    final result = await handleEmailLink(uri, auth: auth);
    switch (result.outcome) {
      case EmailLinkOutcome.recovery:
        router.go('/reset-password');
      case EmailLinkOutcome.signupConfirmed:
        // Username is claimed AFTER confirmation, never before (design spec
        // §4.1) — always true immediately after a signup link, so go there
        // directly rather than via Home (the router's global auth redirect
        // in app_router.dart would reach the same place after a load flash).
        router.go('/onboarding/username');
      case EmailLinkOutcome.emailChanged:
      case EmailLinkOutcome.invited:
      case EmailLinkOutcome.magicLink:
        // Not a new signup — go Home and let the router's global
        // auth/onboarding redirect (evaluateAuthRedirect) decide whether
        // this account still needs onboarding.
        router.go('/');
      case EmailLinkOutcome.failed:
        router.go('/login');
    }
    return;
  }
  final resolved = resolveWebLink(uri.toString());
  if (resolved != null) router.go(resolved);
}

/// Owns the App Links subscription for the app's lifetime (constructed once
/// via incomingLinkListenerProvider) instead of a fire-and-forget
/// `.listen(...)` with no retained subscription, and reports failures
/// instead of letting them become an unhandled Future error.
class IncomingLinkListener {
  IncomingLinkListener({required GoRouter router, required GoTrueClient auth, required this.onError}) {
    final appLinks = AppLinks();
    _subscription = appLinks.uriLinkStream.listen(
      (uri) => _handle(uri, router, auth),
      onError: (Object error, StackTrace stack) => onError(error, stack),
    );
    appLinks.getInitialLink().then((uri) {
      if (uri != null) _handle(uri, router, auth);
    }).catchError((Object error, StackTrace stack) => onError(error, stack));
  }

  final void Function(Object error, StackTrace stack) onError;
  late final StreamSubscription<Uri> _subscription;

  void _handle(Uri uri, GoRouter router, GoTrueClient auth) {
    handleIncomingLink(uri, router: router, auth: auth)
        .catchError((Object error, StackTrace stack) => onError(error, stack));
  }

  void dispose() => _subscription.cancel();
}
```

- [ ] **Step 8: Wire the provider**

Append to `lib/core/routing/incoming_links.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../errors/error_reporter.dart';
import '../providers.dart';
import '../../router/app_router.dart';

final incomingLinkListenerProvider = Provider<IncomingLinkListener>((ref) {
  final reporter = ref.watch(errorReporterProvider);
  final listener = IncomingLinkListener(
    router: ref.watch(routerProvider),
    auth: ref.watch(supabaseClientProvider).auth,
    onError: (error, stack) => reporter.report(error, stack, route: 'incoming-link'),
  );
  ref.onDispose(listener.dispose);
  return listener;
});
```

(Check for an import cycle before running: `app_router.dart` must not import `incoming_links.dart`. It currently
imports only `web_links.dart`, so this is safe — confirm with `flutter analyze` in Step 10.)

- [ ] **Step 9: Replace the call site in `main.dart`**

```dart
// lib/main.dart — replace the final line
container.read(incomingLinkListenerProvider);
```

Remove the now-unused `listenForIncomingLinks(...)` call and its now-unused import if nothing else references it
(`incoming_links.dart` import for `handleIncomingLink`/`isAuthConfirmPath` stays needed by tests, not by `main.dart`).

- [ ] **Step 10: Run the full suite**

Run: `flutter analyze && flutter test`
Expected: no issues, all tests including the two new groups pass.

- [ ] **Step 11: Commit**

```bash
git add lib/core/auth/email_link_handler.dart lib/core/routing/incoming_links.dart lib/main.dart \
  test/core/email_link_handler_test.dart test/core/incoming_links_test.dart
git commit -m "fix(auth): distinguish email-link OTP outcomes, own the incoming-link listener"
```

---

### Task 3: Move `/session/start` to session-lifecycle orchestration

**Files:**
- Create: `lib/core/session/session_lifecycle.dart`
- Create: `test/core/session_lifecycle_test.dart`
- Modify: `lib/features/home/home_providers.dart` (remove `sessionStartedProvider`)
- Modify: `lib/main.dart`

**Interfaces:**
- Consumes: `sessionProvider` (`StreamProvider<Session?>`), `apiClientProvider` (`.postSessionStart()`) from `lib/core/providers.dart`
- Produces: `final sessionLifecycleProvider = Provider<SessionLifecycle>(...)`

- [ ] **Step 1: Write the failing test**

```dart
// test/core/session_lifecycle_test.dart
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/core/session/session_lifecycle.dart';

// A tiny fake standing in for the pieces sessionLifecycleProvider reads —
// exercised through overridden providers, same pattern the rest of this
// repo uses for apiClientProvider/sessionProvider in provider-level tests.
import 'package:sentinelx_mobile/core/providers.dart';
import 'package:sentinelx_mobile/core/api/api_client.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthException;

Session _sessionFor(String userId) => Session(
      accessToken: 'tok-$userId',
      tokenType: 'bearer',
      user: User(id: userId, appMetadata: const {}, userMetadata: const {}, aud: '', createdAt: ''),
    );

void main() {
  test('fires postSessionStart once for a given user id even if the Session object re-emits', () async {
    var calls = 0;
    final controller = StreamController<Session?>.broadcast();
    final container = ProviderContainer(overrides: [
      sessionProvider.overrideWith((ref) => controller.stream),
      apiClientProvider.overrideWith((ref) => _CountingApiClient(() => calls++)),
    ]);
    addTearDown(container.dispose);

    container.read(sessionLifecycleProvider);
    controller.add(_sessionFor('u1'));
    await Future<void>.delayed(Duration.zero);
    // Simulate a token refresh: a new Session instance, same user id.
    controller.add(_sessionFor('u1'));
    await Future<void>.delayed(Duration.zero);

    expect(calls, 1);
  });

  test('a sign-out then a different sign-in fires again for the new user', () async {
    var calls = 0;
    final controller = StreamController<Session?>.broadcast();
    final container = ProviderContainer(overrides: [
      sessionProvider.overrideWith((ref) => controller.stream),
      apiClientProvider.overrideWith((ref) => _CountingApiClient(() => calls++)),
    ]);
    addTearDown(container.dispose);

    container.read(sessionLifecycleProvider);
    controller.add(_sessionFor('u1'));
    await Future<void>.delayed(Duration.zero);
    controller.add(null);
    await Future<void>.delayed(Duration.zero);
    controller.add(_sessionFor('u2'));
    await Future<void>.delayed(Duration.zero);

    expect(calls, 2);
  });
}

class _CountingApiClient implements ApiClient {
  _CountingApiClient(this.onCall);
  final void Function() onCall;

  @override
  Future<SessionStartResponse> postSessionStart() async {
    onCall();
    return const SessionStartResponse(
      dailyLogin: DailyLoginAward(awardedToday: false, coinsAwarded: 0, xpAwarded: 0, streak: 0, milestone: null),
      deletionRequestedAt: null,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
```

(Verify `Session`/`User`'s required constructor fields and `SessionStartResponse`/`DailyLoginAward`'s exact field
names against `lib/core/api/models.dart` before running — if a field name differs, use the real one; this is the
one part of this task most likely to need a small adjustment for the SDK version pinned in `pubspec.lock`.)

- [ ] **Step 2: Run to confirm it fails**

Run: `flutter test test/core/session_lifecycle_test.dart`
Expected: FAIL — `session_lifecycle.dart` does not exist.

- [ ] **Step 3: Implement `SessionLifecycle`**

```dart
// lib/core/session/session_lifecycle.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../providers.dart';

/// Fires POST /session/start exactly once per signed-in user id, regardless
/// of how many times the underlying Supabase Session object changes (token
/// refresh, duplicate initial-session emissions — each is a new Session
/// instance so watching sessionProvider directly, as the old
/// sessionStartedProvider did, re-fires on every one of them). Owned by app
/// startup (see incomingLinkListenerProvider for the sibling pattern), not
/// any particular screen — a signed-in user reaches this exactly once no
/// matter which screen they land on first.
class SessionLifecycle {
  SessionLifecycle(Ref ref) : _ref = ref {
    _sub = ref.listen<AsyncValue<Session?>>(sessionProvider, _onSessionChange, fireImmediately: true);
  }

  final Ref _ref;
  String? _startedForUserId;
  late final ProviderSubscription<AsyncValue<Session?>> _sub;

  void _onSessionChange(AsyncValue<Session?>? previous, AsyncValue<Session?> next) {
    final userId = next.asData?.value?.user.id;
    if (userId == null) {
      _startedForUserId = null;
      return;
    }
    if (_startedForUserId == userId) return;
    _startedForUserId = userId;
    _ref.read(apiClientProvider).postSessionStart().catchError((Object _) {
      // A failed session/start must not crash startup or block navigation —
      // clear the guard so the next auth-state event (e.g. the next token
      // refresh) retries rather than giving up on this user id forever.
      if (_startedForUserId == userId) _startedForUserId = null;
    });
  }

  void dispose() => _sub.close();
}

final sessionLifecycleProvider = Provider<SessionLifecycle>((ref) {
  final lifecycle = SessionLifecycle(ref);
  ref.onDispose(lifecycle.dispose);
  return lifecycle;
});
```

- [ ] **Step 4: Run to confirm it passes**

Run: `flutter test test/core/session_lifecycle_test.dart`
Expected: PASS.

- [ ] **Step 5: Remove `sessionStartedProvider`**

In `lib/features/home/home_providers.dart`, delete the `sessionStartedProvider` declaration and its comment block
(lines 10-17 in the current file), leaving only `homeRepositoryProvider`/`homeProvider`. (Task 6 removes the
`ref.watch(sessionStartedProvider);` call site in `home_screen.dart` — leave that edit to Task 6 so this task's
diff stays about the lifecycle move, not Home's cleanup; `flutter analyze` will report the now-dangling reference
in `home_screen.dart` until Task 6 runs, which is expected and acceptable as an interim state within this same
plan's execution — do not skip Task 6.)

- [ ] **Step 6: Wire it in `main.dart`**

```dart
// lib/main.dart — add before the incomingLinkListenerProvider read (order doesn't matter, both are independent)
container.read(sessionLifecycleProvider);
```

Add the import: `import 'core/session/session_lifecycle.dart';`

- [ ] **Step 7: Commit**

(This task's `flutter analyze`/`flutter test` will not be fully clean until Task 6 removes the dangling
`sessionStartedProvider` reference in `home_screen.dart` — run the verification at the end of Task 6 instead, and
commit this task's files together with Task 6's, OR reorder execution to do Task 6 immediately after Task 3 if
running tasks out of the written order. If executing strictly in order, still commit now with a note in the
message that Task 6 completes the cleanup:)

```bash
git add lib/core/session/session_lifecycle.dart lib/features/home/home_providers.dart lib/main.dart \
  test/core/session_lifecycle_test.dart
git commit -m "feat(session): move /session/start to app-lifecycle orchestration, dedupe by user id"
```

---

### Task 4: Repository/API-layer error resilience

**Files:**
- Modify: `lib/core/auth/auth_repository.dart`
- Modify: `lib/core/api/api_client.dart`
- Modify: `test/core/auth_repository_test.dart` (check the file exists and follow its existing `_FakeAuth`/fake pattern; append), `test/core/api_client_test.dart` (append)

**Interfaces:**
- Produces (unchanged signature, changed behavior): `Future<void> signInWithGoogle()` on `SupabaseAuthRepository` — now always throws `AuthException`, never a raw `GoogleSignInException`.
- Produces (unchanged signature, changed behavior): `ApiClient._send`'s `parse()` failures now throw `ApiException(code: 'bad_response')` instead of propagating a raw `TypeError`.

**Verified:** `test/core/auth_repository_test.dart` (read in full while writing this plan) uses hand-written
`_FakeAuth implements GoTrueClient` / `_FakeApi implements ApiClient` fakes with a shared `_Recording` helper, and
today only compile-checks `signInWithGoogle`'s existence (lines 122-126) — it never calls it, because
`SupabaseAuthRepository.signInWithGoogle()` reaches through the real static `GoogleSignIn.instance` first, which
this repo has no injection seam for. Adding one is a larger refactor outside this review's scope, so the new
`on GoogleSignInException` branch itself is not unit-testable here — it's covered by Task 5's manual device-check
exit criteria (cancel/fail Google sign-in) instead. This step adds the one case that *is* reachable today without
a new seam: the `google_not_configured` guard, which returns before ever touching `GoogleSignIn.instance`, so it
exercises the same function with the same fakes the file already uses.

- [ ] **Step 1: Write the failing test**

Append to `test/core/auth_repository_test.dart`:

```dart
test('signInWithGoogle throws google_not_configured before touching the Google SDK when no client id is set', () async {
  final rec = _Recording();
  final repo = SupabaseAuthRepository(_FakeAuth(rec), _FakeApi(rec)); // googleWebClientId defaults to ''
  await expectLater(
    repo.signInWithGoogle(),
    throwsA(isA<AuthException>().having((e) => e.code, 'code', 'google_not_configured')),
  );
});
```

- [ ] **Step 2: Run to confirm it passes already** (this guard clause is untouched by Step 3's edit, only newly
  tested — expected PASS immediately, no code change needed for this specific test)

Run: `flutter test test/core/auth_repository_test.dart`

- [ ] **Step 3: Implement the wider try/catch in `signInWithGoogle`**

```dart
// lib/core/auth/auth_repository.dart
@override
Future<void> signInWithGoogle() async {
  if (_googleWebClientId.isEmpty) {
    throw const AuthException('google_not_configured', 'Google sign-in is not set up yet.');
  }
  try {
    final googleSignIn = GoogleSignIn.instance;
    await googleSignIn.initialize(serverClientId: _googleWebClientId);
    final account = await googleSignIn.authenticate();
    final idToken = account.authentication.idToken;
    if (idToken == null) {
      throw const AuthException('google_no_token', 'Google sign-in did not return a token.');
    }
    await _auth.signInWithIdToken(provider: OAuthProvider.google, idToken: idToken);
  } on GoogleSignInException catch (e) {
    if (e.code == GoogleSignInExceptionCode.canceled) {
      throw const AuthException('google_canceled', 'Sign-in was canceled.');
    }
    throw AuthException('google_sign_in_failed', e.description ?? 'Google sign-in failed.');
  } on AuthApiException catch (e) {
    throw AuthException(e.code ?? 'signup_failed', e.message);
  }
}
```

(`GoogleSignInException`/`GoogleSignInExceptionCode` are exported by `package:google_sign_in/google_sign_in.dart`,
already imported in this file — no new import needed. `AuthException` thrown from inside the `try` block above
is not re-caught by its own `on GoogleSignInException`/`on AuthApiException` clauses since neither type matches
`AuthException` — it propagates as intended.)

- [ ] **Step 4: Run the auth repository tests**

Run: `flutter test test/core/auth_repository_test.dart`
Expected: PASS, including the pre-existing `AuthApiException` case.

- [ ] **Step 5: Write the failing test for API decode resilience**

Append to `test/core/api_client_test.dart`:

```dart
test('a malformed successful response becomes ApiException(bad_response), not a raw type error', () async {
  final adapter = _FakeAdapter((_) => _json(200, {'data': {'unexpected': true}})); // missing MeResponse's required fields
  await expectLater(
    _client(adapter).getMe(),
    throwsA(isA<ApiException>().having((e) => e.code, 'code', 'bad_response').having((e) => e.status, 'status', 200)),
  );
});
```

- [ ] **Step 6: Run to confirm it fails**

Run: `flutter test test/core/api_client_test.dart`
Expected: FAIL — the current `getMe()` call throws a raw `TypeError` (`null is not a subtype of type 'String'`
from `j['id'] as String` in `MeResponse.fromJson`), which `throwsA(isA<ApiException>()...)` rejects.

- [ ] **Step 7: Implement the wrap in `_send`**

```dart
// lib/core/api/api_client.dart — inside _send, replace the success branch
if (status >= 200 && status < 300 && json is Map<String, dynamic> && json.containsKey('data')) {
  try {
    return parse(json['data']);
  } catch (_) {
    throw ApiException(status: status, code: 'bad_response', message: 'Could not read the server response.');
  }
}
```

- [ ] **Step 8: Run to confirm it passes**

Run: `flutter test test/core/api_client_test.dart`
Expected: PASS, including every pre-existing test in the file (the try/catch only changes behavior when `parse`
itself throws — every existing test's fixtures parse cleanly).

- [ ] **Step 9: Full suite + analyze**

Run: `flutter analyze && flutter test`

- [ ] **Step 10: Commit**

```bash
git add lib/core/auth/auth_repository.dart lib/core/api/api_client.dart \
  test/core/auth_repository_test.dart test/core/api_client_test.dart
git commit -m "fix(auth,api): translate Google SDK and malformed-response failures at the boundary"
```

---

### Task 5: Normalize UI-layer error handling and widget lifecycle safety

**Depends on:** Task 4 (Google errors already arrive at the UI as `AuthException`).

**Files:**
- Modify: `lib/features/auth/login_screen.dart`, `signup_screen.dart`, `forgot_password_screen.dart`,
  `reset_password_screen.dart`, `google_sign_in_button.dart`, `onboarding/onboarding_username_screen.dart`,
  `account/account_screen.dart`
- Modify: `lib/core/l10n/app_en.arb`, `app_fr.arb`
- Modify: `test/features/login_screen_test.dart`, `signup_screen_test.dart` (if present — check first), `forgot_password_screen_test.dart`/`reset_password_screen_test.dart` (if present), `account_screen_test.dart`, `onboarding_username_screen_test.dart`

This task touches seven small files with the same three-part fix each. Do all seven as one deliverable (they are
one reviewable "auth screens are now safe" change) but commit ARB additions first so every subsequent step can
run `flutter gen-l10n` once.

- [ ] **Step 1: Add every new ARB key up front**

In `lib/core/l10n/app_en.arb`, insert alongside the existing `authErrors*` block (after
`"authErrorsResetFailed": "Could not update your password. Please try again."`):

```json
  "authErrorsForgotFailed": "Could not send the reset link. Please try again.",
  "authErrorsResendFailed": "Could not resend the confirmation link. Please try again.",
  "authErrorsGoogleNotConfigured": "Google sign-in isn't set up yet.",
  "authErrorsGoogleFailed": "Google sign-in failed. Please try again.",
```

And a new top-level `account*` group (anywhere after `homeUpcomingHeading` is fine, matching this file's loose
grouping-by-comment convention):

```json
  "accountTitle": "Account",
  "accountLogIn": "Log in",
  "accountCreateAccount": "Create account",
  "accountSignOut": "Sign out",
  "accountSigningOut": "Signing out…",
  "accountSignOutFailed": "Could not sign out. Please try again.",
```

In `lib/core/l10n/app_fr.arb`, insert the matching translations at the same relative positions (this file mirrors
`app_en.arb`'s key order — keep them aligned):

```json
  "authErrorsForgotFailed": "Impossible d'envoyer le lien de réinitialisation. Veuillez réessayer.",
  "authErrorsResendFailed": "Impossible de renvoyer le lien de confirmation. Veuillez réessayer.",
  "authErrorsGoogleNotConfigured": "La connexion Google n'est pas encore configurée.",
  "authErrorsGoogleFailed": "La connexion Google a échoué. Veuillez réessayer.",
```

```json
  "accountTitle": "Compte",
  "accountLogIn": "Se connecter",
  "accountCreateAccount": "Créer un compte",
  "accountSignOut": "Se déconnecter",
  "accountSigningOut": "Déconnexion…",
  "accountSignOutFailed": "Impossible de se déconnecter. Veuillez réessayer.",
```

(Write these as literal UTF-8 characters, not `\u`-escapes, when actually editing the file — the escapes above are
only to survive this plan document's own encoding; match the accent style already used elsewhere in `app_fr.arb`,
e.g. `"À venir"` on line 33.)

Run: `flutter gen-l10n`
Expected: regenerates `lib/core/l10n/gen/app_localizations*.dart` with the new getters; commit the generated diff
together with the `.arb` files at the end of this task, not separately.

- [ ] **Step 2: `login_screen.dart` — mounted-safe errors, resend failure, dispose**

```dart
class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  String? _errorCode;
  bool _resending = false;
  bool _resendFailed = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  String _errorText(AppLocalizations l10n, String code) => switch (code) {
        'invalid_email' => l10n.authErrorsInvalidEmail,
        'password_required' => l10n.authErrorsPasswordRequired,
        'invalid_credentials' => l10n.authErrorsInvalidCredentials,
        'email_not_confirmed' => l10n.authErrorsEmailNotConfirmed,
        _ => l10n.authErrorsSignupFailed,
      };

  Future<void> _submit() async {
    setState(() { _loading = true; _errorCode = null; });
    try {
      await ref.read(authRepositoryProvider).signInWithPassword(email: _email.text.trim(), password: _password.text);
      if (mounted) widget.onLoggedIn();
    } on AuthException catch (e) {
      if (mounted) setState(() => _errorCode = e.code);
    } catch (_) {
      if (mounted) setState(() => _errorCode = 'unexpected');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resend() async {
    setState(() { _resending = true; _resendFailed = false; });
    try {
      await ref.read(authRepositoryProvider).resendConfirmation(_email.text.trim());
    } catch (_) {
      if (mounted) setState(() => _resendFailed = true);
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }
```

In `build()`, add the resend-failure line inside the existing `if (_errorCode == 'email_not_confirmed')` block,
right after the `TextButton` for resend:

```dart
if (_errorCode == 'email_not_confirmed') ...[
  const SizedBox(height: 8),
  TextButton(
    key: const Key('login-resend'),
    onPressed: _resending ? null : _resend,
    child: Text(_resending ? l10n.authLoginResending : l10n.authLoginResend),
  ),
  if (_resendFailed) ...[
    const SizedBox(height: 4),
    Text(l10n.authErrorsResendFailed, style: const TextStyle(color: Colors.redAccent)),
  ],
],
```

- [ ] **Step 3: `signup_screen.dart` — mounted-safe errors, dispose**

```dart
@override
void dispose() {
  _username.dispose();
  _email.dispose();
  _password.dispose();
  super.dispose();
}
```

```dart
Future<void> _submit() async {
  setState(() { _loading = true; _errorCode = null; });
  try {
    final locale = Localizations.localeOf(context).languageCode;
    await ref.read(authRepositoryProvider).signUp(
          username: _username.text.trim(), email: _email.text.trim(), password: _password.text,
          ref: widget.initialRef, locale: locale,
        );
    if (mounted) widget.onSignedUp(_email.text.trim());
  } on AuthException catch (e) {
    if (mounted) setState(() => _errorCode = e.code);
  } catch (_) {
    if (mounted) setState(() => _errorCode = 'unexpected');
  } finally {
    if (mounted) setState(() => _loading = false);
  }
}
```

- [ ] **Step 4: `onboarding_username_screen.dart` — mounted-safe errors, dispose**

```dart
@override
void dispose() {
  _username.dispose();
  super.dispose();
}
```

```dart
Future<void> _submit() async {
  setState(() { _loading = true; _errorCode = null; });
  try {
    await ref.read(authRepositoryProvider).claimUsername(_username.text.trim());
    if (mounted) widget.onClaimed();
  } on AuthException catch (e) {
    if (mounted) setState(() => _errorCode = e.code);
  } catch (_) {
    if (mounted) setState(() => _errorCode = 'unexpected');
  } finally {
    if (mounted) setState(() => _loading = false);
  }
}
```

- [ ] **Step 5: `forgot_password_screen.dart` — give it error handling for the first time**

```dart
class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _email = TextEditingController();
  bool _loading = false;
  bool _sent = false;
  bool _error = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() { _loading = true; _sent = false; _error = false; });
    try {
      await ref.read(authRepositoryProvider).requestReset(_email.text.trim());
      if (mounted) setState(() => _sent = true);
    } catch (_) {
      if (mounted) setState(() => _error = true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
```

In `build()`, after the existing `if (_sent) ...` block:

```dart
if (_error) ...[
  const SizedBox(height: 16),
  Text(l10n.authErrorsForgotFailed, style: const TextStyle(color: Colors.redAccent)),
],
```

- [ ] **Step 6: `reset_password_screen.dart` — give it error handling for the first time**

```dart
class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final _password = TextEditingController();
  bool _loading = false;
  bool _error = false;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() { _loading = true; _error = false; });
    try {
      await ref.read(authRepositoryProvider).resetPassword(_password.text);
      if (mounted) widget.onDone();
    } catch (_) {
      if (mounted) setState(() => _error = true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
```

In `build()`, after the submit `ElevatedButton`:

```dart
if (_error) ...[
  const SizedBox(height: 16),
  Text(l10n.authErrorsResetFailed, style: const TextStyle(color: Colors.redAccent)),
],
```

- [ ] **Step 7: `google_sign_in_button.dart` — code-based copy instead of raw `e.message`, mounted-safe**

```dart
class _GoogleSignInButtonState extends ConsumerState<GoogleSignInButton> {
  bool _loading = false;
  String? _errorCode;

  String? _errorText(AppLocalizations l10n, String code) => switch (code) {
        'google_canceled' => null,
        'google_not_configured' => l10n.authErrorsGoogleNotConfigured,
        _ => l10n.authErrorsGoogleFailed,
      };

  Future<void> _tap() async {
    setState(() { _loading = true; _errorCode = null; });
    try {
      await ref.read(authRepositoryProvider).signInWithGoogle();
      if (mounted) widget.onSignedIn();
    } on AuthException catch (e) {
      if (mounted) setState(() => _errorCode = e.code);
    } catch (_) {
      if (mounted) setState(() => _errorCode = 'unexpected');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final message = _errorCode == null ? null : _errorText(l10n, _errorCode!);
    return Column(
      children: [
        OutlinedButton(
          key: const Key('google-sign-in'),
          onPressed: _loading ? null : _tap,
          child: Text(l10n.authCommonContinueWithGoogle),
        ),
        if (message != null) Text(message, style: const TextStyle(color: Colors.redAccent)),
      ],
    );
  }
}
```

(No `TextEditingController`s in this widget — no `dispose()` needed here.)

- [ ] **Step 8: `account_screen.dart` — awaited sign-out with error handling, localized copy**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_providers.dart';
import '../../core/l10n/gen/app_localizations.dart';
import '../../core/providers.dart';
import '../../shared/widgets/sx_tab_app_bar.dart';

class AccountScreen extends ConsumerStatefulWidget {
  const AccountScreen({super.key, required this.onLogIn, required this.onSignUp, required this.onLogoTap});

  final VoidCallback onLogIn;
  final VoidCallback onSignUp;
  final VoidCallback onLogoTap;

  @override
  ConsumerState<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends ConsumerState<AccountScreen> {
  bool _signingOut = false;
  bool _signOutFailed = false;

  Future<void> _signOut() async {
    setState(() { _signingOut = true; _signOutFailed = false; });
    try {
      await ref.read(authRepositoryProvider).signOut();
    } catch (_) {
      if (mounted) setState(() => _signOutFailed = true);
    } finally {
      if (mounted) setState(() => _signingOut = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final me = ref.watch(meProvider).asData?.value;
    return Scaffold(
      appBar: SxTabAppBar(title: l10n.accountTitle, onLogoTap: widget.onLogoTap),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Center(
          child: me == null
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ElevatedButton(key: const Key('account-login'), onPressed: widget.onLogIn, child: Text(l10n.accountLogIn)),
                    TextButton(key: const Key('account-signup'), onPressed: widget.onSignUp, child: Text(l10n.accountCreateAccount)),
                  ],
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(me.profile?.displayName ?? me.profile?.username ?? me.email ?? ''),
                    TextButton(
                      key: const Key('account-sign-out'),
                      onPressed: _signingOut ? null : _signOut,
                      child: Text(_signingOut ? l10n.accountSigningOut : l10n.accountSignOut),
                    ),
                    if (_signOutFailed) ...[
                      const SizedBox(height: 8),
                      Text(l10n.accountSignOutFailed, style: const TextStyle(color: Colors.redAccent)),
                    ],
                  ],
                ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 9: Update `test/features/account_screen_test.dart` for the new localization delegate requirement**

The two existing `pumpWidget` calls wrap `AccountScreen` in a bare `MaterialApp(home: ...)`, which has no
`AppLocalizations` delegate registered — now required since Step 8 calls `AppLocalizations.of(context)`. Update
both to match the pattern already used in `test/features/login_screen_test.dart`:

```dart
import 'package:sentinelx_mobile/core/l10n/gen/app_localizations.dart';

// ... both pumpWidget calls become:
await tester.pumpWidget(ProviderScope(
  retry: (_, _) => null,
  overrides: [meProvider.overrideWith((ref) async => /* null or me, as before */)],
  child: MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: AccountScreen(onLogIn: () => loginTapped = true, onSignUp: () {}, onLogoTap: () {}),
  ),
));
```

Add one new test for the sign-out failure path:

```dart
testWidgets('sign-out failure shows an error and re-enables the button', (tester) async {
  final me = MeResponse(
    id: 'u1', email: 'a@b.com', roles: const [], isStaff: false, isAdmin: false,
    profile: const MeProfile(
      username: 'ada', displayName: 'Ada', avatarUrl: null, whatsappNumber: null, country: null,
      locale: 'en', membershipTier: null, kycVerified: false, deletionRequestedAt: null,
    ),
  );
  await tester.pumpWidget(ProviderScope(
    retry: (_, _) => null,
    overrides: [
      meProvider.overrideWith((ref) async => me),
      authRepositoryProvider.overrideWithValue(_FailingSignOutRepository()),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: AccountScreen(onLogIn: () {}, onSignUp: () {}, onLogoTap: () {}),
    ),
  ));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('account-sign-out')));
  await tester.pumpAndSettle();
  expect(find.text('Could not sign out. Please try again.'), findsOneWidget);
  expect(tester.widget<TextButton>(find.byKey(const Key('account-sign-out'))).onPressed, isNotNull);
});
```

Add the fake above the `main()` function, matching this file's existing style, implementing every
`AuthRepository` method as a no-op except `signOut`:

```dart
class _FailingSignOutRepository implements AuthRepository {
  @override
  Future<void> signOut() async => throw Exception('boom');
  @override
  Future<void> signInWithPassword({required String email, required String password}) async {}
  @override
  Future<void> signUp({required String username, required String email, required String password, String? ref, String? locale}) async {}
  @override
  Future<void> resendConfirmation(String email) async {}
  @override
  Future<void> requestReset(String email) async {}
  @override
  Future<void> resetPassword(String newPassword) async {}
  @override
  Future<String> claimUsername(String username) async => username;
  @override
  Future<void> signInWithGoogle() async {}
}
```

(Needs `import 'package:sentinelx_mobile/core/auth/auth_repository.dart';` in the test file.)

- [ ] **Step 10: Check for and update any other test files this task's screens touch**

Search for tests over the other five screens before assuming none need changes:

Run: `flutter test test/features/ -r compact`

Fix any failure directly caused by this task's diffs (e.g. a test that previously asserted on `_error` being
absent, or one relying on the old un-mounted-guarded timing). Do not fix unrelated pre-existing failures — note
them instead per `AGENTS.md`'s "Stop and ask" rule.

- [ ] **Step 11: Full suite + analyze**

Run: `flutter analyze && flutter test`
Expected: no issues, full suite green.

- [ ] **Step 12: Commit**

```bash
git add lib/features/auth/ lib/features/onboarding/onboarding_username_screen.dart lib/features/account/account_screen.dart \
  lib/core/l10n/app_en.arb lib/core/l10n/app_fr.arb lib/core/l10n/gen/ \
  test/features/
git commit -m "fix(auth-ui): mounted-safe error handling, controller disposal, localized copy across auth screens"
```

---

### Task 6: Home screen cleanup — drop superseded logic, remove raw error text

**Depends on:** Task 1 (router now owns onboarding enforcement), Task 3 (`sessionStartedProvider` removed).
**Check the collision-risk note in Global Constraints before starting this task** — it is the one most likely to
touch the same lines as the concurrent Phase 3a Flutter-screens work.

**Files:**
- Modify: `lib/features/home/home_screen.dart`
- Modify: `test/features/home_screen_test.dart`
- Modify: `lib/core/l10n/app_en.arb`, `app_fr.arb`

**Interfaces:**
- Consumes: `errorReporterProvider` (`lib/core/providers.dart`, already exists — `.report(Object error, StackTrace? stack, {String? route})`)

- [ ] **Step 1: Add the ARB key**

`app_en.arb`: `"homeLoadError": "Something went wrong loading this page.",`
`app_fr.arb`: `"homeLoadError": "Une erreur s'est produite lors du chargement de cette page.",`

Run: `flutter gen-l10n`

- [ ] **Step 2: Write the failing test for the new error rendering**

Replace the existing `'shows a loading indicator, then the featured tournament and stats'` test's neighbor tests
that specifically cover the now-removed onboarding redirect (`'redirects to onboarding username when the gate says
so'` and `'does not redirect when the gate is clear'` — this behavior now belongs to
`test/router/app_router_test.dart`'s Task 1 test, not Home) with:

```dart
testWidgets('a load failure shows generic localized text, not the raw exception', (tester) async {
  await tester.pumpWidget(ProviderScope(
    retry: (_, _) => null,
    overrides: [homeRepositoryProvider.overrideWithValue(_FailingHomeRepository())],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: HomeScreen(onGoTo: (_) {}),
    ),
  ));
  await tester.pumpAndSettle();
  expect(find.text('Something went wrong loading this page.'), findsOneWidget);
  expect(find.textContaining('Exception'), findsNothing);
});
```

Add the fake near the file's other fakes:

```dart
class _FailingHomeRepository implements HomeRepository {
  @override
  Future<HomeSummary> fetchHome() async => throw Exception('network down');
}
```

- [ ] **Step 3: Run to confirm it fails**

Run: `flutter test test/features/home_screen_test.dart`
Expected: FAIL — current code renders `'Failed to load: Exception: network down'`.

- [ ] **Step 4: Rewrite `home_screen.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/gen/app_localizations.dart';
import '../../core/providers.dart';
import 'home_providers.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key, required this.onGoTo});

  final void Function(String path) onGoTo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(homeProvider, (previous, next) {
      if (next case AsyncError(:final error, :final stackTrace)) {
        ref.read(errorReporterProvider).report(error, stackTrace, route: '/');
      }
    });
    final home = ref.watch(homeProvider);
    final l10n = AppLocalizations.of(context);
    final isSignedIn = ref.watch(meProvider).asData?.value != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sentinel X'),
        actions: [
          IconButton(
            key: const Key('home-account'),
            icon: Icon(isSignedIn ? Icons.person : Icons.person_outline),
            onPressed: () => onGoTo(isSignedIn ? '/account' : '/login'),
          ),
        ],
      ),
      body: home.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(l10n.homeLoadError)),
        data: (summary) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(homeProvider),
          child: ListView(
            children: [
              if (summary.featuredTournament != null)
                ListTile(
                  key: const Key('home-featured'),
                  title: Text(summary.featuredTournament!.title),
                  subtitle: Text(summary.featuredTournament!.status),
                  onTap: () => onGoTo('/tournaments/${summary.featuredTournament!.id}'),
                ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text('${summary.stats.playerCount} players · ${summary.stats.tournamentCount} tournaments'),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(l10n.homeUpcomingHeading),
                    TextButton(onPressed: () => onGoTo('/tournaments'), child: Text(l10n.homeFullRankingsLink)),
                  ],
                ),
              ),
              for (final t in summary.upcomingTournaments)
                ListTile(title: Text(t.title), onTap: () => onGoTo('/tournaments/${t.id}')),
              Padding(padding: const EdgeInsets.all(16), child: Text(l10n.homeTopPlayersHeading)),
              for (final p in summary.leaderboardTeaser) ListTile(title: Text(p.displayName ?? p.username ?? '—')),
            ],
          ),
        ),
      ),
    );
  }
}
```

Note what was removed versus the pre-Task-1/3 version: the `onboarding_gate.dart` import and the
`ref.watch(onboardingGateProvider)`/`addPostFrameCallback` block (now `evaluateAuthRedirect` in the router), and
the `ref.watch(sessionStartedProvider);` line (now `SessionLifecycle`). **If the concurrent Phase 3a work has
already landed its "three entry tiles" on this file, merge by hand: keep its new tiles inside the `data:` branch's
`ListView`, and still remove the two blocks named above — they do not overlap with tile content.**

- [ ] **Step 5: Run to confirm it passes**

Run: `flutter test test/features/home_screen_test.dart`
Expected: PASS.

- [ ] **Step 6: Full suite + analyze (this closes out Task 3's interim dangling-reference state too)**

Run: `flutter analyze && flutter test`
Expected: no issues — this is the first point where `sessionStartedProvider`'s removal (Task 3) and its last
call site's removal (this task) are both done, so this is the true green checkpoint for both tasks.

- [ ] **Step 7: Commit**

```bash
git add lib/features/home/home_screen.dart lib/core/l10n/app_en.arb lib/core/l10n/app_fr.arb lib/core/l10n/gen/ \
  test/features/home_screen_test.dart
git commit -m "fix(home): drop logic superseded by the router guard and session lifecycle; localize the error state"
```

---

## End-of-plan verification

- [ ] `flutter analyze` — zero issues
- [ ] `flutter test` — full suite green, note the total test count before/after (should only have grown)
- [ ] `flutter gen-l10n` was run after every `.arb` edit and its output is committed
- [ ] Rebase onto `origin/master` (per the hotspot-file rule) and re-run both commands after rebasing
- [ ] Manual device/emulator check at 375px width covering the review's stated gaps directly:
  1. Deep-link straight to `/tournaments/<id>` as a signed-in, no-username account → lands on
     `/onboarding/username` instead of the tournament page.
  2. Tap a `type=email_change` confirmation link as an existing (already-onboarded) user → lands on Home, not
     onboarding.
  3. Background the app and return (token refresh) after sign-in → confirm (via a temporary log or breakpoint,
     removed before commit) `postSessionStart` fired once, not again.
  4. Trigger a login failure, then immediately navigate away mid-request → no `setState() after dispose()` assertion
     in the console.
  5. Force `/session/start`, `/me`, or Google sign-in to fail (e.g. airplane mode) → a readable, localized message
     appears; no raw exception text anywhere.
- [ ] Add a dated entry to `TESTING-NOTES.md` documenting the manual check above (matching this repo's PR-3
  convention referenced in the web-repo handoff's Definition of Done).
