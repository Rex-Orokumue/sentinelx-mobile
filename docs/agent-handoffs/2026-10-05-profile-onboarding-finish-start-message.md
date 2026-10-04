# Start message — finish and merge mobile profile onboarding (`feat/profile-onboarding`)

Paste everything below the line into a fresh session in `C:\Users\gorok\sentinelx_mobile`. This is **independent of Phase 5b**
(DMs): do not touch the 5b work or its plan. One job: fix the first-submit bug, bring the branch up to date, verify on a device,
and merge.

---

You are finishing **mobile profile onboarding** for the Sentinel X Flutter app. The code was written and reviewed on
`feat/profile-onboarding` (pushed to `origin/feat/profile-onboarding`, tip `bf57f7f`), but it was **never merged** because a real
device found a bug, and it has since drifted behind `master`.

## Where things stand (verified 2026-10-05)

- Branch `feat/profile-onboarding`: **8 commits ahead, 32 behind `master`** (merge base `c007a15`, 2026-10-03). Worktree:
  `C:\Users\gorok\sentinelx_mobile-profile-onboarding`. Its last commit is the bug write-up; the tree is clean.
- It adds: the compulsory profile gate and `/onboarding/profile` route (after username and optional phone), country and
  game-interest fields, en/fr copy, the onboarding form (canonical country, country-valid WhatsApp, explicit WhatsApp consent, at
  least one game interest), and the same fields in Account → Edit Profile. At handoff: `flutter analyze` clean, `flutter test`
  767 passing. Files: `lib/core/auth/onboarding_gate.dart`, `lib/router/auth_redirect.dart`, `lib/router/app_router.dart`,
  `lib/features/account/profile_onboarding_screen.dart`, `profile_onboarding_providers.dart`, `edit_profile_screen.dart`,
  `country_field.dart`, `game_interests_field.dart`, `lib/core/api/profile_onboarding_models.dart`, `api_client.dart`, `models.dart`.
- **The web side is live.** On production (`itxubrkbropttfdackmi`) the migrations `add_profile_completion_fields` and
  `complete_profile_onboarding_rpc` are applied and `POST /api/mobile/v1/onboarding/profile` is deployed; `GET /me` reports
  `profileCompletedAt: null` for every existing profile. The branch's "do not go live until the web is deployed" condition is
  therefore met. **Consequence:** once this gate ships, every existing player is sent through onboarding once, so a gate that does
  not release on the first submit would trap real users.
- `master` has moved a lot since (5a notifications/push merged; Phase 5b docs). Expect conflicts in the shared hotspot files:
  `lib/router/app_router.dart`, `lib/core/routing/web_links.dart`, `lib/core/api/api_client.dart` (and its `usedOperations` list),
  `lib/core/l10n/app_en.arb` / `app_fr.arb` and the generated `lib/core/l10n/gen/*`, and possibly `lib/core/providers.dart`.

## The bug to fix (unresolved, reproduced on a device)

Read it in full first: `docs/agent-handoffs/2026-10-03-mobile-profile-onboarding-handoff.md` ("Device follow-up") and
`TESTING-NOTES.md`. Summary: Samsung SM-S9010, Android 16, staging. **One** tap on submit → `POST /onboarding/profile 200`, then
`GET /me 200`, `GET /home 200`, yet the app stayed on or returned to the onboarding screen. A **second** deliberate tap sent a
second POST (200) and then left. No Dart, Dio or fatal Android error was logged. The player confirmed one tap per request, so
**do not dismiss it as a double-tap.**

Where to look (hypotheses, not findings): the success sequence in `profile_onboarding_screen.dart` (around
`ref.invalidate(meProvider)` at line ~80 and `onCompleted()`), the router's refresh listener, `auth_redirect.dart` (the
`/onboarding/profile` redirect and `_onboardingRoutes`), and `onboarding_gate.dart` (`me.profile?.profileCompletedAt == null`):
a redirect evaluated against a **stale `/me`** (the gate reads the cached value before the refetch lands), a race between the
invalidate and the redirect, or the redirect running while `meProvider` is `loading`/previous-value. Find the cause with
`superpowers:systematic-debugging` before changing code.

