# Start message — Phase 5b (Direct messages): brainstorm → web spec → web build → mobile plan → mobile build

Paste everything below the line into a fresh session. Web work belongs in the web repo
(`C:\Users\gorok\Videos\sentinelx`, use a worktree off `origin/main`); mobile work belongs in
`C:\Users\gorok\sentinelx_mobile`. If your harness can't work across two repo roots, split at the web →
mobile boundary and hand off with written notes.

---

You are taking **Phase 5b of the Sentinel X Flutter app — Direct messages** from nothing to a merged,
working feature. Unlike 5a, **there is no spec yet**: you start at design. Phase 5 was split by the owner
into **5a Notifications & push (DONE) → 5b Direct messages → 5c Guide quests & support chatbot**. This
message is **5b only**; the guide, chatbot and any new notification types are out of scope.

## Where things stand (verified 2026-10-04)

- Mobile `master` = `origin/master` = `204f928`. `flutter analyze` clean, `flutter test` 965 passing.
  5a (bell at `/notifications`, Settings → Notifications, FCM push, tap routing) is merged and its review
  gaps are closed — see `docs/agent-handoffs/2026-10-03-phase5a-stage-d-handoff.md` including its
  "Follow-up: gaps closed" section.
- **5a has not had its device pass.** Live FCM delivery, the Android 13+ permission dialog, a tap from a
  killed app, and the staging web deployment sending with Firebase project `sentinelx-f061e` are all
  unverified (checklist in `TESTING-NOTES.md`). 5b's DM push and tap routing sit on that same
  infrastructure. If the owner reports a device-pass failure, stop and fix it before building on top.
- The messages bell in the app bar already exists (`bell-messages`, `unreadMessageCountProvider` in
  `lib/core/notifications/unread_counts.dart`) and currently lands on the coming-soon screen. 5b replaces
  that destination. Check what the unread-message count reads today before assuming it is correct.

## Read first

1. Mobile `CLAUDE.md` and `AGENTS.md` — they bind you. A staging database exists: `sentinelx-staging`
   (`ofxmoxpvwbemfouaowoa`) behind the web staging preview. Production is `itxubrkbropttfdackmi`. Never
   test writes against production, in either repo.
2. Mobile master spec `docs/superpowers/specs/2026-09-18-flutter-mobile-app-master-design.md`: **§8.10**
   (Direct messages), **§6.3** (realtime / `RealtimeManager`), **§6.2** (push), the uploads section
   (signed upload URLs, image compression, voice notes), and the DM lines in the phase table. Also
   `docs/superpowers/specs/…-api-v1-conventions.md` in the web repo before adding any endpoint.
