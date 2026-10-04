# Start message — Phase 5b Stage C (mobile plan for Direct messages)

Paste everything below the line into a fresh session in `C:\Users\gorok\sentinelx_mobile`. This is **Stage C only**: write the
mobile implementation plan. No Flutter feature code in this stage. Stage D (the build) is a separate session after the owner
reviews the plan.

---

You are taking **Phase 5b Stage C — the mobile plan for Direct messages** of the Sentinel X Flutter app. Stages A and B (design
and the web build) are **done, merged and live**. Your job: copy the new API contract, resolve the open technical items **with
evidence**, and write the plan the next session will execute. Stop at the plan for owner review.

## Where things stand (verified 2026-10-05)

- **Web** (`github.com/Rex-Orokumue/sentinelx`, `main` = `da3ab5c`, deployed to production by Vercel): the DM API, typing and
  message requests are merged. Both migrations are applied to **staging** (`ofxmoxpvwbemfouaowoa`) **and production**
  (`itxubrkbropttfdackmi`). The web checkout is at `C:\Users\gorok\Videos\sentinelx` (dirty/behind: do not use it); the work
  lives in the worktree `C:\Users\gorok\Videos\sentinelx-p5b-spec`.
- **Mobile**: `master` = `origin/master` = `8cc0056` (`flutter analyze` clean, `flutter test` 965 passing at `204f928`).
  5a (bell, Settings → Notifications, FCM push, tap routing) is merged but **has not had its device pass**
  (`TESTING-NOTES.md` checklist). If the owner reports a 5a failure, stop and fix it before building on it.
- Still unverified on the web side: the cap under truly simultaneous sends, PostgREST error-message mapping over real HTTP, the
  web UI in a browser, two-client typing. Plan the mobile tests so they do not depend on those being proven.

## Read first (in this order)

1. Mobile `CLAUDE.md` and `AGENTS.md` (they bind you).
2. `docs/agent-handoffs/2026-10-04-phase5b-start-message.md`: its **Lessons (1–12)** and **Hard rules** still apply in full.
   Where it says "no spec yet" or lists web ground truth, this message and the web spec supersede it.
