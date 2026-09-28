# Integration branch re-cut — 2026-09-27

`integration/2a-3a-3b` (worktree `C:\Users\gorok\sentinelx_mobile-integration`) now includes **2b** as
well, despite the branch's old name. Kept the existing branch name rather than renaming it, to avoid
breaking any reference to it — content is what matters.

## What changed since the 2026-09-26 integration note

- Merged `phase3a/screens`'s two post-review fix commits (`587a2c9`, `0f269cb` — Hall of Fame crash
  guard, rankings cache scoping/cap, widget-state-bleed fix; see
  `docs/agent-handoffs/2026-09-27-mobile-phase3a-flutter-fix3-notes.md`).
- Merged `phase2b/screens` in full (11 commits: Tasks 1–10 plus its own review-fix commit `50b164c`,
  plus a follow-up fix `4528e4f` — guest-detection now decided from `sessionProvider`, not `meProvider`;
  see `docs/agent-handoffs/2026-09-26-mobile-phase2b-flutter-notes.md`, updated with that follow-up).

## Merge conflicts

- **One conflict, resolved**: `lib/core/api/api_client.dart`'s `_send()` — 2a/2b's side had added a
  `headers` param (Idempotency-Key on writes), 3a's side had added a `publicRequest` flag (omit bearer
  auth on public reads). Kept both params; both are exercised (writes pass `headers`, 3a's public reads
  pass `publicRequest: true`).
- **Merging `phase2b/screens` had zero conflicts** — every other shared hotspot (`app_router.dart`,
  `web_links.dart`, `home_screen.dart`, ARB files, `pump_compete.dart`) merged cleanly, including my
  `sessionProvider`/`meProvider` split in `pump_compete.dart` from the 2b follow-up fix.
- `api/openapi.json` was **not** touched by either merge — 2b's 12 operationIds were already present in
  the integration-only union (2a and 2b's web endpoints share the same web branch,
  `docs/mobile-phase1-phase2a-specs`, so the union already carried both). Still a hand-union artifact,
  not regenerated from a single merged web source — unchanged caveat from the 2026-09-26 note. **The web
  repo itself has not consolidated its branches since that note was written**: 3a's ops are on web
  `main`; 2a+2b's are on `docs/mobile-phase1-phase2a-specs`; 3b's are on `phase3b/web-endpoints`
  (checked 2026-09-27) — none merged together, so this remains the blocker for a single web checkout
  serving a combined device pass.

## Verification

- `flutter analyze`: no issues.
- `flutter test`: **545 passed** (was 368 at the 2026-09-26 note, then 402 after the 3a merge, then 545
  after the 2b merge).
- Generated desktop plugin registrants (`linux/`, `macos/`, `windows/`) restored with
  `git checkout -- linux macos windows` after `flutter pub get`/`flutter test`, before each commit.

## Known open item carried in from 2b

2b's own review flagged one Important finding as explicitly unfixed at merge time into `phase2b/screens`
(guest-detection ambiguity) — that has since been fixed directly (`4528e4f`, included in this merge; see
2b's updated handoff note). No other known Important-severity gaps remain unfixed across 2a/2b/3a/3b as
of this branch.

## Not pushed

Nothing pushed, merged into `master`, or opened as a PR. `master` untouched at `0148b2a`.

## Next steps

1. Web side: decide whether/how to reconcile `docs/mobile-phase1-phase2a-specs` + `phase3b/web-endpoints`
   (3a's already on `main`) so a single web checkout can serve 2a+2b+3a+3b together for the planned
   combined device/staging test pass.
2. Once decided, regenerate `api/openapi.json` from that merged web source (currently a hand-union, not
   machine-regenerated).
3. Run the big device/staging test pass across all four phases.
