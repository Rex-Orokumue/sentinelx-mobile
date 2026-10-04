# Phase 5a Stage D (mobile) - handoff

**Date:** 2026-10-03 · **Branch:** `phase5a/screens` (worktree `..\sentinelx_mobile-p5a`), merged to `master` after review · **Code changed:** yes
**Plan:** `docs/superpowers/plans/2026-10-03-mobile-phase5a-notifications-push-screens.md` · **Web side:** web repo `docs/agent-handoffs/2026-10-03-phase5a-stage-b-web-handoff.md` (merged to web `main`, commit `8e64332`).

## What was built (verified by tests unless noted)

- `ApiClient`: 8 notification methods (all in `usedOperations`, bearer token asserted on every viewer-specific call) + tolerant models.
- Push infrastructure behind `PushGateway` (`lib/core/notifications/push/`): disabled/fake/Firebase implementations, registration lifecycle (sign-in, token refresh, account switch, sign-out unregister), contextual permission prompter, tap router with a cold-start queue, foreground banner, startup wiring. Firebase init is failure-tolerant.
- Bell at `/notifications` (paging, optimistic mark read / read-all, mute/unmute menu, live realtime refresh, permission row), Settings -> Notifications at `/account/notifications` (17 + 6 + 5 toggles, test push), bell wired in the app bar, Account tile.
- ARB en + fr (identical keys, ICU plurals), `resolveWebLink` gained one mapping (`/dashboard/settings` -> `/account/notifications`).
- Android: conditional `google-services` plugin, core-library desugaring, default channel meta-data.

## Verification

`flutter analyze`: no issues. `flutter test`: 958 passed (baseline 753 at start; 958 on the rebased tree). `flutter build apk --debug` succeeded **with** `google-services.json` and **without** it (file moved aside, restored after), before the rebase; with-file re-run after the rebase recorded in the final report. Web side: its own verification is in the web handoff.

## Rulings (what - why - cost if wrong)

Plan Rulings 1-10 stand (see the plan). Additional rulings made while building:

1. **Build order** 7 -> 6 and 9a -> 8 (repository before tap router; prefs provider before the bell screen) - dependencies, not scope.
2. **`PushRegistration` has a `_suppressed` flag and `reregister()`** (not in the plan): after `unregister()` a token refresh must not quietly re-register the phone for the user who is signing out; if the sign-out itself fails, `AccountScreen` calls `reregister()` so a still-signed-in user keeps receiving pushes. *Cost if wrong:* a tiny window where a signed-in user is unregistered.
3. **Account sign-out hook swallows every push error** (including the provider being unreadable in tests): push trouble must never block signing out.
4. **Prefs toggles revert only if no later toggle of the same key happened** (per-key sequence number, per-key serialized patches). The plan said "revert only the changed key on the current value"; a mutation check showed that rule alone can revert over the user's latest intent after a fail + two quick toggles.
5. **`notificationsViewerIdProvider` selects the user id out of the session** instead of watching it: a Supabase token refresh re-emits a new `Session` and would refetch everything. Found by the review (test with real provider); the equivalent `communityViewerIdProvider` has the same latent flaw (below).
6. **Pull-to-refresh while a load is in flight queues an in-place refresh** instead of resetting to page one, so a `loadMore` response can never land on a reset list.
7. **Blank push `url` is treated as absent** (it would otherwise resolve to Home, not the bell).

## Review outcome (fresh-context)

Fixed with RED->GREEN tests: refresh vs loadMore race; realtime event during the first page load was dropped (the first version of that test was vacuous - the fake read the table after the gate; fixed to snapshot at call time); viewer id recomputing on token refresh.

## Deferred / known gaps (not fixed, reviewer-confirmed or judged)

- **Other sign-out paths** (server-side session expiry, a future second sign-out button): the device token is only unregistered via the Account tile. A still-valid token is not rejected by FCM, so the previous user's pushes could keep arriving on a shared phone until someone signs in on it (the server then moves the token). Mitigation to consider: retry the DELETE at next launch / on next sign-in, or have the server drop tokens when a session ends. Not verified server-side.
- **Register/unregister ordering race** (an in-flight POST can land after a DELETE or after the account switched): rare; would need a single serialized queue in `PushRegistration`.
- **`_open` uses `router.push`** for tab destinations (`/tv`, `/community`); the push tap router uses `go`. Layout of a shell-branch route pushed over the bell is unverified - check on the device pass.
- **Test gap:** the cold-start test records locations through `pushNavigatorProvider`; it proves queue-until-settled but cannot detect a bounce through the real auth redirect (no real router in that test).
- **Latent bug outside this phase:** `communityViewerIdProvider` (and so the community feed providers) recompute on a token-refreshed `Session` for the same user; its test passes only because the fixtures are equal `Session`s. Fix the same way as Ruling 5; not touched here.
- Plan-listed gaps: DMs/5b, iOS delivery (Phase 10), row id in push `data`, grouping/quiet hours/rich notifications, monochrome status-bar icon, consolidating the two viewer-id providers, whether to track `google-services.json`.

## Not verified

Live FCM delivery, Doze / OEM battery behavior, channel behavior on a real device, the Android 13+ dialog and its denied / permanently-denied transitions, a tap from a killed app, the staging web deployment sending with Firebase project `sentinelx-f061e` credentials (**unconfirmed**), iOS, the rendering of the default status-bar icon. The device-pass checklist is in `TESTING-NOTES.md`.

## Context from another session

The web profile-onboarding work (separate feature) is live on production: `POST /onboarding/profile`, and `GET /me` now reports `profileCompletedAt: null` for all existing profiles. Not part of this branch.

## Follow-up: gaps closed (2026-10-04, branch `fix/phase5a-gaps`)

- **Viewer id** is now one shared `viewerIdProvider` (`lib/core/providers.dart`); `communityViewerIdProvider` and `notificationsViewerIdProvider` are aliases. The community feed no longer refetches on a token refresh (the old test only passed because its two sessions were equal; it now emits a real refreshed token). The status-viewer tray test was timing-dependent and now gates `viewStatus`.
- **Register/unregister race:** every device call in `PushRegistration` runs through one queue, with the user/suppressed checks made when the turn comes. The 5 s unregister timeout covers the wait behind an in-flight POST.
- **Other sign-out paths:** when a session ends without `unregister()` (expiry, revoked), `PushRegistration` drops the FCM token on the device (`PushGateway.deleteToken`), so the previous user's pushes stop arriving; the next sign-in mints and registers a fresh token. The server-side DELETE still needs a live session and is not attempted.
- **Bell taps to a tab** (`/tournaments`, `/tv`, `/community`, `/exchange`, `/account`) now `go` like push taps (`tabRootLocations`); deeper destinations still `push`, so Back returns to the bell. Real-router tests cover both, plus a push tap through the real redirect with no `/login`/`/onboarding` hop.
- **Still open:** everything under "Not verified" (device pass), the staging Firebase credentials, row id in push `data`, and the plan-listed non-goals.