3. The web DM implementation, as ground truth (find it, don't assume file names): thread/message tables
   and RLS, `dm_can_message`, block/report/mute, requests, edit/unsend 10-minute windows, read receipts,
   typing/presence, stickers, forward, image and voice-note upload, and how DM push is sent (the
   2026-09-13 push bug fix; **the payload must carry the thread id**).
4. 5a's spec and plan for the pattern: web
   `docs/superpowers/specs/2026-10-03-mobile-phase5a-notifications-push-design.md`, mobile
   `docs/superpowers/plans/2026-10-03-mobile-phase5a-notifications-push-screens.md`. Phase 4's
   (community) kickoff structure is the template for the stages below.
5. Existing mobile code to build on, not around: `lib/core/notifications/push/` (gateway, registration,
   tap router, foreground banner — a foreground DM for the open thread should not banner),
   `lib/core/routing/web_links.dart` (`resolveWebLink`, `tabRootLocations`), `lib/router/app_router.dart`,
   `lib/core/providers.dart` (`viewerIdProvider` — use it for anything viewer-specific),
   `lib/features/notifications/` (paging, optimistic, realtime-refresh patterns already solved once).

## Stage A — Design (brainstorm, then web spec) — owner reviews before anything else

Use `superpowers:brainstorming`. Produce the design spec in the web repo
(`docs/superpowers/specs/2026-10-0X-mobile-phase5b-direct-messages-design.md`): ground-truth table of what
the web does today, every ruling with cost-if-wrong, the endpoint table (all writes via `/api/mobile/v1`;
the master spec allows direct RLS reads + realtime for threads/messages, confirm that is still right),
DM push changes (platform partition, channel, thread id in `data`, mute interaction), realtime and
reconnect rules, upload flow, the test list, open items. Decide scope honestly — voice notes, stickers,
forward, typing/presence and message requests are all in the master spec; if you propose staging any of
them across sub-phases, say why. **Checkpoint 0 — stop and wait for the owner to approve the spec.** No
plan and no code before that.

## Stage B — Web plan and build (web repo, separate worktree)

After approval: `superpowers:writing-plans` → TDD numbered tasks → build → full verification (typecheck,
lint, test, build) → **fresh-context review**, fix, re-verify. No schema change unless the spec rules one
in; if you find one is needed, stop and ask. **Checkpoint 1:** report, then after the owner confirms merge
and push to web `main` (no PR) and confirm the staging preview picks it up.

## Stage C — Mobile plan (mobile repo, after Stage B is on web `main`)

Copy the regenerated `openapi/mobile-v1.json` over `api/openapi.json` (copy, never hand-edit). Write
`docs/superpowers/plans/2026-10-0X-mobile-phase5b-direct-messages-screens.md` in the Phase 4/5a plan
structure: models and `ApiClient` methods (each in `usedOperations`), inbox, conversation, composer,
block/report/mute, requests, profile entry point, `/messages` routes plus `resolveWebLink` mapping, DM push
tap routing, ARB en + fr with identical keys and ICU plurals, per-screen test list. Resolve open items
**with evidence** at the exact versions you pin (audio recording and playback packages, permissions).

## Stage D — Mobile build (mobile repo)

New worktree off current `master`: `git worktree add ..\sentinelx_mobile-p5b -b phase5b/screens`. **Copy
`android\app\google-services.json` from the main checkout into the worktree** (untracked; worktrees don't
get it) and keep the no-file path building (`flutter build apk --debug` with it moved aside). Strict TDD,
`flutter analyze` and `flutter test` clean before every commit, and run
`git checkout -- linux macos windows` after `flutter pub get`/`flutter test` and before committing
(they regenerate those files with line-ending noise). Shared hotspot files (`api_client.dart`,
`app_router.dart`, `web_links.dart`, ARB + generated l10n) get minimal append-only hunks. Fresh-context
review, fix, re-verify. **Final checkpoint:** branch + HEAD, test counts, review findings and fixes, every
Ruling, deferred items, what is **not** verified (two-device DM behaviour, voice recording on a real
device, push in all three app states). Then merge to `master` and push immediately, no PR, only after
review and green.

## Lessons — each bit us in Phases 4 and 5a

1. **Viewer-specific reads need the bearer token.** `publicRequest: true` strips it. Test per authenticated
   read that the `Authorization` header is present; fakes can't catch it.
2. **`StreamProvider<void>` notifies once.** Realtime providers emit distinct values (a counter). Test two
   consecutive events.
3. **Caller-specific providers watch `viewerIdProvider`** (user id, not token). Test with a *real*
   refreshed `Session` (different access token, same user) — equal fixture sessions hide the bug.
4. **Optimistic rollback reverts only your own change** and, per key, only if no later change to that key
   happened. Never use a disposed widget's `ref`/`context` after an `await`; make notifier mutators no-ops
   when unmounted. Optimistic send + retry must not duplicate a message on a flaky network (idempotency
   key).
5. **Background/realtime refresh must not reset pagination or race a manual action or `loadMore`.** Re-read
   the loaded window in place; queue a refresh that arrives mid-load; keep an event that lands during the
   first page load. Reconnect always refetches (never assume no gap).
6. **Tolerant parsing:** an unknown message kind or notification type from a newer server must degrade,
   never fail the whole list.
7. **Serialize anything where order matters** (send/edit/unsend/read-receipt on one thread; device
   register/unregister was a real race in 5a).
8. **Plurals:** ICU plural in en and fr from the start.
9. **A link-resolution function used as a router redirect runs on every location.** A new `/messages`
   mapping must not swallow an in-app path; add tests.
10. **Tab roots are `go`, deeper screens `push`** (`tabRootLocations`): a pushed tab page has no Back.
11. **Windows encoding:** never edit source with bare Python `open().read()/write()`; use the Edit/Write
    tools or `encoding='utf-8', newline=''`. Analyzer "URI doesn't exist" for files that exist means
    corrupted UTF-8, not a stale cache.
12. **Verify a reviewer's claim before acting**, and make sure a new test can actually fail (a vacuous
    test passed review once in 5a).

## Hard rules throughout

- Never test writes against production; staging needs `--dart-define` of `SUPABASE_URL`,
  `SUPABASE_PUBLISHABLE_KEY`, `API_BASE_URL`. Don't commit keys.
- No copy hard-coded in widgets: ARB en + fr, then `flutter gen-l10n`; commit the generated output.
- All writes and TypeScript-computed reads go through `/api/mobile/v1`; never write via PostgREST.
- Don't delete or reset anything in either repo without asking. Don't push the web checkout at
  `C:\Users\gorok\Videos\sentinelx` directly — use a worktree.
- Log every deviation from the spec or plan as a **Ruling** (what, why, cost if wrong).
- Write a dated handoff note per stage in the relevant repo's `docs/agent-handoffs/`; separate verified
  facts from recommendations; record verification limits and whether code changed.
- `feat/profile-onboarding` (worktree `..\sentinelx_mobile-profile-onboarding`) is a separate, unmerged
  feature, 27 commits behind `origin/master`. Don't touch it.
