# Start message — Phase 4 (Community) Stage C: mobile Flutter plan

Paste everything below the line into a fresh session opened in `C:\Users\gorok\sentinelx_mobile`.

---

You are writing the mobile Flutter implementation plan for Phase 4 (Community) of the Sentinel X
app. Stages A and B are done — the web API this plan builds against is real, merged, and live in
source (not yet deployed to any database, see below). Your job is Stage C only: produce
`docs/superpowers/plans/2026-09-28-mobile-phase4-community-screens.md`. Do not write Flutter code —
that's Stage D, a separate session.

**Read first, in this order**
1. `CLAUDE.md` and `AGENTS.md` in this repo — they bind you (production-database caution, Riverpod/
   manual-providers rule, ARB-not-hardcoded-copy rule, shared-hotspot-files-append-only rule).
2. `docs/agent-handoffs/2026-09-27-phase4-start-message.md` (this repo) — the original 4-stage
   kickoff. Its Stage C section is your task description; everything below adds detail now that
   Stages A/B are actually done (they weren't when it was written).
3. `docs/superpowers/specs/2026-09-27-mobile-phase4-community-design.md` in the **web** repo
   (`C:\Users\gorok\Videos\sentinelx`, on `main`) — the resolved API spec. Read all of it, not just
   the endpoint list: §6/§7/§9 carry the owner's Checkpoint-1 decisions (report is fully in scope
   this phase, not deferred; mobile gets genuine live-new-post push via `community_posts` joining
   the realtime publication; all staff moderation, including the report review queue, is Phase 8's,
   not this plan's).
4. `docs/agent-handoffs/2026-09-28-mobile-phase4-web-endpoints-notes.md` (this repo) — what actually
   got built in Stage B, including a few real implementation details the spec's prose doesn't cover
   (e.g. `GET /community/posts/{id}/comments` reuses `fetchPostDetail` under the hood and is capped
   at 50 rows with no separate pagination — plan the comments screen accordingly, not against an
   assumed paginated-comments endpoint).
5. The actual committed contract, in the web repo: `lib/mobile-api/endpoints/community-reads.ts` and
   `community-writes.ts` (24 endpoints, real request/response zod schemas — more authoritative than
   the spec's prose for exact field names) and `openapi/mobile-v1.json` on `main`. **This repo's own
   `api/openapi.json` does not have these 24 operationIds yet** — Stage B only touched the web repo.
   Copying the regenerated contract into this repo's `api/openapi.json` and wiring `ApiClient` is
   Stage D's first step (mirroring how `07946e2` did this for the 2a/2b/3a/3b consolidation), not
   yours — but read the real web-side file now so your plan's task descriptions reference the actual
   field names, not guessed ones.
6. Template for both structure and depth:
   `docs/superpowers/plans/2026-09-26-mobile-phase2b-flutter-screens.md` (Global Constraints, Review
   Focus, Coordination, then numbered Tasks). Match its granularity — one Task per screen/flow, each
   with its own test list.
7. Existing realtime precedent in this codebase: `lib/core/notifications/unread_counts.dart` — a
   disposable `client.from(table).stream(primaryKey: [...]).eq(...)` inside a
   `StreamProvider.autoDispose`, one per screen, no shared channel manager. Its own comment notes a
   general-purpose realtime channel manager was deliberately deferred until there are "three real
   consumers to design against" (bell, DMs, feed). Community's feed/post-detail/status realtime
   (§7 of the spec — `post_comments`, `post_reactions`, `player_statuses`, `community_posts`) may be
   exactly that third consumer. Decide explicitly in your plan whether Phase 4 still follows the
   disposable-per-screen pattern (simplest, consistent with precedent) or is the trigger to build the
   shared manager now — **this is a real architectural decision, not a detail**; per the project's
   standing "build fully future-proof, not one-size-fits-all" rule, don't default to copy-pasting the
   disposable pattern four times without at least explicitly weighing the shared-manager option and
   stating why you chose what you chose.

## What your plan must cover

Every screen/flow named in master spec §8.9 and built in Stage B: feed (pinned + paginated, 4-emoji
reactions, weekly-challenges rail, Best-Play-of-the-Week banner, status-rings tray, top members,
upcoming events, gallery), post detail, compose (text + up to 5 images, boost for 200 coins),
statuses/stories (post, view, viewer list — author-only per the spec's RLS note), weekly-challenges
progress (read-only, no submit UI), Best Play voting, report (post and comment — **new in this
phase**, plan the report reason-picker UI against the real `reason_code` enum: `spam`, `harassment`,
`hate_speech`, `nudity_or_sexual_content`, `violence`, `misinformation`, `other`), delete-own (post
and comment). No staff-facing moderation UI anywhere in this plan (Ruling 7 — Phase 8's).

For each: ARB copy (en + fr, identical key sets, added via `tool/gen_l10n_from_web.dart` if the web
repo's `messages/en.json` has a matching namespace already — check before assuming you need to add
one there too), Riverpod provider shape (feature-specific providers beside the feature, per
`CLAUDE.md`), and a full test list per screen — empty state, error state, signed-out behavior (reads
are public per §3, writes require sign-in — plan what a signed-out user sees when they tap react/
comment/report/boost), realtime update handling, boost insufficient-coins state, report submitted/
already-reported state, and anything else this repo's existing Review Focus sections (2b/3a plans)
demonstrate the rigor for.

## Hard rules

- Don't write any Flutter code — Stage D's job, a fresh session, new worktree.
- Log every deviation or judgement call as a **Ruling** in the plan itself (what, why) — the project
  standard by now, see every prior phase's spec/plan.
- Don't touch any existing worktree (`-p2a`, `-p2b`, `-p3a`, `-p3b`, `-integration`,
  `-auth-hardening`, `-regfields` if Codex's is still around) — you're in the primary checkout,
  writing one new markdown file.
- This project's two standing rules apply here too: (1) once this plan is written and you're
  confident in it, commit and push it directly to `origin/master` immediately — no PR, don't leave a
  finished plan sitting uncommitted; (2) don't design a v1/MVP version of anything — every screen's
  plan should be the real, complete, engineered-for-its-purpose design, not a placeholder to revisit
  later.

## When done

Report: the plan's path, a one-paragraph summary of the realtime architecture decision and why, and
anything you flagged as needing the owner's input before Stage D starts (mirroring how Stage A
surfaced its three open questions rather than guessing).
