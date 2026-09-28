# Mobile Phase 4 (Community) — Stage B, web endpoints

- Repo: `sentinelx` (web), branch `main`
- Spec: `docs/superpowers/specs/2026-09-27-mobile-phase4-community-design.md` (already on `main` as of
  this session's earlier commit `d3f8f57`, resolving Checkpoint 1's three open questions)
- Executed as a fork of the session that wrote that spec, per
  `docs/agent-handoffs/2026-09-27-phase4-start-message.md`'s Stage B instructions

## What was built

Every read (§3) and write (§4) endpoint from the spec, plus the report table (§5) and realtime
publication change (§7):

**Migration** `supabase/migrations/20260928120000_community_content_reports.sql` — the
`community_content_reports` table (reason-code taxonomy, resolution enum, RLS, two partial-unique
dedupe indexes), and `ALTER PUBLICATION supabase_realtime ADD TABLE public.community_posts`. Not
applied to any database (never test writes against production; this is a file for the next deploy's
migration run).

**`lib/supabase/types.ts`** — hand-added the `community_content_reports` Row/Insert/Update/Relationships
entry (this repo's established pattern for a table ahead of a full type regen, same as
`game_registration_fields` was added the same way).

**New service files** in `lib/community/` (`post-service.ts`, `reaction-service.ts`,
`comment-service.ts`, `status-service.ts`, `best-play-service.ts`, `report-service.ts`) — injectable
core logic (`perform*` functions taking `supabase`/`admin`/`userId` explicitly) shared between the
mobile-api endpoints and, where safe, the existing web Server Actions. Mirrors this repo's own
`lib/tournaments/register-service.ts` ↔ `actions.ts` relationship.

**New endpoint files** `lib/mobile-api/endpoints/community-reads.ts` (11 GET endpoints) and
`community-writes.ts` (13 write endpoints — POST/PUT/DELETE), registered in
`lib/mobile-api/endpoints/index.ts`, wired to Next.js route handlers under
`app/api/mobile/v1/community/**` (one `route.ts` per path/method-set, matching every existing
endpoint's wiring convention).

**`openapi/mobile-v1.json`** regenerated (`npm run openapi`) — 24 new operationIds.

**Existing `lib/community/*.ts` files touched** (minimal, behavior-preserving where noted):
- `feed-query.ts`, `status-query.ts` — `hydratePosts`/`fetchFeedPage`/`fetchPostDetail`/
  `fetchStatusRings`/`fetchStatusViewers` now take an injected Supabase client instead of calling
  `createClient()` (cookie-session) internally. **This was a correctness fix, not just refactoring
  convenience**: the mobile-api's bearer-token-authenticated `ctx.userClient` is a *different* client
  from the web's cookie-session `createClient()`; a mobile request has no cookies, so the old
  internal `createClient()` call would always run as a fully anonymous session regardless of the
  caller's real signed-in status. For `player_statuses` (sign-in required to read at all, per
  CLAUDE.md) and `community_post_images`/`notification_mutes` (narrower-than-public RLS), that would
  have silently returned empty/wrong results for every genuinely signed-in mobile caller. Fixed by
  threading the real client through; call sites in `app/[locale]/(public)/community/**` and
  `load-more-action.ts` updated to pass their own `createClient()` explicitly (no behavior change for
  web — it already had a real session-bound client available at each call site).
- `post-actions.ts`, `comment-actions.ts`, `status-actions.ts` — `createPost`, `createComment`,
  `postStatus`, `deleteStatus`, `recordStatusView`, `boostPost` now delegate to the new service
  functions (their external `'use server'` signatures are unchanged, so every client-component call
  site — `PostComposer.tsx`, `CommentInput.tsx`, `StatusComposer.tsx`, `StatusViewer.tsx` — needed no
  changes; Server Actions can't accept a `SupabaseClient` argument across the client/server RPC
  boundary, which is why the injectable core had to live in a separate non-`'use server'` file rather
  than just adding parameters in place).