Method, strictly TDD:
1. **Reproduce in a test first**: a widget/provider test where a successful first submit is followed by a refetched `/me` and the
   router must end **off** `/onboarding/profile`. Use a *real* refreshed provider state (not an equal fixture), and make the fake
   `/me` return `profileCompletedAt: null` before the POST and non-null after, with a delayed refetch to expose the stale read.
   Watch it fail for the right reason. A test that cannot fail is worthless.
2. Fix the cause (not by adding a manual second navigation or retry), watch the test pass, run the whole suite.
3. Also add the regression for the edge a fix tends to introduce: a failed POST (validation or network error) must **stay** on the
   screen with the error shown and not mark the profile complete.

## Steps

1. **Rebase or merge `master` into the branch** (merge is fine if a rebase is painful; the branch is pushed, so do not rewrite it
   without saying so). Resolve the hotspot conflicts keeping **both** sides (5a's push/notification wiring and this gate). Run
   `flutter pub get`, `flutter gen-l10n` (commit generated output), `flutter analyze` and `flutter test` clean. Run
   `git checkout -- linux macos windows` before committing (they regenerate with line-ending noise).
2. **Refresh the API contract**: copy the current web `openapi/mobile-v1.json` over `api/openapi.json` (copy, never hand-edit):
   `git -C C:\Users\gorok\Videos\sentinelx fetch origin` then
   `git -C C:\Users\gorok\Videos\sentinelx show origin/main:openapi/mobile-v1.json > api\openapi.json` (read-only; do not edit or
   check out in that dirty checkout). `master` may already carry a newer contract than the branch; keep `usedOperations` correct.
3. **Fix the bug** as above.
4. **Gate interplay with 5a**: the new gate must not trap the push-permission prompt, a push tap from a killed app, or
   `/notifications`. A push tap while the profile is incomplete should land on onboarding first and then continue to its target
   (or be dropped), and this must be a conscious ruling with a test, not an accident.
5. **Staging device pass**: build with `--dart-define` of the staging `SUPABASE_URL`, `SUPABASE_PUBLISHABLE_KEY` and
   `API_BASE_URL` (staging project `ofxmoxpvwbemfouaowoa` behind the web preview). **One tap → leaves onboarding.** Also: a fresh
   signup, an existing account with an incomplete profile, edit-profile round-trip, airplane-mode failure then retry. The owner
   runs the physical device; give them an exact checklist and wait for their result. Never test writes against production.
6. **Merge to `master` and push** (no PR) only after review and green, per the owner's standing preference. Do not merge before the
   device pass confirms the single-tap fix.

## Review and finish

Before merging, get a fresh-context review of the branch diff (dispatch a reviewer on the most capable model with the plan
`docs/superpowers/plans/2026-10-03-mobile-profile-onboarding.md`, the handoff and this message), re-grade its findings by effect,
fix Critical/Important ones with a failing test first, record deferred minors. Then update `TESTING-NOTES.md` and the handoff note
with the resolution, the cause, and what was **not** verified.

## Hard rules

- Never test writes against production. Test accounts use the `zzqa_` username prefix and plus-addressed emails and are logged in
  `TESTING-NOTES.md`; the existing staging account `zzqa_mobile_profile` (auth user `aeaffd10-35e7-4952-8e9b-a0acb0762537`) is
  marked cleanup **Pending**: remove it with `anonymise_account` after verification and update the note.
- No copy hard-coded in widgets: ARB en + fr with identical keys, then `flutter gen-l10n`.
- All writes go through `/api/mobile/v1`; never write via PostgREST.
- **Windows encoding:** never edit source with bare Python `open().read()/write()`; use the Edit/Write tools or
  `encoding='utf-8', newline=''`. Analyzer "URI doesn't exist" for files that exist means corrupted UTF-8.
- Tripwire from `CLAUDE.md`: do not set `enforce_phone_verification=true` anywhere until a shipped app version has the
  onboarding-phone screen.
- Log every deviation from the plan as a **Ruling** (what, why, cost if wrong). Don't delete or reset anything without asking.
  Work in the existing worktree; leave the other Phase 5b / `master` work alone.

## Deliverable

The fixed, rebased, device-verified branch merged to `master` and pushed, with: the root cause, the regression tests, test
counts, review findings and fixes, every Ruling, deferred items, and what is **not** verified. If the device pass fails, stop and
report with the logs instead of merging.
