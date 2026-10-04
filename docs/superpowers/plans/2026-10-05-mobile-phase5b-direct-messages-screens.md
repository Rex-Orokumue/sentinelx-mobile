# Mobile Phase 5b (Flutter) — Direct messages Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. Strict TDD: failing test first, watch it fail for the right reason, minimal code, green, commit.

**Goal:** Full-parity direct messages in the Android app: inbox, conversation (text, photo, sticker, voice note, reply, edit/unsend in the 10-minute window, forward, delivered/read ticks), online dot, typing indicator, message requests, block/unblock/report, start-from-profile, and DM push tap routing — backed by the 15 `/api/mobile/v1/messages/**` operations web Stage B shipped to `sentinelx` `main` (`708060f`, migrations live on staging **and** production).

**Architecture:** Every viewer-specific read and every write goes through `ApiClient` (never PostgREST). Realtime is only a **nudge**: `dm_messages` `postgres_changes` triggers an in-place refetch of the loaded window through the API; media URLs and content are never taken from a realtime payload. One new shared realtime layer, `lib/core/realtime/` (a hub over a testable channel port), replaces per-screen subscriptions for the bell, inbox, thread, presence and typing. Feature code lives in `lib/features/messages/`; the three-layer split matches 5a (models in `lib/core/api/`, repository interface + fake, providers, screens). Conversation state is one `AsyncNotifier` per thread holding the server window plus a list of *pending* (optimistic) outgoing items; all mutations on a thread run through one per-thread serial queue.

