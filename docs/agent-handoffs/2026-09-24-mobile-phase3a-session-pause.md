# Mobile Phase 3a session pause — 2026-09-24

## Current state

Work is paused after completing and publishing PR 1 of the required three-PR sequence.

- Web PR 1: <https://github.com/Rex-Orokumue/sentinelx/pull/4>
- Branch: `phase3a/web-extraction`
- Worktree: `C:\Users\gorok\Videos\sentinelx\.worktrees\phase3a-web-extraction`
- Head commit: `6a8e9afeaf43a0e758a18ad0865760ed249fcb61`
- PR state: ready for review, not merged
- Vercel deployment check: success (`8JpBThxC9QnSfBwyHSmZ2LEkjmU7`)

Do not begin PR 2 until PR 1 has been reviewed and merged, per the Phase 3a handoff.

## What PR 1 contains

- Shared fake-Supabase test support, deterministic React-tree serialization, and progression fixtures.
- Characterization tests and immutable snapshots for rankings, Hall of Fame, and season pages.
- Exact-key-set tests for the season leaderboard data path.
- Behavior-neutral extraction of:
  - `getRankings`
  - `getHallOfFame`
  - season data services
- Page components now call the extracted services without intentional rendered-output changes.

Commits, oldest first:

1. `816a112` test support and fixtures
2. `e70619f` rankings characterization
3. `4032b56` Hall of Fame characterization
4. `4da8faf` season characterization and exact-key tests
5. `4dfc103` rankings service extraction
6. `5e1eca4` Hall of Fame service extraction
7. `6a8e9af` season service extraction

## Fresh verification evidence

Run from the PR 1 worktree before pushing:

- `npx vitest run`: 256 files passed, 1,814 tests passed
- `npm run lint`: no warnings or errors
- `npm run build`: exit 0
- Snapshot audit: exactly three `.snap` files were added, each only in its original characterization commit
- Branch was rebased/checked against current `origin/main`; it was already up to date

The production build needs the primary web checkout's `.env.local` values loaded into the process. Do not copy or commit the environment file.

## Deliberate plan deviations

- Vitest uses Oxc's automatic JSX runtime. The plan's legacy `esbuild.jsxInject` setting is ignored by this repository's Vite 8 stack.
- Hall-of-Fame and season fixtures are overlays rather than additions to the rankings base fixture. This prevents later fixture changes from mutating the locked rankings snapshot.
- The rankings sensitivity mutation reverses `goalDiff`. Swapping the planned wins/win-rate values did not affect the fixture ordering, while the `goalDiff` mutation correctly caused snapshot failure before being reverted.
- `gameSlug` was not added to the extracted season service because it changed the immutable page snapshot. PR 2 must derive it at the API boundary using the plan's allowed fallback.

## Known verification limitation

The required live staging rankings interaction has not been completed:

- Vercel reports the preview deployment as healthy.
- Windows DNS returned `DNS server failure` for both the preview hostname and `sentinelxesports.vercel.app`.
- The in-app browser runtime also rejected the session's sandbox metadata.
- Therefore, selected-tab persistence across Next-page navigation and game/region filtering was not observed, and five-run live timing medians were not recorded.

Retry this when DNS/browser access is healthy. Record the observation in the appropriate PR description. Follow the literal-parity addendum if the selected tab snaps back to Wins.

## Exact restart sequence

1. Read PR 1 review feedback from Claude.
2. Apply any accepted feedback in the existing PR 1 worktree.
3. Before another push, run `npx vitest run`, `npm run lint`, and `npm run build`; keep snapshots unchanged.
4. Merge PR 1 only after review approval and passing checks.
5. Create a fresh web worktree/branch for PR 2 from the newly merged `origin/main` using the branch name required by the original handoff.
6. Implement web plan Tasks 9–14 plus the literal-parity addendum, including the five mobile endpoints and OpenAPI contract.
7. Run the staging rankings browser observation early and record its result.
8. Start PR 3 in a separate mobile worktree only after PR 2's OpenAPI file exists on a branch.

## Rules that remain critical

- Never test writes against production; Phase 3a is read-only.
- Public endpoints must not inspect bearer tokens. Only `GET /rankings/me` is authenticated.
- Season endpoints use the service-role client: explicit column lists, strict Zod schemas, and exact-key-set tests are the data-leak boundary.
- Never regenerate characterization snapshots with `vitest -u`.
- Preserve worktree isolation and rebase before final checks.
- Shared hotspot changes must remain append-only where directed by the repository instructions.
- Report after each PR with exact test output, plan deviations, and surprises.

No mobile Phase 3a implementation files have been changed yet.
