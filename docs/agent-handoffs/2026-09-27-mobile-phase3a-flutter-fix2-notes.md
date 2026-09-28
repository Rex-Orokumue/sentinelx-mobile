# Mobile Phase 3a Flutter fresh-review fixes — handoff

- Branch: `phase3a/screens`
- Worktree: `C:\Users\gorok\sentinelx_mobile-p3a`
- Base: `f44d355` (`fix(progress): match rankings seasons and hall parity`)
- HEAD: `587a2c962b0757c282111311188c4d60a8e8376c` (`fix(progress): scope ranking cache and guard awards`)
- Verification: `flutter analyze` -> `No issues found! (ran in 24.4s)`
- Verification: `flutter test` -> `+194: All tests passed!` (baseline: 192)

## Fixed

- Hall of Fame now skips category awards with no options for the selected game, preventing `_AwardState` from calling `clamp(0, -1)`. The regression widget test selected DLS, reproduced the `ArgumentError` before the guard, and passed after it.
- Rankings last-success data is cached by game/region/metric/tabGame scope. A failed filter change no longer renders rows from a different scope; a failed subsequent page in the same scope still retains the last successful rows and retry banner.
- Season detail computes the 50-row leaderboard cap once before the loop instead of recomputing `take(50).length` per iteration.
- The ignored Phase 3a SDD ledger was updated in the p3a worktree with one line per fix and the rulings below.

## Rulings

- Page is intentionally excluded from the rankings cache key. Finding 7 requires failed pagination to retain the last successful rows for the same game/region/metric/tabGame scope; all content-changing filter dimensions are included.
- The season cap hoist has no observable pre-fix failure. Its existing dedicated widget test (50 rows rendered, row 51 absent, top-three medals) was used as the behavioral guard after the minimal computation-only change rather than adding a source-shape test.

## Not fixed

- No other Phase 3a findings, deferred minors, shared files, localization, API contract, routing, or UI copy were changed.

## Not verified

- No live API/server or staging parity sample.
- No emulator or physical-device run.
- No 375px visual side-by-side against the web pages.
- No production writes were made.
