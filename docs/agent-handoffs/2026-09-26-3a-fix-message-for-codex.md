# Message for Codex — fix the Phase 3a review findings

Paste everything below the line into the Codex session that built the 3a screens (or a fresh Codex session opened in `C:\Users\gorok\sentinelx_mobile`).

---

You built the Phase 3a Flutter screens (rankings, seasons, hall of fame) on branch `phase3a/screens` in the worktree `C:\Users\gorok\sentinelx_mobile-p3a` (HEAD `e0c17ee`). A fresh reviewer went through them. The wire contract and models are correct and nothing crashes, but several things break the spec's **literal-parity exit criterion** or leave dead-end UI. Your job now is to fix them, test-first, and nothing else.

**Read first:** `C:\Users\gorok\sentinelx_mobile\CLAUDE.md` and `AGENTS.md`; the full review with severities, file:line references and fixes in `docs/agent-handoffs/2026-09-26-integration-and-3a-review.md` (section "Phase 3a review"); your own plan `docs/superpowers/plans/2026-09-23-mobile-phase3a-flutter-screens.md`; the web spec `C:\Users\gorok\Videos\sentinelx\docs\superpowers\specs\2026-09-23-mobile-phase3a-rankings-seasons-hof-design.md` and the literal-parity addendum `docs/superpowers/plans/2026-09-24-mobile-phase3a-literal-parity-addendum.md` (same web repo). The web components the app must match are in `components/rankings/` (`LeaderboardTable.tsx`, `TrendCell.tsx`, `GameTabs.tsx`) and the season leaderboard table.

**Work only in** `C:\Users\gorok\sentinelx_mobile-p3a` on branch `phase3a/screens`. Do not touch the other worktrees (`-p2a`, `-p3b`, `-integration`, `-auth-hardening`) or `master`.

**Fix, in this order, each with a failing test FIRST (run it, read the failure, then fix, then green):**
1. **"(you)" highlight** on the viewer's own on-page row in Rankings (compare the row's player id with the signed-in `/me` id; key `rank-row-me`; reuse an existing "you" ARB key or add one; a tint from `SxColors`). The pinned off-page card stays as is.
2. **Trend column:** `up` → "▲ {delta}" (green), `down` → "▼ {delta}" (red), everything else including `flat`, `new` and any unknown value → "—". No raw English words; localize any label through ARB (en + fr).
3. **Win% column:** `'${(winRate * 100).round()}%'` in the trailing column. **Fix the test fixture: the server sends `winRate` as a 0..1 ratio (e.g. 0.875), not 87.5.**
4. **Game vs region:** choosing a game must drop the region filter (web's game tabs link to plain `/rankings?game=<slug>`); changing the region keeps the game. Keep metric per the addendum's default.
5. **Season leaderboard:** render at most the first 50 rows, medals 🥇🥈🥉 for the top 3, and the empty line "No season points awarded yet." (new ARB key, en + fr).
6. **Dead ends:** make "Couldn't load. Tap to retry." actually tappable (invalidate the provider) on the seasons list, season detail and hall of fame; give season detail's loading and error states an `AppBar` (so a bad-slug deep link has a back button); add pull-to-refresh to those three screens.
7. **Rankings error state:** a failed load must not wipe the rows and controls. When the provider already has a value, keep rendering it and show the error as a banner/snackbar with a retry; if there is no value, show the retry state but keep the filter controls and pager so the user can go back a page.
8. **Avatar frames:** every `PlayerAvatar` call site must pass `resolveAsset(frameUrl, siteUrl)` (the server's `frameUrl` is site-relative, e.g. `/coin-items/x.webp`); also let the frame overhang the avatar (it is currently clamped by a tight `SizedBox`).
9. **Public endpoints must not carry the bearer token** (`/rankings`, `/seasons`, `/seasons/{slug}`, `/hall-of-fame`; only `/rankings/me` needs it). Implement a small per-request flag (for example `Options(extra: {'public': true})`) that the `ApiClient` auth interceptor honors, with a test proving the header is absent for the four public calls and present for `/rankings/me`. Keep this change **minimal** in `api_client.dart`.
10. **Tests the plan asked for and the branch lacks:** signed-out never calls `/rankings/me`; the your-rank card appears off-page and hides when the viewer is on-page; a filter change resets to page 1; Next keeps filters; a metric tab refetches the same page; sub-game chips; tombstone player shows "Deleted player"; empty and error states; season "you" row, provisional badge/note, invite-only chip; Hall of Fame option switching and empty sections hidden under a filter; the router resolves `/rankings`, `/seasons/:slug` and `/hall-of-fame`. Split them into the files the plan named (`rankings_screen_test`, `seasons_screens_test`, `hall_of_fame_screen_test`, `progress_routes_test`).
11. **Minor fixes only if trivial and covered by a test:** stop `/rankings/me` refetching on every page change (`.select` on game/region/metric/tabGame), replace the medal list lookup with a `switch`, clamp `_AwardState.selected`.

**Hard rules**
- **Do NOT reformat or rewrap any existing code, especially the shared files** `lib/core/api/api_client.dart`, `lib/router/app_router.dart`, `lib/features/home/home_screen.dart`, `lib/core/api/progress_models.dart`, `lib/core/routing/web_links.dart` and the tests around them. Your earlier commit reflowed whole files, which forced a hand-resolved merge. Every hunk you add must be minimal and match the surrounding style. Do not run `dart format` on files you are not otherwise changing.
- Never test writes against production (3a is read-only). No secrets in files.
- No copy hard-coded in widgets: ARB en + fr with identical key sets, then `flutter gen-l10n`.
- Before each commit: `flutter analyze` (no issues) and `flutter test` (all pass; the branch is at 163 tests today). After `flutter pub get`/`flutter test`, run `git checkout -- linux macos windows` before committing.
- **Do not push, merge or open a PR.**

**When done**
1. Update your ledger `.superpowers/sdd/2026-09-23-mobile-phase3a-flutter-screens/progress.md` (it is stale) with a line per fix and a `Ruling:` for every deviation, including anything you decided not to fix and why.
2. Write `docs/agent-handoffs/2026-09-26-mobile-phase3a-flutter-notes.md` in `C:\Users\gorok\sentinelx_mobile` (untracked, like the other handoffs): branch, HEAD, test counts, what was fixed, what was not, what is **not** verified (live server, device).
3. Report: commit hashes, exact `flutter analyze` / `flutter test` output, rulings, and anything surprising.

Start with fix 1.
