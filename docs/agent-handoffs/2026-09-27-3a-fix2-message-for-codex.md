# Message for Codex — fix two bugs in the 3a fix pass

Paste everything below the line into the Codex session that did the 3a review fixes (or a fresh Codex session opened in `C:\Users\gorok\sentinelx_mobile`).

---

You fixed the Phase 3a review findings on branch `phase3a/screens` in the worktree `C:\Users\gorok\sentinelx_mobile-p3a` (HEAD `f44d355`, "fix(progress): match rankings seasons and hall parity"). A fresh reviewer went through that commit. Findings 1–6 and 8–11 are correctly implemented, `flutter analyze` is clean, and `flutter test` passes (192). But two of the fixes themselves introduced bugs, and one is a crash. Fix these, test-first, and nothing else.

**Read first:** `C:\Users\gorok\sentinelx_mobile\CLAUDE.md` and `AGENTS.md`; your own prior handoff `docs/agent-handoffs/2026-09-26-mobile-phase3a-flutter-notes.md`; the original review `docs/agent-handoffs/2026-09-26-integration-and-3a-review.md` (finding 7 in particular, which fix #2 below regressed).

**Work only in** `C:\Users\gorok\sentinelx_mobile-p3a` on branch `phase3a/screens`. Do not touch the other worktrees or `master`.

**Fix, in this order, each with a failing test FIRST (run it, read the failure, then fix, then green):**

1. **Crash in Hall of Fame** (`lib/features/hall_of_fame/hall_of_fame_screen.dart:72`). Category awards (`h.awards.categories`) are rendered via `_Award` with no `isNotEmpty` guard — unlike the sibling `goldenBoot` case, which is guarded at line 66. When a category award's `options` list is empty for the selected game filter, `_AwardState.build()`'s clamp (`selected.clamp(0, widget.options.length - 1)`, line 182) evaluates `0.clamp(0, -1)` and throws `ArgumentError`, crashing the screen. Write a widget test that selects a game filter under which a category award has zero options, confirm it crashes today, then guard the category-awards render the same way `goldenBoot` is already guarded (skip/hide the award, don't render `_Award` with an empty `options` list).

2. **Stale/mismatched data on filter-change failure** (`lib/features/rankings/rankings_providers.dart:32`, `rankings_screen.dart:17`). Finding #7 asked for: don't wipe rows/controls on a failed load *when the provider already has a value for that query* — show an error banner with retry, keep rendering what's there. What got built (`rankingsCacheProvider`) is a single global cache with no query-key scoping, so on a *filter change* that then fails, the screen falls back to the *previous, different* filter's cached rows while the chip UI already shows the new filter as selected (e.g. tap the `dls` game chip, fetch for `game: dls` fails, screen renders the old "All games" rows under an error banner while `chip-game-dls` shows selected). That's worse than the original bug — it silently shows content that doesn't match the visible filter state. Write a test that: (a) loads successfully with filter A, (b) changes to filter B, (c) filter B's fetch fails, (d) asserts the screen does NOT render filter A's rows — it should show the retry/error state (no stale rows from a different query), while a same-query subsequent-page failure still keeps last-success rows per the original fix. Scope the cache to the query key (game/region/metric/tabGame/page or whatever `rankingsQueryProvider` already keys on), not a bare "last successful value."

3. **Minor, only if trivial and covered by a test:** `lib/features/seasons/season_detail_screen.dart:97` — `game.leaderboard.take(50).length` is recomputed inside the loop-condition on every iteration instead of once. Hoist it out (e.g. `final cap = math.min(50, game.leaderboard.length);`) before the loop.

**Hard rules**
- **Do NOT reformat or rewrap any existing code**, especially the shared files (`api_client.dart`, `app_router.dart`, `home_screen.dart`, `progress_models.dart`, `web_links.dart`) and the tests around them. Every hunk you add must be minimal and match the surrounding style. Do not run `dart format` on files you are not otherwise changing.
- Never test writes against production (3a is read-only). No secrets in files.
- No copy hard-coded in widgets: ARB en + fr with identical key sets, then `flutter gen-l10n`, if fix 1 needs any new copy (it shouldn't — it's a guard, not new UI).
- Before each commit: `flutter analyze` (no issues) and `flutter test` (all pass; the branch is at 192 tests today).
- After `flutter pub get`/`flutter test`, run `git checkout -- linux macos windows` before committing.
- **Do not push, merge or open a PR.**

**When done**
1. Update your ledger `.superpowers/sdd/2026-09-23-mobile-phase3a-flutter-screens/progress.md` with a line per fix and a `Ruling:` for any deviation.
2. Write `docs/agent-handoffs/2026-09-27-mobile-phase3a-flutter-fix2-notes.md` in `C:\Users\gorok\sentinelx_mobile` (untracked, like the other handoffs): branch, HEAD, test counts, what was fixed, what was not, what is **not** verified.
3. Report: commit hash, exact `flutter analyze` / `flutter test` output, rulings, and anything surprising.

Start with fix 1 — it's the crash.