- **Deliberately NOT delegated:** `deletePost` (`post-actions.ts`) and `deleteComment`
  (`comment-actions.ts`) stay exactly as they were — a blind RLS-scoped update with no ownership
  pre-check. Both `community_posts` and `post_comments` have a `*_staff_manage` RLS policy alongside
  the player policy; the new mobile-only service functions (`performDeletePost`/`performDeleteComment`)
  are author-only by design (Ruling 5 — mobile excludes staff moderation, left to Phase 8). Reusing
  them for the web actions would have silently broken staff's existing ability to delete other
  players' posts/comments via RLS. Caught this while refactoring `deletePost` first — see Rulings.
  `toggleReaction` (`reaction-actions.ts`) and `castBestPlayVote` (`best-play-actions.ts`) were also
  left untouched — different semantics (Ruling 6) and missing validation (see Rulings) respectively,
  not worth risking a web behavior change to retrofit.
- Missing route file found and fixed in passing: `GET /tournaments/{id}/registration-fields`
  (`lib/mobile-api/endpoints/registration-fields.ts`) was registered in `ALL_ENDPOINTS` for the OpenAPI
  contract but had no `app/api/mobile/v1/tournaments/[id]/registration-fields/route.ts` — the endpoint
  was unreachable over HTTP despite being in the committed contract Codex is about to build the mobile
  client against (`docs/agent-handoffs/2026-09-28-registration-fields-message-for-codex.md`). Added the
  one-line route file.

## Rulings

1. **`lib/community/*.ts`'s query functions needed client injection for correctness**, not just to
   match convention — see the feed-query.ts/status-query.ts bullet above. This wasn't anticipated in
   the spec (which only flagged `performBoostPost` for extraction); found while implementing.