3. **The binding spec** (web repo): `docs/superpowers/specs/2026-10-04-mobile-phase5b-direct-messages-design.md`, and the
   handoff `docs/agent-handoffs/2026-10-05-phase5b-stage-b-web-handoff.md` (verified vs not verified, rulings). Read them from
   `C:\Users\gorok\Videos\sentinelx-p5b-spec\` (or `git show origin/main:<path>` in any web clone after `git fetch`).
4. The web plan for how the endpoints are built:
   `docs/superpowers/plans/2026-10-04-mobile-phase5b-direct-messages-web.md`.
5. Mobile master spec §8.10, §6.3 (realtime), §6.5 (media), and the Phase 4 / 5a plans as the **plan template**:
   `docs/superpowers/plans/2026-10-03-mobile-phase5a-notifications-push-screens.md`.
6. Existing code to build on, not around: `lib/core/notifications/push/` (gateway, registration, tap router, foreground banner),
   `lib/core/notifications/unread_counts.dart` (the messages bell counts unread `direct_message` rows in
   `player_notifications`), `lib/core/routing/web_links.dart` (`resolveWebLink`, `tabRootLocations`), `lib/router/app_router.dart`,
   `lib/core/providers.dart` (`viewerIdProvider`), `lib/features/notifications/` (paging, optimistic, realtime-refresh patterns),
   `lib/features/community/community_image_uploader.dart` (direct-to-storage upload precedent), `lib/features/players/`
   (profile screen: where the Message button goes).

## Step 1: take the contract

Copy the regenerated `openapi/mobile-v1.json` from web `main` over `api/openapi.json` **(copy, never hand-edit)**, e.g.
`git -C C:\Users\gorok\Videos\sentinelx-p5b-spec show origin/main:openapi/mobile-v1.json > api\openapi.json` after `git fetch`.
Confirm the new operations are present, then follow the repo's existing `usedOperations` convention (each `ApiClient` method must be
listed). Commit the copy on its own.

## What Stage B actually shipped (the contract the plan must target)

All under `/api/mobile/v1`, bearer auth, envelope `{data}` / `{error:{code,message,fields?}}`. Sends and forwards require an
`Idempotency-Key` header (400 `idempotency_key_required` without it; a retry with the same key replays the first result).

| operationId | Method + path | Body | Response `data` |
|---|---|---|---|
| `getMessageThreads` | `GET /messages/threads?cursor&box=inbox\|requests` | — | `{threads:[{threadId, other:{id,name,username,avatarUrl}, preview:{kind,text,stickerId}, lastMessageAt, unread, requestState, direction}], nextCursor, requestCount}` (page 20) |
| `getMessageThread` | `GET /messages/threads/{id}` | — | `{threadId, other, blockedByMe, blockedByThem, requestState, direction}` (404 if not a participant) |
| `getThreadMessages` | `GET /messages/threads/{id}/messages?before` | — | `{messages:[…], nextBefore}` newest first, page 40, media already signed |
| `startMessageThread` | `POST /messages/threads` | `{recipientId}` | `{threadId, requestState}` (get-or-create) |
| `sendMessage` | `POST /messages/threads/{id}/messages` (**idempotent**) | `{body?, imagePath?, stickerId?, audioPath?, audioDurationSeconds?, replyToId?}` | `{messageId, createdAt}` |
| `editMessage` | `PATCH /messages/{id}` | `{body}` | `{ok}` (10-minute window) |
| `unsendMessage` | `DELETE /messages/{id}` | — | `{ok}` (10-minute window) |
| `forwardMessage` | `POST /messages/{id}/forward` (**idempotent**) | `{toThreadId}` | `{messageId}` |
| `markThreadRead` | `POST /messages/threads/{id}/read` | — | `{ok}` (best-effort, stamps read+delivered, clears the thread's bell rows) |
| `markAllDelivered` | `POST /messages/delivered` | — | `{ok}` (best-effort) |
| `blockPlayer` / `unblockPlayer` | `PUT` / `DELETE /messages/blocks/{playerId}` | — | `{ok}` (block also severs follows) |
| `reportThread` | `POST /messages/threads/{id}/report` | `{messageId?, reason}` (1–1000 chars) | `{ok}` |
| `acceptMessageRequest` / `declineMessageRequest` | `POST /messages/threads/{id}/accept` / `/decline` | — | `{ok}` |

A message: `{id, senderId, body, imageUrl, stickerId, audioUrl, audioDurationSeconds, forwarded, createdAt, deliveredAt, readAt,
editedAt, deletedAt, replyTo:{id,senderName,body,removed}|null}`. An unsent message arrives with all content `null` and
`deletedAt` set. `preview.kind` and `requestState` are **plain strings on the wire: an unknown value from a newer server must
degrade, never fail the list.** Failure codes (HTTP): `not_found` 404, `validation` 400, `blocked_by_me` 403, `blocked` 403,
`messaging_restricted` 403, `edit_window_closed` 409, `not_forwardable` 409, `request_pending_limit` 409,
`request_media_not_allowed` 400, `send_failed` 500, `action_failed` 500, `invalid_cursor` 400. The `message` is the exact English
string the web shows; map codes to ARB copy (en + fr), do not display server text.

### Rules the UI must implement

- **Message requests.** A new thread starts `pending` unless the sender is staff or an accepted friend. While pending the initiator
  may send **one text-only message** (no photo, sticker, voice). Any message from the other player, or Accept, makes it
  `accepted`. Decline hides the thread from the recipient. `direction` is `incoming` / `outgoing` only while pending, else null.
  - `box=inbox` = accepted threads + the viewer's own pending requests; `box=requests` = incoming pending; `requestCount` is the
    incoming-pending count (cap 100, blocked excluded).
  - Incoming request view is **preview-only** with Accept / Decline / Block-and-report; opening it stamps no receipts.
  - Outgoing pending: text-only composer, disabled after the first message ("Waiting for X to accept"). **While an outgoing-pending
    thread is open and visible, poll `getMessageThread` every 20–30 s** (nothing polls otherwise); refetch on resume covers the rest.
  - **A decline is indistinguishable from a block to the sender**: they get `blockedByThem: true`, the thread leaves their inbox,
    sends fail with `blocked`. Do not surface "declined" anywhere for the sender.
  - A pending message writes a bell row but **no push** until accepted.
- **Edit / unsend** only on your own messages within 10 minutes of `createdAt`; disable the controls after, server enforces 409.
- **Receipts.** Ticks: sent / delivered / read from `deliveredAt` / `readAt`. Call `markThreadRead` when a thread is open and
  visible, and `markAllDelivered` on resume.
- **Typing** (new on both platforms): private Realtime **broadcast** channel `dm-typing:<threadId>`, event `typing`, payload
  `{userId}`, `broadcast.self=false`, `private=true`. Send at most one event per 3 s while composing; show "typing…" for 5 s after
  the last event from the *other* user. **No typing in a pending thread and none when blocked.** Never use the site-wide
  `dm-online` presence channel for typing. (`dm-online` stays the online-dot source: presence key = user id, topic `dm-online`.)
- **Block / unblock / report**, **forward** (sheet of the viewer's inbox threads), **reply** (`replyToId` must be in the same thread).
- **Stickers** are a fixed bundled pack (14 ids) validated server-side: `gg, fire, trophy, rage, ez, clutch, lol, ggwp, sad, clap,
  rocket, skull, eyes, goat`. Bundle them with a test that fails if the id set drifts from the web's `STICKER_PACK`
  (`lib/messages/stickers.ts` in the web repo). Unknown sticker id from a newer server → a placeholder bubble.
- **Uploads go directly to private Supabase buckets `dm-images` / `dm-audio`, path `<yourUserId>/<uuid>.<ext>`** (storage RLS allows
  only your own folder); there is **no** `/uploads/sign`. Send the path as `imagePath` / `audioPath`; **the server rejects any path
  not under your own user id (400 `validation`, "Invalid attachment.")**. Images: compress on device (long edge ≤ 1600 px, JPEG,
  strip EXIF). Voice: AAC/m4a, hard cap **120 s** (server accepts ≤ 130), pause-and-review before sending. Media URLs in messages are
  signed for ~1 h: refetch the window on resume, never cache them as permanent.
- **Push**: DM payload `data` is `{url:'/messages/<threadId>', type:'direct_message', threadId}`, Android channel `messages_v1`
  (5a). Tap → `/messages/<threadId>` pushed over the current tab. A foreground DM for the **open** thread shows no banner.

## Step 2: resolve open items with evidence (at the exact versions you pin)

- Audio **recording** and **playback** packages for Flutter on Android first (iOS later): candidates and decision with the pub.dev
  version, maintenance status, `minSdk`/Gradle impact on this project, and a smoke check that it resolves with the current
  `pubspec.lock` (`flutter pub get`, `flutter analyze`). Include m4a/AAC encoding at the needed bitrate/size, background/interruption
  behaviour, and what happens on permission denial.
- **Permissions**: `RECORD_AUDIO` (and anything else) in the Android manifest, the runtime-permission flow, a denial/"don't ask again"
  UX, and what `image_picker` already covers for photos.
- A shared realtime helper in `lib/core/realtime/` replacing per-screen subscriptions (5a said it would be revisited in 5b): one
  place for subscribe-when-visible, unsubscribe-on-dispose, resubscribe on resume/connectivity, **refetch on reconnect**, emitting a
  **counter** so consecutive events are not swallowed. Consumers: bell, inbox, thread, online presence, typing. Design it from the
  existing code, do not rewrite 5a's working pieces.
- Realtime stays a **nudge**: `postgres_changes` on `dm_messages` only triggers a refetch of the loaded window **in place**
  (also covers edit/unsend/receipt UPDATEs); media is never taken from the payload (it carries raw storage paths).

## Step 3: write the plan

`docs/superpowers/plans/2026-10-0X-mobile-phase5b-direct-messages-screens.md`, in the Phase 4 / 5a plan structure and the
`superpowers:writing-plans` format (header, Global Constraints, Review Focus, numbered TDD tasks with exact files, interfaces, tests
and commits). It must cover: models and tolerant parsing; each `ApiClient` method (each in `usedOperations`); the realtime helper;
inbox (paging, realtime refetch in place, Requests entry with count); conversation (window + paging up, optimistic send with an
idempotency key and retry that never duplicates, per-thread serialization of send/edit/unsend/read, receipts, reply, edit/unsend
window, forward, stickers, photo, voice, typing, presence dot); request view and the outgoing-pending poll; block/report/unblock;
profile entry point (`startMessageThread` then push `/messages/<id>`) and replacing the messages-bell destination;
`/messages` and `/messages/:threadId` routes + `resolveWebLink` mapping (must not swallow in-app paths; add tests); DM push tap
routing and foreground-banner suppression for the open thread; ARB en + fr with identical keys and ICU plurals; and a per-screen
test list. Put the 12 lessons from the 5b start message into the tasks as concrete tests (bearer header on every authenticated
read; realtime counter emits twice; `viewerIdProvider` with a *real* refreshed `Session`; optimistic rollback scope and unmounted
no-ops; refresh must not reset paging or race `loadMore`; tolerant parsing; serialization; plurals; redirect non-swallowing; tab
roots `go` vs pushed screens; Windows encoding; tests that can actually fail).

Order the tasks so core DM (inbox, conversation, text/photo/sticker, receipts) lands first, then requests, then typing, then voice
notes last (highest uncertainty). End with the Stage D handoff (worktree
`git worktree add ..\sentinelx_mobile-p5b -b phase5b/screens`, copy `android\app\google-services.json` into it, keep the no-file
build working, `git checkout -- linux macos windows` before commits).

## Hard rules (unchanged)

- Never test writes against production. Staging needs `--dart-define` of `SUPABASE_URL`, `SUPABASE_PUBLISHABLE_KEY`,
  `API_BASE_URL`; don't commit keys. Staging has test users only under the `zzqa_` prefix convention.
- No copy hard-coded in widgets: ARB en + fr, `flutter gen-l10n`, commit generated output.
- All writes and TypeScript-computed reads go through `/api/mobile/v1`; never write via PostgREST; direct RLS reads are not used
  for DMs (the API serves them).
- Log every deviation from the spec as a **Ruling** (what, why, cost if wrong). Don't delete or reset anything without asking.
- `feat/profile-onboarding` (worktree `..\sentinelx_mobile-profile-onboarding`) is separate and unmerged: don't touch it.

## Deliverable and stop

The plan file (committed and pushed to mobile `master`, docs only) plus a short note listing: the packages chosen with their
evidence, every Ruling, and what could **not** be verified. Then **stop and ask the owner to review the plan and choose an
execution method** (subagent-driven or native). Do not start Stage D.
