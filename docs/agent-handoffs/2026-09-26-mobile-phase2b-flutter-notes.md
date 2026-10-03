# Phase 2b Flutter — running log / handoff note

Branch `phase2b/screens`, worktree `..\sentinelx_mobile-p2b`, cut from `integration/2a-3a-3b` @ `a98956f`.
HEAD: `50b164c` (11 commits: Tasks 1–10 at `48a9c34`/`5621c9e`, plus one post-review fix-pass commit;
Task 0 was verification-only, no commit).

## Final whole-branch review (opus, fresh context) — a98956f..5621c9e

Verdict: **ready to merge, with fixes.** No Critical findings. 5 Important, 9 Minor. All 4 rulings
in this note were reviewed and agreed with.

**Fixed in commit `50b164c`** (each with a failing test watched RED then GREEN, full suite re-run green):
1. **Stale-key replay after an edited retry.** `WriteFlow.run` now takes an optional payload
   fingerprint; a kept key (`network`/`idempotency_in_progress`/`bad_response`) is discarded if the
   retried payload differs from the one the key was minted for. Wired through wager, rating, result
   and lobby-result submission (`evidence.dart`'s `ResultSubmitter.submit` also takes a fingerprint,
   combined with the picked image's identity).
2. **Sheets draggable-closed mid-write.** `wager_sheet.dart` and `rating_sheet.dart` now set
   `enableDrag: false` (matches `registration_sheet.dart` from 2a) — drag-to-dismiss bypasses
   `PopScope` and was dropping an in-flight coin-spending write.
3. **Wager info hidden once the window closes.** The wager card now shows `mtcWagerYourPick`
   whenever the server returns a stake, not only while `windowOpen` — only the button/fee/estimate
   hide when the window is closed.
4. **Match Centre blanks to a spinner on every refresh.** Switched from `.isLoading`/`.asData` to
   `AsyncValue.value` so pull-to-refresh, a check-in, or placing a wager keeps the page visible
   with its previous data while the refetch is in flight.

**Not fixed — ran out of session budget mid-investigation:**
5. **Guest-detection ambiguity in `match_centre_screen.dart`** (~line 93): `me == null` from
   `meProvider.asData?.value` can't distinguish "signed out", "`/me` still loading" and "`/me`
   failed" — a signed-in user can briefly see the guest wager prompt, and permanently see it if
   `/me` errors. The correct fix is deciding signed-in/guest from `sessionProvider` (the Supabase
   session token) rather than from `/me`'s own success, per the reviewer's suggestion. Doing that
   safely requires a fake Supabase `Session`/`User` test fixture (they have no lenient constructor)
   wired into the shared `competeBaseOverrides()` helper in `test/support/pump_compete.dart`, used
   by dozens of test files — that fixture work was left undone. **This is a real, reproducible
   Important-severity bug**, not a judgment call; whoever picks this up next should fix it before
   merge, following the reviewer's report (delivered in full to the owner).

**Deferred minors** (Minor findings never enter a fix pass per policy — noted for a future pass):
6. `validation_failed` field errors aren't shown on the score/placement/kills fields — only a
   generic banner (`result_submission_screen.dart`, `lobby_result_screen.dart`).
7. Submitting a wager with no player picked shows the stake-range message instead of
   `mtcEcInvalidPick` (`wager_sheet.dart:65-66`).
8. Rating star semantic labels are hard-coded English (`rating_sheet.dart`) — needs an ARB plural key.
9. Home's pull-to-refresh doesn't invalidate `meSummaryProvider`, so the fixtures card can go stale.
10. `/me` failure on the result/lobby screens always says "session expired", even for a dropped
    connection.
11. Leaving a write screen/sheet after a network failure loses the kept key and (for evidence
    screens) the upload memo — low-cost per the reviewer (server upserts / unique ratings).
12. Result screens have no `PopScope` while busy (the sheets do).
13. Match Centre's submit-button visibility uses an allow-list, not the plan's exact deny-list
    wording — safer, but the change wasn't logged as a ruling before this note.
14. `app_router.dart` import ordering is slightly out of place (cosmetic, shared hotspot file).

Full reviewer report (strengths, all findings, "declined to judge" list) was relayed to the owner in
chat at review time; ask them to re-paste it if needed for a future session — it wasn't re-saved to
disk verbatim.

## Status

`flutter analyze`: no issues. `flutter test`: **496 tests pass.** Nothing pushed; no PR opened.

## Follow-up fix (2026-09-27, done directly by Claude, not this agent) — HEAD `4528e4f`

Fixed finding #5 above (guest-detection ambiguity), which this run left unfixed. `match_centre_screen.dart`
now decides signed-in/guest from `sessionProvider` (the Supabase session token) instead of `meProvider`'s
value, so a signed-in user whose `/me` call is still loading or has failed no longer sees the guest wager
prompt — the server-side centre/wager reads already know the caller's identity from the bearer token
regardless of `/me`. `competeBaseOverrides()` in `test/support/pump_compete.dart` now overrides
`sessionProvider` and `meProvider` independently (previously only `meProvider` was overridden, which is why
this bug was untestable through the shared helper) and takes a new `meFails` flag; `Session`/`User` fixtures
use their ordinary constructors, no `fromJson` round-trip needed (contrary to this run's assumption that
they had "no lenient constructor"). Two new tests reproduce the bug (RED) and pass against the fix (GREEN).
`flutter analyze` clean; `flutter test` **511 passed** (was 509 before this fix, 496 at this note's original
writing). Not pushed.

## Task 0 — base check

- Base: analyze clean, 368 tests pass on `integration/2a-3a-3b` @ `a98956f`.
- 2a pieces present (`newIdempotencyKey`, `headers`, `CompeteTournament`, `cmpEcGeneric`, `competeBaseOverrides`, `_withQuery`).
- All 12 Phase 2b operationIds present in `api/openapi.json` (the integration-only union was left untouched, not re-copied).
- `image_picker` added; iOS `NSPhotoLibraryUsageDescription` added.
- Staging (`ofxmoxpvwbemfouaowoa`, read-only): `matches` 14, `tournament_stages` 5, `tournaments` 3 columns present; bucket `match-evidence` exists, `public=false`.

## Commits (Tasks 1–10)

| Task | Commit | What |
|---|---|---|
| 1 | `15aa301` | `match_models.dart` + 12 `ApiClient` methods + `usedOperations` |
| 2 | `a31824f` | ARB en+fr (Phase 2b copy) + `matchErrorCopy` |
| 3 | `2cbd7d5` | `WriteFlow` — the one idempotent-write notifier |
| 4 | `19627cd` | screenshot pick + upload-once `ResultSubmitter` |
| 5 | `c69926e` | bracket / group standings / stage standings / champion card |
| 6 | `ff1ea6b` | Match Centre + check-in + wager sheet |
| 7 | `bcb0911` | result submission (screenshot) + rating sheet |
| 8 | `f40c744` | lobby result submission |
| 9 | `7030a42` | dashboard `FixturesCard` on Home |
| 10 | `48a9c34` | routes/deep links; retired `lib/data`, `lib/models`, `lib/features/tournaments` |

## Rulings (in order made)

1. **Task 6 — guest wager prompt widget shape.** Built as a single tappable text button (`TextButton` wrapping the
   `mtcWagerLoginPrompt` copy) rather than a message + separate button. The plan's prose only said "a login button";
   the two-widget version overflowed at 375px transiently while `meProvider` was still loading. Cost if wrong:
   cosmetic tweak, one widget.
2. **Task 7 — new ARB key `mtcDone`.** The result/lobby confirmation panel needs a "Done" button; the plan's Task 2
   key list has no such key and copy is never hard-coded in widgets. Added `mtcDone` ("Done" / fr "Terminé") to both
   ARB files and regenerated l10n. Cost if wrong: a trivial rename via `flutter gen-l10n`.
3. **Task 9 — `FixturesCard` callback shape.** Took the plan's own Note over its Produces block: `onGoTo` is
   `void Function(String path)` (paths only) plus a separate `onOpenLobby: void Function(String lobbyId, NextLobby lobby)`,
   rather than the Produces block's combined `void Function(String path, {Object? extra})`. This keeps `HomeScreen`'s
   existing `onGoTo` signature and call sites unchanged, per the Note's explicit instruction. Cost if wrong: rename in
   3 places (`FixturesCard`, `HomeScreen`, the router builder).
4. **Task 10 — cold-deep-link stage stub name.** `/tournaments/:id/stages/:stageId` reached without `extra` (a raw
   deep link) builds a `StageInfo` stub whose `name` is the localized `mtcStages` ("Stages") placeholder — the plan
   said to build a stub but didn't say what name to show. Cost if wrong: one-line copy change.

No other deviations from the plan's Interfaces blocks; every model/method/provider/widget name matches what the plan specified.

## Deferred / known gaps (do not build; matches the plan's own list)

- Squad create/lookup **screens** are out of scope — the server still rejects `squadId` on register. Task 1 added
  only the two client methods (`postSquads`, `getSquadLookup`) and their models; no squad UI exists.
- `noShowEligible` is informational only — no player-facing no-show endpoint in 2b.
- No preview of an earlier submitted screenshot, and no editing a submitted result — the app always requires a fresh
  screenshot on submit.
- No realtime updates on the Match Centre — pull-to-refresh is the only refresh mechanism.

## Coverage against the spec (§4–§8)

- **Reads** (§4): bracket, group standings, stage (points-race) standings, tournament results/champion, Match Centre,
  dashboard summary — Tasks 1, 5, 6. Two T1 Supabase reads (match row, tournament stages) — Task 5.
- **Match Centre / check-in** (§4, §6): guest/participant/non-participant control sets, check-in with no
  Idempotency-Key, double-tap guard — Task 6.
- **Result submission** (§5): screenshot upload-once, `WriteFlow` Idempotency-Key policy, never-optimistic
  confirmation panel — Tasks 3, 4, 7.
- **Opponent rating** (§6): rating sheet with the same key policy — Task 7.
- **Wager** (§6): pools/fee/estimate rendered exactly as returned, key policy, own-match/window-closed/
  insufficient-coins copy — Task 6.
- **Lobby result** (§8, points-race formats): same shape as result submission — Task 8.
- **Dashboard fixtures** (§7): next match, next lobby, submit prompt, qualify/eliminate banners, pending payments —
  Task 9.
- **Idempotency-Key policy** (§5 / master spec): implemented once in `WriteFlow` (Task 3), reused by every write
  screen (Tasks 6–8) — never re-implemented per screen.
- **Squads** (§4/§8): client methods + models only (Task 1); screens deferred per the plan.
- **Exit criteria / Review Focus**: covered by the task-level test suites; the live-server proofs (Review Focus's
  double-submit / key-loss claims against a real backend) are **not** verified — see below.

## What is verified vs. not verified

**Verified** (496 unit/widget tests, `flutter analyze` clean):
- Every model's `fromJson` against the spec's zod shapes (snake_case vs camelCase fields, nullable fields, enum
  parsing with `FormatException` on unknown values).
- Every `ApiClient` method's path, query encoding, request body, and Idempotency-Key header presence/absence.
- The Idempotency-Key policy's exact retry semantics (`WriteFlow`): key kept only on `network` /
  `idempotency_in_progress` / `bad_response`, minted fresh on any other error, cleared on success, one request per
  concurrent `run()` call.
- Upload-once semantics: a retry after a server error does not re-upload; a retry after a network error does not
  re-upload; a different picked image does upload again; an upload failure sends nothing and reports `upload_failed`.
- Every screen's odd-data and guard-rail behavior named in the plan's Review Focus (guest/participant/non-participant
  control visibility, bye/cancelled/disputed/forfeited rendering, null scores never shown as `null`, never an
  optimistic result, 60-char names / 5 knockout rounds at 375px with no overflow).
- Routing: bracket → fixture tap → Match Centre; Match Centre → result screen (with and without `extra`); lobby
  result route with and without `extra`; stage standings route without `extra`; the retired slice's routes and web
  links are gone and the new ones are covered.

**Not verified** (needs the device round once the web endpoints ship, per `TESTING-NOTES.md`'s new pending section):
- Any live-server behavior at all — none of the twelve 2b endpoints exist on a reachable server yet (they're on the
  web branch `docs/mobile-phase1-phase2a-specs`), so nothing here has made a real HTTP call.
- The real screenshot upload to the staging `match-evidence` bucket (only exercised by `FakeUploader` in tests).
- End-to-end idempotency proof against a real database (one `api_idempotency_keys` row, one result/rating/wager row,
  one storage object after an airplane-mode retry).
- The full device checklist appended to `TESTING-NOTES.md` (12 items, all "pending").

## Notes for the next agent / reviewer

- `api/openapi.json` was **not** re-copied from a single web file — it remains the integration-only union. It must be
  regenerated from the merged web repo once the Phase 2b web branch lands on `main`.
- Shared-hotspot files were touched append-only, as required: `lib/core/api/api_client.dart` (12 methods +
  `usedOperations` lines appended), `lib/router/app_router.dart` (routes/imports appended, one route's builder
  replaced in place), `lib/core/routing/web_links.dart` (one case added), ARB files (keys appended, `flutter gen-l10n`
  run and committed), `lib/features/home/home_screen.dart` (one param + one line added).
- The retired slice (`lib/data/`, `lib/models/`, `lib/features/tournaments/`, their tests, and
  `test/fakes/fake_tournaments_repository.dart`) is fully removed; nothing in `lib/` or `test/` references it anymore
  (verified by grep before deleting).
