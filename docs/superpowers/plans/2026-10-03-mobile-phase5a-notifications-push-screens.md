# Mobile Phase 5a (Flutter) — Notifications & push Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. Strict TDD: failing test first, watch it fail for the right reason, minimal code, green, commit.

**Goal:** Native Android push for Sentinel X (permission, channels, token lifecycle, foreground banner, tap routing incl. cold start), the in-app bell at `/notifications` (paging, mark read / read-all, mute, live badge), and Settings → Notifications (17 push + 6 WhatsApp + 5 achievement-sharing toggles, test notification, system-permission row) — backed by the eight `/api/mobile/v1/notifications/*` endpoints and the platform-aware sender that web Stage B shipped to `sentinelx` `main` (`8e64332`, live on staging).

**Architecture:** All Firebase/OS surface sits behind one interface, `PushGateway` (`lib/core/notifications/push/`), with a `DisabledPushGateway` (used when Firebase cannot initialize) and a fake for tests — nothing but `FirebasePushGateway` imports `firebase_*`. Registration, permission prompting, tap routing and the foreground banner are plain Riverpod-provided classes over that interface. The bell **reads rows directly** from `player_notifications` (owner RLS, realtime — the spec's one sanctioned exception) and **writes through `ApiClient`**; prefs and mutes read and write through `ApiClient`. Feature code lives in `lib/features/notifications/`; cross-cutting push infrastructure in `lib/core/notifications/push/`.

**Tech Stack:** Flutter 3.41.9 (stable), Dart ^3.11, `flutter_riverpod` ^3.3 (manual providers), `go_router` ^17, `dio`, `supabase_flutter`. **New dependencies (versions resolved by `flutter pub add --dry-run` on 2026-10-03 against this project's constraints):** `firebase_core ^4.15.0`, `firebase_messaging ^16.7.0`, `flutter_local_notifications ^22.3.1`, `app_settings ^9.0.0`; Android Gradle plugin `com.google.gms.google-services` `4.4.4`.

**Spec:** web repo `docs/superpowers/specs/2026-10-03-mobile-phase5a-notifications-push-design.md` (binding; §3 Rulings, §4 endpoints, §5 app design). Web Stage B plan and handoff (read both — the handoff lists facts this plan relies on and the Rulings that refine the spec): `docs/superpowers/plans/2026-10-03-mobile-phase5a-notifications-push-web.md` and `docs/agent-handoffs/2026-10-03-phase5a-stage-b-web-handoff.md` (web repo). Master spec §6.2 (push), §6.3 (realtime), §8.11. **Read this repo's `CLAUDE.md` and `AGENTS.md` first.** Structure template: `docs/superpowers/plans/2026-09-28-mobile-phase4-community-screens.md`; review lessons: `docs/agent-handoffs/2026-10-03-mobile-phase4-stage-d-handoff.md`.

## Global Constraints

- **Never test writes against production** (`itxubrkbropttfdackmi`). Every test here uses fakes / a `_FakeAdapter`; live work is the owner's device pass on staging (`sentinelx-staging`, `ofxmoxpvwbemfouaowoa`) via `--dart-define` of `SUPABASE_URL`, `SUPABASE_PUBLISHABLE_KEY`, `API_BASE_URL`.
- **Writes only through `ApiClient`.** The only direct Supabase use is: (a) the bell's row **reads** and the unread count/realtime on `player_notifications` (spec §3.1), selecting **named columns only** (`id, type, title, body, link, read, created_at`), never `select()` of `*`; (b) nothing else. Never read `profiles`.
- **Every new `ApiClient` method is listed in `ApiClient.usedOperations`**; `test/core/api_contract_test.dart` checks it against `api/openapi.json`, a **copy** of web `openapi/mobile-v1.json` (copied in Task 0, never hand-edited). `postDevice`/`deleteDevice` already exist in `ApiClient` (`registerDevice`/`unregisterDevice`) and are reused unchanged. New models go in a new file, not `models.dart`.
- **Channel ids** (exactly, versioned — web asserts the same set): `matches_v1`, `social_v1`, `messages_v1`, `money_v1`, `admin_v1`. The app creates all five at startup, before any push can reference them. Importance: matches/messages/money/admin = high, social = default.
- **Push payload facts (web handoff, verified):** Android push = top-level `notification` + `data {url, type, title, body}`; `data.url` is a **web path** (`/matches/…`, `/community/<uuid>`, `/dashboard/settings`, …) and **may be absent**; the **row id is NOT in `data`** (Stage B Ruling 3) — a tap marks the row read by finding the newest unread own row whose `link` equals `data.url`, then `POST /notifications/{id}/read`; best-effort. FCM displays `notification` messages itself while backgrounded/terminated — **no Dart background handler is needed or registered**.
- **Permission:** `firebase_messaging` **16.7.0 owns the Android 13+ dialog** — verified in its source (`FlutterFirebaseMessagingPlugin.java`: `Messaging#requestPermission` → `requestPermissions()`, manifest declares `POST_NOTIFICATIONS`, status mapped to `authorized / notDetermined / denied / deniedPermanently` with a SharedPreferences "already asked" record; below API 33 the status is `authorized` or `denied` (= notifications disabled in system settings), never `notDetermined`). `flutter_local_notifications` is used **only** to create channels; its `requestNotificationsPermission` is never called. Consequence, and the single rule for the "API gate": **a trigger prompts only when status is `notDetermined`** (which only exists on API 33+). Never re-ask once denied; passive rows then offer "Open system settings" (`app_settings`, `AppSettingsType.notification`).
- **Firebase must be failure-tolerant.** `Firebase.initializeApp()` throwing (no `google-services.json`, iOS without plist, tests) ⇒ `DisabledPushGateway`: the app boots normally, push UI that depends on it is hidden or inert. Tests never touch Firebase.
- **No-`google-services.json` build must keep working** (CI, fresh clones). Decision: the Gradle plugin is declared in `settings.gradle.kts` (`apply false`) and **applied in `android/app/build.gradle.kts` only when `android/app/google-services.json` exists**. The file itself stays **untracked and excluded locally** (owner's decision whether it is ever committed; it holds project ids and a restricted API key, no service-account secret). Both paths are verified with `flutter build apk --debug` (Task 3). A new worktree must copy the file from the main checkout to build the live path.
- **`flutter_local_notifications` requires core-library desugaring** (its README, ≥ v10): enable `isCoreLibraryDesugaringEnabled` and add `coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")`.
- **Copy never hard-coded in widgets:** `lib/core/l10n/app_en.arb` **and** `app_fr.arb` (identical key sets, enforced by `test/core/l10n_test.dart`), `flutter gen-l10n`, commit the generated output. The web has **no** messages namespace for these labels (its settings forms hard-code English in `components/settings/*.tsx`), so keys are added to the ARBs directly, prefix `ntf`. Server `error.message` is never shown; map `error.code` through `notificationErrorCopy`. Counts use ICU plurals in en **and** fr from the start.
- Mobile-first at 375px; `SxColors` only; American spelling in code/prose; `PlayerAvatar` not needed.
- **Before every commit:** `flutter analyze` (no issues) and `flutter test` (all pass; baseline on `master` at plan time is whatever `flutter test` reports in Task 0 — record it), then `git checkout -- linux macos windows`. Never edit source with bare Python `open().read()/write()` (cp1252 corrupts UTF-8; use Edit/Write). Do not chain `git push` to a piped test command.

## Rulings (decisions this plan makes; cost if wrong)

1. **Android 13+ dialog owner = `firebase_messaging`** (evidence above). *Cost if wrong:* the dialog never appears; caught by the device pass; mitigated because everything goes through `PushGateway.requestPermission()`, a one-method swap.
2. **`google-services` plugin 4.4.4**, conditional apply. Evidence: Google Maven lists 4.4.4 as latest; its Gradle module metadata declares only `kotlin-stdlib-jdk8 1.7.10` and JVM 11 — no AGP/Gradle ceiling — and this project is AGP 8.11.1 / Gradle 8.14 / Kotlin 2.2.20 / Java 17. Final proof is the two `flutter build apk --debug` runs in Task 3. *Cost if wrong:* a build break in Task 3, found before anything else depends on it.
3. **Prompt-once rule uses the OS status, not our own storage** (`notDetermined` ⇒ ask; the plugin records the ask). Plus an in-memory per-process guard so a dismissed-without-answer dialog is not re-fired in the same run. *Cost if wrong:* an extra prompt on an OEM that leaves status `notDetermined` after dismissal — at most one per app launch, and only at a stake.
4. **Register the token whenever signed in, regardless of permission.** The server sends; the OS drops what the user disabled; enabling later then needs no re-registration. *Cost if wrong:* a few wasted sends to devices that denied.
5. **Tap on a link `resolveWebLink` cannot map ⇒ `/notifications`** (spec §3.7). `resolveWebLink` gains exactly one new mapping: `/dashboard/settings` ⇒ `/account/notifications` (the test push's url, and the web's own settings page for prefs). `/notifications` and `/account/notifications` are in-app paths and must pass through `resolveWebLink` untouched (`null`) — it runs as the router redirect on every location (Phase 4 lesson 8).
6. **No new dependency for "viewer id"**: a `notificationsViewerIdProvider` (user id, awaits the first session value) beside the feature, same pattern as `communityViewerIdProvider`; consolidating the two is deferred (do not touch the community feature).
7. **Realtime:** the bell list gets its own disposable per-screen channel (`player_notifications` filtered `player_id = me`) emitting a **counter** (never `void`); the unread badge keeps using the unchanged `unreadNotificationCountProvider`. The general channel manager remains deferred to 5b.
8. **Mutes in the bell menu** show "Unmute" when the type/thread is currently muted (from `GET /notifications/mutes` for timed rows plus `push[type] == false` from prefs for "always"). *Cost if wrong:* a stale menu label until the next refetch.
9. **Foreground banner is an in-app overlay** (`PushBannerHost` in `MaterialApp.builder`), not a local notification — FCM does not display `notification` messages while the app is foregrounded, and the realtime bell/badge already update. `flutter_local_notifications` therefore stays channel-only.
10. **Small notification icon** is the default (launcher icon) — a dedicated monochrome status-bar icon is design work outside 5a; record as a known gap.

## Review Focus

Failure modes the spec implies that no task's happy-path tests would catch, most likely first. Each has a test in the owning task.

1. **A push tap that arrives before the session/`/me` have settled (cold start) must neither be lost nor bounce through login/onboarding** — and must route exactly once. (Task 6)
2. **An unrecognized notification `type`, a row with a null/garbage `link`, an empty title/body, or a `link` the app cannot map must never break the list or a tap** — render generically; unmapped tap ⇒ stay in the bell. (Tasks 1, 7, 8)
3. **Concurrent background refresh (realtime) vs. a manual action** (mark read, mark all, load more, a second realtime event): no lost optimistic change, no pagination reset, no duplicate rows, and the second consecutive realtime event must still fire. (Task 7)
4. **Signed-out / account switch:** signed-out bell and settings show a login CTA, never an error or another user's data; switching accounts on one phone re-registers the same token for the new user and the previous user's bell/prefs are not shown. (Tasks 4, 7, 8, 9)
5. **Permission edge states:** denied-once vs. denied-permanently vs. notifications disabled below API 33; user returns from system settings with it now enabled (row updates on resume); a trigger firing twice in a row (double stake) asks once. (Task 5)

## Coordination (shared-file hotspots)

- **Base `master`; new worktree** `git worktree add ..\sentinelx_mobile-p5a -b phase5a/screens` (no other worktrees exist). Copy `android/app/google-services.json` from the main checkout into the worktree for live-path builds; **never commit it** and do not remove the `.git/info/exclude` entry.
- Hotspots — **append-only, minimal hunks, never reformat:** `lib/core/api/api_client.dart`, `lib/router/app_router.dart`, `lib/core/routing/web_links.dart`, ARB + generated l10n, `lib/features/compete/registration_flow.dart` (two one-line hook calls), `lib/features/account/account_screen.dart` (one tile, one sign-out hook), `lib/shared/widgets/sx_tab_app_bar.dart` (bell target), `lib/main.dart`, `lib/app.dart`.
- `home_screen.dart` is not touched.

## Deferred / known gaps (record in the report, do not build)

- DMs, messages inbox, DM push (5b); guide/chatbot (5c); iOS delivery, APNs, bundle id (Phase 10 — `PushGateway` is platform-neutral, iOS payload shape is server-tested only).
- Row id in push `data` (Stage B Ruling 3): taps mark read via link lookup; revisit only if the device pass shows stale badges.
- Notification grouping, quiet hours, rich notifications, monochrome status-bar icon.
- Consolidating `communityViewerIdProvider` and `notificationsViewerIdProvider`.
- Tracking `google-services.json` in git (owner's call).

---

## File Structure

| File | Responsibility |
|---|---|
| `pubspec.yaml`, `android/settings.gradle.kts`, `android/app/build.gradle.kts`, `android/app/src/main/AndroidManifest.xml` | deps, conditional google-services, desugaring, default channel meta-data |
| `lib/core/api/notifications_models.dart` (new) | `NotificationPrefs`, `NotificationMutes`, pref key lists |
| `lib/core/api/api_client.dart` (modify, append) | 8 methods + `usedOperations` lines |
| `lib/core/notifications/push/push_models.dart` (new) | `PushMessage`, `PushPermission`, `PushChannel`, `kPushChannels` |
| `lib/core/notifications/push/push_gateway.dart` (new) | `PushGateway`, `DisabledPushGateway`, `pushGatewayProvider` |
| `lib/core/notifications/push/firebase_push_gateway.dart` (new) | the only file importing `firebase_*` / `flutter_local_notifications` / `app_settings` |
| `lib/core/notifications/push/push_registration.dart` (new) | token lifecycle (sign-in, refresh, sign-out) |
| `lib/core/notifications/push/push_permission.dart` (new) | `PushPermissionPrompter`, `pushPermissionProvider` |
| `lib/core/notifications/push/push_tap_router.dart` (new) | tap → destination, cold-start queue, mark-read |
| `lib/core/notifications/push/push_bootstrap.dart` (new) | startup wiring (channels, streams, initial message) |
| `lib/core/notifications/push/push_banner_host.dart` (new) | foreground banner overlay |
| `lib/features/notifications/notification_models.dart` (new) | `BellNotification` (tolerant), link helpers |
| `lib/features/notifications/notifications_repository.dart` (new) | row reads (Supabase) + writes (ApiClient) behind an interface |
| `lib/features/notifications/notifications_providers.dart` (new) | viewer id, list notifier, realtime counter, mutes |
| `lib/features/notifications/notifications_screen.dart` (new) | the bell |
| `lib/features/notifications/notification_prefs_providers.dart`, `notification_settings_screen.dart` (new) | settings |
| `lib/features/notifications/push_permission_row.dart` (new) | shared passive permission row |
| `lib/features/notifications/notification_error_copy.dart` (new) | `error.code` → ARB copy |
| `lib/features/notifications/relative_time.dart` (new) | pure relative-time formatter |
| `test/**` mirroring the above, plus `test/fakes/fake_push_gateway.dart`, `test/fakes/fake_notifications_repository.dart` | |

---

### Task 0: Worktree, base, contract copy, dependencies, build paths

**Files:** modify `pubspec.yaml`, `api/openapi.json`, `android/settings.gradle.kts`, `android/app/build.gradle.kts`, `android/app/src/main/AndroidManifest.xml`; create `docs/agent-handoffs/2026-10-0X-phase5a-stage-d-handoff.md` (running log).

- [ ] **Step 1: Worktree.** `git worktree add ..\sentinelx_mobile-p5a -b phase5a/screens` from `master`; copy `android\app\google-services.json` from the main checkout into `..\sentinelx_mobile-p5a\android\app\` (verify `git status` does not list it).
- [ ] **Step 2: Contract.** `api/openapi.json` was copied from web `openapi/mobile-v1.json` on this plan's commit; confirm byte-identical to web `main`'s file (`git -C <web> show origin/main:openapi/mobile-v1.json | diff - api/openapi.json`) and that it contains the eight operations `getNotificationPrefs`, `patchNotificationPrefs`, `getNotificationMutes`, `postNotificationMute`, `deleteNotificationMute`, `postNotificationRead`, `postNotificationsReadAll`, `postTestPush`. If web `main` has moved, re-copy.
- [ ] **Step 3: Baseline.** `flutter pub get`, `flutter analyze`, `flutter test`; record the test count in the handoff log; `git checkout -- linux macos windows`.
- [ ] **Step 4: Dependencies.** `flutter pub add firebase_core firebase_messaging flutter_local_notifications app_settings`; confirm pins match the Tech Stack line (otherwise stop and report). `git checkout -- linux macos windows`. Do **not** commit yet — Task 3 commits the Android side with its build proof.
- [ ] **Step 5: Commit** only the contract copy now: `chore(api): pull the Phase 5a notification endpoints into the pinned contract`.

### Task 1: Models and `ApiClient` methods

**Files:** create `lib/core/api/notifications_models.dart`, `test/core/notifications_models_test.dart`, `test/core/api_client_notifications_test.dart`; modify `lib/core/api/api_client.dart` (append). Read `test/core/api_client_community_test.dart` first and copy its `_FakeAdapter` pattern.

**Interfaces — Produces:**
```dart
const kPushPrefKeys = <String>['match_reminder','result_confirmed','achievement_unlocked','challenge_completed',
  'new_announcement','tournament_announced','wager_settled','referral_converted','post_comment','post_reaction',
  'bracket_released','match_assigned','prize_credited','status_from_friend','status_viewed','new_follower','direct_message'];
const kWhatsappPrefKeys = <String>['match_reminder','result_confirmed','prize_credited','challenge_completed','achievement_unlocked','registration_confirmed'];
const kSharingPrefKeys = <String>['tournament','milestone','streak','social','other'];

enum PrefSection { push, whatsapp, achievementSharing } // wire names: push / whatsapp / achievementSharing

class NotificationPrefs {
  const NotificationPrefs({required this.push, required this.whatsapp, required this.achievementSharing});
  final Map<String, bool> push, whatsapp, achievementSharing;
  factory NotificationPrefs.fromJson(Map<String, dynamic> j);
  Map<String, bool> section(PrefSection s);
  NotificationPrefs withValue(PrefSection s, String key, bool value); // returns a copy
}
class MutedType { const MutedType(this.type, this.mutedUntil); final String type; final DateTime mutedUntil; }
class MutedPost { const MutedPost(this.postId, this.mutedUntil); final String postId; final DateTime mutedUntil; }
class NotificationMutes { const NotificationMutes({required this.types, required this.posts}); final List<MutedType> types; final List<MutedPost> posts;
  factory NotificationMutes.fromJson(Map<String, dynamic> j); bool isTypeMuted(String type, DateTime now); bool isPostMuted(String postId, DateTime now); }
enum MuteDuration { oneHour('1h'), oneWeek('1w'), always('always'); const MuteDuration(this.wire); final String wire; }
```
`ApiClient` (append; each listed in `usedOperations` with the exact `'method /api/mobile/v1/…'` string):
```dart
Future<NotificationPrefs> getNotificationPrefs();                          // 'getNotificationPrefs': 'get /api/mobile/v1/notifications/prefs'
Future<NotificationPrefs> patchNotificationPrefs(PrefSection s, Map<String,bool> values); // body {<sectionWire>: values}; 'patchNotificationPrefs': 'patch …/notifications/prefs'
Future<NotificationMutes> getNotificationMutes();                          // 'getNotificationMutes': 'get …/notifications/mutes'
Future<void> muteNotificationType(String type, MuteDuration d);            // POST mutes {scope:'type',type,duration}; 'postNotificationMute': 'post …/notifications/mutes'
Future<void> muteNotificationPost(String postId, MuteDuration d);          // POST mutes {scope:'post',postId,duration}
Future<void> unmuteNotificationType(String type);                          // DELETE mutes {scope:'type',type}; 'deleteNotificationMute': 'delete …/notifications/mutes'
Future<void> unmuteNotificationPost(String postId);                        // DELETE mutes {scope:'post',postId}
Future<void> markNotificationRead(String id);                              // POST /notifications/{id}/read; 'postNotificationRead': 'post …/notifications/{id}/read'
Future<int> markAllNotificationsRead();                                    // POST /notifications/read-all → data.updated; 'postNotificationsReadAll'
Future<void> sendTestPush();                                               // POST /notifications/test-push; 'postTestPush'
```
Path `{id}` must be URL-encoded (`Uri.encodeComponent`). None of these use `publicRequest` (all `auth: 'user'`) and none send an Idempotency-Key.

- [ ] **Step 1: Failing tests** (`notifications_models_test.dart`): `NotificationPrefs.fromJson` of a full server body gives 17/6/5 keys and `withValue` changes only that key and returns a new object; missing keys in a section are tolerated (treated absent, not crash) — a **newer server adding a key must not break parsing**; `NotificationMutes.fromJson` parses ISO timestamps; `isTypeMuted` is false for a past `mutedUntil` and true for a future one (`now` injected); an unparseable `mutedUntil` row is dropped, not fatal; the three key lists have lengths 17/6/5 and `kPushPrefKeys` contains no `status_removed`.
- [ ] **Step 2: Failing tests** (`api_client_notifications_test.dart`, via `_FakeAdapter`): for each method assert method, path, body (exact JSON, e.g. `patch` body `{"push":{"post_reaction":false}}`, mute body `{"scope":"type","type":"post_reaction","duration":"always"}`, unmute body has **no** `duration`), parsed result, and error mapping (`validation_failed` with `fields`; `404 not_found` for read). **Lesson 1:** for `getNotificationPrefs`, `getNotificationMutes`, `patchNotificationPrefs`, `markNotificationRead`, `markAllNotificationsRead`, `sendTestPush` assert the **`Authorization: Bearer …` header is present** (an `accessToken` supplier returning a token) — none may be public. Assert the id in the read path is encoded (`a/b` → `a%2Fb`).
- [ ] **Step 3:** run → fail (symbols missing). **Step 4:** implement (models with tolerant `fromJson`; methods appended after the Phase 4 block; `usedOperations` appended). **Step 5:** `flutter test test/core` incl. `api_contract_test.dart` → pass; analyze clean.
- [ ] **Step 6: Commit** `feat(api): notification prefs, mutes, read and test-push client methods`.

### Task 2: Copy (ARB en + fr) and error copy

**Files:** modify `lib/core/l10n/app_en.arb`, `app_fr.arb` (append), regenerate `lib/core/l10n/gen/*`; create `lib/features/notifications/notification_error_copy.dart`, `lib/features/notifications/relative_time.dart`, `test/features/notifications/notification_error_copy_test.dart`, `test/features/notifications/relative_time_test.dart`, `test/core/notifications_plurals_test.dart`.

ARB keys (en | fr). Plurals use ICU in both languages (`one` + `other`; French treats 0 and 1 as `one` — keep `one`/`other` and let gen-l10n's fr rules apply; assert with the plural test):

| key | en | fr |
|---|---|---|
| `ntfTitle` | Notifications | Notifications |
| `ntfMarkAllRead` | Mark all read | Tout marquer comme lu |
| `ntfMuteThread` | Mute this thread | Mettre ce fil en sourdine |
| `ntfUnmuteThread` | Unmute this thread | Réactiver ce fil |
| `ntfMuteType` | Mute this type | Mettre ce type en sourdine |
| `ntfUnmuteType` | Unmute this type | Réactiver ce type |
| `ntfMuteFor1h` | For 1 hour | Pendant 1 heure |
| `ntfMuteFor1w` | For 1 week | Pendant 1 semaine |
| `ntfMuteAlways` | Always | Toujours |
| `ntfMuted` | Muted | Mis en sourdine |
| `ntfUnmuted` | Unmuted | Réactivé |
| `ntfEmptyTitle` | You're all caught up | Vous êtes à jour |
| `ntfEmptyBody` | Fixture assignments, results and prizes show up here. | Les affectations de matchs, les résultats et les gains apparaissent ici. |
| `ntfLoadError` | Couldn't load your notifications. | Impossible de charger vos notifications. |
| `ntfRetry` | Try again | Réessayer |
| `ntfSignedOut` | Log in to see your notifications. | Connectez-vous pour voir vos notifications. |
| `ntfLogIn` | Log in | Se connecter |
| `ntfActionFailed` | That didn't work. Try again. | Ça n'a pas marché. Réessayez. |
| `ntfUnreadCount(count)` | `{count, plural, one{{count} unread notification} other{{count} unread notifications}}` | `{count, plural, one{{count} notification non lue} other{{count} notifications non lues}}` |
| `ntfTimeNow` | Just now | À l'instant |
| `ntfTimeMinutes(count)` | `{count, plural, one{{count} minute ago} other{{count} minutes ago}}` | `{count, plural, one{il y a {count} minute} other{il y a {count} minutes}}` |
| `ntfTimeHours(count)` | `{count, plural, one{{count} hour ago} other{{count} hours ago}}` | `{count, plural, one{il y a {count} heure} other{il y a {count} heures}}` |
| `ntfTimeDays(count)` | `{count, plural, one{{count} day ago} other{{count} days ago}}` | `{count, plural, one{il y a {count} jour} other{il y a {count} jours}}` |
| `ntfPermTitle` | Turn on notifications | Activer les notifications |
| `ntfPermBody` | Get fixture assignments and match reminders on this phone. | Recevez vos affectations de matchs et rappels sur ce téléphone. |
| `ntfPermEnable` | Turn on | Activer |
| `ntfPermOpenSettings` | Open system settings | Ouvrir les paramètres du système |
| `ntfPermOn` | Notifications are on for this phone. | Les notifications sont activées sur ce téléphone. |
| `ntfPermBlocked` | Notifications are turned off for this app in your phone settings. | Les notifications sont désactivées pour cette application dans les paramètres du téléphone. |
| `ntfSettingsTitle` | Notification settings | Paramètres de notification |
| `ntfSettingsEntry` | Notifications | Notifications |
| `ntfSectionPush` | Push notifications | Notifications push |
| `ntfSectionWhatsapp` | WhatsApp | WhatsApp |
| `ntfSectionSharing` | Share achievements to the community | Partager les succès avec la communauté |
| `ntfSaveFailed` | Couldn't save that change. | Impossible d'enregistrer ce changement. |
| `ntfTestAction` | Send a test notification | Envoyer une notification de test |
| `ntfTestSent` | Test sent — it should arrive in a moment. | Test envoyé — il devrait arriver dans un instant. |
| `ntfTestNoDevice` | This phone isn't registered for notifications yet. | Ce téléphone n'est pas encore enregistré pour les notifications. |
| `ntfTestFailed` | The test notification couldn't be delivered. | La notification de test n'a pas pu être livrée. |
| `ntfPushMatchReminder` | Match reminders | Rappels de match |
| `ntfPushResultConfirmed` | Result confirmed | Résultat confirmé |
| `ntfPushAchievementUnlocked` | Achievement unlocked | Succès débloqué |
| `ntfPushChallengeCompleted` | Weekly challenge completed | Défi hebdomadaire terminé |
| `ntfPushNewAnnouncement` | Community announcements | Annonces de la communauté |
| `ntfPushTournamentAnnounced` | New tournaments | Nouveaux tournois |
| `ntfPushWagerSettled` | Wager settled | Pari réglé |
| `ntfPushReferralConverted` | Referral converted | Parrainage converti |
| `ntfPushPostComment` | Comments on your posts | Commentaires sur vos publications |
| `ntfPushPostReaction` | Reactions on your posts | Réactions à vos publications |
| `ntfPushBracketReleased` | Bracket released | Tableau publié |
| `ntfPushMatchAssigned` | New fixture assigned | Nouveau match assigné |
| `ntfPushPrizeCredited` | Prize credited | Gain crédité |
| `ntfPushStatusFromFriend` | A friend posts a status | Un ami publie un statut |
| `ntfPushStatusViewed` | Someone views your status | Quelqu'un voit votre statut |
| `ntfPushNewFollower` | Someone follows you | Quelqu'un vous suit |
| `ntfPushDirectMessage` | Direct messages | Messages privés |
| `ntfWaMatchReminder` | Match reminders (1h before kickoff) | Rappels de match (1 h avant le coup d'envoi) |
| `ntfWaResultConfirmed` | Result confirmed | Résultat confirmé |
| `ntfWaPrizeCredited` | Prize credited to wallet | Gain crédité au portefeuille |
| `ntfWaChallengeCompleted` | Weekly challenge completed | Défi hebdomadaire terminé |
| `ntfWaAchievementUnlocked` | Achievement unlocked | Succès débloqué |
| `ntfWaRegistrationConfirmed` | Registration confirmed | Inscription confirmée |
| `ntfShareTournament` | Tournament wins | Victoires en tournoi |
| `ntfShareMilestone` | Milestone achievements (100 matches, etc.) | Succès d'étape (100 matchs, etc.) |
| `ntfShareStreak` | Streak achievements | Succès de série |
| `ntfShareSocial` | Social achievements (reactions, posts) | Succès sociaux (réactions, publications) |
| `ntfShareOther` | All other achievements | Tous les autres succès |
| `ntfChannelMatches` / `ntfChannelMatchesDesc` | Matches / Fixtures, reminders and results | Matchs / Affectations, rappels et résultats |
| `ntfChannelSocial` / `ntfChannelSocialDesc` | Community / Comments, reactions, followers and achievements | Communauté / Commentaires, réactions, abonnés et succès |
| `ntfChannelMessages` / `ntfChannelMessagesDesc` | Messages / Direct messages | Messages / Messages privés |
| `ntfChannelMoney` / `ntfChannelMoneyDesc` | Money / Prizes and referral rewards | Argent / Gains et récompenses de parrainage |
| `ntfChannelAdmin` / `ntfChannelAdminDesc` | Admin alerts / Staff-only alerts | Alertes admin / Alertes réservées au personnel |
| `ntfErrValidation` / `ntfErrNotFound` / `ntfErrNetwork` / `ntfErrGeneric` | That value isn't valid. / That notification no longer exists. / Check your connection and try again. / Something went wrong. | Cette valeur n'est pas valide. / Cette notification n'existe plus. / Vérifiez votre connexion et réessayez. / Une erreur est survenue. |
| `ntfBannerOpen` | Open | Ouvrir |

Pref-label lookup helpers (pure, in `notification_error_copy.dart` or a sibling `pref_labels.dart`): `String pushPrefLabel(AppLocalizations l, String key)`, `whatsappPrefLabel`, `sharingPrefLabel` — a `switch` per key with a `default:` returning the raw key so a future server key never throws.

- [ ] **Step 1: Failing tests.** `l10n_test.dart` (existing) must stay green — adding en keys without fr fails it, which is the point. New: `notifications_plurals_test.dart` pumps `AppLocalizations` en and fr and asserts `ntfUnreadCount(1)` = "1 unread notification" / "1 notification non lue", `ntfUnreadCount(3)` plural, same for `ntfTimeMinutes/Hours/Days` with 1 and 5 (lesson 7). `notification_error_copy_test.dart`: `notificationErrorCopy(l10n, 'validation_failed'|'not_found'|'network'|<unknown>)`. `relative_time_test.dart`: `relativeTime(l10n, created, now)` — <1 min ⇒ `ntfTimeNow`, 59 s ⇒ now, 60 s ⇒ 1 minute, 59 min, 60 min ⇒ 1 hour, 23 h, 24 h ⇒ 1 day, 40 days ⇒ "40 days ago"; a `created` in the future (clock skew) ⇒ now, never negative. Pref-label helpers: every key in `kPushPrefKeys`/`kWhatsappPrefKeys`/`kSharingPrefKeys` maps to a non-raw label, and an unknown key returns itself.
- [ ] **Step 2–4:** fail → add the ARB keys (en + fr), `flutter gen-l10n`, implement helpers → pass. **Step 5:** analyze + test; **Commit** `feat(notifications): ARB copy (en/fr), error and relative-time helpers`.

### Task 3: `PushGateway`, Firebase implementation, Android build

**Files:** create `lib/core/notifications/push/push_models.dart`, `push_gateway.dart`, `firebase_push_gateway.dart`, `test/fakes/fake_push_gateway.dart`, `test/core/push_channels_test.dart`, `test/core/disabled_push_gateway_test.dart`; modify `pubspec.yaml`, `android/settings.gradle.kts`, `android/app/build.gradle.kts`, `android/app/src/main/AndroidManifest.xml`.

**Interfaces — Produces:**
```dart
enum PushPermission { notDetermined, authorized, denied, deniedPermanently }

class PushMessage {
  const PushMessage({this.title, this.body, this.url, this.type});
  final String? title, body, url, type;
  /// `url` falls back to data['link'] (spec §3.7 accepts a future `link`); blank strings become null.
  factory PushMessage.fromData(Map<String, dynamic> data, {String? title, String? body});
}

class PushChannel { const PushChannel({required this.id, required this.nameKey, required this.descriptionKey, required this.highImportance}); ... }
const kPushChannelIds = ['matches_v1', 'social_v1', 'messages_v1', 'money_v1', 'admin_v1'];

abstract class PushGateway {
  bool get isAvailable;
  Future<String?> getToken();
  Stream<String> get onTokenRefresh;
  Future<PushPermission> permission();
  Future<PushPermission> requestPermission();
  Stream<PushMessage> get onForegroundMessage;
  Stream<PushMessage> get onMessageOpened;     // background taps
  Future<PushMessage?> getInitialMessage();    // terminated tap
  Future<void> createChannels(List<PushChannelSpec> channels); // PushChannelSpec = resolved id/name/description/importance
  Future<void> openSystemSettings();
}
class DisabledPushGateway implements PushGateway { const DisabledPushGateway(); /* isAvailable false; getToken null; streams empty; permission denied; everything else no-op */ }
final pushGatewayProvider = Provider<PushGateway>((ref) => const DisabledPushGateway());
```
`FirebasePushGateway.tryInitialize()` → `Future<PushGateway>`: `try { await Firebase.initializeApp().timeout(10s); return FirebasePushGateway._(...) } catch (e, s) { debugPrint(...); return const DisabledPushGateway(); }`. Every method of the Firebase gateway wraps the plugin call in try/catch and returns a safe default (null token, `denied`, empty stream) — an FCM failure must not crash a screen. Status mapping: `AuthorizationStatus.authorized|provisional → authorized`, `notDetermined → notDetermined`, `denied → denied`, `deniedPermanently → deniedPermanently`. `onMessageOpened` = `FirebaseMessaging.onMessageOpenedApp`; `onForegroundMessage` = `FirebaseMessaging.onMessage`; `createChannels` uses `FlutterLocalNotificationsPlugin().resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.createNotificationChannel(AndroidNotificationChannel(id, name, description: …, importance: high ? Importance.high : Importance.defaultImportance))` — it must not request permission. `openSystemSettings` → `AppSettings.openAppSettings(type: AppSettingsType.notification)`.

- [ ] **Step 1: Failing tests.** `push_channels_test.dart`: `kPushChannelIds` equals exactly `['matches_v1','social_v1','messages_v1','money_v1','admin_v1']` (a literal copy of web's `ANDROID_CHANNEL_IDS`; comment names the web file) and `kPushChannels` has one entry per id with unique ids; `PushMessage.fromData` — `url` preferred, falls back to `link`, blank → null, non-string values ignored, missing everything → all-null message (never throws); `DisabledPushGateway` returns the safe defaults and its streams are empty and closable. No test touches Firebase.
- [ ] **Step 2–3:** fail → implement models/gateway/fake (`FakePushGateway` in `test/fakes/`: controllable `permissionResult`, recorded `requestPermissionCalls`, `openSettingsCalls`, `createdChannels`, `StreamController`s for token refresh / foreground / opened, settable `initialMessage`, `token`).
- [ ] **Step 4: Android build wiring** — edits:
  - `settings.gradle.kts` plugins block: `id("com.google.gms.google-services") version "4.4.4" apply false`.
  - `android/app/build.gradle.kts`: after the `plugins { }` block add
    ```kotlin
    // Applied only when the Firebase config is present, so a fresh clone / CI without
    // google-services.json still builds (push is then disabled at runtime; see FirebasePushGateway).
    if (file("google-services.json").exists()) {
        apply(plugin = "com.google.gms.google-services")
    }
    ```
    inside `android { compileOptions { isCoreLibraryDesugaringEnabled = true … } }` and `dependencies { coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4") }` (add the `dependencies` block).
  - `AndroidManifest.xml`: inside `<application>` add `<meta-data android:name="com.google.firebase.messaging.default_notification_channel_id" android:value="social_v1"/>` (a push whose type has no channel falls back to a channel that exists).
- [ ] **Step 5: Build proof (both paths, record outputs in the handoff).** (a) With `android/app/google-services.json` present: `flutter build apk --debug` succeeds. (b) Move the file aside (`Rename-Item`), `flutter build apk --debug` succeeds again, **restore the file**. If either fails, stop and report — do not paper over it. Confirm `git status` shows no `google-services.json`.
- [ ] **Step 6:** `flutter analyze`, `flutter test`; **Commit** `feat(push): PushGateway, tolerant Firebase implementation, Android wiring (conditional google-services)`.

### Task 4: Registration lifecycle (sign-in, token refresh, sign-out)

**Files:** create `lib/core/notifications/push/push_registration.dart`, `test/core/push_registration_test.dart`; modify `lib/features/account/account_screen.dart` (sign-out hook, minimal hunk), `test/features/account_screen_test.dart` (append).

**Interfaces — Produces:**
```dart
class PushRegistration {
  PushRegistration(Ref ref);                       // listens to sessionProvider (like SessionLifecycle) and gateway.onTokenRefresh
  Future<void> unregister();                       // best-effort DELETE /devices for this token; never throws; ≤ 5 s
}
final pushRegistrationProvider = Provider<PushRegistration>(...);   // dispose closes subscriptions
```
Behavior: when the signed-in **user id** becomes non-null and differs from the last registered id → `gateway.getToken()` → `api.registerDevice(token:, platform:, appVersion:)` (`platform` = `ios` only on `TargetPlatform.iOS`, else `android`; `appVersion` = `installedVersionProvider`). A failed register clears the guard so the next session/token event retries (mirror `SessionLifecycle`). A token refresh while signed in registers the new token. `isAvailable == false` ⇒ nothing is ever sent. `unregister()` deletes the cached/current token and clears the guard; a failure/timeout is swallowed. Signing in as a different user on the same phone (no sign-out between, or after one) registers the same token again for the new user id.

- [ ] **Step 1: Failing tests** (fake gateway + fake `ApiClient` recording `registerDevice`/`unregisterDevice`; follow `session_lifecycle_test.dart` for the session override): registers once on first signed-in value; **not** again on a token-refreshed `Session` for the same user id (duplicate session emissions); registers again when the token refreshes (new token string); account switch A → B registers B with the same token; sign-out then sign-in registers again; register failure then a later session event retries; `isAvailable == false` sends nothing; `unregister()` calls `unregisterDevice(currentToken)` and **swallows** a thrown `ApiException`/timeout (use `fake_async` for the 5 s bound) and returns normally; signed-out ⇒ no register.
- [ ] **Step 2: Failing tests (account screen, append):** tapping sign-out calls `unregister()` **before** `signOut()` (record call order in fakes); **sign-out failure of the device call does not block sign-out** (`unregister` completes normally even when the API throws, `signOut` still called, no error text shown); an existing test for a `signOut` failure still shows `accountSignOutFailed`.
- [ ] **Step 3–5:** implement; in `account_screen.dart` `_signOut`: `await ref.read(pushRegistrationProvider).unregister();` immediately before `ref.read(authRepositoryProvider).signOut()` inside the existing `try`; **Commit** `feat(push): token registration lifecycle and sign-out unregister`.

### Task 5: Permission prompter and the three stake triggers

**Files:** create `lib/core/notifications/push/push_permission.dart`, `test/core/push_permission_test.dart`; modify `lib/features/compete/registration_flow.dart` (two hook lines), `test/features/compete/registration_flow_test.dart` (append — find the existing flow test file with `ls test/features/compete`).

**Interfaces — Produces:**
```dart
class PushPermissionPrompter {
  PushPermissionPrompter(Ref ref);
  /// Contextual ask at a confirmed stake. Asks only when signed in, the gateway is available, status is
  /// notDetermined, and it has not already asked during this process. Never throws.
  Future<void> onStake();
  /// User-initiated (bell empty state, settings row). authorized → no-op; notDetermined → system dialog;
  /// denied/deniedPermanently → try the dialog once, and if still not authorized open system settings.
  Future<PushPermission> enableFromUser();
}
final pushPermissionPrompterProvider = Provider<PushPermissionPrompter>(...);
/// Current OS status for passive UI; callers invalidate it on app resume and after enableFromUser.
final pushPermissionProvider = FutureProvider.autoDispose<PushPermission>((ref) => ref.watch(pushGatewayProvider).permission());
```
Hooks: in `RegistrationFlow._finishConfirmed()` and in `submitWaitlist`'s success branch (after `state = waitlisted`): `unawaited(ref.read(pushPermissionPrompterProvider).onStake());`. Invitation accepts reach `_finishConfirmed` through `_run`, so the three stakes (register, waitlist join, invitation accept) are all covered; a register that goes through Paystack only fires on confirmed payment, not on `awaitingPayment`/`cancelled`/`notConfirmed`/`failed`.

- [ ] **Step 1: Failing tests** (`push_permission_test.dart`, fake gateway): `onStake` with `notDetermined` calls `requestPermission` once; with `authorized` (also the pre-API-33 case) / `denied` / `deniedPermanently` calls it **never** (the API gate and never-re-ask rules); two `onStake` calls back to back, and one concurrent with the first still in flight, call it **once** (double stake); a second `onStake` after the dialog returned `denied` does not ask again; signed-out ⇒ never asks; `isAvailable == false` ⇒ never asks; gateway throwing ⇒ `onStake` completes without throwing. `enableFromUser`: authorized ⇒ no dialog, no settings; notDetermined ⇒ dialog only; denied ⇒ dialog then, still not authorized, `openSystemSettings` called once; deniedPermanently ⇒ settings opened and the result returned; dialog result `authorized` ⇒ settings not opened.
- [ ] **Step 2: Failing tests (registration flow, append):** with a fake prompter recording calls and the existing fake `RegistrationRepository`: confirmed registration ⇒ one `onStake`; waitlist join ⇒ one; invitation accept confirmed ⇒ one; **not** called on `awaitingPayment`, `failed`, `cancelled`, `notConfirmed`; a payment confirmed after polling ⇒ one.
- [ ] **Step 3–5:** implement; **Commit** `feat(push): contextual permission prompt at the first confirmed stake`.

### Task 6: Tap routing (incl. cold start), foreground banner, web-link mapping

**Files:** create `lib/core/notifications/push/push_tap_router.dart`, `push_bootstrap.dart`, `push_banner_host.dart`, `test/core/push_tap_router_test.dart`, `test/core/push_bootstrap_test.dart`, `test/core/push_banner_host_test.dart`; modify `lib/core/routing/web_links.dart` (+1 case), `test/core/web_links_test.dart` (append), `lib/app.dart` (wrap builder child), `lib/main.dart`.

**Interfaces — Produces:**
```dart
/// Pure: where a tapped push goes. resolveWebLink(url) ?? '/notifications' (url null/blank/unmappable → bell).
String destinationFor(PushMessage m);

class PushTapRouter {
  PushTapRouter(Ref ref);
  void onTap(PushMessage m);   // queues until markReady(); then routes immediately
  void markReady();            // flushes at most the latest queued tap, exactly once
}
final pushTapRouterProvider = Provider<PushTapRouter>(...);
final foregroundPushProvider = NotifierProvider<ForegroundPushController, PushMessage?>(...); // show(m) / dismiss(); auto-dismiss after 5 s
final pushBootstrapProvider = Provider<void>(...);  // see below
```
`PushTapRouter._route`: `ref.read(routerProvider).go(destinationFor(m))`, then fire-and-forget `ref.read(notificationsRepositoryProvider).markReadForLink(url)` when `url != null` (errors swallowed — Task 7 owns the method; until Task 7 lands it is a no-op stub on the interface). **Readiness** (`pushBootstrapProvider`): `await ref.read(sessionProvider.future)`; if a session exists `await ref.read(meProvider.future)` (errors swallowed); then `tapRouter.markReady()`. **If signed out when settled, the queued tap is dropped** (nothing to open; the player lands on the default screen). Bootstrap also: `gateway.createChannels(resolvedChannels)` (names/descriptions from `lookupAppLocalizations(PlatformDispatcher.instance.locale)`, falling back to `en`), subscribes `onMessageOpened` → `tapRouter.onTap`, `onForegroundMessage` → `foregroundPushProvider.show`, and `getInitialMessage()` → `tapRouter.onTap`. Wrapped end-to-end in try/catch — a failing gateway never breaks startup. `main.dart`: `final gateway = await FirebasePushGateway.tryInitialize();` before `ProviderContainer`; override `pushGatewayProvider.overrideWithValue(gateway)`; after `runApp`: `container.listen(pushBootstrapProvider, (_, _) {});` and `container.listen(pushRegistrationProvider, (_, _) {});` (Riverpod 3 pauses unlistened providers — same note as `sessionLifecycleProvider`). `app.dart` builder: `AppGate(child: PushBannerHost(child: child ?? const SizedBox.shrink()))`.
`web_links.dart`: add one case `'dashboard/settings'` ⇒ `'/account/notifications'` (exact match only; `/dashboard/settings/x` stays `null`).
`PushBannerHost`: a `Stack` over its child; when `foregroundPushProvider` has a message, a `Material` banner anchored under the status bar (`SafeArea`, `Key('push-banner')`, title + body, `ntfBannerOpen`), tap ⇒ `tapRouter.onTap(message)` + dismiss; auto-dismisses after 5 s; a new message replaces the visible one and restarts the timer.

- [ ] **Step 1: Failing tests — `web_links_test.dart` (append):** `/dashboard/settings` and `https://sentinelxesports.com.ng/en/dashboard/settings` ⇒ `/account/notifications`; `/dashboard/settings/extra`, `/dashboard/wallet`, `/messages/abc`, `/admin/matches/1/review`, `/exchange/abc` ⇒ `null`; **in-app paths pass through untouched (lesson 8):** `/notifications`, `/account/notifications`, `/account` ⇒ `null`; existing community rules unchanged.
- [ ] **Step 2: Failing tests — `push_tap_router_test.dart`:** `destinationFor`: `/matches/m1` ⇒ `/matches/m1`; `/community/<uuid>` ⇒ post; null url ⇒ `/notifications`; blank url ⇒ `/notifications`; `/dashboard/wallet` ⇒ `/notifications`; absolute web URL with locale prefix resolves. Router behavior with a `GoRouter` test double (record `go` locations): **foreground/background taps** after ready route immediately; a **tap before ready routes nothing**, then `markReady()` routes **exactly once** to the destination (Review Focus 1); two taps before ready ⇒ only the latest is routed; `markReady()` twice ⇒ no second route; routing triggers `markReadForLink(url)` once for a mapped link and also for an unmapped one, never for a null url; a throwing `markReadForLink` does not throw out of `onTap`.
- [ ] **Step 3: Failing tests — `push_bootstrap_test.dart`** (fake gateway; `sessionProvider` / `meProvider` overridden with controllable completers): channels created once with exactly the five ids and localized names; **cold start while signed in:** gateway `initialMessage` set ⇒ no route until session **and** `/me` have resolved, then exactly one `go` to the destination, and **no intermediate `/login` or `/onboarding/username` location** is ever visited (drive a real `buildAppRouter` with `authGate` wired to the same state, or assert the recorded locations); cold start **signed out** ⇒ never routes; `onMessageOpened` event ⇒ routes (after ready); `onForegroundMessage` event ⇒ `foregroundPushProvider` shows it; a gateway whose `getInitialMessage` throws ⇒ bootstrap still completes and later taps still work; `DisabledPushGateway` ⇒ no work, no throw.
- [ ] **Step 4: Failing tests — `push_banner_host_test.dart`:** a foreground message shows `push-banner` with title and body; tap routes via the tap router and hides it; hides itself after 5 s (`pump(Duration(seconds: 5))`); a second message replaces the first and restarts the timer; null title/body ⇒ the banner still renders with whatever exists (never throws); with no message nothing is rendered and the child is untouched.
- [ ] **Step 5–6:** implement; `flutter analyze`, `flutter test`; **Commit** `feat(push): tap routing with cold-start queue, foreground banner, startup wiring`.

### Task 7: Notifications repository and providers

**Files:** create `lib/features/notifications/notification_models.dart`, `notifications_repository.dart`, `notifications_providers.dart`, `test/fakes/fake_notifications_repository.dart`, `test/features/notifications/notification_models_test.dart`, `notifications_providers_test.dart`, `notifications_repository_test.dart`.

**Interfaces — Produces:**
```dart
class BellNotification {
  const BellNotification({required this.id, required this.type, required this.title, required this.body, this.link, required this.read, required this.createdAt});
  final String id, type, title, body; final String? link; final bool read; final DateTime createdAt;
  /// Tolerant: null/odd title,body → ''; unknown `type` kept verbatim; bad `created_at` → epoch; non-bool `read` → false.
  /// Returns null only when `id` is missing (a row without an id cannot be acted on).
  static BellNotification? tryParse(Map<String, dynamic> row);
  BellNotification copyWith({bool? read});
  /// postId when `link` is a web path /community/<uuid> (with optional locale prefix / host), else null.
  String? get postId;
  /// True when `type` is one of kPushPrefKeys (the only types the server lets you mute).
  bool get typeMutable;
}

abstract class NotificationsRepository {
  Future<List<BellNotification>> page({required int offset, required int limit}); // newest first, owner rows only
  Future<void> markRead(String id);
  Future<int> markAllRead();
  Future<void> markReadForLink(String link);   // newest unread own row with that link → markRead(id); no-op if none
  Future<NotificationMutes> mutes();
  Future<void> muteType(String type, MuteDuration d);  Future<void> unmuteType(String type);
  Future<void> mutePost(String postId, MuteDuration d); Future<void> unmutePost(String postId);
  Future<NotificationPrefs> prefs();
  Future<NotificationPrefs> patchPrefs(PrefSection s, Map<String,bool> values);
  Future<void> sendTestPush();
}
final notificationsRepositoryProvider = Provider<NotificationsRepository>(...); // Supabase reads + ApiClient writes

final notificationsViewerIdProvider = FutureProvider.autoDispose<String?>((ref) async => (await ref.watch(sessionProvider.future))?.user.id);

class BellState { final List<BellNotification> items; final bool hasMore, loadingMore; ... copyWith }
class NotificationsNotifier extends AsyncNotifier<BellState> {
  Future<void> loadMore();
  Future<void> refreshInPlace();            // re-reads the loaded window [0, max(loaded, 20)) in place; serialised with loadMore
  Future<bool> refresh();                   // pull-to-refresh; never throws; false on failure
  Future<bool> markRead(String id);         // optimistic; rollback reverts ONLY this row's `read` and only if still true
  Future<bool> markAllRead();               // optimistic on all currently-loaded unread rows; rollback reverts only those ids still read
}
final notificationsProvider = AsyncNotifierProvider.autoDispose<NotificationsNotifier, BellState>(NotificationsNotifier.new);
final notificationsRealtimeProvider = StreamProvider.autoDispose<int>(...);   // counter via tickSignal-style numbering
final notificationMutesProvider = FutureProvider.autoDispose<NotificationMutes?>(...); // watches viewer id; null signed out
```
Repository details: `page` is `from('player_notifications').select('id, type, title, body, link, read, created_at').eq('player_id', userId).order('created_at', ascending: false).range(offset, offset + limit - 1)`; `userId` comes from the current session (null ⇒ `[]`); malformed rows are skipped via `tryParse`, never fatal (Review Focus 2). `markReadForLink` queries `…eq('player_id', me).eq('read', false).eq('link', link).order('created_at', ascending: false).limit(1)`. Writes call `ApiClient` (Task 1). Realtime: `client.channel('ntf-bell-$userId').onPostgresChanges(event: all, schema: 'public', table: 'player_notifications', filter: PostgresChangeFilter(type: eq, column: 'player_id', value: userId))`, debounced 400 ms (reuse the idea of `debouncedChangeSignal`; **do not import it from `features/community`** — copy the ~25 lines into this feature or lift it to `lib/core/notifications/` in the same commit with the community import left untouched), numbered with a counter.
`NotificationsNotifier.build` awaits `notificationsViewerIdProvider.future` (lesson 3: rebuild on login/logout/account switch, not on token refresh), returns an empty `BellState` for a signed-out viewer, and `ref.listen(notificationsRealtimeProvider, (_, _) => refreshInPlace())`. Every mutator no-ops when `!ref.mounted`, resolves the repository **at build/entry** (never from a disposed widget's `ref`), and never replaces state with a stale tap-time snapshot (lesson 4).

- [ ] **Step 1: Failing tests — models:** `tryParse` of a full row; unknown `type` kept; null title/body ⇒ `''`; missing id ⇒ `null`; bad/missing `created_at` ⇒ epoch (no throw); `read` as non-bool ⇒ false; `postId` for `/community/<uuid>`, `https://sentinelxesports.com.ng/fr/community/<uuid>`, and `null` for `/community/compose`, `/matches/x`, null link, garbage; `typeMutable` true for `post_reaction`, false for `status_removed`, `direct_message` true, `something_new` false.
- [ ] **Step 2: Failing tests — repository** (fake Supabase layer or a thin query-builder fake; if the Supabase builder is impractical to fake, extract a tiny `NotificationRowSource` interface and fake that — decide by reading `test/core/unread_counts_test.dart`): `page` selects the named columns only, filters by the signed-in id, orders newest first, uses the right range; signed-out returns `[]` without querying; malformed rows skipped. `markReadForLink` finds the newest unread row for the link and calls `markRead` with its id; no row ⇒ no API call; row lookup error ⇒ swallowed.
- [ ] **Step 3: Failing tests — notifier** (fake repository, `ProviderContainer`): initial page of 20 ⇒ `hasMore`; `loadMore` appends and de-duplicates across the page boundary; **realtime refresh keeps the loaded window and does not reset to page one** (load 40, emit a tick, still 40, and a new row appears at the top); **two consecutive realtime ticks both refresh** (lesson 2 — counter provider); a realtime refresh arriving **during** `loadMore` is queued, runs after, and loses no row (lesson 5); `markRead` is optimistic (row read immediately) and on failure reverts only that row; **rollback never clobbers fresher data** (row re-fetched meanwhile as read by realtime, then the failed call returns ⇒ stays read? — the rule is: revert only if the row is still in the state we set; assert the exact chosen behavior with a test and comment); `markAllRead` optimistic and rollback reverts only the ids it flipped; `markRead`/`markAllRead` on a disposed notifier do nothing and do not throw; signed-out viewer ⇒ empty state; **account switch:** viewer id A → B ⇒ list refetched (fake records the second `page` call) while a token refresh for the same id does not refetch; refresh failure keeps the last good list.
- [ ] **Step 4–5:** implement; analyze/test; **Commit** `feat(notifications): bell repository, tolerant models, paging/read/realtime providers`.

### Task 8: Bell screen, bell wiring, route

**Files:** create `lib/features/notifications/notifications_screen.dart`, `push_permission_row.dart`, `test/features/notifications/notifications_screen_test.dart`, `push_permission_row_test.dart`; modify `lib/router/app_router.dart` (append route), `lib/shared/widgets/sx_tab_app_bar.dart`, `test/router/app_router_test.dart` (append); read `test/support/pump_app.dart` for the router pumping helper.

Screen behavior (`Key`s in brackets): `AppBar` title `ntfTitle` with a "Mark all read" action (`ntf-mark-all`, disabled when nothing is unread or while in flight); body: `RefreshIndicator` over a `ListView.builder` — row (`ntf-row-<id>`): unread dot, title, body (2 lines, ellipsized — long titles/bodies must not overflow at 375px), relative time (`relativeTime`), overflow `PopupMenuButton` (`ntf-menu-<id>`) with: **"Mute this thread"** only when `postId != null`, **"Mute this type"** only when `typeMutable` — each opens a bottom sheet of the three durations (`ntf-mute-1h|1w|always`); when already muted (mutes provider timed row, or `prefs.push[type] == false`) the item reads **"Unmute …"** and unmutes directly. Tap row: optimistic `markRead` then navigate — **unmapped/null link ⇒ stay in the bell** (do nothing beyond marking read), mapped ⇒ `context.push(resolveWebLink(link))` (push, so Back returns to the bell). Near the end of the list `loadMore` fires (with a trailing spinner row). States: loading spinner; **error** (`ntfLoadError` + `ntfRetry`, `ntf-retry`); **signed out** (`ntfSignedOut` + `ntfLogIn` ⇒ `context.push('/login')`, never an error); **empty** (`ntfEmptyTitle/Body` + the passive `PushPermissionRow`). Action failures show `notificationErrorCopy` in a `SnackBar`; success of a mute shows `ntfMuted`/`ntfUnmuted`. `PushPermissionRow` (shared, `ntf-perm-row`): hidden when `!gateway.isAvailable` or status is `authorized` (empty-state variant may show `ntfPermOn`? — **no**: authorized ⇒ hidden); `notDetermined`/`denied` ⇒ title/body + `ntfPermEnable` (`ntf-perm-enable`) calling `enableFromUser()`; `deniedPermanently` ⇒ `ntfPermBlocked` + `ntfPermOpenSettings`; it is a `WidgetsBindingObserver` that **invalidates `pushPermissionProvider` on `AppLifecycleState.resumed`**, so returning from system settings with it now on hides the row (Review Focus 5).
`sx_tab_app_bar.dart`: the notification bell's `onPressed` becomes `() => GoRouter.of(context).push('/notifications')` (keep `Key('bell-notifications')`, the count badge, and give the icon a `Semantics`/`tooltip` of `ntfUnreadCount(count)`); the **messages bell stays on coming-soon** until 5b. If any existing test pumps `SxTabAppBar` without a router, give `_BellIcon` an injectable `onPressed` and have tests pass one (find with `grep -rn "SxTabAppBar\|bell-notifications" test lib`).
Route: top-level `GoRoute(path: '/notifications', builder: (_, _) => const NotificationsScreen())`, appended beside `/invitations` (outside the shell, like it, so Back returns to where the bell was tapped).

- [ ] **Step 1: Failing widget tests** (fake repository + overrides; real `AppLocalizations` en, plus one fr smoke): renders rows newest first with unread dot only on unread; **unknown type** row renders title/body and tapping it with a null link marks read and stays on the screen (Review Focus 2); a row with a very long title/body and a long unbroken string does not overflow at 375×800; tap a mapped link (`/matches/m1`) pushes `/matches/m1` and the row becomes read; tap an **unmapped** link (`/dashboard/wallet`) navigates nowhere; menu shows "Mute this thread" only for a `/community/<uuid>` link and "Mute this type" only for mutable types; muting calls the repository with the right scope/duration and shows `ntfMuted`; already-muted type shows "Unmute" and calls unmute; **mark all read** flips every row and the action disables; mark-read failure reverts the row and shows the failure copy; paging: scrolling near the end calls `page` with offset 20; **empty** state shows `ntfEmptyTitle` and the permission row (fake status `notDetermined`), tapping enable calls `requestPermission`, `deniedPermanently` shows open-settings and tapping it calls `openSystemSettings`, `authorized` hides the row, a `resumed` lifecycle event with status now `authorized` hides it (simulate with `tester.binding.handleAppLifecycleStateChanged`); **error** state shows retry and retry refetches; **signed out** shows the login CTA and `context.push('/login')` on tap; pull-to-refresh refetches; a plural check: header/semantics for 1 vs 3 unread.
- [ ] **Step 2: Router test (append):** `/notifications` builds `NotificationsScreen`; Back from it returns to the previous location; `resolveWebLink('/notifications')` is `null` so the redirect leaves it alone; tapping the app bar bell from a tab pushes `/notifications`.
- [ ] **Step 3–5:** implement; analyze/test; **Commit** `feat(notifications): bell screen at /notifications with mute menu and permission row`.

### Task 9: Settings → Notifications

**Files:** create `lib/features/notifications/notification_prefs_providers.dart`, `notification_settings_screen.dart`, `test/features/notifications/notification_prefs_providers_test.dart`, `notification_settings_screen_test.dart`; modify `lib/router/app_router.dart` (child route `notifications` under `/account`), `lib/features/account/account_screen.dart` (one `ListTile`), `test/features/account_screen_test.dart` (append).

**Interfaces — Produces:**
```dart
class NotificationPrefsNotifier extends AsyncNotifier<NotificationPrefs?> {   // null when signed out
  Future<bool> set(PrefSection s, String key, bool value);   // optimistic; PATCH {section:{key:value}}
}
final notificationPrefsProvider = AsyncNotifierProvider.autoDispose<NotificationPrefsNotifier, NotificationPrefs?>(...); // watches notificationsViewerIdProvider
```
`set` rule (lesson 4): record `before = current[section][key]`; apply `value`; call `patchPrefs`; on failure revert **only that key**, **only if the current value is still `value`** (a later toggle or refresh wins), never restoring a snapshot of the whole object; on success **do not replace state with the server body** (it could clobber a fresher local toggle) — only keys the server returned that differ from local *and* have no in-flight change are not touched either; keep it simple: success leaves local state as is. Same-key rapid toggles are serialised per key (the second waits for the first to finish) so responses cannot arrive out of order. Mutator is a no-op when `!ref.mounted`; the screen resolves the notifier at build (`final notifier = ref.read(notificationPrefsProvider.notifier)` captured in the toggle callback's closure creation, not read from a disposed `ref` after an `await`).
Screen (`/account/notifications`, `Key`s): permission row (`PushPermissionRow`) first; section **Push** (17 `SwitchListTile`s `ntf-push-<key>`), **WhatsApp** (6, `ntf-wa-<key>`), **Share achievements** (5, `ntf-share-<key>`) with labels from the Task 2 helpers; **Send a test notification** (`ntf-test-push`, disabled while in flight): success ⇒ `ntfTestSent`, `not_found` ⇒ `ntfTestNoDevice`, any other failure ⇒ `ntfTestFailed`; states: loading, error + retry, signed-out login CTA. A toggle failure shows `ntfSaveFailed` and the switch returns to its previous value.
Account tile: `ListTile(key: Key('account-notifications'), title: ntfSettingsEntry, onTap: push('/account/notifications'))` placed after "My progress" (only for a signed-in `me`).

- [ ] **Step 1: Failing tests — notifier:** 17/6/5 keys exposed; `set` is optimistic (state changes before the future completes — use a `Completer`); success calls `patchPrefs` with exactly `(section, {key: value})`; **failure reverts only that key** while a different key toggled in the meantime stays; **failure after the same key was toggled again** does not revert (current value ≠ the failed value); two rapid toggles of the same key reach the API in order; disposed notifier ⇒ no-op, no throw; signed-out ⇒ `null`; **account switch** A → B refetches and does not show A's values.
- [ ] **Step 2: Failing tests — screen:** renders all 28 switches with labels (en) and a fr smoke; toggling flips immediately and sends the patch; failing patch flips back and shows `ntfSaveFailed`; test notification success / `not_found` / failure copy and disabled-while-in-flight (no double-tap sends two); permission row states as in Task 8; error + retry; signed-out CTA; long French labels at 375px do not overflow. **Account screen (append):** tile shown for signed-in `me`, hidden when signed out, tap pushes `/account/notifications`. **Router (append):** route builds the screen.
- [ ] **Step 3–5:** implement; analyze/test; **Commit** `feat(notifications): Settings → Notifications with optimistic toggles and test push`.

### Task 10: Docs, full verification, review, handoff

- [ ] **Step 1:** Update `README.md` (push setup: the file location, the conditional plugin, `--dart-define` for staging, the no-file behavior) and `TESTING-NOTES.md` (device-pass checklist from the web spec §6: test push in foreground / background / terminated; tap routing from each including a cold start while signed in; account switch on one phone; a real fixture assignment; the open item that the staging web deployment must send with Firebase project `sentinelx-f061e`'s credentials; the unverified list below). Add `CLAUDE.md` route-map rows for `/notifications` and `/account/notifications` and a one-line "Phase 5a" note (tripwires: push never required to boot; `google-services.json` untracked by design).
- [ ] **Step 2: Full verification** in the worktree: `flutter analyze` (clean), `flutter test` (all pass; report the count vs. the Task 0 baseline), **`flutter build apk --debug` with and without `google-services.json`** (restore it after), `git checkout -- linux macos windows`, `git status` shows no `google-services.json`.
- [ ] **Step 3: Fresh-context review** (`/code-review`, high effort) of the whole branch against this plan's Review Focus and Phase 4 lessons 1–10; verify each finding by reading code or a test before acting (lesson 10); fix; re-run Step 2.
- [ ] **Step 4: Handoff note** `docs/agent-handoffs/2026-10-0X-phase5a-stage-d-handoff.md`: branch + HEAD, test counts, review findings and fixes, every Ruling (this plan's 10 plus any new), what's deferred, and **what is not verified**: live FCM delivery, Doze/OEM battery behavior, channel behavior on a real device, the Android 13+ dialog and its denied/permanently-denied transitions, cold-start tap from a killed app, the staging Firebase credentials, iOS (shape only), the actual rendering of the status-bar icon.
- [ ] **Step 5: Merge to `master` and push immediately (no PR)** — only after review and green. Report to the owner.

---

## Self-review (spec ↔ plan)

- Spec §3.5 permission (once, any of the three stakes, API gate, never re-ask, passive rows, package verified) → Global Constraints + Tasks 5, 8, 9. §3.6 lifecycle (sign-in, refresh, sign-out before clear, failure tolerated, no `locale`) → Task 4 (`registerDevice` sends no locale). §3.7 tap routing (foreground/background/terminated, queue until session and `/me` settle, unmappable → bell, mark read) → Task 6 + Task 7 `markReadForLink`. §3.4 channels (five, versioned, created at startup) → Tasks 3, 6. §4 endpoints → Task 1 (all eight in `usedOperations`) with consumers in Tasks 7–9. §5 bell, badge unchanged, settings, push service, realtime, copy, packages → Tasks 3–9. §6 tests → per-task test lists. §8 open items 1 and 5 resolved here with evidence (Rulings 1–2); 3 resolved by Stage B Ruling 3; 4 remains an owner check (Task 10 notes).
- Names are consistent across tasks: `PushGateway`, `PushPermission`, `PushMessage`, `PushRegistration`, `PushPermissionPrompter` (`onStake`, `enableFromUser`), `PushTapRouter` (`onTap`, `markReady`), `NotificationsRepository` (`markReadForLink` referenced by Task 6, defined in Task 7), `NotificationPrefs`/`PrefSection`/`MuteDuration` (Task 1), providers `notificationsViewerIdProvider`, `notificationsProvider`, `notificationPrefsProvider`, `pushPermissionProvider`.
- No placeholders: every task states files, interfaces, exact behaviors and the failing tests to write first; implementation bodies for the screens are specified by behavior and keys (the plan author deliberately did not paste ~600 lines of widget code the executor would write test-first anyway).
