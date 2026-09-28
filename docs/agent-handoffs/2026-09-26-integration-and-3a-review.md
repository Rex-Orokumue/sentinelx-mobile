# Integration branch + Phase 3a review — 2026-09-26

Nothing is pushed. `master` is untouched.

## Integration branch

- Worktree `C:\Users\gorok\sentinelx_mobile-integration`, branch `integration/2a-3a-3b`, cut from `master` (0148b2a).
- Contents: `phase2a/screens` (merge), `phase3a/screens` (merge, HEAD e0c17ee), and the nine 3b Flutter commits **cherry-picked** (`94bc284..e0fb47a`) — a plain merge of `phase3b/screens` would have collided with its old copy of the 3a base.
- Verified on this branch: `flutter analyze` no issues; `flutter test` **368 passed**.
- Conflicts were all in the shared hotspots and were resolved by keeping both sides: `api_client.dart` (usedOperations + methods), `app_router.dart` (3a routes + 3b players/progress routes + 2a invitations/games/profile), `web_links.dart`, `home_screen.dart`, `account_screen.dart` (kept the 2a stateful widget; the 3b "My progress" tile is now an OPTIONAL `onOpenProgress`), ARB files (key-wise union; zero key clashes), tests, TESTING-NOTES.
- **`api/openapi.json` on this branch is an integration-only UNION** (web `phase3b/web-endpoints` contract, 41 ops, plus 3a's five operations = 46). No single web branch contains all of them: 3a is on web `main`, 2a/2b on `docs/mobile-phase1-phase2a-specs`, 3b on `phase3b/web-endpoints`. Regenerate it from the merged web repo before anything ships.
- The 3b cherry-pick also gained no 3a `_withQuery` conflict because both sides define the same helper.

## Phase 3a review (fresh reviewer, most capable model; read-only)

Verdict: **Ready to merge: With fixes.** No crashes, no contract errors (models match the zod schemas key-for-key), no rank/points math in Dart, signed-out never calls `/rankings/me`. Findings (severity re-graded by effect):

**Important (literal-parity / dead ends — fix before the 3a branch is trusted):**
1. Rankings has no "(you)" highlight on the viewer's own on-page row (`rankings_screen.dart:93`). Web marks it.
2. Trend column prints the raw wire word (`up`/`down`/`flat`) and is not localized; web shows ▲ delta / ▼ delta / "—" (`rankings_screen.dart:251`). "New" should also be "—".
3. Win% column missing; web shows `round(winRate*100)%`. The test fixture's `winRate: 87.5` is not what the server sends (a 0..1 ratio), which hid this.
4. Choosing a game keeps the region filter; web drops it (`rankings_providers.dart:13`).
5. Season leaderboard is not capped at 50 rows; no medals for the top 3; no "No season points awarded yet." empty line (`season_detail_screen.dart:63`).
6. "Tap to retry" is not tappable on three screens; season detail has no app bar while loading/erroring (a bad-slug deep link is a dead end); no pull-to-refresh (`seasons_list_screen.dart`, `season_detail_screen.dart`, `hall_of_fame_screen.dart`).
7. A failed rankings load wipes all rows and controls; if page 3 keeps failing there is no way back except leaving (`rankings_screen.dart:18`).
8. Avatar frames never render: `frameUrl` is site-relative and `resolveAsset` is never called; `PlayerAvatar` also clamps the frame to the avatar size.
9. Public endpoints (`/rankings`, `/seasons*`, `/hall-of-fame`) are sent the bearer token, which costs an `optionalAuth` lookup per request server-side and may defeat CDN caching (verify Vercel behavior). Only `/rankings/me` needs it. Fix: a per-request "public" flag honored by the interceptor.
10. Commit e0c17ee reformatted whole shared files (`api_client.dart`, `app_router.dart`, `home_screen.dart`, `progress_models.dart`, two tests) despite the append-only rule — this is why merging needed hand resolution.
11. Test coverage is thin: one file with 4 tests vs the plan's four files (missing: signed-out `/me` never called, pinned card, filter/page reset, tombstone, empty/error, season provisional/invite-only, HoF sections, router resolution).

**Minor (deferred):** `/rankings/me` refetches on every page change; the pinned row differs from web (medals, position, expandable-but-empty wins); medal lookup can RangeError on a bad rank; Top Performers/4-stat bar unused; Hall of Fame small differences (Open section, Champions Cup shows all, bronze empty text, MVP null, metric label, tombstone subtitle); `_AwardState.selected` never clamped; seasons list shows raw ISO dates; `resolveWebLink` slug re-encoding and dropped `?game=` query; the ledger is stale and no rulings were recorded.

**Not judged:** whether metric persists across navigation on the live web page (the addendum's browser check was never recorded); Vercel caching of Authorization requests; French wording; device/staging.

## Suggested Codex fix brief for 3a (self-contained)

Work only in `C:\Users\gorok\sentinelx_mobile-p3a`, branch `phase3a/screens`. Do NOT reformat shared files. TDD each fix (failing test first). Fix findings 1–8 and 11 above (9 is a small interceptor change — do it if `ApiClient.create` tests can cover it; otherwise log it as a follow-up), fix the fixture to use a 0..1 `winRate`, add the missing tests, update the ledger with rulings, keep `flutter analyze` clean, and write `docs/agent-handoffs/2026-09-26-mobile-phase3a-flutter-notes.md`. Do not push.