**Tech Stack:** Flutter 3.41.9 (stable), Dart ^3.11, `flutter_riverpod` ^3.3 (manual providers), `go_router` ^17, `dio`, `supabase_flutter` 2.17.2 (`realtime_client` 2.13.0), `image_picker` 1.2.3. **New dependencies, resolved and build-checked on 2026-10-05 (see Rulings 1–3):** `record ^6.2.1` (resolves to 6.2.1 / `record_android` 1.5.2), `just_audio ^0.10.6` (0.10.6, pulls `audio_session` 0.2.4), `image ^4.10.1` (pure Dart). **Rejected:** `permission_handler` (breaks the Android build on this project's AGP 8.11.1), `flutter_image_compress`, `audioplayers`, `flutter_sound`.

**Spec:** web repo (read with `git -C C:\Users\gorok\Videos\sentinelx show origin/main:<path>`): `docs/superpowers/specs/2026-10-04-mobile-phase5b-direct-messages-design.md` (binding), `docs/agent-handoffs/2026-10-05-phase5b-stage-b-web-handoff.md` (verified / not verified, Rulings), `docs/superpowers/plans/2026-10-04-mobile-phase5b-direct-messages-web.md`. Mobile master spec §8.10, §6.3, §6.5. **Read this repo's `CLAUDE.md` and `AGENTS.md` first.** Lessons 1–12 and Hard rules from `docs/agent-handoffs/2026-10-04-phase5b-start-message.md` apply in full; each is a concrete test below (see the Lesson map at the end). Structure template: `docs/superpowers/plans/2026-10-03-mobile-phase5a-notifications-push-screens.md`.

## Global Constraints

- **Never test writes against production** (`itxubrkbropttfdackmi`). All unit/widget tests use fakes or a `_FakeAdapter`; live work is the owner's device pass on staging (`sentinelx-staging`, `ofxmoxpvwbemfouaowoa`) via `--dart-define` of `SUPABASE_URL`, `SUPABASE_PUBLISHABLE_KEY`, `API_BASE_URL`. Staging test users use the `zzqa_` prefix. Do not commit keys.
- **All writes and all viewer-specific reads go through `/api/mobile/v1`** (`ApiClient`). The only direct Supabase use in this phase is **Realtime** (`dm_messages` change nudges, `player_notifications`, `dm-online` presence, `dm-typing:<id>` broadcast) and **Storage uploads** to `dm-images` / `dm-audio` (precedent: `community_image_uploader.dart`). Never read `profiles`, `dm_threads` or `dm_messages` through PostgREST.
- **Every new `ApiClient` method is listed in `ApiClient.usedOperations`**; `test/core/api_contract_test.dart` checks each against `api/openapi.json`, the **copy** of web `openapi/mobile-v1.json` already committed (`f635bb4`, never hand-edited). New models go in new files, not `models.dart`.
- **Every authenticated read sends the bearer token** (no `publicRequest: true` on any messages call). One test per read method asserts the `Authorization` header (Lesson 1).
- **Idempotency:** `sendMessage` and `forwardMessage` require an `Idempotency-Key` header (400 `idempotency_key_required` otherwise); a retry with the same key replays the first result. Keys come from `newIdempotencyKey()` (`lib/core/utils/idempotency_key.dart`), generated **once per compose action** and reused for every retry of that action.
- **Server error text is never shown.** Map `ApiException.code` to ARB copy (`dmErrorCopy`). Codes: `not_found`(404) `validation`(400) `blocked_by_me`(403) `blocked`(403) `messaging_restricted`(403) `edit_window_closed`(409) `not_forwardable`(409) `request_pending_limit`(409) `request_media_not_allowed`(400) `send_failed`(500) `action_failed`(500) `invalid_cursor`(400) `idempotency_key_required`(400); anything else -> generic copy. Statuses are **not** reliable: the pinned contract documents only 200/400/401/403/426/500 for these operations although the server also returns 404/409 (Ruling 7), so branch on `code`, never on `status`.
- **Wire tolerance:** `preview.kind`, `requestState`, `direction` are plain strings on the wire; an unknown value must degrade (never throw, never drop the list). A malformed row is skipped, not fatal.
- **Uploads:** private buckets `dm-images` / `dm-audio`, path `<yourUserId>/<uuid>.<ext>` (storage RLS: first segment must equal `auth.uid()`; the server rejects any other prefix with 400 `validation`). The buckets set **no** size or mime limit, so the client enforces them. Images: long edge <= 1600 px, JPEG, EXIF/GPS stripped. Voice: AAC-LC `.m4a`, hard cap **120 s** (server accepts <= 130), pause-and-review before sending. Media URLs in messages are signed for ~1 h: never cache them as permanent; refetch the window on resume.
- **Typing:** private broadcast channel `dm-typing:<threadId>`, event `typing`, payload `{userId}`, `self=false`, `private=true`; send at most one event per 3 s while composing; show "typing" for 5 s after the last event from the **other** user; none in a pending thread, none when blocked. Never use `dm-online` for typing. `dm-online` (presence key = user id, topic `dm-online`, `private=true`) stays the online-dot source.
- **Stickers** are a bundled fixed pack of 14 ids (`gg, fire, trophy, rage, ez, clutch, lol, ggwp, sad, clap, rocket, skull, eyes, goat`) with a parity test. An unknown sticker id from a newer server renders a placeholder bubble.
- **Copy never hard-coded in widgets:** `lib/core/l10n/app_en.arb` **and** `app_fr.arb` (identical key sets, enforced by `test/core/l10n_test.dart`), then `flutter gen-l10n`, commit generated output. Key prefix `dm`. Counts use ICU plurals in en **and** fr from the start (`dmUnreadCount`, `dmRequestsCount`, `dmVoiceSeconds`).
- **Navigation:** tab roots are `go`, everything deeper is `push` (`tabRootLocations`). `/messages`, `/messages/requests`, `/messages/:threadId` are pushed screens outside the shell.
- Mobile-first at 375 px; `SxColors` only; American spelling in code/prose.
- **Before every commit:** `flutter analyze` (no issues) and `flutter test` (all pass; baseline 965 at `204f928`, re-measured in Task 0), then `git checkout -- linux macos windows`. Never edit source with bare Python `open().read()/write()` (cp1252 corrupts UTF-8; use Edit/Write; analyzer "URI doesn't exist" for an existing file means corrupted UTF-8). Do not chain `git push` onto a piped test command.
- Hotspot files get **append-only minimal hunks**: `lib/core/api/api_client.dart`, `lib/router/app_router.dart`, `lib/core/routing/web_links.dart`, ARB + generated l10n, `lib/shared/widgets/sx_tab_app_bar.dart`, `lib/features/players/player_profile_screen.dart`, `lib/core/notifications/push/*`, `android/app/src/main/AndroidManifest.xml`.

## Rulings (decisions this plan makes; cost if wrong)

1. **No `permission_handler`; microphone permission via `record`.** Evidence (2026-10-05): a real `flutter build apk --debug` of this project plus `permission_handler 13.0.2` **fails** — `permission_handler_android 14.1.0`'s `build.gradle.kts` hard-codes AGP 9.0.1 / Kotlin 2.3.20, uses `kotlin { compilerOptions }` without applying the Kotlin plugin (unlike `audio_session`, which guards on `agpMajor < 9`), and declares `compileSdk = 37`; this project is AGP 8.11.1 / Gradle 8.14 / Kotlin 2.2.20 / SDK 36.1. Upgrading the toolchain is out of scope. `record.hasPermission(request: true)` shows the OS dialog; `hasPermission(request: false)` reads without asking; `app_settings` (already a dependency) opens system settings. *Cost if wrong:* "denied once" and "denied permanently" cannot be told apart, so the denial UI always offers **both** "Try again" and "Open settings" (no heuristic on timing). Revisit when the project moves to AGP 9.
2. **`record` pinned at 6.2.1, not 7.1.1.** 7.1.1 (published 2026-06-29) requires Dart ^3.12 / Flutter >= 3.44; the installed toolchain is Flutter 3.41.9 / Dart 3.11.5 and `flutter pub add record` resolves 6.2.1. `record_android` 1.5.2 `minSdk 23`, `just_audio` `minSdk 16`, `audio_session` `minSdk 24`; Flutter's default `minSdkVersion` is 24, so **no `minSdk` change**. `record_android` itself declares `RECORD_AUDIO`; the app manifest also declares it explicitly. On audio-focus loss (phone call, another app) `record_android` pauses the recorder (`AudioRecorder.kt` `requestAudioFocus`); the UI treats a paused recording like a user pause and does **not** auto-resume. *Cost if wrong:* a 6.x -> 7.x migration later; the recorder sits behind `VoiceRecorderPort`.
3. **Photos: native downscale by `image_picker`, then a pure-Dart sanitize with `image` 4.10.1 that re-encodes JPEG with an empty `ExifData`.** Evidence: `image_picker_android 0.8.13+17`'s `ExifDataCopier` **copies EXIF back into the resized file, including every `TAG_GPS_*`** — so `maxWidth`/`imageQuality` alone do **not** satisfy "strip EXIF" (the spec rule; many players are minors). A scratch test proved: (a) a JPEG with a GPS + Make tag keeps both after a plain decode/encode, (b) both are gone after `im.exif = ExifData()` (the test fails if that line is removed — mutation-checked), (c) 3000x2000 -> 1600x1067, 1200x4000 -> 480x1600, PNG input -> JPEG, non-image input throws. `flutter_image_compress` was rejected: its `minWidth/minHeight` mean "scale down until the result is at least this size", not "long edge <=", and native output cannot be asserted in `flutter test`. *Cost if wrong:* ~0.3-1 s CPU per photo (decode of an already <=1600 px image, run in `compute`); no native dependency. **Side finding for the owner (out of scope here):** `PluginMultiImagePicker` (community posts, **public** bucket) and the evidence uploader rely on `image_picker` resizing alone and therefore publish GPS EXIF; the same `sanitizeJpeg` should be applied there in a separate fix.
4. **Realtime hub over a channel port, lifecycle-aware.** `lib/core/realtime/` owns channel creation behind `RealtimeChannelPort` so tests drive events/statuses without a socket. Every consumer receives `Stream<RealtimeSignal>` with a **monotonic `seq`** (Lesson 2) and a `kind`: `event`, `reconnected` (any `subscribed` status after the first, or after a re-created channel), `resumed` (app lifecycle `resumed`). All consumers refetch on `reconnected`/`resumed` and on `event`. On `paused`/`hidden` the hub removes its channels (frees Realtime connections, makes presence leave promptly); on `resumed` it re-creates them and emits `resumed`. Retry after `channelError`/`timedOut`/`closed` uses 2 s, 4 s, 8 s ... capped at 30 s, reset on success. *Cost if wrong:* whether `realtime_client` re-fires `subscribed` on its own rejoin is **unverified**; the explicit `resumed` signal plus the hub's own re-subscribe on error cover it, and device pass item 6 checks it.
5. **Requests live at `/messages/requests` (a path), not `?box=requests`.** `resolveWebLink` ignores query strings, so a query-based route would be redirected away and lose the box. A non-UUID second segment under `/messages` passes through `resolveWebLink` untouched when it has no authority (same rule as `/community/compose`); an external `https://…/messages/<garbage>` falls back to `/messages`. *Cost if wrong:* none beyond one extra route; the inbox just offers a "Message requests (n)" row that pushes it.
6. **Push navigation: stack over the current tab, never replace it.** `pushNavigatorProvider` today calls `go`, which would make a DM tap replace the stack (no Back). It becomes: tab roots and `/` -> `go`; anything else -> `push`, **except** when the router's current location already equals the destination (no duplicate page). The bell's unmapped-link fallback (`/notifications`) therefore also pushes. A DM tap routes from the payload `threadId` (`data.type == 'direct_message'`) to `/messages/<id>` and falls back to the `url` resolution only when `threadId` is absent. *Cost if wrong:* changed Back behavior for the 5a fallback; covered by tests.
7. **Contract gap, logged for the web repo:** the OpenAPI response lists for these operations omit 404 and 409 (the web handoff and start message list `not_found`, `edit_window_closed`, `not_forwardable`, `request_pending_limit`). Mobile maps by `code`. Not worked around beyond that; the next contract regeneration should add them.
8. **Edit/unsend window uses the device clock to *offer* the controls and the server to *decide*.** Controls are shown only when `now - createdAt < 10 min` at menu-open time; a 409 `edit_window_closed` is authoritative: the controls disappear and the player sees copy. *Cost if wrong:* a skewed device clock shows a control that the server refuses once.
9. **Unsent pending bubbles and drafts are in memory only.** A process kill loses a message that never reached the server. The text draft survives a screen pop (kept per thread in a provider) but not a kill. *Cost if wrong:* a lost unsent message after a kill; persisting an outbox is deferred.
10. **Online presence is app-wide while the app is resumed** (matches the web's "has a tab open"), tracked by a hub-owned `dm-online` channel mounted by the DM screens and the app bar, not only the thread screen. *Cost if wrong:* one extra Realtime connection per foregrounded signed-in player (the web already does this); if the free-plan quota bites, restrict to DM screens by changing one provider.
11. **`markAllDelivered`:** on app resume and on a realtime nudge that brings a new incoming message into the inbox or an open thread, throttled to at most one call per 15 s. Never called while only pending incoming requests exist for the nudge (the server skips them anyway). *Cost if wrong:* a short delay before the sender sees two ticks.
12. **No Android App Link intent filter for `/messages` in 5b.** DM links reach the app through push `data`, not browser URLs; adding a verified `pathPrefix` is the owner's call. `resolveWebLink` still maps web `/messages` paths for any caller (bell rows, e-mail links opened inside the app).
13. **Stickers bundled with a drift check that runs when the pack is synced,** not on every CI run, because CI cannot see the web repo: `tool/sync_stickers.dart` reads the web file and rewrites `test/fixtures/web_sticker_pack.json`; the unit test asserts the bundled pack equals that fixture. *Cost if wrong:* a web-side pack change goes unnoticed until someone re-runs the tool; the server rejecting an unknown id then surfaces as `validation` copy.

## Review Focus

Failure modes the spec implies that the happy-path tests would not catch, most likely first. Each has a test in the owning task.

1. **A retry after an ambiguous failure must not duplicate a bubble** (request timed out after the server committed; app foregrounded twice; double tap on Retry): one key per compose action, pending item reconciled by key, a second tap on Send/Retry while in flight is a no-op. (Tasks 7, 8)
2. **A gap in the window:** resume after a long background, a reconnect, or more than a page (40) of new messages while away must not leave a hole or reset the scroll position/paging; unsend/edit/receipt UPDATEs that arrive as nudges must be reflected in place. (Tasks 5, 7)
3. **Content the app does not know:** an unsent message (all content null, `deletedAt` set), an unknown sticker id, an unknown `preview.kind`/`requestState`/`direction`, a reply to a removed message, a thread whose other player has no username/avatar. None may throw; each has a defined rendering. (Tasks 1, 5, 8, 9)
4. **Expired signed media (~1 h):** an image or voice URL that 403s must trigger **one** rate-limited window refetch (not a loop), and resume refetches. (Tasks 7, 10, 17)
5. **A decline or block must look identical to the sender, and an incoming request must stamp nothing:** the sender never sees "declined"; `blockedByThem` and a declined request show the same copy; opening an incoming pending request never calls `markThreadRead`, and no typing is sent/shown while pending or blocked; the outgoing-pending poll runs only while that thread is open and visible. (Task 13)

## Coordination

- **Base `master`; new worktree** `git worktree add ..\sentinelx_mobile-p5b -b phase5b/screens`. Copy `android\app\google-services.json` from the main checkout into it (untracked by design; `git status` must not list it) and keep the no-file build working (`flutter build apk --debug` both ways, Task 12 and Task 18). Do not touch `feat/profile-onboarding` (`..\sentinelx_mobile-profile-onboarding`).
- Another session may be working on `master` docs; `git pull --rebase` before the final merge, never force-push.

## Deferred / known gaps (record in the report, do not build)

- Per-thread mute (web has none), message search, group chats, reactions, GIFs, link previews, drafts surviving process death (Ruling 9), a persistent outbox, voice-note waveforms, sticker store, a "Declined" box for the recipient, iOS (Phase 10: `record`/`just_audio` are cross-platform, the iOS `NSMicrophoneUsageDescription` and `UIBackgroundModes` are not added now).
- Applying the sanitize step to community/evidence uploads (Ruling 3 side finding).
- The fixture-exemption for non-friend opponents (web `dm_is_exempt`), App Link for `/messages` (Ruling 12), fr is the only second language (web also ships pcm).
- Fixing 404/409 in the OpenAPI response lists (Ruling 7, web repo).

---

## File Structure

| File | Responsibility |
|---|---|
| `lib/core/api/messages_models.dart` (new) | `OtherPlayer`, `ThreadSummary`, `ThreadsPage`, `ThreadHeader`, `DmMessage`, `ReplyPreview`, tolerant enums `PreviewKind`, `RequestState`, `RequestDirection`, `MessageKind` |
| `lib/core/api/api_client.dart` (append) | 15 methods + 15 `usedOperations` lines |
| `lib/core/realtime/realtime_port.dart` (new) | `RealtimeChannelSpec`, `RealtimeChannelPort`, `RealtimeChannelFactory`, `SupabaseRealtimeChannelFactory` |
| `lib/core/realtime/realtime_hub.dart` (new) | `RealtimeHub`, `RealtimeSignal`, lifecycle handling, backoff, `realtimeHubProvider`, `debouncedSignals` |
| `lib/features/notifications/notifications_realtime.dart` (modify) | bell nudge re-based on the hub; `debouncedTicks` stays exported |
| `lib/features/messages/message_error_copy.dart` (new) | `ApiException.code` -> ARB copy |
| `lib/features/messages/stickers.dart` (new), `tool/sync_stickers.dart` (new), `test/fixtures/web_sticker_pack.json` (new) | bundled pack + drift check |
| `lib/features/messages/messages_repository.dart` (new) | `MessagesRepository` interface + `ApiMessagesRepository` |
| `lib/features/messages/inbox_providers.dart` (new) | `InboxNotifier` (per box), request count, realtime nudge, `markAllDelivered` throttle |
| `lib/features/messages/inbox_screen.dart`, `requests_screen.dart` (new) | inbox + requests list |
| `lib/features/messages/thread_providers.dart` (new) | `ThreadNotifier` (window + pending), `ThreadActionQueue`, `openThreadIdProvider`, drafts |
| `lib/features/messages/thread_window.dart` (new) | pure merge/overlap-walk functions (unit tested without Riverpod) |
| `lib/features/messages/conversation_screen.dart`, `message_bubble.dart`, `composer.dart`, `message_actions_sheet.dart`, `forward_sheet.dart`, `sticker_picker.dart` (new) | the conversation UI |
| `lib/features/messages/dm_image_pipeline.dart`, `dm_media_uploader.dart` (new) | `sanitizeJpeg`, pick+compress, storage upload |
| `lib/features/messages/block_report.dart` (new) | block/unblock/report sheets and banner |
| `lib/features/messages/request_view.dart` (new) | incoming request preview, outgoing-pending banner + poll |
| `lib/features/messages/presence_providers.dart`, `typing_controller.dart` (new) | online set; typing sender/tracker + provider |
| `lib/features/messages/voice/` (new: `voice_ports.dart`, `voice_recorder_controller.dart`, `voice_composer.dart`, `voice_bubble.dart`) | recording state machine, review UI, playback |
| `lib/core/routing/web_links.dart` (append) | `/messages`, `/messages/<uuid>` |
| `lib/router/app_router.dart` (append) | three routes; `pushNavigatorProvider` rule |
| `lib/core/notifications/push/push_models.dart`, `push_tap_router.dart`, `push_bootstrap.dart` (modify) | `threadId`, DM destination, banner suppression |
| `lib/shared/widgets/sx_tab_app_bar.dart` (modify) | messages bell -> `/messages` |
| `lib/features/players/player_profile_screen.dart` (modify) | Message button |
| `test/**` mirroring the above, `test/fakes/fake_messages_repository.dart`, `test/fakes/fake_realtime.dart`, `test/fakes/fake_voice.dart` | |

---

### Task 0: Worktree, baseline, contract check

- [ ] **Step 1: Worktree.** From `master`: `git worktree add ..\sentinelx_mobile-p5b -b phase5b/screens`. Copy `android\app\google-services.json` into `..\sentinelx_mobile-p5b\android\app\` (verify `git status` does not list it).
- [ ] **Step 2: Contract.** `api/openapi.json` was copied on the plan's parent commit `f635bb4`; confirm it is byte-identical to web `main`: `git -C C:\Users\gorok\Videos\sentinelx fetch origin`, then `git -C C:\Users\gorok\Videos\sentinelx show origin/main:openapi/mobile-v1.json | diff - api\openapi.json`. If web `main` moved and the diff is non-empty, re-copy and commit it alone. Confirm the 15 operations are present: `getMessageThreads getMessageThread getThreadMessages startMessageThread sendMessage editMessage unsendMessage forwardMessage markThreadRead markAllDelivered blockPlayer unblockPlayer reportThread acceptMessageRequest declineMessageRequest`.
- [ ] **Step 3: Baseline.** `flutter pub get`, `flutter analyze`, `flutter test`; record the test count in `docs/agent-handoffs/2026-10-0X-phase5b-stage-d-handoff.md` (create it now as the running log); `git checkout -- linux macos windows`.
- [ ] **Step 4: Owner gate.** If the owner reported a 5a device-pass failure, stop and fix it first (it shares the push infrastructure).

---

### Task 1: Models and tolerant parsing

**Files:** create `lib/core/api/messages_models.dart`, `test/core/messages_models_test.dart`. Read `lib/core/api/notifications_models.dart` for the tolerance idiom.

**Interfaces — Produces:**
```dart
enum PreviewKind { text, image, sticker, voice, removed, unknown }       // parsePreviewKind(String?) never throws
enum RequestState { pending, accepted, declined, unknown }              // wire strings 'pending'|'accepted'|'declined'
enum RequestDirection { incoming, outgoing }                            // null when not pending / unknown value

class OtherPlayer { const OtherPlayer({required this.id, required this.name, this.username, this.avatarUrl});
  final String id, name; final String? username, avatarUrl;
  String get displayName => name.trim().isNotEmpty ? name : (username ?? '?'); }

class ThreadPreview { final PreviewKind kind; final String? text, stickerId; }
class ThreadSummary { final String threadId; final OtherPlayer other; final ThreadPreview preview;
  final DateTime lastMessageAt; final int unread; final RequestState requestState; final RequestDirection? direction;
  static ThreadSummary? tryParse(Object? json); }                       // null for a malformed row
class ThreadsPage { final List<ThreadSummary> threads; final String? nextCursor; final int requestCount;
  factory ThreadsPage.fromJson(Map<String, dynamic> j); }               // skips malformed rows, keeps the rest
class ThreadHeader { final String threadId; final OtherPlayer other; final bool blockedByMe, blockedByThem;
  final RequestState requestState; final RequestDirection? direction;
  factory ThreadHeader.fromJson(Map<String, dynamic> j);
  bool get iAmBlocked => blockedByThem; bool get canSend; }              // see rules below

class ReplyPreview { final String id; final String? senderName, body; final bool removed; }
enum MessageKind { text, image, sticker, voice, removed, unknown }
class DmMessage { final String id, senderId; final String? body, imageUrl, stickerId, audioUrl;
  final int? audioDurationSeconds; final bool forwarded; final DateTime createdAt;
  final DateTime? deliveredAt, readAt, editedAt, deletedAt; final ReplyPreview? replyTo;
  MessageKind get kind;                    // removed iff deletedAt != null; else audio > image > sticker > text; none of them -> unknown
  bool isMine(String viewerId); bool get isEdited; 
  static DmMessage? tryParse(Object? json); }
class MessagesPage { final List<DmMessage> messages /* newest first */; final String? nextBefore;
  factory MessagesPage.fromJson(Map<String, dynamic> j); }
```
Rules: `canSend` = `!blockedByMe && !blockedByThem && requestState != declined`; the **sender-side decline is reported by the server as `blockedByThem`**, so the app never needs to show "declined" (spec). `audioDurationSeconds` accepts int or double on the wire (`number`), stored as a rounded int (min 1). A timestamp that fails to parse makes the row malformed (message) / epoch (thread summary `lastMessageAt`, so the thread still lists). `DmMessage.kind`: `deletedAt != null` -> `removed` even if a stale body is present.

- [ ] **Step 1: Failing tests:** full thread row, full message of each kind; **unknown `preview.kind` ("poll"), unknown `requestState`, unknown `direction`** each degrade and the surrounding list still parses; a list with one bad row (missing `threadId`) keeps the other rows; `username`/`avatarUrl` null -> `displayName` falls back; message with `audioDurationSeconds: 12.0` and `12`; unsent message (all content null, `deletedAt` set) -> `removed`; a message with only unknown fields (no body/image/sticker/audio, no `deletedAt`) -> `unknown`; `replyTo` null, `replyTo.removed == true`, `replyTo` with null `senderName`; `canSend` truth table (blockedByMe, blockedByThem, declined); `isMine`.
- [ ] **Step 2-4:** implement; analyze/test; **Commit** `feat(messages): tolerant DM wire models`.

---

### Task 2: `ApiClient` methods

**Files:** modify `lib/core/api/api_client.dart` (append methods + `usedOperations`); create `test/core/api_client_messages_test.dart`. Read `test/core/api_client_community_test.dart` first and copy its `_FakeAdapter` pattern (it records the request, including headers).

**Interfaces — Produces** (append; each in `usedOperations` with the exact `'method /api/mobile/v1/…'` string from the contract):
```dart
Future<ThreadsPage> getMessageThreads({String? cursor, String box = 'inbox'});         // 'getMessageThreads': 'get /api/mobile/v1/messages/threads'
Future<ThreadHeader> getMessageThread(String threadId);                               // 'getMessageThread': 'get …/messages/threads/{id}'
Future<MessagesPage> getThreadMessages(String threadId, {String? before});            // 'getThreadMessages': 'get …/messages/threads/{id}/messages'
Future<({String threadId, RequestState requestState})> startMessageThread(String recipientId); // 'startMessageThread': 'post …/messages/threads'
Future<({String messageId, DateTime createdAt})> sendMessage(String threadId, {String? body, String? imagePath,
    String? stickerId, String? audioPath, int? audioDurationSeconds, String? replyToId, required String idempotencyKey}); // 'sendMessage': 'post …/messages/threads/{id}/messages'
Future<void> editMessage(String messageId, String body);                              // 'editMessage': 'patch …/messages/{id}'
Future<void> unsendMessage(String messageId);                                         // 'unsendMessage': 'delete …/messages/{id}'
Future<String> forwardMessage(String messageId, {required String toThreadId, required String idempotencyKey}); // 'forwardMessage': 'post …/messages/{id}/forward'
Future<void> markThreadRead(String threadId);                                         // 'markThreadRead': 'post …/messages/threads/{id}/read'
Future<void> markAllDelivered();                                                      // 'markAllDelivered': 'post …/messages/delivered'
Future<void> blockPlayer(String playerId);                                            // 'blockPlayer': 'put …/messages/blocks/{playerId}'
Future<void> unblockPlayer(String playerId);                                          // 'unblockPlayer': 'delete …/messages/blocks/{playerId}'
Future<void> reportThread(String threadId, {String? messageId, required String reason}); // 'reportThread': 'post …/messages/threads/{id}/report'
Future<void> acceptMessageRequest(String threadId);                                   // 'acceptMessageRequest': 'post …/messages/threads/{id}/accept'
Future<void> declineMessageRequest(String threadId);                                  // 'declineMessageRequest': 'post …/messages/threads/{id}/decline'
```
Path segments use `Uri.encodeComponent`; cursors use `_withQuery`. `sendMessage` omits null fields from the body. Sends and forwards carry `Idempotency-Key`; no other messages call does.

- [ ] **Step 1: Failing tests** (one group per method): correct verb + path + body (null fields omitted, `audioDurationSeconds` an int) + parsed result; **`Authorization: Bearer …` present on every read** (`getMessageThreads`, `getMessageThread`, `getThreadMessages`) and on every write — the adapter must be built through `ApiClient.create(accessToken: …)` so the interceptor is exercised, not a hand-built `Dio` (Lesson 1); `Idempotency-Key` present on send/forward and **absent** on the rest; `cursor`/`before` appear in the query only when non-null and are URL-encoded; `box=requests`; error mapping: a 409 `{error:{code:'request_pending_limit'}}` and a 403 `blocked` surface as `ApiException` with that `code`; a 200 body missing `data` -> `bad_response`; `usedOperations` has 15 new entries (the existing contract test covers drift against `api/openapi.json`).
- [ ] **Step 2-4:** implement; `flutter test test/core/api_contract_test.dart test/core/api_client_messages_test.dart`; analyze/test; **Commit** `feat(api): messages client methods (15 operations)`.

---

### Task 3: Shared realtime hub

**Files:** create `lib/core/realtime/realtime_port.dart`, `lib/core/realtime/realtime_hub.dart`, `test/fakes/fake_realtime.dart`, `test/core/realtime_hub_test.dart`; modify `lib/features/notifications/notifications_realtime.dart`, `test/features/notifications/notifications_providers_test.dart` (only if its fakes need the new seam). Read `notifications_realtime.dart` and `unread_counts.dart` first; **do not rewrite the 5a bell logic**, only swap its channel source (`unreadCount` keeps using supabase `.stream` unchanged).

**Interfaces — Produces:**
```dart
enum RealtimeSignalKind { event, reconnected, resumed }
class RealtimeSignal { const RealtimeSignal(this.seq, this.kind); final int seq; final RealtimeSignalKind kind; } // seq strictly increases per stream

sealed class RealtimeBinding {}
class PostgresBinding extends RealtimeBinding { PostgresBinding({required this.table, this.schema = 'public', this.filterColumn, this.filterValue, this.event = 'all'}); … }
class BroadcastBinding extends RealtimeBinding { BroadcastBinding(this.event, this.onPayload); final String event; final void Function(Map<String, dynamic>) onPayload; }
class PresenceBinding extends RealtimeBinding { PresenceBinding({required this.key, required this.onSync, this.trackPayload}); … } // onSync(Set<String> keys)

class RealtimeChannelSpec { const RealtimeChannelSpec({required this.topic, this.private = false, this.selfBroadcast = false,
    this.presenceKey, this.bindings = const []}); }
enum PortStatus { subscribed, error, closed, timedOut }
abstract class RealtimeChannelPort { void subscribe(void Function(PortStatus) onStatus); Future<void> send(String event, Map<String, dynamic> payload); Future<void> dispose(); }
abstract class RealtimeChannelFactory { RealtimeChannelPort create(RealtimeChannelSpec spec); }
class SupabaseRealtimeChannelFactory implements RealtimeChannelFactory { SupabaseRealtimeChannelFactory(this._client); … }

class RealtimeHub {
  RealtimeHub({required RealtimeChannelFactory factory, required AppLifecycleSource lifecycle, Duration Function(int attempt)? backoff});
  /// One managed channel per call; cancelling the subscription disposes the channel. Signals are NOT debounced here.
  RealtimeHandle open(RealtimeChannelSpec spec);
}
class RealtimeHandle { Stream<RealtimeSignal> get signals; Future<void> send(String event, Map<String, dynamic> payload); Future<void> close(); }
Stream<RealtimeSignal> debouncedSignals(Stream<RealtimeSignal> source, {Duration debounce = const Duration(milliseconds: 400)}); // keeps the LAST kind, new seq per emission, 'reconnected'/'resumed' win over 'event' inside one window
final realtimeHubProvider = Provider<RealtimeHub>(...);   // overridable
```
Behavior: `open` creates the port and subscribes on first listen; `PortStatus.subscribed` after the first time -> `reconnected`; status `error|closed|timedOut` -> dispose the port, schedule a re-create with backoff 2 s, 4 s, 8 s ... capped 30 s (reset on `subscribed`); `AppLifecycleState.paused|hidden` -> dispose all ports (keep handles), `resumed` -> re-create all + emit `resumed` on every handle; a `send` before the channel is subscribed is dropped (typing is best-effort), never throws; `close()` is idempotent and a late status callback after close does nothing. `AppLifecycleSource` is a small interface over `WidgetsBindingObserver` so tests push lifecycle states.

- [ ] **Step 1: Failing tests (`test/core/realtime_hub_test.dart`, fake factory):** two consecutive `event`s deliver **two** signals with distinct `seq` (Lesson 2 — a `StreamProvider<void>` would deliver one); `debouncedSignals` coalesces a burst of 5 events inside 400 ms into one signal (fake_async) and still emits a second signal for a later burst; a `reconnected` inside a burst of events wins; a status `error` re-creates the channel after 2 s, then 4 s on a second failure, and the backoff resets after `subscribed`; the second `subscribed` produces `reconnected`; `paused` disposes the port (fake records it), `resumed` re-creates it and emits `resumed`; cancelling the stream disposes the port and a late `subscribed` callback afterwards emits nothing and does not throw; `send` before subscribed is dropped without throwing; the binding list reaches the factory unchanged (spec equality: topic, `private`, `selfBroadcast`).
- [ ] **Step 2: Failing test for the bell:** with the fake factory, the bell's nudge provider opens a channel for `player_notifications` filtered `player_id = <viewer>` and two consecutive events refresh the bell twice (the existing 5a tests in `notifications_providers_test.dart` keep passing unchanged).
- [ ] **Step 3: Implement** `SupabaseRealtimeChannelFactory` against `client.channel(topic, opts: RealtimeChannelConfig(private: …, self: …, key: presenceKey))` with `onPostgresChanges` / `onBroadcast(event:, callback:)` / `onPresenceSync` and `subscribe((status, error) {...})` — signatures verified in `realtime_client 2.13.0`. Re-base `notificationRowChanges` on the hub; leave `debouncedTicks` exported (re-export) so 5a call sites compile.
- [ ] **Step 4:** analyze/test; **Commit** `feat(realtime): lifecycle-aware hub with counter signals; bell re-based on it`.

---

### Task 4: Error copy and the sticker pack

**Files:** create `lib/features/messages/message_error_copy.dart`, `lib/features/messages/stickers.dart`, `tool/sync_stickers.dart`, `test/fixtures/web_sticker_pack.json`, `test/features/messages/message_error_copy_test.dart`, `test/features/messages/stickers_test.dart`; modify both ARBs + generated l10n. Read `lib/features/notifications/notification_error_copy.dart` and `tool/gen_l10n_from_web.dart` for the idiom.

**Interfaces — Produces:**
```dart
String dmErrorCopy(AppLocalizations l, Object error);   // ApiException.code -> ARB; unknown/network/non-ApiException -> dmErrorGeneric
class Sticker { const Sticker(this.id, this.emoji, this.labelKey); final String id, emoji; }
const kStickerPack = <Sticker>[ /* 14, in the web's order: gg 🎮, fire 🔥, trophy 🏆, rage 😤, ez 😎, clutch 💪, lol 😂, ggwp 🤝, sad 😭, clap 👏, rocket 🚀, skull 💀, eyes 👀, goat 🐐 */ ];
Sticker? stickerById(String id);
```
ARB keys (en + fr, identical sets; the full DM copy is added here so later tasks only reference keys): `dmErrorGeneric dmErrorBlockedByMe dmErrorBlocked dmErrorRestricted dmErrorEditWindow dmErrorNotForwardable dmErrorRequestLimit dmErrorRequestNoMedia dmErrorNotFound dmErrorSendFailed dmErrorAction dmErrorValidation`, and the UI keys each later task names (`dmInboxTitle dmRequestsTitle dmEmptyInbox dmWaitingFor(name) dmTyping dmOnline dmUnreadCount(count) dmRequestsCount(count) dmVoiceSeconds(seconds) …`). Plural keys use ICU `{count, plural, one{…} other{…}}` in both languages. **Copy for "blocked by them" and "request declined" is the same key** (Review Focus 5).

- [ ] **Step 1: Failing tests:** every code in the Global Constraints list maps to a non-generic string in en and fr; `blocked` and `blocked_by_me` differ; an unknown code, a `status: 0 network` exception and a plain `StateError` -> generic; the pack has exactly 14 unique ids in the web order; `stickerById('goat')` found, `stickerById('nope')` null; **`kStickerPack` ids/emoji equal `test/fixtures/web_sticker_pack.json`** (a fixture written by the tool; the test fails if either side changes without the other); ARB parity (existing `l10n_test.dart`) with the new keys; a plural check for `dmUnreadCount` 1 vs 3 in en and fr.
- [ ] **Step 2: `tool/sync_stickers.dart`:** takes the web checkout path, runs `git -C <web> show origin/main:lib/messages/stickers.ts`, parses `{ id: '…', emoji: '…' }` lines, rewrites the fixture as UTF-8 (`utf8.encode`, no BOM); run it once now and commit the result (it must equal the 14 above).
- [ ] **Step 3-4:** implement; `flutter gen-l10n`; analyze/test; **Commit** `feat(messages): error copy, bundled sticker pack with drift fixture, DM strings`.

---

### Task 5: Inbox data layer

**Files:** create `lib/features/messages/messages_repository.dart`, `lib/features/messages/inbox_providers.dart`, `test/fakes/fake_messages_repository.dart`, `test/features/messages/inbox_providers_test.dart`, `test/features/messages/messages_repository_test.dart`. Read `lib/features/notifications/notifications_providers.dart` end to end: **copy its `_inFlight`/`_refreshQueued`/`_eventDuringFirstLoad` discipline**.

**Interfaces — Produces:**
```dart
abstract class MessagesRepository {                       // all methods delegate to ApiClient; the fake is in-memory
  Future<ThreadsPage> threads({required InboxBox box, String? cursor});
  Future<ThreadHeader> thread(String threadId);
  Future<MessagesPage> messages(String threadId, {String? before});
  Future<({String threadId, RequestState requestState})> start(String recipientId);
  Future<({String messageId, DateTime createdAt})> send(String threadId, SendDraft draft, {required String idempotencyKey});
  Future<void> edit(String messageId, String body);   Future<void> unsend(String messageId);
  Future<String> forward(String messageId, {required String toThreadId, required String idempotencyKey});
  Future<void> markRead(String threadId);             Future<void> markAllDelivered();
  Future<void> block(String playerId);                Future<void> unblock(String playerId);
  Future<void> report(String threadId, {String? messageId, required String reason});
  Future<void> accept(String threadId);               Future<void> decline(String threadId);
}
enum InboxBox { inbox, requests }
class SendDraft { const SendDraft({this.body, this.imagePath, this.stickerId, this.audioPath, this.audioDurationSeconds, this.replyToId}); … }
class InboxState { final List<ThreadSummary> threads; final String? nextCursor; final int requestCount; final bool loadingMore; bool get hasMore; }
class InboxNotifier extends AsyncNotifier<InboxState> { // family-like: one provider per box via two top-level providers
  Future<void> loadMore(); Future<void> refreshInPlace(); Future<bool> refresh();
}
final inboxProvider = AsyncNotifierProvider.autoDispose<InboxNotifier, InboxState>(…);          // box = inbox
final requestsInboxProvider = AsyncNotifierProvider.autoDispose<InboxNotifier, InboxState>(…);  // box = requests
final dmViewerIdProvider = viewerIdProvider;     // same pattern as notificationsViewerIdProvider
final messagesRepositoryProvider = Provider<MessagesRepository>(…);
final dmNudgeProvider = StreamProvider.autoDispose<RealtimeSignal>(…); // dm_messages, unfiltered (RLS scopes it), 400 ms debounce
final deliveredThrottleProvider = …;           // Ruling 11: at most one markAllDelivered per 15 s
```
Rules: `build` awaits `dmViewerIdProvider.future` (rebuilds on login/logout/account switch, **not** on token refresh — Lesson 3), signed out -> empty state; it listens to `dmNudgeProvider`: a signal while loading is remembered (`_eventDuringFirstLoad`) and replayed once after the first page; later signals call `refreshInPlace`. `refreshInPlace` re-reads pages **from the first cursor until it has covered as many threads as are loaded** (`while loaded < current.length && nextCursor != null`), in place; it is queued (not dropped) when `loadMore` or another refresh is in flight and never resets `nextCursor` below the loaded window (Lesson 5). `loadMore` de-duplicates by `threadId` (a thread can move across the page boundary). Every mutator no-ops when `!ref.mounted` and resolves the repository at entry (Lesson 4). A `resumed`/`reconnected` signal refetches the window **and** calls `markAllDelivered` through the throttle.

- [ ] **Step 1: Failing tests (fake repository + fake hub):** first page and `hasMore`; `loadMore` appends, de-dupes a thread that slid across the boundary, and stops at `nextCursor == null`; **a nudge refetches the loaded window in place** (load 2 pages = 40, emit, still 40 threads, re-ordered, `requestCount` updated, no reset to page one); **two consecutive nudges both refresh** (Lesson 2); a nudge during `loadMore` is queued and runs after with no lost/duplicated row; a nudge during the first load is replayed after it (Lesson 5); refresh failure keeps the last good list; `refresh()` returns false on failure and never throws; a **real refreshed `Session`** (same user, new access token, built with `Session(accessToken: …, tokenType: 'bearer', user: …)` fed through `sessionProvider`) does **not** refetch (fake counts `threads` calls) while a different user id does and does not show user A's threads (Lesson 3); signed out -> empty; mutators on a disposed notifier do nothing and do not throw; the throttle lets one `markAllDelivered` through per 15 s (fake_async) and ignores a nudge that brings only own messages; repository test: `ApiMessagesRepository` delegates each method to `ApiClient` with the same arguments (spot-check send/forward pass the key through).
- [ ] **Step 2-3:** implement; analyze/test; **Commit** `feat(messages): repository, inbox providers with in-place realtime refresh`.

---

### Task 6: Inbox screen, routes, bell destination

**Files:** create `lib/features/messages/inbox_screen.dart`, `requests_screen.dart`, `test/features/messages/inbox_screen_test.dart`, `requests_screen_test.dart`; modify `lib/router/app_router.dart` (append routes), `lib/core/routing/web_links.dart` (append), `lib/shared/widgets/sx_tab_app_bar.dart`, `test/core/web_links_test.dart` (append), `test/router/app_router_test.dart` (append), the app-bar test (find with `grep -rn "SxTabAppBar\|bell-messages" test lib`). Read `notifications_screen.dart` for the paging/refresh/empty/error/signed-out scaffolding and copy it.

Behavior (`Key`s in brackets): `/messages` — AppBar `dmInboxTitle`; a first row **"Message requests (n)"** (`dm-requests-row`, plural `dmRequestsCount`, shown only when `requestCount > 0`) pushes `/messages/requests`; thread rows (`dm-thread-<id>`): avatar (`PlayerAvatar` pattern from players), display name, one-line preview by `PreviewKind` (text excerpt / "Photo" / sticker emoji / "Voice message" / "Message removed" / generic for unknown), relative time (reuse `relative_time.dart`), unread badge with plural semantics; **outgoing pending** rows show "Waiting for <name>" (`dmWaitingFor`); tap -> `context.push('/messages/<id>')`. States: loading, error + retry (`dm-retry`), signed out (login CTA), empty (`dmEmptyInbox`). Near the end `loadMore` fires; pull-to-refresh calls `refresh()`. `/messages/requests` shows the `requests` box with the same row (Accept/Decline happen inside the thread; rows show a "Request" chip) and an empty state. The messages bell (`bell-messages`) gets `onPressed: () => GoRouter.of(context).push('/messages')` and a tooltip with `dmUnreadCount`; the coming-soon helper in `_BellIcon` is deleted once nothing uses it (the notifications bell already passes `onPressed`).
Routing: `resolveWebLink` gains **only**: `messages` -> `/messages`; `messages/<uuid>` -> `/messages/<uuid>` (lower-cased), locale prefix stripped; `messages/<non-uuid>`: no authority -> `null` (in-app path such as `/messages/requests` passes through the redirect untouched), with authority -> `/messages`. Routes appended outside the shell: `/messages`, `/messages/requests` (declared **before**) and `/messages/:threadId`. `tabRootLocations` is unchanged (Lesson 10).

- [ ] **Step 1: Failing tests:** `resolveWebLink`: `/messages` -> `/messages`; `/messages/<uuid>` -> same; `https://sentinelxesports.com.ng/fr/messages/<uuid>` -> `/messages/<uuid>`; `/messages/requests` -> **`null`**; `https://sentinelxesports.com.ng/messages/requests` -> `/messages`; `/messages/<uuid>/x` -> `null`; router: navigating to `/messages/requests` builds `RequestsScreen` (not the thread screen) and `resolveWebLink` does not redirect it away (Lesson 9); pushing `/messages/<uuid>` from `/community` leaves `/community` underneath (Back returns); the bell on a tab pushes `/messages`; **widget tests (en + a fr smoke):** rows render newest first, unread badge only when `unread > 0` with 1 vs 3 plural semantics, every `PreviewKind` incl. `unknown`, a null username/avatar row, a long name + long preview do not overflow at 375x800, outgoing-pending row text, requests row hidden at 0 and shown with the count, tap pushes the thread, paging at the end calls `threads` with the cursor, pull-to-refresh, error + retry, signed-out CTA pushes `/login`, empty state.
- [ ] **Step 2-3:** implement; analyze/test; **Commit** `feat(messages): inbox and requests screens, routes, bell destination`.

---

### Task 7: Thread data layer — window, pending sends, serialization, receipts

**Files:** create `lib/features/messages/thread_window.dart`, `lib/features/messages/thread_providers.dart`, `test/features/messages/thread_window_test.dart`, `test/features/messages/thread_providers_test.dart`. This is the riskiest logic task; keep the merge functions **pure** so most tests need no Riverpod.

**Interfaces — Produces:**
```dart
// thread_window.dart (pure)
class PendingItem { final String clientKey /* = idempotency key, one per compose action */, localId; final SendDraft draft;
  final PendingStatus status /* sending | failed */; final Object? error; final DateTime queuedAt; }
enum PendingStatus { sending, failed }
class ThreadView { final List<DmMessage> messages /* NEWEST FIRST, server truth */; final String? nextBefore; final List<PendingItem> pending; final bool loadingOlder; }
List<DmMessage> mergeNewestPage(List<DmMessage> window, MessagesPage page);                       // replaces by id, inserts new, keeps older loaded rows
MergeResult reconcileWindow({required List<DmMessage> window, required Future<MessagesPage> Function(String? before) fetch, int maxPages = 10});
  // walks newest -> older until a fetched page overlaps the loaded window by id (or the window is empty/maxPages hit);
  // if no overlap within maxPages the OLD window is dropped and replaced by what was fetched with hasMore = true
List<DmMessage> appendOlder(List<DmMessage> window, MessagesPage page);                           // de-dupes by id

// thread_providers.dart
class ThreadNotifier extends AsyncNotifier<ThreadView> {              // family on threadId
  Future<void> loadOlder();   Future<void> refreshInPlace();   Future<void> refreshWindow();  // refreshWindow = reconcileWindow, on resume/reconnect/media error
  Future<void> send(SendDraft draft);                  // optimistic; creates PendingItem with a fresh key
  Future<void> retry(String localId);                  // SAME clientKey; no-op if already sending
  void discard(String localId);
  Future<bool> edit(String messageId, String body);    Future<bool> unsend(String messageId);
  Future<bool> forward(String messageId, String toThreadId);
  Future<void> markRead();                              // coalesced
}
final threadProvider = AsyncNotifierProvider.autoDispose.family<ThreadNotifier, ThreadView, String>(…);
final threadHeaderProvider = FutureProvider.autoDispose.family<ThreadHeader, String>(…);
class ThreadActionQueue { Future<T> run<T>(String threadId, Future<T> Function() op); }   // FIFO per thread id; an error in one op does not poison the chain
final threadActionQueueProvider = Provider<ThreadActionQueue>(…);
final openThreadIdProvider = NotifierProvider<OpenThread, String?>(…);       // set by the visible conversation, cleared on dispose/pause
final threadDraftProvider = NotifierProvider.autoDispose.family<…, String, String>(…); // in-memory text draft per thread
```
Rules:
- **Send:** `send()` appends a `PendingItem{status: sending}` immediately (so the bubble shows), then `queue.run(threadId, …)` calls the repository with the item's `clientKey`. On success the item is replaced by a synthesized `DmMessage` (id and `createdAt` from the response, own sender id, no receipts) inserted into the window **by id** (a refresh that already brought the same id must not duplicate it). On failure the item becomes `failed` with the error (copy via `dmErrorCopy`); a **non-retryable** code (`blocked`, `blocked_by_me`, `messaging_restricted`, `request_pending_limit`, `request_media_not_allowed`, `validation`) is also `failed` but its Retry is hidden (only Discard), and `blocked`/`request_*` additionally invalidates `threadHeaderProvider` so the composer state updates.
- `retry(localId)` re-sends with the **same** `clientKey`; if the item is already `sending` it returns immediately (double tap safe); a retry after an ambiguous timeout therefore replays the server's first result (fake server in tests replays by key).
- **Serialization:** send, edit, unsend, forward and markRead for one thread run through `ThreadActionQueue` in submission order; two threads run independently. `markRead` is coalesced: if one is already queued (not running) a second call is dropped.
- **Refresh discipline** (same as the bell, Lesson 5): `_inFlight`/`_refreshQueued`; `refreshInPlace` merges the **newest page** into the window; `refreshWindow` runs `reconcileWindow` (resume, `reconnected`, media-URL error); neither resets `nextBefore` for older pages already loaded, neither drops pending items; a nudge during the first load is replayed after it; mutators no-op when `!ref.mounted`; the repository is resolved at entry.
- **Optimistic edit/unsend:** apply locally, call through the queue, on failure revert **only that message's fields** and only if it is still in the state this call set (a refresh that already delivered the server truth wins); a 409 `edit_window_closed` reverts and returns false (the screen shows copy and hides the controls).
- `openThreadIdProvider` + `threadDraftProvider` exist here so Tasks 8 and 12 can use them.
- A real `Session` refresh (same user) must not rebuild the thread; a different user must (family key stays, but `build` awaits `dmViewerIdProvider.future`).

- [ ] **Step 1: Failing tests — pure window (`thread_window_test.dart`):** `mergeNewestPage` replaces an edited message in place (same id, new body/`editedAt`), applies `deletedAt` (unsend) and `readAt` (receipt), inserts a new newest message and keeps order newest-first; **older loaded rows are untouched**; `reconcileWindow`: 3 new messages -> single fetch, no gap; **60 new messages (more than one page)** -> walks a second page until overlap, no hole; no overlap within `maxPages` -> old window dropped, `hasMore` true, no exception; empty window -> first page only; `appendOlder` de-dupes a message that slid across the boundary.
- [ ] **Step 2: Failing tests — notifier (fake repository, fake hub, `fake_async` where timing matters):** first page + `loadOlder` paging; a nudge refreshes in place without resetting older pages (load 2 pages, nudge, still 80 rows); **two consecutive nudges both refresh**; a nudge during `loadOlder` is queued and loses nothing; a nudge during first load is replayed; `send` shows a pending bubble **before** the future completes (Completer), then replaces it with the server message; **a refresh that returns the sent message before the send's own response arrives yields exactly one bubble** (reconcile by id); failure -> `failed` bubble; **retry reuses the same key** (assert the fake saw the same `Idempotency-Key` twice and the fake server created one message); double `retry` while in flight sends once; an ambiguous failure (fake throws `ApiException(status: 0, code: 'network')` *after* recording success) followed by retry shows **one** bubble; non-retryable code (`blocked`) -> failed with retry hidden and header invalidated; **per-thread serialization:** `send` then `edit` then `unsend` on one thread reach the repository in that order even if the first is slow (Completer), and a failure in one does not stop the next; thread A's slow op does not delay thread B; `markRead` called three times while one is queued issues at most two requests; optimistic edit reverts only that message on failure and **does not clobber** a refresh that already delivered the edit; unsend likewise; 409 `edit_window_closed` returns false and reverts; mutators on a disposed notifier are no-ops and do not throw (Lesson 4); a real refreshed `Session` (new access token, same user) does not refetch while a different user does; `refreshWindow` is called on a `resumed` signal and on a media-error request, **rate-limited to one per 30 s** (Review Focus 4); `openThreadIdProvider` and `threadDraftProvider` keep a draft across a notifier dispose.
- [ ] **Step 3-4:** implement; analyze/test; **Commit** `feat(messages): thread window, pending sends with idempotency, per-thread serial queue`.

---

### Task 8: Conversation screen — text, bubbles, reply, edit/unsend, receipts

**Files:** create `lib/features/messages/conversation_screen.dart`, `message_bubble.dart`, `composer.dart`, `message_actions_sheet.dart`, `test/features/messages/conversation_screen_test.dart`, `message_bubble_test.dart`, `composer_test.dart`; modify `lib/router/app_router.dart` (route builds the screen). Read `compose_screen.dart` for text-field/keyboard handling and `post_detail_screen.dart` for scaffolding.

Behavior (`Key`s in brackets): header = avatar + display name (tap opens `/players/<username>` when username present) + the online dot slot (Task 15) + overflow menu (block/report in Task 11). Body = reversed `ListView` over `ThreadView.messages` (newest at the bottom) **with the pending items rendered below the newest message**; date separators ("Today", "Yesterday", dates) from `createdAt`; `loadOlder` when scrolled near the top, with a small spinner; a new message arriving while the player is scrolled up shows a "New messages" pill instead of jumping (`dm-new-pill`). Bubbles (`dm-msg-<id>`): mine right/theirs left; **text**, reply quote (`replyTo`: sender name + excerpt, "Original message removed" when `removed`), "Forwarded" label, "edited" label (`editedAt`), **removed** bubble ("Message removed" in muted italics), **unknown-kind** bubble ("Unsupported message") — never an exception; **receipt ticks** on my messages only: sent (single), delivered (`deliveredAt`, double grey), read (`readAt`, double accent), semantics labels from ARB; a `sending` pending bubble (clock icon) and a `failed` bubble (error text from `dmErrorCopy`, **Retry** `dm-retry-<localId>` unless non-retryable, **Discard**). Long-press (or overflow) opens `MessageActionsSheet`: Reply, Copy (text only), Forward (Task 9), **Edit** and **Unsend** only on my own non-removed text messages (Edit: text only) with `now - createdAt < 10 min` (Ruling 8) — otherwise hidden; Report (Task 11) on theirs. Composer (`dm-composer`): multiline text field (max 2000 chars; counter appears near the limit), Send button disabled while empty or while a send is being **queued for this exact draft**, a reply bar (`dm-reply-bar`, dismiss X), an edit mode (`dm-edit-bar`: Save/Cancel; Save calls `edit`), draft persisted through `threadDraftProvider`; Enter inserts a newline (no hardware-Enter send). Lifecycle: while the screen is mounted **and** the app is `resumed`, it sets `openThreadIdProvider`, calls `markRead` once on open (**not** for an incoming pending request — Task 13), again when a new incoming message arrives while visible, and clears the open-thread id on dispose/pause; `markAllDelivered` is handled by Task 5's throttle. Image errors (`errorBuilder`) call `refreshWindow()` through the rate limiter (Task 7) and show a placeholder tile.

- [ ] **Step 1: Failing widget tests (fake repository, fake hub; en + one fr smoke):** messages render newest at the bottom with date separators; **removed, unknown-kind, forwarded, edited, reply-to-removed** bubbles all render without throwing; ticks: sent/delivered/read on mine, none on theirs; semantics labels differ per state; long unbroken text and a very long name do not overflow at 375x800; sending a message shows a pending bubble immediately, then the confirmed one; **double-tapping Send creates one pending item**; a failed send shows Retry; tapping Retry twice quickly sends once and keeps the same key; non-retryable failure hides Retry; reply flow sets `replyToId`, shows the quote, clears after send; **Edit/Unsend appear only on my text messages younger than 10 minutes** (fake clock at 9:59 vs 10:01) and never on theirs, on removed ones, or on image/sticker/voice for Edit; a 409 from edit hides the controls and shows `dmErrorEditWindow`; Copy puts the text on the clipboard; `markRead` is called on open and when a new incoming message arrives while visible, **not** while the app is paused (lifecycle simulation), and `openThreadIdProvider` is set while visible and cleared on pop; scrolled-up + new message shows the pill and does not move the scroll offset (Lesson 5: assert `controller.offset` unchanged); `loadOlder` fires near the top once; a draft survives pop/re-push; a 2000-char limit; error + retry state for the first load; 404 thread -> "conversation not found" empty state.
- [ ] **Step 2: Route test:** `/messages/<uuid>` builds the screen; Back returns; an unknown `:threadId` still builds (404 handled in the screen).
- [ ] **Step 3-4:** implement; analyze/test; **Commit** `feat(messages): conversation screen with reply, edit/unsend window, receipts`.

---

### Task 9: Stickers and forward

**Files:** create `lib/features/messages/sticker_picker.dart`, `forward_sheet.dart`, `test/features/messages/sticker_picker_test.dart`, `forward_sheet_test.dart`; modify `composer.dart`, `message_bubble.dart`, `message_actions_sheet.dart`.

Behavior: a sticker button in the composer opens a 14-cell grid (`dm-sticker-<id>`) from `kStickerPack`; tapping one **sends immediately** as its own message (`SendDraft(stickerId:)`, own key). Sticker bubbles render the emoji oversized with no bubble background; an **unknown sticker id** renders a placeholder (grey rounded tile with a generic glyph and the semantics label `dmStickerUnknown`). Forward: the actions sheet's Forward opens `ForwardSheet` listing the viewer's **inbox** threads (reads `inboxProvider`; excludes the current thread; excludes outgoing-pending threads for non-text sources is **not** done client-side — the server decides); tapping a thread calls `ThreadNotifier.forward` with a fresh key, closes the sheet, shows `dmForwarded`; failures map `not_forwardable`/`request_media_not_allowed`/`blocked` through `dmErrorCopy` in a SnackBar; a sticker/removed message cannot be forwarded when removed (action hidden).

- [ ] **Step 1: Failing tests:** 14 cells in web order; tapping sends exactly one `SendDraft(stickerId:)` with a key, and a double tap on the same cell sends once while the first is in flight; sticker bubble shows the emoji; **unknown sticker id ('bogus') renders the placeholder and does not throw**; forward sheet lists inbox threads, excludes the current one, shows empty copy when there are none, calls `forward` with `(messageId, toThreadId)` and a key, a second tap while in flight is ignored; `not_forwardable` shows its copy; Forward is hidden on removed messages.
- [ ] **Step 2-3:** implement; analyze/test; **Commit** `feat(messages): stickers and forward sheet`.

---

### Task 10: Photos — pick, sanitize, upload, send

**Files:** create `lib/features/messages/dm_image_pipeline.dart`, `dm_media_uploader.dart`, `test/features/messages/dm_image_pipeline_test.dart`, `dm_media_uploader_test.dart`, `test/fakes/fake_dm_media.dart`; modify `pubspec.yaml` (`image: ^4.10.1`), `composer.dart`, `message_bubble.dart`, `thread_providers.dart` (draft with a local upload step). Read `community_image_uploader.dart`.

**Interfaces — Produces:**
```dart
Uint8List sanitizeJpeg(Uint8List bytes, {int maxEdge = 1600, int quality = 82});   // decodeImage -> bakeOrientation -> copyResize (long edge) -> exif = ExifData() -> encodeJpg; throws FormatException on non-images
Future<Uint8List> sanitizeJpegIsolated(Uint8List bytes);                            // compute()
abstract class DmImagePicker { Future<PickedImage?> pick(ImageSource source); }     // wraps ImagePicker().pickImage(maxWidth: 1600, maxHeight: 1600, imageQuality: 85)
abstract class DmMediaUploader {
  /// Uploads to `dm-images` at `<userId>/<uuid>.jpg` (contentType image/jpeg, upsert false) and returns the STORAGE PATH.
  Future<String> uploadImage({required String userId, required Uint8List jpeg, required String pathId});
  Future<String> uploadAudio({required String userId, required File file, required String pathId});   // `dm-audio`, `<userId>/<uuid>.m4a`, audio/mp4 (Task 17)
}
String dmMediaPath({required String userId, required String id, required String ext});
final dmMediaUploaderProvider, dmImagePickerProvider;
```
Rules: the **path id is generated once per pending item** and reused on retry, and an upload error whose status is `409`/"Duplicate" is treated as success (the first attempt landed, the response was lost) — so a retry never orphans or duplicates a file; the image is sent as `imagePath` only after the upload resolves; a picked file larger than 25 MB before sanitizing, or a sanitized result larger than 3 MB, is rejected with `dmErrorImageTooLarge` before upload; picking permission is handled by `image_picker` (Android Photo Picker needs no storage permission; the camera source needs the `CAMERA` permission, which `image_picker_android` requests itself — no manifest change beyond what it declares; verify by reading its manifest at the pinned version and record it in the handoff). A pending image bubble shows the local bytes while uploading (never the remote URL). Image bubbles tap to a full-screen viewer (`InteractiveViewer`).

- [ ] **Step 1: Failing tests — `sanitizeJpeg` (port the scratch proof exactly; it ran green and its mutation failed on 2026-10-05):** fixture JPEG 3000x2000 with `GPSLatitudeRef` + `Make` -> asserts the fixture **has** both tags first (so the test cannot pass vacuously), output has neither, is 1600x1067; portrait 1200x4000 -> 480x1600; image already under the cap is not upscaled; **PNG input -> JPEG (`FF D8`)** within the cap; non-image bytes throw `FormatException`; a mutation guard comment pointing at the `exif = ExifData()` line. **Uploader tests (fake storage):** path is `<userId>/<id>.jpg`, bucket `dm-images`, contentType `image/jpeg`, `upsert: false`; a duplicate-object error resolves to the same path (no throw); any other error rethrows; **path never starts with another id** (assert `startsWith('$userId/')`). **Composer/thread tests:** picking shows a pending image bubble from local bytes; send waits for upload then calls `send(imagePath: <that exact path>)`; **a retry after a failed `send` reuses the same path id and the same key and does not upload twice** (fake counts uploads); an upload failure -> failed bubble with Retry; oversize rejected before upload with copy; cancelling the picker sends nothing; an image URL error in the bubble triggers one rate-limited `refreshWindow`.
- [ ] **Step 2-3:** implement; `flutter pub get`; `git checkout -- linux macos windows`; analyze/test; **Commit** `feat(messages): photo messages with EXIF-stripping sanitize and direct dm-images upload`.

---

### Task 11: Block, unblock, report

**Files:** create `lib/features/messages/block_report.dart`, `test/features/messages/block_report_test.dart`; modify `conversation_screen.dart`, `composer.dart`, `message_actions_sheet.dart`.

Behavior: overflow menu -> **Block** (confirm dialog, then `block`), **Report** (sheet with a multiline reason, 1-1000 chars, optional `messageId` when launched from a message's actions; Submit disabled when empty/over limit), and, when `blockedByMe`, **Unblock**. After a block: the composer is replaced by a banner (`dm-blocked-banner`) — `blockedByMe` -> "You blocked <name>" + **Unblock** button; `blockedByThem` -> `dmCannotMessage` (**the same copy** used for a declined request, Review Focus 5) with no action. `block`/`unblock` invalidate `threadHeaderProvider` and `inboxProvider`; blocking removes the thread from the inbox (server hides it). Report success -> `dmReported`; failures via `dmErrorCopy`. Incoming-request "Block and report" (Task 13) reuses these two flows.

- [ ] **Step 1: Failing tests:** Block asks for confirmation (cancel does nothing); confirm calls `block(otherId)` once even on a double tap; header refetch flips the composer to the blocked banner; `blockedByThem` shows `dmCannotMessage` and no Unblock; Unblock calls `unblock` and restores the composer; Report disabled for empty and for 1001 chars, enabled at 1 and 1000, passes `messageId` only when launched from a message; success and failure snackbars; fr smoke; a `blocked` send error (from Task 7) flips the banner after the header refetch.
- [ ] **Step 2-3:** implement; analyze/test; **Commit** `feat(messages): block, unblock and report`.

---

### Task 12: Push — DM tap routing, banner suppression, navigation rule

**Files:** modify `lib/core/notifications/push/push_models.dart`, `push_tap_router.dart`, `push_bootstrap.dart`; tests `test/core/push_models_test.dart`, `push_tap_router_test.dart`, `push_bootstrap_test.dart`, `push_banner_host_test.dart`, `test/router/app_router_test.dart` (append). Read all three source files first (`PushMessage.fromData`, `destinationFor`, `pushNavigatorProvider`, where the foreground stream calls `foregroundPushProvider.show`).

Changes: (1) `PushMessage` gains `threadId` (`_str(data['threadId'])`). (2) `destinationFor(m)`: when `m.type == 'direct_message'` and `threadId` is a UUID -> `/messages/<threadId>`; otherwise the existing url logic (a DM push without `threadId` but with `url: /messages/<uuid>` resolves through `resolveWebLink`; unmappable -> `/notifications`). (3) `pushNavigatorProvider` default (Ruling 6): `/` and `tabRootLocations` -> `router.go`; else `router.push`, **skipped when the router's current location already equals the destination**. (4) Foreground suppression: in the bootstrap's foreground handler, a message with `type == 'direct_message'` and `threadId == ref.read(openThreadIdProvider)` shows **no banner** (still no OS notification, FCM does not show foreground ones); any other DM, and every other type, behaves as before. (5) On a DM tap, `_markRead(url)` keeps working (the bell row's link is `/messages/<threadId>`); additionally `markThreadRead` is **not** called by the router — the opened conversation does it.

- [ ] **Step 1: Failing tests:** `PushMessage.fromData` parses `threadId` and blanks to null; `destinationFor`: DM with threadId -> `/messages/<id>`; DM with a **non-UUID** threadId and no url -> `/notifications`; DM without threadId but `url: '/messages/<uuid>'` -> `/messages/<uuid>`; non-DM unchanged (existing tests stay green); navigator: from `/community` a DM tap **pushes** (Back returns to `/community`), a tab-root destination still `go`es, `/` goes, **a tap while that exact thread is already on top does not push a second copy**, `/notifications` fallback now pushes; cold start (tap queued until `markReady`) still routes once and the DM opens over Home; foreground DM for the **open** thread shows no banner, a foreground DM for **another** thread shows one with the existing 5 s dismissal, a non-DM push is unaffected, a DM with no `threadId` shows a banner; tapping that banner routes through the same navigator.
- [ ] **Step 2: Build check:** `flutter build apk --debug` with and without `google-services.json` (restore it afterwards).
- [ ] **Step 3-4:** implement; analyze/test; **Commit** `feat(push): DM tap opens the thread over the current tab; no banner for the open thread`.

---

### Task 13: Message requests

**Files:** create `lib/features/messages/request_view.dart`, `test/features/messages/request_view_test.dart`; modify `conversation_screen.dart`, `composer.dart`, `thread_providers.dart`, `inbox_providers.dart` (request-count invalidation), `block_report.dart` (reuse).

Rules (spec 3.9, Stage B handoff Rulings 3-5), expressed as screen states from `ThreadHeader` (`requestState`, `direction`, `blockedBy*`):
- **Incoming pending** (`pending` + `incoming`): **preview-only**. Render the message(s) read-only, hide the composer, show three actions: **Accept** (`accept`, then header + inbox + request-count refetch, composer appears, then `markRead`), **Decline** (`decline`, pop, invalidate inbox + requests; no confirmation beyond one tap-to-confirm), **Block and report** (the Task 11 flows chained: block + report sheet). **Opening it never calls `markThreadRead` and never `markAllDelivered`-stamps anything** (guard in `ConversationScreen`: `markRead` only when `!(pending && incoming)`), and the typing channel is not opened.
- **Outgoing pending** (`pending` + `outgoing`): the composer is **text-only** (no sticker/photo/voice buttons — hidden, not disabled) and **disables after the first message** with `dmWaitingFor(name)`; the unsent-and-resend bypass is server-enforced (`request_pending_limit`), so a `request_pending_limit` or `request_media_not_allowed` error shows copy and the failed bubble offers Discard only. **While this thread is open and visible, poll `getMessageThread` every 25 s** (a `Timer.periodic` owned by a provider that is cancelled on dispose, on app pause, and as soon as the state leaves outgoing-pending); refetch on `resumed`. When the poll shows `accepted` the composer re-enables with all media buttons; when it shows `blockedByThem` the blocked banner appears (a decline looks like a block — **no "declined" copy anywhere**).
- Any state with `requestState == unknown` is treated as `accepted` for rendering (never hides the composer behind an unknown future state) except the server will still reject; `declined` (never expected for the viewer) is treated as blocked-by-them.
- The inbox row for incoming requests exists only in the requests box; `requestCount` refreshes after Accept/Decline/Block and on every nudge.

- [ ] **Step 1: Failing tests (fake repository records every call; fake_async for the poll):** incoming pending: no composer, three actions, **`markRead` and the typing channel are never opened** (assert zero calls over 60 s and after a nudge); Accept calls `accept` once (double tap = once), then the header refetch shows the composer and `markRead` fires once; Decline calls `decline`, pops, and the requests box refetches; Block-and-report runs block then opens the report sheet; outgoing pending: text field present, **no** sticker/photo/mic buttons, after the first send the composer is disabled with `dmWaitingFor`, a second send attempt (forced) -> `request_pending_limit` copy and Discard-only bubble; **poll:** `thread()` is called every 25 s while the thread is open and visible, **not** while the app is paused, **not** after the screen is popped (assert no call after dispose), **not** for an accepted thread, and stops the moment the header turns `accepted`; header `blockedByThem` after a poll shows the **same text** as the block case and no word "declined" appears in any en/fr string reachable from this screen (grep the ARB values in the test); unknown `requestState` renders as accepted; `declined` renders blocked-by-them; request count in the inbox drops after Accept.
- [ ] **Step 2-3:** implement; analyze/test; **Commit** `feat(messages): message requests (incoming preview, outgoing waiting, poll)`.

---

### Task 14: Profile entry point

**Files:** modify `lib/features/players/player_profile_screen.dart` (append a button beside Follow), `lib/features/players/players_providers.dart` only if a callback is needed; `lib/router/app_router.dart` (pass `onMessage`); tests `test/features/player_profile_screen_test.dart` (append) and the router test. Read the profile screen and its existing follow tests first.

Behavior: a **Message** button (`message-button`) next to Follow, hidden on the own profile and shown signed-out (it opens login like Follow does). Tap: disable while in flight, `startMessageThread(p.id)` through `messagesRepositoryProvider`, then `context.push('/messages/<threadId>')`. Errors map through `dmErrorCopy` in a SnackBar (`blocked`/`blocked_by_me` -> their copy; self is impossible because the button is hidden). A thread that starts `pending` opens straight into the outgoing-pending composer (Task 13).

- [ ] **Step 1: Failing tests:** button hidden on own profile, visible for others, signed out -> `onLogIn`; tap calls `start` once (double tap = once) with the **player id**, then pushes `/messages/<id>` and Back returns to the profile; `blocked` error shows copy and stays; the button is disabled while in flight; existing follow tests remain green.
- [ ] **Step 2-3:** implement; analyze/test; **Commit** `feat(messages): Message button on player profiles`.

---

### Task 15: Online presence

**Files:** create `lib/features/messages/presence_providers.dart`, `test/features/messages/presence_providers_test.dart`; modify `conversation_screen.dart` (header dot), `inbox_screen.dart` (row dot). Read the web `PresenceProvider.tsx` behavior in Task 3's references (key = viewer id, `private`, `track({online_at})` on `subscribed`).

**Interfaces — Produces:**
```dart
final onlinePlayersProvider = StreamProvider.autoDispose<Set<String>>(...);   // opens `dm-online` (private, presence key = viewer id); tracks {online_at} on every `subscribed`
final isOnlineProvider = Provider.autoDispose.family<bool, String>((ref, userId) => ...);   // select on the set
```
Rules: the stream emits a **new Set instance** on every presence sync (so equal sets in a row still notify only when contents change — use `select` in `isOnlineProvider`); keys come from `presenceState()` -> `SinglePresenceState.key`; the viewer's own key is excluded from "others online" but still tracked; signed out -> empty and no channel; `reconnected`/`resumed` re-track (the hub re-creates the channel, `subscribed` triggers `track` again); closed on dispose. Mounted by the inbox and conversation screens and by `SxTabAppBar`'s bell area **only through the providers** (Ruling 10) — no new widget tree dependency in the app bar.

- [ ] **Step 1: Failing tests (fake hub):** a presence sync with keys {a, b} -> `isOnline('a')` true, `isOnline('z')` false; a later sync removing `a` flips it; **two consecutive syncs with different contents both notify** (Lesson 2); the viewer id is tracked once per `subscribed` and **re-tracked after `reconnected`**; signed out opens no channel; dispose closes the channel; `viewerIdProvider` change (account switch) re-opens with the new key and a real refreshed `Session` for the same user does not; the green dot widgets appear in the header and inbox row only when online and carry a semantics label (`dmOnline`).
- [ ] **Step 2-3:** implement; analyze/test; **Commit** `feat(messages): online presence dot over dm-online`.

---

### Task 16: Typing indicator

**Files:** create `lib/features/messages/typing_controller.dart`, `test/features/messages/typing_controller_test.dart`; modify `conversation_screen.dart`, `composer.dart`.

**Interfaces — Produces** (pure, injected clock; mirrors web `lib/messages/typing.ts`):
```dart
const kTypingSendInterval = Duration(seconds: 3);
const kTypingExpire = Duration(seconds: 5);
String typingTopic(String threadId) => 'dm-typing:$threadId';
class TypingSender { TypingSender(this._now, this._send); void keystroke(); }          // at most one send per 3 s
class TypingTracker { TypingTracker(this._now); void onEvent(String userId); bool isTyping(String userId); } // true for < 5 s after the last event
final threadTypingProvider = StreamProvider.autoDispose.family<bool, ThreadTypingArgs>(…);   // args: threadId, otherId, enabled
final typingNotifierProvider = Provider.autoDispose.family<void Function(), ThreadTypingArgs>(…);  // composer calls it on text change
```
Rules: the channel is opened (`private: true`, `selfBroadcast: false`, `BroadcastBinding('typing', …)`) **only when `enabled`**: `enabled = requestState == accepted (or unknown) && !blockedByMe && !blockedByThem && app resumed && screen visible`; events whose `userId` is the viewer or not the other player are ignored; the indicator expires after 5 s via a 1 s ticker that stops when nothing is typing; payload sent is exactly `{userId: <viewer>}`; send failures are swallowed; nothing is stored; a `reconnected`/`resumed` signal clears the tracker.

- [ ] **Step 1: Failing tests (fake_async, fake hub):** sender: 10 keystrokes inside 3 s -> 1 send, a keystroke at 3.0 s -> 2nd send, none at 2.9 s; tracker: typing true at 4.9 s, false at 5.0 s; a second event restarts the window; events from the viewer id or a third id are ignored; **disabled** (pending thread, blockedByMe, blockedByThem, app paused) -> **no channel opened and no send** (assert the fake factory was never asked for `dm-typing:*`) — in particular opening an incoming/outgoing pending thread never opens it; topic string exact; spec flags exact (`private`, no self); the ticker stops when idle (no pending timers after expiry — `fake_async.elapse` leaves `pendingTimersCount == 0`); typing label shows and hides in the conversation header (`dmTyping`) and never appears in the inbox; send payload equals `{userId: viewer}`.
- [ ] **Step 2-3:** implement; analyze/test; **Commit** `feat(messages): typing indicator over per-thread private broadcast`.

---

### Task 17: Voice notes (highest uncertainty, last)

**Files:** create `lib/features/messages/voice/voice_ports.dart`, `voice_recorder_controller.dart`, `voice_composer.dart`, `voice_bubble.dart`, `test/fakes/fake_voice.dart`, `test/features/messages/voice/*_test.dart`; modify `pubspec.yaml` (`record: ^6.2.1`, `just_audio: ^0.10.6`), `android/app/src/main/AndroidManifest.xml` (`<uses-permission android:name="android.permission.RECORD_AUDIO"/>`), `composer.dart`, `message_bubble.dart`, `dm_media_uploader.dart`; `lib/core/l10n` keys were added in Task 4 (add any missing `dmVoice*` keys in en + fr).

**Interfaces — Produces:**
```dart
enum MicPermission { granted, denied }
abstract class VoiceRecorderPort {                                  // production: wraps `record` 6.2.1 AudioRecorder
  Future<MicPermission> ensurePermission();                          // hasPermission(request: true)
  Future<MicPermission> peekPermission();                            // hasPermission(request: false)
  Future<void> start(String path);   // RecordConfig(encoder: AudioEncoder.aacLc, bitRate: 64000, sampleRate: 44100, numChannels: 1), AAC-LC in .m4a
  Future<void> pause(); Future<void> resume(); Future<String?> stop(); Future<void> cancel(); Future<void> dispose();
  Stream<VoiceRecorderState> get states;   // recording | paused | stopped (paused also on audio-focus loss)
  Stream<double> get levels;               // 0..1 from onAmplitudeChanged(100 ms)
}
abstract class VoicePlayerPort { Future<void> load(String urlOrPath); Future<void> play(); Future<void> pause(); Future<void> seek(Duration p); Stream<Duration> get position; Stream<VoicePlayerState> get state; Duration? get duration; Future<void> dispose(); } // production: just_audio
enum VoicePhase { idle, requestingPermission, permissionDenied, recording, paused, review, uploading, failed }
class VoiceRecorderController extends Notifier<VoiceState> {       // VoiceState { phase, elapsed, level, file, error }
  Future<void> begin();   Future<void> pause(); Future<void> resume();
  Future<void> stopToReview();       // elapsed >= 1 s else discard silently
  Future<void> discard();            // deletes the temp file
  Future<void> send();               // upload + SendDraft(audioPath, audioDurationSeconds) via ThreadNotifier
  static const kMaxVoiceSeconds = 120;
}
```
Rules: **permission** (Ruling 1): `begin()` calls `ensurePermission()`; `denied` -> phase `permissionDenied` showing a banner with **Try again** (calls `ensurePermission()` again) and **Open settings** (`app_settings` `AppSettingsType.settings`); on `AppLifecycleState.resumed` while in `permissionDenied` it re-checks with `peekPermission()` and returns to `idle` if now granted (the player came back from system settings). **Recording:** temp file `<cache dir>/dm-voice-<uuid>.m4a`; elapsed excludes paused time and is driven by the recorder's `states`, not wall clock alone; at 120 s it **auto-stops to review** (never auto-sends); an audio-focus pause (call/other app) puts phase `paused` without discarding; the app going to the background during `recording` pauses it (and releases nothing else); popping the screen or `discard` cancels the recorder and deletes the file; leaving a recording phase on dispose never leaks the recorder. **Review:** play/pause/seek over the local file through `VoicePlayerPort`, Delete, Send; a recording shorter than 1 s is discarded with copy. **Send:** upload to `dm-audio` through `DmMediaUploader.uploadAudio` (same path-id/duplicate rules as images, Task 10), then `send(SendDraft(audioPath:, audioDurationSeconds: ceil(elapsed).clamp(1, 120)))`; failure -> `failed` pending bubble with Retry (same key, same path id, file kept until success or Discard); the temp file is deleted after success or discard. **Pending threads:** the mic button is hidden (Task 13). **Bubble:** `VoiceBubble` shows play/pause, a progress bar, `audioDurationSeconds` formatted with the plural `dmVoiceSeconds` for accessibility, one player playing at a time (starting another pauses the first via a shared `activeVoicePlayerProvider`), pause on app background and on dispose; a playback error (403 from an expired signed URL) triggers the rate-limited `refreshWindow` once (Review Focus 4) and shows a retry affordance; an unsent/removed voice message shows the removed bubble.

- [ ] **Step 1: Dependencies and build proof (do first, alone):** `flutter pub add record:^6.2.1 just_audio:^0.10.6`; confirm `pubspec.lock` shows `record 6.2.1`, `record_android 1.5.2`, `just_audio 0.10.6`, `audio_session 0.2.4` and **no** `permission_handler`; add the manifest permission; `flutter analyze`; `flutter build apk --debug` with and without `google-services.json`; `git checkout -- linux macos windows`. If this fails, **stop and report** — do not substitute a package without evidence. (Evidence on 2026-10-05, in a scratch copy of this project at `204f928` + the same manifest permission: `flutter analyze` clean and `flutter build apk --debug` **succeeded** (`app-debug.apk`, 695 s cold Gradle) with `record 6.2.1`, `just_audio 0.10.6` and `flutter_image_compress 2.5.1`, no `minSdk` change. That run included `flutter_image_compress`, which this plan then dropped, so the final set is a subset of what was proven; `image` is pure Dart and adds no native code. The earlier run with `permission_handler 13.0.2` instead failed at Gradle script compilation, Ruling 1.)
- [ ] **Step 2: Failing tests — controller (fake recorder/player/clock, fake_async):** `begin` with permission granted -> `recording` and the recorder got `start(path)` with an `.m4a` path in the cache dir and the exact config (aacLc, 64000, 44100, mono); denied -> `permissionDenied`, no recorder start; **Try again** re-asks and proceeds when granted; **resumed with permission now granted returns to `idle`** (lifecycle simulation); elapsed counts only recording time (record 5 s, pause 10 s, resume 5 s -> 10 s); **auto-stop at 120 s lands in `review`, not `uploading`**, and the recorder was stopped; recorder `paused` state from an audio-focus loss shows `paused`, does not auto-resume; background during `recording` pauses; a 0.5 s recording is discarded (file deleted, phase `idle`); `discard` deletes the file and cancels the recorder; dispose while recording cancels the recorder and deletes the file; `send` uploads exactly once to `<userId>/<uuid>.m4a` (assert prefix), sends `audioDurationSeconds` as an **int** within 1..120 (e.g. 4.2 s -> 5, 119.9 s -> 120), deletes the file on success, keeps it on failure, and a **retry reuses the key and path id without a second upload when the first upload succeeded**; double tap on Send sends once; the temp file name never collides across two recordings.
- [ ] **Step 3: Failing widget tests:** the mic button appears for accepted threads and is **absent** while outgoing-pending and when blocked; recording UI shows the timer and level, Pause/Resume, Stop; review UI Play/Delete/Send; denied banner shows both actions and Open settings calls `app_settings` through a fake; the voice bubble: play/pause toggles, **starting a second voice bubble pauses the first**, progress, duration semantics (1 vs 12 seconds plural in en and fr), playback error triggers exactly one `refreshWindow` and shows retry, removed voice message shows the removed bubble, long durations do not overflow at 375 px.
- [ ] **Step 4-5:** implement; analyze/test; **Commit** `feat(messages): voice notes (record, review, upload, playback)`.

---

### Task 18: Docs, full verification, review, handoff

- [ ] **Step 1: Docs.** `CLAUDE.md`: route-map rows for `/messages`, `/messages/requests`, `/messages/:threadId`; a "Phase 5b" note (realtime is a nudge; `lib/core/realtime/` hub; photo sanitize rule and the `image_picker` GPS finding; `permission_handler` rejected and why; no App Link for `/messages`). `README.md`/`TESTING-NOTES.md`: **device-pass checklist** (two real accounts on staging, `zzqa_` prefix): send/receive text both ways; ticks sent -> delivered -> read; image (check the received file has no GPS EXIF); sticker; voice note record -> pause -> review -> send -> play on the other device, 120 s cap, phone call mid-recording, permission denied then Open settings then return; reply, edit and unsend inside and after 10 minutes; forward; typing in both directions and **absence** in pending/blocked threads; online dot; **DM push in foreground (open thread: no banner; other thread: banner), background and killed (tap opens the thread over the current tab, Back returns)**; message request flow end to end (stranger starts -> recipient sees preview-only with no receipts and no push -> Accept; Decline looks like a block to the sender; reply auto-accepts; the 20-30 s outgoing poll); block/unblock/report; airplane-mode toggle and background for 10 minutes then return (window reconciles, no gap, signed URLs refresh); Realtime rejoin after network loss (Ruling 4); `markAllDelivered` timing; the web 5a device pass still outstanding.
- [ ] **Step 2: Full verification** in the worktree: `flutter analyze` (clean), `flutter test` (all pass; report the count against the Task 0 baseline), `flutter build apk --debug` with and without `google-services.json` (restore it), `git checkout -- linux macos windows`, `git status` shows no `google-services.json`. Run the new tests with `--reporter expanded` once and read the list for vacuous names; spot-check three tests by **mutating the code under test** (e.g. drop the idempotency key reuse, remove `exif = ExifData()`, remove the `!(pending && incoming)` guard) and watching them fail, then restore (Lesson 12).
- [ ] **Step 3: Fresh-context review** (`/code-review`, high effort) of the whole branch against this plan's Review Focus, the 12 lessons and Rulings; verify each finding by reading code or a test before acting (Lesson 12); fix; re-run Step 2.
- [ ] **Step 4: Handoff note** `docs/agent-handoffs/2026-10-0X-phase5b-stage-d-handoff.md`: branch + HEAD, test counts, review findings and fixes, every Ruling (this plan's 13 plus any new), deferred items, and **what is not verified**: two-device DM behavior, the cap under simultaneous sends, PostgREST error mapping over real HTTP, voice recording/playback on real hardware and across OEM audio-focus behavior, `realtime_client` rejoin signalling (Ruling 4), the typing channel under real latency and its Realtime Authorization on a device, presence at scale, DM push in all three app states, the web UI, iOS.
- [ ] **Step 5: Merge to `master` and push immediately (no PR)** — only after review and green; `git pull --rebase` first. Report to the owner.

---

## Lesson map (start message Lessons 1-12 -> concrete tests)

1. Bearer on every authenticated read -> Task 2 (per-method `Authorization` assertion through `ApiClient.create`).
2. Counter, not `void` -> Task 3 (two consecutive events), Tasks 5, 7, 15 (consumer tests).
3. `viewerIdProvider` with a real refreshed `Session` -> Tasks 5, 7, 15.
4. Optimistic rollback scope, unmounted no-ops, idempotent retry -> Task 7 (edit/unsend rollback, disposed notifier, same-key retry, ambiguous failure), Tasks 5, 8, 10, 17.
5. Refresh must not reset paging or race `loadMore`; reconnect refetches -> Tasks 5, 7 (queued refresh, first-load replay, window reconcile), Task 8 (scroll offset).
6. Tolerant parsing -> Task 1, Task 8 (bubbles), Task 6 (rows), Task 9 (sticker placeholder).
7. Serialization -> Task 7 (`ThreadActionQueue`), Task 10/17 (single upload).
8. Plurals -> Tasks 4, 6, 17 (en and fr).
9. Redirect non-swallowing -> Task 6 (`/messages/requests` -> `null`, router test).
10. Tab roots `go`, pushed screens `push` -> Tasks 6, 12 (navigator rule, same-location guard).
11. Windows encoding -> Global Constraints; `tool/sync_stickers.dart` writes UTF-8 explicitly.
12. Verify reviewer claims; tests that can fail -> Task 10 (fixture asserts GPS present before strip), Task 18 Step 2 (mutation spot-checks).

## Self-review (spec ↔ plan)

- Spec 3.1 reads via API with realtime as nudge -> Tasks 3, 5, 7. 3.3 endpoints -> Task 2 (all 15, `usedOperations`), consumers Tasks 5-14. 3.4 path validation is server-side; the client always uploads under its own id -> Tasks 10, 17 (`startsWith('$userId/')` tests). 3.5 uploads (1600 px JPEG EXIF-stripped, AAC m4a 120 s, pause-and-review) -> Tasks 10, 17 with evidence in Rulings 2-3. 3.6 typing (per-thread private broadcast, 3 s/5 s, none pending/blocked, never presence) -> Task 16. 3.7 push (`threadId`, open-thread suppression, tap over current tab) -> Task 12. 3.8 mobile structure (routes, shared realtime helper with five consumers, serialized queue, tolerant parsing, ARB, entry points) -> Tasks 3, 6, 7, 14, 4. 3.9 requests (preview-only incoming, text-only outgoing, 20-30 s poll, decline = block, no receipts/typing/push while pending) -> Task 13. Stage C items: models/tolerant parsing (1), `ApiClient` (2), realtime helper (3), inbox (5, 6), conversation incl. optimistic send/idempotency/serialization/receipts/reply/edit/unsend/forward/stickers/photo/voice/typing/presence (7-10, 15-17), requests (13), block/report (11), profile entry + bell replacement (6, 14), routes + `resolveWebLink` (6), push routing + banner (12), ARB en + fr (4 and per task), per-screen test lists (each task).
- Names are consistent across tasks: `MessagesRepository`, `SendDraft`, `InboxBox`, `ThreadView`, `PendingItem`, `ThreadNotifier` (`send`, `retry`, `discard`, `edit`, `unsend`, `forward`, `markRead`, `loadOlder`, `refreshInPlace`, `refreshWindow`), `ThreadActionQueue`, `openThreadIdProvider`, `threadDraftProvider`, `RealtimeHub`/`RealtimeSignal`/`RealtimeChannelSpec`, `DmMediaUploader` (`uploadImage`, `uploadAudio`), `VoiceRecorderPort`/`VoicePlayerPort`, `dmErrorCopy`, `kStickerPack`.
- No placeholders: every task states files, interfaces, rules and the failing tests to write first; widget bodies are specified by behavior and `Key`s (the 5a precedent: the executor writes them test-first).
