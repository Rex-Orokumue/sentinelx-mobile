# Start message — Phase 4 (Community): spec → web endpoints → mobile plan → mobile build

Paste everything below the line into a fresh session. Stage A/B belong in the web repo
(`C:\Users\gorok\Videos\sentinelx`); Stage C/D belong in the mobile repo (`C:\Users\gorok\sentinelx_mobile`).
If your harness can't easily work across two repo roots in one session, split at the Stage B→C boundary
and hand off with your own written notes — don't skip reading them into the mobile side.

---

You are taking **Phase 4 of the Sentinel X Flutter app — Community** from zero to a merged, working
feature. Unlike every prior phase, **nothing exists yet**: no web API spec, no mobile-api endpoints, no
mobile plan. You are doing all four stages below, in order, with two mandatory stop-and-report checkpoints
(end of Stage A, end of Stage B's review) before continuing. Do not skip the checkpoints because "it's
obviously fine" — every prior phase in this project went through a review round before merging, and Phase
4 touches production coin-spend (post boosts) and public content moderation, which raises the stakes, not
lowers them.

**Read first**
1. `C:\Users\gorok\sentinelx_mobile\CLAUDE.md` and `AGENTS.md` (mobile repo rules; they bind you) — note
   the production-database caution (Supabase project `itxubrkbropttfdackmi`, no dev/staging instance,
   never test writes against production) and the three-tier access rule (all writes and all
   TypeScript-computed reads go through `/api/mobile/v1/*`, never PostgREST, even where RLS allows it).
2. The master spec, `docs/superpowers/specs/2026-09-18-flutter-mobile-app-master-design.md` §8.9
   (Community, Phase 4) — the one paragraph that defines scope: feed (post types manual/match_result/
   achievement/announcement, pinned & boosted, 4-emoji reactions, threaded comments, weekly challenges
   rail, Best Play of the Week voting, status stories row, top members, upcoming events, gallery), post
   detail, compose (text + image(s), boost for 200 coins), statuses (24h stories, viewer list,
   friend-only notifications), weekly challenges progress, Best Play vote. Public read; write/react
   require sign-in. Realtime new-post/reaction updates. Moderation: report/delete own; staff pin/announce/
   delete (confirm with the owner whether staff moderation belongs in this phase's player-facing app or in
   the later Admin phase, §8.24 — don't assume).
3. Known facts already confirmed in this repo's `CLAUDE.md`: `community_posts` / `post_comments` are
   publicly readable (`is_deleted = false`); only `player_statuses` requires sign-in.
4. In the web repo: the three existing feature-design docs — `docs/superpowers/specs/2026-07-13-community-pillar-design.md`,
   `2026-08-16-community-wallet-redesign-design.md`, `2026-09-07-community-system-overview.md` — describe
   the *website's* Community feature (already built and live). These are your ground truth for what exists
   today: real tables, RLS, Server Actions, coin-spend logic for boosts. They are NOT a mobile-api spec —
   that's what you're about to write.
5. For the spec-writing and plan-writing *style* to match, read one prior phase's pair as a template:
   web `docs/superpowers/specs/2026-09-23-mobile-phase3a-rankings-seasons-hof-design.md` (spec) and mobile
   `docs/superpowers/plans/2026-09-23-mobile-phase3a-flutter-screens.md` (plan it produced).
6. `docs/agent-handoffs/2026-09-27-integration-recut.md` and `2026-09-27-mobile-phase3a-flutter-fix3-notes.md`
   for how shared-hotspot files get touched append-only, and the project's now-settled practice: **finish,
   verify green, merge and push directly to `main`/`master` immediately — no PR, don't let work sit
   unmerged.** That practice still requires each phase to go through its own review-and-fix round first
   (see every prior phase's handoff notes) — "push immediately" means immediately *after* verified/reviewed,
   not instead of.

## Stage A — Web API design spec (web repo)

Investigate before designing: read the actual website Community feature's code (find where posts/comments/
reactions/statuses/boosts/weekly-challenges/Best-Play-voting are implemented server-side today — Server
Actions, not just the design docs) and the real Supabase schema (`list_tables`/migrations for
`community_posts`, `post_comments`, reactions, `player_statuses`, weekly challenge and Best Play tables).
Ground the spec in what's actually there, not the design docs' intent, in case they've drifted.

Design the mobile-api surface: what endpoints are needed for every write action Phase 4 needs (react,
comment, post, boost — a coin spend, needs an Idempotency-Key like every other coin-spend/payment flow in
this codebase — statuses/stories, weekly challenge progress if it's not pure read, Best Play vote, report,
delete-own). Decide and document explicitly whether reads (feed, post detail, statuses) go through
`/api/mobile/v1/*` too for consistency, or stay direct-Supabase per the confirmed-public-read tables (both
are legitimate; prior phases used direct-Supabase reads for other confirmed-public tables — follow that
precedent unless there's a reason not to, and say what that reason is if you deviate).

Write the spec: `docs/superpowers/specs/<today's date>-mobile-phase4-community-design.md` in the web repo,
matching the depth/structure of the 3a/3b spec examples above (endpoint list, request/response shapes,
auth requirements per endpoint, idempotency policy, error codes, what's out of scope and why).

**Checkpoint 1 — stop here.** Report the spec's location and a short summary (endpoint list, the
read-strategy decision, anything you're unsure about) to the owner before writing a line of endpoint code.
This is genuinely new design, not a review-fix — don't freelance it further than the spec.

## Stage B — Implement the web endpoints (only after Checkpoint 1 is confirmed)

TDD each endpoint, mirroring the test patterns already in `lib/mobile-api/endpoints/*.test.ts` (e.g.
`rankings.test.ts`, `follows.test.ts`). Idempotency-Key handling for the boost (coin-spend) endpoint should
reuse whatever this repo's existing idempotency helper is (check how `wager.ts`/`match-result.ts` do it —
don't reinvent it). Regenerate the openapi contract (`npm run openapi`) once all operationIds are wired.
**Never test writes against production** — use this repo's own established safe-test pattern (mocks/local,
not the live Supabase project). Run this repo's full verification (typecheck/lint/test/build).

Then get this reviewed the way every other phase's endpoints have been (a fresh-context review pass; this
repo's own conventions dictate the mechanism). Fix findings.

**Checkpoint 2 — stop here.** Report: what was built, review findings and fixes, verification output.
Once confirmed green and reviewed, merge and push directly to `main` (no PR, per the owner's standing
preference) — but only after this checkpoint, not before.

## Stage C — Mobile Phase 4 plan (mobile repo, only after Stage B is on `main`)

Write `docs/superpowers/plans/<today's date>-mobile-phase4-community-screens.md`, following the Task-based
structure of `docs/superpowers/plans/2026-09-26-mobile-phase2b-flutter-screens.md` (Global Constraints,
Review Focus, Coordination, then numbered Tasks). Cover: feed (with realtime new-post/reaction updates —
check how realtime is already wired elsewhere in this app, e.g. the bell/`player_notifications`, for the
established pattern), post detail, compose (text + image(s), boost), statuses/stories (viewer list,
friend-only notifications), weekly challenges progress, Best Play vote, moderation (report/delete own;
confirm staff actions' scope per the note in point 2 above), ARB copy (en + fr, identical key sets), and
the full test list per screen (empty/error states, signed-out behavior, realtime update handling, boost
insufficient-coins state, etc. — mirror the rigor of the 3a/2b plans' Review Focus sections).

## Stage D — Mobile Phase 4 build (mobile repo)

New worktree off current mobile `master` (`sentinelx_mobile-p4`), new branch `phase4/screens`. Strict TDD:
failing test first, watch it fail, minimal code, green, repeat. `flutter analyze` clean and `flutter test`
all passing before every commit; `git checkout -- linux macos windows` after `flutter pub get`/`flutter
test`, before committing. Shared hotspot files (`lib/core/api/api_client.dart`, `lib/router/app_router.dart`,
`lib/core/routing/web_links.dart`, ARB files + generated l10n, `lib/features/home/home_screen.dart`) get
minimal, append-only hunks — never reformat or rewrap existing code.

Get this reviewed too (fresh-context review pass, same as 2a/2b/3a/3b all got), fix findings, re-verify.

**Final checkpoint.** Report: branch + HEAD, test counts, review findings and fixes, every Ruling made,
what's deferred, what's **not** verified (live-server behavior, device/staging — same disclaimers every
prior phase's handoff carried). Once green and reviewed, merge and push directly to mobile `master`
immediately, no PR — matching the now-settled project practice.

## Hard rules throughout

- Never test writes against production, in either repo.
- No copy hard-coded in Flutter widgets; ARB en+fr, then `flutter gen-l10n`.
- Don't touch the other mobile worktrees (`-p2a`, `-p2b`, `-p3a`, `-p3b`, `-integration`, `-auth-hardening`)
  or reset/delete anything in either repo without asking.
- Log every deviation from the spec/plan as a **Ruling** (what, why, cost if wrong) in a running note —
  don't deviate silently.
- Write a handoff note per stage in `docs/agent-handoffs/` in the relevant repo, matching the naming and
  depth of the existing ones there.

Start with Stage A's investigation. Stop at Checkpoint 1 and report back before designing further.