2. **`deletePost`/`deleteComment` (web Server Actions) are NOT delegated to the new author-only
   service functions** — reusing them would have silently dropped staff's existing delete-any
   capability (RLS permits it; the mobile-only service functions correctly don't, per Ruling 5, but
   that's the wrong behavior for web). Left both as the original blind RLS-scoped update.
3. **`castBestPlayVote` (web) left un-refactored** — it doesn't currently check nomination existence
   or the voting window before inserting, unlike what the mobile spec requires
   (`performVoteBestPlay`, a new function, adds both checks). Retrofitting those checks into the web
   action would be a behavior change outside this phase's scope; flagging in case it's a latent web
   bug worth its own follow-up.
4. **`GET /community/posts/{id}/comments` reuses `fetchPostDetail`** (which also hydrates the full
   post) rather than a dedicated comments-only query, since no such function exists and the comments
   result set is already capped at 50 with no separate pagination path. Simpler, slightly wasteful
   (one extra post hydration per call) — flagged rather than building a new query function for a
   sub-50-row list.
5. **Report insert-error mapping**: a non-unique-violation DB error on `community_content_reports`
   insert (`performReportPost`/`performReportComment`) returns a new `report_failed` (500) error code
   rather than falling through to `not_found` — caught in self-review; a generic DB failure mapped to
   404 would have been misleading. Covered by a new test in `report-service.test.ts`.
6. **`performBoostPost`'s write-failure path** similarly gets its own `boost_failed` (500) code
   instead of reusing `not_found`, for the same reason.
7. Response-shape zod schemas in `community-reads.ts` were hand-written against each `lib/community/
   *-query.ts` function's actual TypeScript return type (re-read every one, not inferred from the
   spec's prose) to avoid the response validation silently 500ing on a real, correctly-shaped payload.
8. **`performBoostPost` had an unused `supabase` parameter** — found during a manual "reverse
   direction" pass (what each new service function actually calls, not just what calls it) prompted
   by a partial automated-review thread that got cut off mid-check on exactly this question. The
   function only ever used `admin` (matching the original `boostPost`'s own comment: no player-facing
   UPDATE policy permits writing `boosted_until` directly, so it goes through the service role
   throughout) — the `supabase` param was dead weight from copying the sibling functions' signature
   shape. Removed; both call sites (`community-writes.ts`, `post-actions.ts`) updated. Re-verified
   green (`tsc`, targeted tests, full build) after the fix.
9. **`getStatusViewers` (`status-actions.ts`) calling `fetchStatusViewers(createClient(), statusId)`
   with a freshly-constructed client** was flagged as a possible session mismatch during the same
   reverse-direction pass. Checked concretely against `lib/supabase/server.ts`: `createClient()` is
   stateless and reads `cookies()` from the current request on every call, so a second call within the
   same request/Server Action is session-equivalent to the first, just a different JS object instance
   — not a different session. Confirmed correct, no change needed.

## Verification

- `npx tsc --noEmit -p tsconfig.json` — clean (checked repeatedly through the session, including
  after the final review-driven fix).
- `npm run lint` (`next lint`) — clean, no warnings.
- `npx vitest run` — full suite green, run multiple times across the session. Final scoped run
  (`--exclude '**/.worktrees/**'`, excluding sibling sessions' own worktrees nested under this
  checkout, which are not this repo's code): **309 test files, 2183 tests, all passing.** New/changed
  test files: `lib/mobile-api/endpoints/community-reads.test.ts`, `community-writes.test.ts`,
  `lib/community/report-service.test.ts`, `best-play-service.test.ts`, `reaction-service.test.ts`,
  plus the pre-existing `lib/community/comment-actions.test.ts` updated for the refactored mock shape.
  Earlier un-scoped full-repo runs (which sweep in every `.worktrees/*` copy of the suite too) showed
  occasional unrelated timeout flakes under heavy concurrent load from a peer session working in this
  same checkout (`lib/notifications/notify.test.ts`, and duplicate copies of
  `lib/community/comment-actions.test.ts`/`lib/tournaments/*.test.ts` under `.worktrees/phase3a-api/`
  and `.worktrees/phase3a-web-extraction/`) — all confirmed passing cleanly in isolated re-runs; none
  are files this session changed.
- `npm run openapi` (`vitest run lib/mobile-api/openapi.test.ts -u`) — contract regenerated and the
  "openapi/mobile-v1.json is up to date" snapshot test passes.
- `npm run build` (`next build`) — clean, run three times across the session (including after the
  final fix); all 24 new community routes and the fixed registration-fields route appear in the
  build's function manifest.
- **Review**: two automated `/code-review high` runs failed on infrastructure, not content — one
  stalled (600s watchdog, no progress) and one hit a session rate limit — both while the machine was
  under heavy concurrent load from other sessions/worktrees in the same environment. Neither produced
  a findings list. In place of a third automated attempt, did a manual review pass covering: every
  new file read in full at least twice, every response zod schema cross-checked against its backing
  function's actual TS return type (not the spec's prose), and — prompted by a partial thread one of
  the stalled review sub-agents left mid-check — an explicit "reverse direction" pass over every new
  `perform*` service function: what it actually calls vs. what each endpoint handler passes it. That
  pass found Ruling 8 (unused parameter) and cleared Ruling 9 (a suspected session-mismatch that
  turned out correct). Fixed, re-verified green.

## Not verified

- No live Supabase run — the migration has not been applied anywhere (no dev/staging database for
  this project per `CLAUDE.md`; this is source only).
- No manual/E2E hit against a running `next dev` server or deployed preview.
- No load/perf check on `fetchFeedPage`'s per-post hydration under the new client-injection path
  (structurally unchanged, just a different client instance, but not measured).

## Commits (pushed)

`sentinelx` `main`, fast-forwarded from `d3f8f57` (this session's earlier Checkpoint-1-resolution
commit):

- `3804678` — `feat(db): community_content_reports table + community_posts realtime publication`
- `0f3fa9b` — `feat(mobile-api): Community feed/posts/reactions/comments/statuses/best-play/report endpoints`

`git log origin/main -3 --oneline` confirms both are on `origin/main`.
