# Mobile Phase 3a Flutter review fixes — handoff

- Branch: `phase3a/screens`
- Worktree: `C:\Users\gorok\sentinelx_mobile-p3a`
- HEAD: `f44d355` (`fix(progress): match rankings seasons and hall parity`)
- Base before this fix run: `e0c17ee`
- Verification: `flutter analyze` → `No issues found! (ran in 55.9s)`
- Verification: `flutter test` → `+192: All tests passed!` (baseline was 163)

## Fixed

- Rankings highlights the signed-in viewer's on-page row with `rank-row-me`, localized `(you)` copy, and an existing-palette tint.
- Trend parity: green `▲ delta`, red `▼ delta`, and `—` for flat/new/unknown.
- Win rate displays rounded percent from the API's 0..1 ratio; fixtures now use `0.875`, not `87.5`.
- Selecting a game clears region and resets page; region preserves game; metric persists per the addendum.
- Season standings cap at 50, use medals for the top three, and show localized `No season points awarded yet.` when a game's leaderboard is empty.
- Seasons list/detail and Hall of Fame retry text is tappable; all three support pull-to-refresh; season detail loading/error retains an AppBar.
- Rankings retains the last successful rows/controls after a later load failure and shows a retry banner. First-load errors retain base filters and pager.
- All `PlayerAvatar` call sites resolve site-relative frame URLs; frames can overhang the avatar bounds.
- Public Phase 3a endpoints omit bearer auth; `/rankings/me` retains it.
- Added the four plan-named test files and coverage for signed-out behavior, pinned/on-page viewer rows, filters/paging/metrics/sub-games, tombstones, empty/error states, season viewer/provisional/invite behavior, Hall option/filter behavior, and route resolution.
- Minor covered fixes: `/rankings/me` ignores page-only changes, season medals use a switch, and Hall award selection clamps after option lists shrink.

## Rulings / intentionally not fixed

- Metric/tab-game persistence follows the approved literal-parity addendum. The live web browser observation was not repeated.
- A whole season with no games keeps the generic empty state; an existing game with no standings uses the new season-points empty line.
- The rankings last-success value is provider-owned so the screen remains a `ConsumerWidget`; it is retained across query invalidation to support failed-page recovery.
- `appConfigProvider.apiBaseUrl` is used as the site asset origin because it is the active web deployment origin for each flavor/staging preview.
- Deferred review minors outside the explicitly authorized trivial list were not changed: pinned-row styling details, unused performer/stat blocks, raw season dates, web-link query/slug behavior, and remaining Hall-of-Fame layout/copy differences.

## Not verified

- No live API/server or staging parity sample.
- No emulator or physical-device run.
- No 375px visual side-by-side against the live web pages.
- No Vercel/CDN observation; bearer omission is verified at the Dio request-adapter boundary.
- French wording is present and key-parity tested, but was not reviewed by a native speaker.
