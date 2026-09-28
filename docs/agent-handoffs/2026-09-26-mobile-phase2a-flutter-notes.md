# Mobile Phase 2a (Flutter) session notes — 2026-09-26

Nothing is pushed. No secrets are recorded here.

## Where things are

| What | Where |
|---|---|
| Plan (untracked) | `C:\Users\gorok\sentinelx_mobile\docs\superpowers\plans\2026-09-26-mobile-phase2a-flutter-screens.md` |
| Code | worktree `C:\Users\gorok\sentinelx_mobile-p2a`, branch `phase2a/screens`, HEAD `a1d6767`, based on `origin/master` 0148b2a (13 commits) |
| Web endpoints (unmerged) | `C:\Users\gorok\Videos\sentinelx`, branch `docs/mobile-phase1-phase2a-specs` (has all 2a AND 2b endpoints); `api/openapi.json` is byte-identical to its `openapi/mobile-v1.json` |

## Verified

- `flutter analyze` clean; `flutter test` 277/277 (full suite ~80 s; one gate run took 24 min from machine load, not code).
- Built test-first; every fix from the whole-branch review (fresh reviewer, most capable model) was RED→GREEN.
- Staging schema check: all 37 columns the T1 reads select exist on `ofxmoxpvwbemfouaowoa`.

## NOT verified

- Anything against a live server (the 2a endpoints are not deployed anywhere), the Paystack WebView (no widget-test platform), real payments, the slug deep link on a device, Riverpod listener behavior while the checkout route is on top. Checklist: `TESTING-NOTES.md` in the branch ("Phase 2a … PENDING").
- `config/dev.json` still resolves to PRODUCTION URLs. Any dev run must pass staging dart-defines (see the 3b session note). Owner decision pending on making dev fail closed / point at staging.

## Open items (web / owner)

1. **Register overwrites `paystack_reference`** on a pending row (and re-deducts coins): a second `POST /register` can orphan an in-flight bank-transfer/USSD payment. The app now re-checks the stored reference instead of re-registering, but the server should stop overwriting a live reference.
2. Accepted-invitation payment has no re-init path (invitation is claimed before payment; `view` returns `invitation_only` ahead of `complete_payment`).
3. Add `bio` to `GET /me` (the app reads its own bio directly from `profiles` only to avoid PATCH erasing it — `ownBioProvider`).
4. Entrants list needs an endpoint (RLS blocks direct read). Avatar upload deferred. Live countdown and game category chips not built (spec 6.1/6.6).
5. Merging: none of this can run against a server until the web branch lands; 3a/3b Flutter branches are separate and unmerged.

## Deferred minors

M1 key reused when form edited after a network failure · M2 resume has no busy guard · M3 draft tournaments reachable by id/slug · M4 needs_username path unreachable and drops wizard state · M5 registration state does not watch the session; login returns to Home · M6 invitations hide a /me failure as empty · M7 currency/labels hard-coded · M8 countdown/category chips · M9 unknown view shows connection copy.

## Rulings made

Task 3: slug-or-id lookup folded in early; fixed a plan bug (stale `loadMoreFailed`). Task 6: sheet cannot be dismissed while busy; success snackbar wording depends on whether a payment actually happened; prefill awaits `meProvider.future`. Task 7: launcher finds the navigator through `routerProvider`'s delegate key (no new key). Task 8: 4 extra ARB status keys; resume check awaits `meProvider.future`. Task 10: **plan defect** — PATCH clears an empty bio and `/me` has none, so an own-bio read is required before the form is offered. Task 11: web_links `/tournaments/<slug>` now maps (old test flipped); old placeholder list/detail screens deleted. Final: dev.json left on production (owner decision).
