# Mobile Phase 3a Flutter — third fix round (done directly, not via Codex)

- Branch: `phase3a/screens`
- Worktree: `C:\Users\gorok\sentinelx_mobile-p3a`
- HEAD: `0f269cb` (`fix(rankings,hof): key award widgets, scope rankings cache, cap it`)
- Base before this fix run: `587a2c9`
- Verification: `flutter analyze` → `No issues found! (ran in 8.8s)`
- Verification: `flutter test` → `+197: All tests passed!` (base was 194)

This round fixed three issues a fresh reviewer found in Codex's second fix pass
(`587a2c9`, itself a fix of two earlier review findings). Implemented directly
by Claude in this session, test-first, rather than sent back to Codex.

## Fixed

- **Hall of Fame widget state bleed** (`hall_of_fame_screen.dart`) — `_Award`
  widgets (goldenBoot and each category award) had no `Key`. When a filter
  change hid one award (now-empty options) and a later award shifted into its
  old list slot, Flutter reused the hidden award's `State` — including its
  `selected` index — for the award that moved into that position. No crash,
  but the wrong option showed pre-selected on an unrelated award. Fixed by
  giving `goldenBoot` and each category award a stable `ValueKey`
  (`award-goldenBoot`, `award-<category>`). Regression test added:
  reproduces the bleed by selecting a non-default Golden Boot option, then
  filtering so Golden Boot disappears and a category award (never touched)
  shifts into its slot — confirms the category award now shows its own
  default, not Golden Boot's stale index.
- **Duplicated cache-key logic** (`rankings_providers.dart` /
  `rankings_screen.dart`) — the screen inline-recomputed
  `query.copyWith(page: 1)` instead of reusing the provider file's key
  helper, because that helper was library-private. Made it public
  (`rankingsCacheKey`) and had the screen call it. Pure refactor, no
  behavior change; existing tests stay green.
- **Unbounded rankings cache** (`rankings_providers.dart`) —
  `rankingsCacheProvider`'s map was never pruned, growing one entry per
  unique game/region/metric/tabGame combination for the app's lifetime.
  Capped at 8 entries with insertion-order eviction (re-storing an existing
  key doesn't move its position in the map, so genuinely stale/untouched
  entries evict first). New test file `rankings_providers_test.dart` covers
  eviction past the cap and confirms re-storing an existing key never
  evicts anything.

## Rulings

- Cache cap set to 8 (within the reviewer's suggested 8–16 range); the
  filter domain (game/region/metric/tabGame) is small and finite, so the
  exact number has no user-facing effect.
- Fix 2 (public cache-key helper) is a non-observable refactor; no new test
  was written for it specifically, existing cache/filter tests cover it.

## Not verified

- No live API/server or staging parity sample.
- No emulator or physical-device run.
- No 375px visual side-by-side against the live web pages.
- Generated desktop plugin registrants (`linux/`, `macos/`, `windows/`) were
  touched by `flutter pub get`/`flutter test` during this run and restored
  with `git checkout -- linux macos windows` before committing, per the
  hard rule.

## Not pushed

Nothing pushed, merged, or opened as a PR. `master` untouched.
