# Mobile Phase 5c (Flutter) — Guide quests, coach marks and support chat Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give the Flutter app the Battle Ready quest (checklist, claim, Home card), first-run coach marks, a signed-out visitor tour, avatar upload (which quest step 1 needs), and the streamed support chat with history, chips and the equipped mascot skin.

**Architecture:** Everything goes through `/api/mobile/v1` via `ApiClient` (never PostgREST; avatar bytes go to the `avatars` storage bucket under RLS, like community and evidence uploads). Screens are `ConsumerWidget`s over feature providers keyed on `viewerIdProvider`. Chat is a notifier state machine over a `Stream<ChatEvent>` (NDJSON) with a repository seam for tests. Coach marks are client-only (a target registry, an overlay host and a local seen-flag).

**Tech Stack:** Flutter, `flutter_riverpod` ^3.3.2 (manual providers, `ref.mounted`), `go_router` ^17.5.0, `dio`, `image` 4.10.1, `image_picker`, `shared_preferences` (promoted from transitive), `fake_async`.

**Spec:** `C:\Users\gorok\Videos\sentinelx\docs\superpowers\specs\2026-10-05-mobile-phase5c-guide-and-chatbot-design.md` (rev 2, owner-approved 2026-10-05). Web plan: `C:\Users\gorok\Videos\sentinelx\docs\superpowers\plans\2026-10-05-mobile-phase5c-web-guide-and-chat.md`. **Tasks 3 onward need the web Stage B contract** (`openapi/mobile-v1.json` with the five new operations); Tasks 0-2 do not.

## Global Constraints

- Supabase `itxubrkbropttfdackmi` is **production**. Never test writes against it. Use staging via `--dart-define` of `SUPABASE_URL`, `SUPABASE_PUBLISHABLE_KEY`, `API_BASE_URL`; test users use the `zzqa_` prefix; never commit keys.
- All writes and viewer-specific reads go through `ApiClient`; every new method is in `ApiClient.usedOperations` and checked against `api/openapi.json` (a **copy** of the web `openapi/mobile-v1.json`; re-copy, never hand-edit). Server error text is never shown: map `ApiException.code` to ARB copy. Branch on `code`, not `status`.
- Tolerant parsing: unknown values degrade, one bad row/line is skipped, nothing throws.
- Anything the model returns is untrusted text: render as plain `Text`, never HTML/Markdown, auto-link nothing, strip control and bidi-override characters, never execute it, never let it pick a route or call (only the validated destination enum, mapped through a fixed table).
- Copy is ARB only (`lib/core/l10n/app_en.arb` + `app_fr.arb`, identical key sets, ICU plurals); run `flutter gen-l10n` and commit the generated output; American spelling; `SxColors` only; mobile-first at 375 px.
- A refreshed `Session` (same user, new token) must not refetch anything: providers key on `viewerIdProvider`. Optimistic writes reuse one idempotency/turn key per compose action; mutators no-op when `!ref.mounted`; a pushed go_router page does not change `currentConfiguration.uri` (use `.last.matchedLocation`); in-app paths must make `resolveWebLink` return `null`.
- Flutter stops building frames while paused: pause handling lives in a lifecycle source, not a rebuild.
- Tests: write the failing test first and watch it fail for the right reason; mutation-check the load-bearing ones; use `fake_async` or an injected clock, never real sleeps.
- Edit with Edit/Write, or Python with `encoding='utf-8'`. `git checkout -- linux macos windows` before each commit. `android/app/google-services.json` stays untracked; keep both build paths working.
- Hotspot files (`api_client.dart`, `app_router.dart`, `api/openapi.json`, ARB and generated l10n) change by **appended lines / new routes only**; rebase onto `origin/master` before final checks. Put new API models in new files.
- Do **not** touch `..\sentinelx_mobile-profile-onboarding` (separate worktree). Task 2 edits `edit_profile_screen.dart`, which that branch may also edit: rebase carefully and report conflicts.
- Machine: 15 GB RAM. Run the full `flutter test` (~3 min) alone, check free RAM first, stop Gradle after APK builds (`android\gradlew --stop`).
- Before every commit: `flutter analyze` (clean), the touched tests, and `flutter gen-l10n` after ARB edits. Before the final task: full `flutter test`.
- Merge to `master` and push only after the owner approves (ask first); `git pull --rebase` first; never force-push.

## Review Focus

1. A reply or history row containing `<b>`, a Markdown link, bidi-override or control characters must render literally and harmlessly (Task 8).
2. A turn interrupted by backgrounding or a dropped connection must show Retry and reuse the same `clientTurnId`, and must not produce a duplicate bubble or history row (Task 7).
3. A signed-out visitor must never send a bearer, must never see account data, and must see the "sign in" copy when chat is unavailable (Tasks 7, 8).
4. An unknown quest step key, unknown target, unknown chat event or unknown destination from a newer server must degrade, not crash (Task 3).
5. An avatar photo with GPS EXIF must be re-encoded without it before it leaves the device (Task 2).

---

## File Structure

Create:
- `lib/core/storage/local_kv.dart` — `LocalKv`, `PrefsLocalKv`, `localKvProvider`, `chatDeviceIdProvider`.
- `lib/core/lifecycle/app_lifecycle_provider.dart` — `appLifecycleSourceProvider`.
- `lib/core/api/guide_models.dart`, `chat_models.dart`.
- `lib/features/account/avatar_pipeline.dart`, `avatar_uploader.dart`, `avatar_field.dart`.
- `lib/features/guide/guide_repository.dart`, `guide_providers.dart`, `guide_screen.dart`, `quest_card.dart`, `quest_routes.dart`, `visitor_tour.dart`, `guide_mascot.dart`.
- `lib/features/guide/coach/coach_registry.dart`, `coach_controller.dart`, `coach_host.dart`, `coach_tours.dart`.
- `lib/features/support_chat/chat_repository.dart`, `chat_notifier.dart`, `chat_screen.dart`, `chat_bubble_view.dart`, `chat_error_copy.dart`, `chat_destinations.dart`.
- Tests mirroring each, plus `test/fakes/fake_chat_repository.dart`, `fake_guide_repository.dart`, `fake_local_kv.dart`.
- `assets/mascot/mascot-bubble.png` (copied from the web repo `public/mascot/mascot-bubble.png`).

Modify (append-only where a hotspot): `pubspec.yaml`, `lib/core/api/api_client.dart`, `lib/core/api/models.dart` (`MeProfile.bubbleSkinUrl`), `lib/core/api/compete_models.dart` (`ProfileEdit.avatarUrl`), `lib/features/account/edit_profile_screen.dart`, `lib/features/home/home_screen.dart`, `lib/shared/widgets/sx_tab_app_bar.dart`, `lib/router/app_router.dart`, `lib/core/l10n/app_en.arb`, `app_fr.arb`, `CLAUDE.md`, `TESTING-NOTES.md`, `api/openapi.json`.

---

### Task 0: Worktree, baseline, contract

**Files:** none (setup).

- [ ] **Step 1: Create the worktree** (AGENTS.md: never the primary checkout)

```powershell
cd C:\Users\gorok\sentinelx_mobile
git fetch origin
git worktree add ..\sentinelx_mobile-5c -b phase5c/guide-chat origin/master
cd ..\sentinelx_mobile-5c
```

- [ ] **Step 2: Baseline.** Check free RAM, then run `flutter pub get`, `flutter analyze`, `flutter test` (alone). Expected: analyze clean, 1332 tests passing. Record the count; stop and report if the baseline is not green.
- [ ] **Step 3: Contract (do this when the web Stage B is on staging).** Copy the web contract and confirm the new operations exist:

```powershell
git -C C:\Users\gorok\Videos\sentinelx show <web-branch-or-main>:openapi/mobile-v1.json | Out-File -Encoding utf8 api\openapi.json
Select-String -Path api\openapi.json -Pattern 'getGuideQuests|claimGuideBadge|postChatMessage|getChatHistory|deleteChatHistory'
```
Expected: all five operation ids. (`api/openapi.json` equals the web file modulo CRLF.) If any are missing, stop: Tasks 3+ are blocked.

---

### Task 1: Local key-value store, device id, app lifecycle provider

**Files:**
- Create: `lib/core/storage/local_kv.dart`, `lib/core/lifecycle/app_lifecycle_provider.dart`, `test/fakes/fake_local_kv.dart`
- Modify: `pubspec.yaml`
- Test: `test/core/storage/local_kv_test.dart`

**Interfaces — Produces:**

```dart
abstract class LocalKv { Future<String?> read(String key); Future<void> write(String key, String value); Future<void> remove(String key); }
final localKvProvider = FutureProvider<LocalKv>(...);
final chatDeviceIdProvider = FutureProvider<String>(...);          // generated once, persisted, in-memory fallback
final appLifecycleSourceProvider = Provider<AppLifecycleSource>(...); // WidgetsLifecycleSource, disposed with the provider
class MemoryLocalKv implements LocalKv { final Map<String, String> values; bool failWrites; }  // test/fakes
```

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/core/storage/local_kv.dart';
import '../../fakes/fake_local_kv.dart';

void main() {
  test('device id is generated once, persisted and reused', () async {
    final kv = MemoryLocalKv();
    final c = ProviderContainer(overrides: [localKvProvider.overrideWith((ref) async => kv)]);
    addTearDown(c.dispose);
    final first = await c.read(chatDeviceIdProvider.future);
    expect(first.length, greaterThanOrEqualTo(8));
    expect(kv.values['chat.deviceId'], first);
    final c2 = ProviderContainer(overrides: [localKvProvider.overrideWith((ref) async => kv)]);
    addTearDown(c2.dispose);
    expect(await c2.read(chatDeviceIdProvider.future), first);
  });
  test('device id matches the server header pattern [A-Za-z0-9-]{8,64}', () async {
    final c = ProviderContainer(overrides: [localKvProvider.overrideWith((ref) async => MemoryLocalKv())]);
    addTearDown(c.dispose);
    expect(RegExp(r'^[A-Za-z0-9-]{8,64}$').hasMatch(await c.read(chatDeviceIdProvider.future)), isTrue);
  });
  test('when storage cannot write, a device id is still returned (in memory)', () async {
    final kv = MemoryLocalKv()..failWrites = true;
    final c = ProviderContainer(overrides: [localKvProvider.overrideWith((ref) async => kv)]);
    addTearDown(c.dispose);
    expect((await c.read(chatDeviceIdProvider.future)).isNotEmpty, isTrue);
  });
}
```

```dart
// test/fakes/fake_local_kv.dart
import 'package:sentinelx_mobile/core/storage/local_kv.dart';

class MemoryLocalKv implements LocalKv {
  final Map<String, String> values = {};
  bool failWrites = false;
  @override Future<String?> read(String key) async => values[key];
  @override Future<void> write(String key, String value) async {
    if (failWrites) throw StateError('write failed');
    values[key] = value;
  }
  @override Future<void> remove(String key) async => values.remove(key);
}
```

- [ ] **Step 2: Run to verify it fails** — `flutter test test/core/storage/local_kv_test.dart` → FAIL (files missing).
- [ ] **Step 3: Promote the dependency.** `shared_preferences` is already in `pubspec.lock` as `transitive` (via supabase_flutter). Read the locked version (`Select-String -Path pubspec.lock -Pattern 'shared_preferences:' -Context 0,8`), add `shared_preferences: <that exact version>` under `dependencies:` in `pubspec.yaml`, run `flutter pub get`, and confirm `git diff pubspec.lock` shows only the `dependency:` line changing from `transitive` to `direct main` (no new package, so no new native code and no AGP risk).
- [ ] **Step 4: Implement**

```dart
// lib/core/storage/local_kv.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/idempotency_key.dart';

/// Small per-install key/value store (coach-mark flags, anonymous chat device id). Never holds anything secret.
abstract class LocalKv {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> remove(String key);
}

class PrefsLocalKv implements LocalKv {
  PrefsLocalKv(this._prefs);
  final SharedPreferences _prefs;
  @override Future<String?> read(String key) async => _prefs.getString(key);
  @override Future<void> write(String key, String value) async => _prefs.setString(key, value);
  @override Future<void> remove(String key) async => _prefs.remove(key);
}

final localKvProvider = FutureProvider<LocalKv>((ref) async => PrefsLocalKv(await SharedPreferences.getInstance()));

/// Random per-install id sent as `X-Device-Id` on signed-out chat. Spoofable on purpose-built clients, so the
/// server only uses it to add a rate-limit bucket, never to raise a limit.
final chatDeviceIdProvider = FutureProvider<String>((ref) async {
  const key = 'chat.deviceId';
  try {
    final kv = await ref.watch(localKvProvider.future);
    final existing = await kv.read(key);
    if (existing != null && RegExp(r'^[A-Za-z0-9-]{8,64}$').hasMatch(existing)) return existing;
    final fresh = newIdempotencyKey();
    await kv.write(key, fresh);
    return fresh;
  } catch (_) {
    return newIdempotencyKey(); // storage unavailable: a per-run id still works
  }
});
```

```dart
// lib/core/lifecycle/app_lifecycle_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../realtime/realtime_hub.dart' show AppLifecycleSource, WidgetsLifecycleSource;

/// The same lifecycle abstraction the realtime hub uses, exposed as a provider so features other than realtime
/// (chat interruption, quest refresh on resume) can react to pause/resume. Tests override it with `FakeLifecycle`.
final appLifecycleSourceProvider = Provider<AppLifecycleSource>((ref) {
  final source = WidgetsLifecycleSource();
  ref.onDispose(source.dispose);
  return source;
});
```

- [ ] **Step 5: Run** `flutter test test/core/storage/local_kv_test.dart && flutter analyze` → PASS.
- [ ] **Step 6: Commit** (`feat(core): local key-value store, anonymous chat device id, app lifecycle provider`) with the Co-Authored-By line.

---

### Task 2: Avatar upload (Stage A1, mobile) — sanitize on device, upload, save

Quest step 1 needs an avatar, and mobile has no avatar upload at all. The photo is re-encoded on the device (square crop, 400 px, JPEG, **EXIF/GPS removed**) before it is uploaded to the public `avatars` bucket under the player's own folder.

**Files:**
- Create: `lib/features/account/avatar_pipeline.dart`, `avatar_uploader.dart`, `avatar_field.dart`, `test/fakes/fake_avatar.dart`
- Modify: `lib/core/api/compete_models.dart` (`ProfileEdit`), `lib/features/account/edit_profile_screen.dart`, ARB (en + fr)
- Test: `test/features/account/avatar_pipeline_test.dart`, `avatar_field_test.dart`, `test/core/api/profile_edit_test.dart` (or extend the existing `ProfileEdit` test)

**Interfaces — Produces:**

```dart
Uint8List sanitizeAvatar(Uint8List bytes, {int size = 400, int quality = 85});   // throws FormatException('not an image')
Future<Uint8List> sanitizeAvatarIsolated(Uint8List bytes);
final avatarSanitizerProvider = Provider<Future<Uint8List> Function(Uint8List)>(...);
final avatarPickerProvider = Provider<DmImagePicker>(...);                       // reuses DmImagePicker/PickedImage types
abstract class AvatarUploader { Future<String> upload(Uint8List jpeg); }         // returns the public URL
final avatarUploaderProvider = Provider<AvatarUploader>(...);
class AvatarField extends ConsumerStatefulWidget { AvatarField({required String? url, required bool enabled, required ValueChanged<String> onChanged}) }
// ProfileEdit gains: final String? avatarUrl; toJson adds 'avatarUrl' only when non-null
```

- [ ] **Step 1: Write the failing pipeline tests** (mirror `test/features/messages/dm_image_pipeline_test.dart`, including its "fixture really carries GPS" guard)

```dart
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:sentinelx_mobile/features/account/avatar_pipeline.dart';

Uint8List _jpegWithExif(int w, int h) {
  final src = img.Image(width: w, height: h);
  img.fill(src, color: img.ColorRgb8(200, 80, 40));
  src.exif.gpsIfd.gpsLatitudeRef = 'N';
  src.exif.imageIfd.make = 'TestCam';
  return Uint8List.fromList(img.encodeJpg(src));
}

void main() {
  test('the fixture really carries GPS and Make (the strip test cannot pass vacuously)', () {
    final d = img.decodeJpg(_jpegWithExif(3000, 2000))!;
    expect(d.exif.gpsIfd.gpsLatitudeRef, 'N');
    expect(d.exif.imageIfd.hasMake, isTrue);
  });
  test('strips EXIF/GPS and returns a 400x400 square JPEG', () {
    final out = sanitizeAvatar(_jpegWithExif(3000, 2000));
    final after = img.decodeJpg(out)!;
    expect(after.exif.imageIfd.hasMake, isFalse);      // MUTATION GUARD: removing `im.exif = ExifData()` fails these two
    expect(after.exif.gpsIfd.gpsLatitudeRef, isNull);
    expect([after.width, after.height], [400, 400]);
    expect(out[0], 0xFF); expect(out[1], 0xD8);
  });
  test('a portrait is center-cropped square (1000x3000 -> 400x400)', () {
    final after = img.decodeJpg(sanitizeAvatar(_jpegWithExif(1000, 3000)))!;
    expect([after.width, after.height], [400, 400]);
  });
  test('never upscales: 100x80 -> 80x80', () {
    final after = img.decodeJpg(sanitizeAvatar(_jpegWithExif(100, 80)))!;
    expect([after.width, after.height], [80, 80]);
  });
  test('non-image bytes throw FormatException', () {
    expect(() => sanitizeAvatar(Uint8List.fromList([1, 2, 3])), throwsFormatException);
  });
}
```

- [ ] **Step 2: Run to verify FAIL**, then **Step 3: implement**

```dart
// lib/features/account/avatar_pipeline.dart
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;

import '../messages/dm_image_pipeline.dart' show DmImagePicker, PluginDmImagePicker;

/// Center-crops to a square, caps at [size] px (never upscales), re-encodes as JPEG with an EMPTY EXIF block.
/// Avatars are public and most players are minors, so GPS must never leave the device.
Uint8List sanitizeAvatar(Uint8List bytes, {int size = 400, int quality = 85}) {
  final img.Image? decoded;
  try {
    decoded = img.decodeImage(bytes);
  } catch (_) {
    throw const FormatException('not an image');
  }
  if (decoded == null) throw const FormatException('not an image');
  var im = img.bakeOrientation(decoded);
  final side = im.width < im.height ? im.width : im.height;
  im = img.copyCrop(im, x: (im.width - side) ~/ 2, y: (im.height - side) ~/ 2, width: side, height: side);
  if (side > size) im = img.copyResize(im, width: size, height: size);
  im.exif = img.ExifData(); // the privacy step
  return Uint8List.fromList(img.encodeJpg(im, quality: quality));
}

Future<Uint8List> sanitizeAvatarIsolated(Uint8List bytes) => compute(sanitizeAvatar, bytes);

final avatarSanitizerProvider = Provider<Future<Uint8List> Function(Uint8List)>((_) => sanitizeAvatarIsolated);
final avatarPickerProvider = Provider<DmImagePicker>((_) => PluginDmImagePicker());
```

```dart
// lib/features/account/avatar_uploader.dart
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/providers.dart';
import '../../core/utils/idempotency_key.dart';

abstract class AvatarUploader {
  /// Uploads a sanitized JPEG to `avatars/<uid>/<uuid>.jpg` and returns its public URL.
  Future<String> upload(Uint8List jpeg);
}

/// Same direct-to-storage-under-RLS pattern as community and evidence uploads (`avatars` insert policy:
/// first path segment must equal auth.uid()). The web API then validates the URL is in the caller's own folder.
class SupabaseAvatarUploader implements AvatarUploader {
  SupabaseAvatarUploader(this._client);
  final SupabaseClient _client;
  @override
  Future<String> upload(Uint8List jpeg) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) throw StateError('not signed in');
    final path = '$uid/${newIdempotencyKey()}.jpg';
    await _client.storage.from('avatars').uploadBinary(path, jpeg, fileOptions: const FileOptions(contentType: 'image/jpeg', upsert: false));
    return _client.storage.from('avatars').getPublicUrl(path);
  }
}

final avatarUploaderProvider = Provider<AvatarUploader>((ref) => SupabaseAvatarUploader(ref.watch(supabaseClientProvider)));
```

- [ ] **Step 4: `ProfileEdit.avatarUrl`.** In `compete_models.dart` add an optional `this.avatarUrl` constructor parameter, `final String? avatarUrl;`, and `if (avatarUrl != null) 'avatarUrl': avatarUrl,` at the end of `toJson`. Test (add beside the existing `ProfileEdit` serialization test): `toJson` omits `avatarUrl` when null and includes it when set; existing keys unchanged.
- [ ] **Step 5: AvatarField + tests.** Widget: shows the current avatar (`PlayerAvatar(avatarUrl: url, size: 72)`), a "Change photo" button opening a bottom sheet (gallery / camera) -> `avatarPickerProvider.read(...).pick(source)`; a picked file over `kMaxPickedBytes` (from `dm_image_pipeline.dart`) shows `avatarTooLarge`; sanitize via `avatarSanitizerProvider` (FormatException -> `avatarNotImage`); upload via `avatarUploaderProvider`; success calls `onChanged(url)`; any failure shows `avatarUploadFailed` and leaves the old avatar; shows a progress indicator and disables the button while busy; ignores results after dispose (`mounted` checks).

```dart
// test/features/account/avatar_field_test.dart (core assertions)
testWidgets('uploads the SANITIZED bytes (no GPS) and reports the public URL', (tester) async {
  final uploader = FakeAvatarUploader(); // records bytes, returns 'https://x/storage/v1/object/public/avatars/u1/a.jpg'
  String? changed;
  await tester.pumpWidget(ProviderScope(
    overrides: [
      avatarPickerProvider.overrideWithValue(FakeAvatarPicker(_jpegWithExif(3000, 2000))),
      avatarSanitizerProvider.overrideWithValue((b) async => sanitizeAvatar(b)),
      avatarUploaderProvider.overrideWithValue(uploader),
    ],
    child: MaterialApp(localizationsDelegates: AppLocalizations.localizationsDelegates, supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: AvatarField(url: null, enabled: true, onChanged: (u) => changed = u))),
  ));
  await tester.tap(find.byKey(const Key('avatar-change')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('avatar-source-gallery')));
  await tester.pumpAndSettle();
  final sent = img.decodeJpg(uploader.uploaded.single)!;
  expect(sent.exif.gpsIfd.gpsLatitudeRef, isNull);
  expect(sent.width, 400);
  expect(changed, contains('/avatars/u1/'));
});
testWidgets('a non-image shows the not-an-image message and uploads nothing', ...);   // picker returns [1,2,3]
testWidgets('an upload failure shows the failure message and keeps the old avatar', ...); // uploader throws
```
Write the three tests in full with `FakeAvatarPicker implements DmImagePicker` and `FakeAvatarUploader implements AvatarUploader` in `test/fakes/fake_avatar.dart` (`_jpegWithExif` is copied from the pipeline test into a shared helper in the same fake file).

- [ ] **Step 6: Wire into `_EditFormState`.** Add `String? _avatarUrl; bool _avatarChanged = false;` (initialized from `widget.me.profile?.avatarUrl`), place `AvatarField(url: _avatarUrl, enabled: !_saving, onChanged: (u) => setState(() { _avatarUrl = u; _avatarChanged = true; }))` as the first child of the form `Column`, and pass `avatarUrl: _avatarChanged ? _avatarUrl : null` in the `ProfileEdit(...)` built by `_save`. Extend `test/features/account/` edit-profile tests: saving after an avatar change sends `avatarUrl`; saving without one omits it.
- [ ] **Step 7: ARB (en + fr).** Keys: `avatarChangePhoto` ("Change photo" / "Changer la photo"), `avatarFromGallery`, `avatarFromCamera`, `avatarUploading`, `avatarUploadFailed`, `avatarTooLarge`, `avatarNotImage` (write natural fr for each). `flutter gen-l10n`; the existing ARB parity test must pass.
- [ ] **Step 8: Run** `flutter test test/features/account test/core && flutter analyze` → PASS.
- [ ] **Step 9: Mutation check.** Remove `im.exif = img.ExifData();` from `sanitizeAvatar`; the pipeline test and the field test must fail; restore.
- [ ] **Step 10: Commit** (`feat(account): avatar upload with on-device EXIF stripping`). Report to the owner: iOS `Info.plist` photo/camera usage strings are still owed (Phase 10); community and evidence uploads still publish EXIF (known open item).

---

### Task 3: Contract models and `ApiClient` methods (needs the web contract from Task 0 Step 3)

**Files:**
- Create: `lib/core/api/guide_models.dart`, `lib/core/api/chat_models.dart`
- Modify: `lib/core/api/api_client.dart` (append methods + `usedOperations` entries), `lib/core/api/models.dart` (`MeProfile.bubbleSkinUrl`), `api/openapi.json`
- Test: `test/core/api/guide_models_test.dart`, `chat_models_test.dart`, `chat_stream_test.dart`; the existing `test/core/api_contract_test.dart` must stay green

**Interfaces — Produces (used by every later task):**

```dart
// guide_models.dart
enum QuestTarget { editProfile, tournaments, matches; static QuestTarget? parse(Object? v); }
class QuestStep { final String key; final bool done; final QuestTarget? target; static QuestStep? tryParse(Object? j); }
class Quest { final String id; final List<QuestStep> steps; final int totalCount; final bool allComplete, claimed; final int rewardXp, rewardCoins; int get doneCount; static Quest? tryParse(Object? j); }
class GuideQuests { final List<Quest> quests; factory GuideQuests.fromJson(Map<String, dynamic> j); }
class BadgeClaim { final bool alreadyClaimed; final int xp, coins; factory BadgeClaim.fromJson(Map<String, dynamic> j); }
// chat_models.dart
enum ChatDestination { tournaments, matches, wallet, profile, notifications, rules, safety, help; static ChatDestination? parse(Object? v); }
sealed class ChatEvent {}  // ChatStatus, ChatDelta(String text), ChatActions(List<ChatDestination> items), ChatDone(bool persisted), ChatError(String code)
ChatEvent? parseChatLine(String line);                  // null for blank/bad/unknown
class ChatTurnMessage { final String role; final String content; Map<String, Object?> toJson(); }  // role 'user'|'assistant'
class ChatHistoryItem { final String id, role, content; final DateTime createdAt; static ChatHistoryItem? tryParse(Object? j); }
class ChatHistoryPage { final List<ChatHistoryItem> messages; final String? nextBefore; factory ChatHistoryPage.fromJson(Map<String, dynamic> j); }
String cleanChatText(String s);                         // strips control + bidi-override characters (same set as the server)
// api_client.dart
Future<GuideQuests> getGuideQuests();
Future<BadgeClaim> postGuideBadge();
Future<ChatHistoryPage> getChatHistory({String? before, int? limit});
Future<void> deleteChatHistory();
Stream<ChatEvent> postChatMessage({required List<ChatTurnMessage> messages, required String clientTurnId, required String locale, String? deviceId});
```

- [ ] **Step 1: Write the failing model tests**

```dart
// test/core/api/guide_models_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/core/api/guide_models.dart';

void main() {
  final good = {
    'quests': [
      {'id': 'battle_ready', 'steps': [
        {'key': 'profile_complete', 'done': true, 'target': 'edit_profile'},
        {'key': 'first_tournament_entered', 'done': false, 'target': 'tournaments'},
        {'key': 'first_match_completed', 'done': false, 'target': 'matches'},
      ], 'doneCount': 1, 'totalCount': 3, 'allComplete': false, 'claimed': false, 'reward': {'xp': 100, 'coins': 50}},
    ],
  };
  test('parses a quest and counts done steps itself', () {
    final q = GuideQuests.fromJson(good).quests.single;
    expect(q.id, 'battle_ready');
    expect(q.doneCount, 1);
    expect(q.steps.first.target, QuestTarget.editProfile);
    expect([q.rewardXp, q.rewardCoins], [100, 50]);
  });
  test('an unknown target degrades to null, an unknown step key is kept (generic label later)', () {
    final s = QuestStep.tryParse({'key': 'brand_new_step', 'done': false, 'target': 'wallet_screen'})!;
    expect(s.key, 'brand_new_step');
    expect(s.target, isNull);
  });
  test('a malformed quest or step is skipped, never thrown', () {
    final r = GuideQuests.fromJson({'quests': [1, {'id': 5}, ...(good['quests']! as List)]});
    expect(r.quests, hasLength(1));
    final withBadStep = Quest.tryParse({'id': 'x', 'steps': [{'key': 1}, {'key': 'a', 'done': true}], 'totalCount': 1, 'allComplete': true, 'claimed': false, 'reward': {'xp': 1, 'coins': 1}})!;
    expect(withBadStep.steps, hasLength(1));
  });
  test('missing quests list yields an empty list', () {
    expect(GuideQuests.fromJson(const {}).quests, isEmpty);
  });
  test('BadgeClaim parses', () {
    final c = BadgeClaim.fromJson({'claimed': true, 'alreadyClaimed': true, 'xp': 100, 'coins': 50});
    expect([c.alreadyClaimed, c.xp, c.coins], [true, 100, 50]);
  });
}
```

```dart
// test/core/api/chat_models_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/core/api/chat_models.dart';

void main() {
  group('parseChatLine', () {
    test('each known event', () {
      expect(parseChatLine('{"t":"status","state":"checking_account"}'), isA<ChatStatus>());
      expect((parseChatLine('{"t":"delta","text":"hi"}') as ChatDelta).text, 'hi');
      expect((parseChatLine('{"t":"done","persisted":true}') as ChatDone).persisted, isTrue);
      expect((parseChatLine('{"t":"error","code":"chat_truncated"}') as ChatError).code, 'chat_truncated');
    });
    test('actions keep only known destinations', () {
      final a = parseChatLine('{"t":"actions","items":["wallet","evil",7,"tournaments"]}') as ChatActions;
      expect(a.items, [ChatDestination.wallet, ChatDestination.tournaments]);
    });
    test('blank, garbage, non-object, unknown t and wrong field types are null, never throw', () {
      for (final l in ['', '  ', 'nope', '[1]', '{"t":"future"}', '{"t":"delta","text":5}', '{"x":1}']) {
        expect(parseChatLine(l), isNull, reason: l);
      }
    });
    test('an error without a string code becomes "internal"', () {
      expect((parseChatLine('{"t":"error"}') as ChatError).code, 'internal');
    });
  });
  group('cleanChatText', () {
    test('strips control and bidi-override characters, keeps newlines, emoji and ZWJ sequences', () {
      expect(cleanChatText('a\u0000b\u202Ec\u2066d\u200Fe'), 'abcde');
      expect(cleanChatText('x\ny\tz'), 'x\ny\tz');
      expect(cleanChatText('👨‍👩‍👧 ok'), '👨‍👩‍👧 ok');
    });
    test('does not interpret markup: it is returned verbatim', () {
      expect(cleanChatText('<b>hi</b> [x](https://evil.example)'), '<b>hi</b> [x](https://evil.example)');
    });
  });
  test('ChatHistoryPage skips bad rows', () {
    final p = ChatHistoryPage.fromJson({'messages': [
      {'id': 'a', 'role': 'user', 'content': 'hi', 'createdAt': '2026-10-05T10:00:00Z'},
      {'id': 'b', 'role': 'system', 'content': 'x', 'createdAt': '2026-10-05T10:00:00Z'},
      {'id': 'c', 'role': 'assistant', 'content': 'x', 'createdAt': 'not a date'},
    ], 'nextBefore': 'cur'});
    expect(p.messages.map((m) => m.id), ['a']);
    expect(p.nextBefore, 'cur');
  });
}
```

- [ ] **Step 2: Run to verify FAIL.** Step 3: implement.

```dart
// lib/core/api/guide_models.dart
enum QuestTarget {
  editProfile, tournaments, matches;
  static QuestTarget? parse(Object? v) => switch (v) {
        'edit_profile' => editProfile,
        'tournaments' => tournaments,
        'matches' => matches,
        _ => null,
      };
}

class QuestStep {
  const QuestStep({required this.key, required this.done, this.target});
  final String key;
  final bool done;
  final QuestTarget? target;
  static QuestStep? tryParse(Object? j) {
    if (j is! Map<String, dynamic>) return null;
    final key = j['key'], done = j['done'];
    if (key is! String || done is! bool) return null;
    return QuestStep(key: key, done: done, target: QuestTarget.parse(j['target']));
  }
}

class Quest {
  const Quest({required this.id, required this.steps, required this.totalCount, required this.allComplete, required this.claimed, required this.rewardXp, required this.rewardCoins});
  final String id;
  final List<QuestStep> steps;
  final int totalCount;
  final bool allComplete, claimed;
  final int rewardXp, rewardCoins;
  int get doneCount => steps.where((s) => s.done).length;
  static Quest? tryParse(Object? j) {
    if (j is! Map<String, dynamic>) return null;
    final id = j['id'], steps = j['steps'];
    if (id is! String || steps is! List) return null;
    final reward = j['reward'] is Map<String, dynamic> ? j['reward'] as Map<String, dynamic> : const <String, dynamic>{};
    return Quest(
      id: id,
      steps: steps.map(QuestStep.tryParse).whereType<QuestStep>().toList(),
      totalCount: j['totalCount'] is int ? j['totalCount'] as int : steps.length,
      allComplete: j['allComplete'] == true,
      claimed: j['claimed'] == true,
      rewardXp: reward['xp'] is int ? reward['xp'] as int : 0,
      rewardCoins: reward['coins'] is int ? reward['coins'] as int : 0,
    );
  }
}

class GuideQuests {
  const GuideQuests(this.quests);
  final List<Quest> quests;
  factory GuideQuests.fromJson(Map<String, dynamic> j) {
    final raw = j['quests'];
    return GuideQuests(raw is List ? raw.map(Quest.tryParse).whereType<Quest>().toList() : const []);
  }
}

class BadgeClaim {
  const BadgeClaim({required this.alreadyClaimed, required this.xp, required this.coins});
  final bool alreadyClaimed;
  final int xp, coins;
  factory BadgeClaim.fromJson(Map<String, dynamic> j) => BadgeClaim(
        alreadyClaimed: j['alreadyClaimed'] == true,
        xp: j['xp'] is int ? j['xp'] as int : 0,
        coins: j['coins'] is int ? j['coins'] as int : 0,
      );
}
```

```dart
// lib/core/api/chat_models.dart
import 'dart:convert';

enum ChatDestination {
  tournaments, matches, wallet, profile, notifications, rules, safety, help;
  static ChatDestination? parse(Object? v) {
    if (v is! String) return null;
    for (final d in values) {
      if (d.name == v) return d;
    }
    return null;
  }
}

sealed class ChatEvent { const ChatEvent(); }
class ChatStatus extends ChatEvent { const ChatStatus(); }
class ChatDelta extends ChatEvent { const ChatDelta(this.text); final String text; }
class ChatActions extends ChatEvent { const ChatActions(this.items); final List<ChatDestination> items; }
class ChatDone extends ChatEvent { const ChatDone(this.persisted); final bool persisted; }
class ChatError extends ChatEvent { const ChatError(this.code); final String code; }

/// One NDJSON line -> event. Anything unreadable or from a newer server returns null so the stream keeps going.
ChatEvent? parseChatLine(String line) {
  final s = line.trim();
  if (s.isEmpty) return null;
  final Object? j;
  try {
    j = jsonDecode(s);
  } catch (_) {
    return null;
  }
  if (j is! Map<String, dynamic>) return null;
  switch (j['t']) {
    case 'status':
      return const ChatStatus();
    case 'delta':
      final t = j['text'];
      return t is String ? ChatDelta(t) : null;
    case 'actions':
      final items = j['items'];
      return ChatActions(items is List ? items.map(ChatDestination.parse).whereType<ChatDestination>().toList() : const []);
    case 'done':
      return ChatDone(j['persisted'] == true);
    case 'error':
      final c = j['code'];
      return ChatError(c is String ? c : 'internal');
  }
  return null;
}

class ChatTurnMessage {
  const ChatTurnMessage(this.role, this.content);
  final String role;
  final String content;
  Map<String, Object?> toJson() => {'role': role, 'content': content};
}

class ChatHistoryItem {
  const ChatHistoryItem({required this.id, required this.role, required this.content, required this.createdAt});
  final String id, role, content;
  final DateTime createdAt;
  static ChatHistoryItem? tryParse(Object? j) {
    if (j is! Map<String, dynamic>) return null;
    final id = j['id'], role = j['role'], content = j['content'], at = j['createdAt'];
    if (id is! String || content is! String || at is! String) return null;
    if (role != 'user' && role != 'assistant') return null;
    final t = DateTime.tryParse(at);
    return t == null ? null : ChatHistoryItem(id: id, role: role as String, content: content, createdAt: t);
  }
}

class ChatHistoryPage {
  const ChatHistoryPage({required this.messages, this.nextBefore});
  final List<ChatHistoryItem> messages;
  final String? nextBefore;
  factory ChatHistoryPage.fromJson(Map<String, dynamic> j) {
    final raw = j['messages'];
    return ChatHistoryPage(
      messages: raw is List ? raw.map(ChatHistoryItem.tryParse).whereType<ChatHistoryItem>().toList() : const [],
      nextBefore: j['nextBefore'] as String?,
    );
  }
}

// C0/C1 controls except \n \t \r, bidi overrides/isolates and marks. ZWJ/ZWNJ stay (emoji sequences).
final _unsafe = RegExp('[\u0000-\u0008\u000B\u000C\u000E-\u001F\u007F-\u009F\u061C\u200E\u200F\u202A-\u202E\u2066-\u2069]');
String cleanChatText(String s) => s.replaceAll(_unsafe, '');
```

- [ ] **Step 4: `MeProfile.bubbleSkinUrl`.** In `lib/core/api/models.dart` (`MeProfile`, lines ~1-40): add `this.bubbleSkinUrl` (optional, default null), `bubbleSkinUrl: j['bubbleSkinUrl'] as String?` in `fromJson`, and `final String? bubbleSkinUrl;`. Add a test to the existing `/me` model test: present, absent and `null` all parse; existing fields unchanged.
- [ ] **Step 5: Write the failing stream/ApiClient tests** (`test/core/api/chat_stream_test.dart`)

```dart
import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/core/api/api_client.dart';
import 'package:sentinelx_mobile/core/api/chat_models.dart';

class _Adapter implements HttpClientAdapter {
  _Adapter(this.respond);
  final ResponseBody Function(RequestOptions) respond;
  RequestOptions? last;
  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<Uint8List>? s, Future<void>? c) async { last = o; return respond(o); }
  @override
  void close({bool force = false}) {}
}

ResponseBody _stream(List<String> chunks, {int status = 200}) => ResponseBody(
      Stream.fromIterable(chunks.map((c) => Uint8List.fromList(utf8.encode(c)))), status,
      headers: {Headers.contentTypeHeader: [status == 200 ? 'application/x-ndjson' : 'application/json']});

ApiClient _client(_Adapter a, {String? token}) =>
    ApiClient.create(baseUrl: 'https://x.test', appVersion: '1', platform: 'android', accessToken: () async => token, adapter: a);
const _msgs = [ChatTurnMessage('user', 'hi')];

void main() {
  test('lines split across network chunks are reassembled', () async {
    final a = _Adapter((_) => _stream(['{"t":"delta","te', 'xt":"hi"}\n{"t":"do', 'ne","persisted":false}\n']));
    final events = await _client(a).postChatMessage(messages: _msgs, clientTurnId: 't', locale: 'en').toList();
    expect(events.map((e) => e.runtimeType), [ChatDelta, ChatDone]);
  });
  test('a bad line and an unknown event are skipped', () async {
    final a = _Adapter((_) => _stream(['garbage\n{"t":"future"}\n{"t":"delta","text":"ok"}\n']));
    final events = await _client(a).postChatMessage(messages: _msgs, clientTurnId: 't', locale: 'en').toList();
    expect(events, hasLength(1));
  });
  test('a non-200 before the stream is an ApiException with code and fields', () async {
    final a = _Adapter((_) => _stream(['{"error":{"code":"chat_rate_limited","message":"x","fields":{"retryAfterSeconds":"42"}}}'], status: 429));
    expect(
      () => _client(a).postChatMessage(messages: _msgs, clientTurnId: 't', locale: 'en').toList(),
      throwsA(isA<ApiException>().having((e) => e.code, 'code', 'chat_rate_limited').having((e) => e.fields['retryAfterSeconds'], 'retry', '42')),
    );
  });
  test('sends the body, the device id header only when given, and the bearer only when signed in', () async {
    final a = _Adapter((_) => _stream(['{"t":"done","persisted":false}\n']));
    await _client(a).postChatMessage(messages: _msgs, clientTurnId: 'turn-1', locale: 'fr', deviceId: 'device-abc-123').toList();
    expect(a.last!.headers['X-Device-Id'], 'device-abc-123');
    expect(a.last!.headers.containsKey('Authorization'), isFalse);
    expect(a.last!.data, {'messages': [{'role': 'user', 'content': 'hi'}], 'clientTurnId': 'turn-1', 'locale': 'fr'});
    await _client(a, token: 'tok').postChatMessage(messages: _msgs, clientTurnId: 't', locale: 'en').toList();
    expect(a.last!.headers['Authorization'], 'Bearer tok');
    expect(a.last!.headers.containsKey('X-Device-Id'), isFalse);
  });
  test('a connection that drops mid-stream ends the stream without a terminal event (no throw)', () async {
    final a = _Adapter((_) => ResponseBody(Stream<Uint8List>.multi((c) { c.add(Uint8List.fromList(utf8.encode('{"t":"delta","text":"a"}\n'))); c.addError(const FormatException('socket closed')); c.close(); }), 200));
    final events = await _client(a).postChatMessage(messages: _msgs, clientTurnId: 't', locale: 'en').toList();
    expect(events.single, isA<ChatDelta>());
  });
}
```

- [ ] **Step 6: Implement the `ApiClient` additions** (append after the last method; add the imports `dart:convert` and the two model files). Append to `usedOperations`:

```dart
    'getGuideQuests': 'get /api/mobile/v1/guide/quests',
    'claimGuideBadge': 'post /api/mobile/v1/guide/badge',
    'postChatMessage': 'post /api/mobile/v1/chat/messages',
    'getChatHistory': 'get /api/mobile/v1/chat/history',
    'deleteChatHistory': 'delete /api/mobile/v1/chat/history',
```

```dart
  Future<GuideQuests> getGuideQuests() => _send('GET', '/guide/quests', (d) => GuideQuests.fromJson(d! as Map<String, dynamic>));

  Future<BadgeClaim> postGuideBadge() =>
      _send('POST', '/guide/badge', (d) => BadgeClaim.fromJson(d! as Map<String, dynamic>), body: {'quest': 'battle_ready'});

  Future<ChatHistoryPage> getChatHistory({String? before, int? limit}) => _send(
        'GET',
        _withQuery('/chat/history', {'before': before, 'limit': limit}),
        (d) => ChatHistoryPage.fromJson(d! as Map<String, dynamic>),
      );

  Future<void> deleteChatHistory() => _send('DELETE', '/chat/history', (_) {});

  /// Streams NDJSON events. Pre-stream failures (rate limit, unavailable, 401) throw [ApiException]; once the
  /// stream has started a dropped connection simply ends it, and the caller treats "ended without a terminal
  /// event" as an interrupted turn. Signed-out callers get no bearer (the interceptor sends one only when a
  /// session exists) and should pass [deviceId].
  Stream<ChatEvent> postChatMessage({
    required List<ChatTurnMessage> messages,
    required String clientTurnId,
    required String locale,
    String? deviceId,
  }) async* {
    final Response<ResponseBody> res;
    try {
      res = await _dio.request<ResponseBody>(
        '$_base/chat/messages',
        data: {'messages': messages.map((m) => m.toJson()).toList(), 'clientTurnId': clientTurnId, 'locale': locale},
        options: Options(
          method: 'POST',
          responseType: ResponseType.stream,
          receiveTimeout: const Duration(seconds: 60),
          headers: {if (deviceId != null) 'X-Device-Id': deviceId},
        ),
      );
    } on DioException catch (e) {
      throw ApiException(status: 0, code: 'network', message: e.message ?? 'Network error');
    }
    final status = res.statusCode ?? 0;
    final body = res.data;
    if (body == null) throw ApiException(status: status, code: 'bad_response', message: 'Unexpected response ($status).');
    if (status != 200) {
      String text = '';
      try {
        text = await body.stream.cast<List<int>>().transform(utf8.decoder).join();
      } catch (_) {}
      Object? json;
      try {
        json = jsonDecode(text);
      } catch (_) {}
      if (json is Map<String, dynamic> && json['error'] is Map<String, dynamic>) {
        final err = json['error'] as Map<String, dynamic>;
        throw ApiException(
          status: status,
          code: err['code'] as String? ?? 'unknown',
          message: err['message'] as String? ?? 'Request failed',
          fields: (err['fields'] as Map<String, dynamic>?)?.map((k, v) => MapEntry(k, v.toString())) ?? const <String, String>{},
        );
      }
      throw ApiException(status: status, code: 'bad_response', message: 'Unexpected response ($status).');
    }
    try {
      await for (final line in body.stream.cast<List<int>>().transform(utf8.decoder).transform(const LineSplitter())) {
        final e = parseChatLine(line);
        if (e != null) yield e;
      }
    } catch (_) {
      return; // dropped mid-stream: end without a terminal event
    }
  }
```

(`_withQuery` accepts `Object?` values, as the existing `getRankings` call with an `int` page shows.)

- [ ] **Step 7: Run** `flutter test test/core && flutter analyze`. The contract test must pass with the five operations. If it reports an operation missing from `api/openapi.json`, Task 0 Step 3 was not done.
- [ ] **Step 8: Commit** (`feat(api): guide quests, badge claim, streamed chat and chat history client`).

---

### Task 4: Guide state — repository, quests provider, claim notifier

**Files:**
- Create: `lib/features/guide/guide_repository.dart`, `guide_providers.dart`, `quest_routes.dart`, `test/fakes/fake_guide_repository.dart`
- Test: `test/features/guide/guide_providers_test.dart`

**Interfaces:**
- Consumes: `ApiClient.getGuideQuests/postGuideBadge`, `viewerIdProvider`, `progressProvider` (`lib/features/progress`), `meProvider`.
- Produces:

```dart
abstract class GuideRepository { Future<List<Quest>> quests(); Future<BadgeClaim> claim(); }
final guideRepositoryProvider = Provider<GuideRepository>(...);
final questsProvider = FutureProvider.autoDispose<List<Quest>>(...);       // [] when signed out; keyed on viewerIdProvider
Quest? battleReady(List<Quest> quests);                                    // the quest with id 'battle_ready'
enum ClaimPhase { idle, claiming, claimed, failed }
class ClaimState { final ClaimPhase phase; final String? errorCode; final BadgeClaim? result; }
final claimBadgeProvider = NotifierProvider.autoDispose<ClaimBadgeNotifier, ClaimState>(...);
String? questStepRoute(QuestTarget? t);   // editProfile -> '/account/profile', tournaments -> '/tournaments', matches -> '/', null -> null
```

- [ ] **Step 1: Write the failing tests**

```dart
// test/features/guide/guide_providers_test.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/core/api/api_client.dart';
import 'package:sentinelx_mobile/core/api/guide_models.dart';
import 'package:sentinelx_mobile/core/providers.dart';
import 'package:sentinelx_mobile/features/guide/guide_providers.dart';
import 'package:sentinelx_mobile/features/guide/guide_repository.dart';
import 'package:sentinelx_mobile/features/guide/quest_routes.dart';
import '../../fakes/fake_guide_repository.dart';

Quest _q({bool all = true, bool claimed = false}) => Quest(id: 'battle_ready', steps: [QuestStep(key: 'a', done: all)], totalCount: 1, allComplete: all, claimed: claimed, rewardXp: 100, rewardCoins: 50);
ProviderContainer _c(FakeGuideRepository repo, {String? viewer = 'u1'}) {
  final c = ProviderContainer(overrides: [
    viewerIdProvider.overrideWith((ref) async => viewer),
    guideRepositoryProvider.overrideWithValue(repo),
  ]);
  addTearDown(c.dispose);
  return c;
}

void main() {
  test('signed out: no request, empty list', () async {
    final repo = FakeGuideRepository(seed: [_q()]);
    expect(await _c(repo, viewer: null).read(questsProvider.future), isEmpty);
    expect(repo.questsCalls, 0);
  });
  test('signed in: loads the quests once', () async {
    final repo = FakeGuideRepository(seed: [_q()]);
    final c = _c(repo);
    expect(battleReady(await c.read(questsProvider.future))?.id, 'battle_ready');
    expect(repo.questsCalls, 1);
  });
  test('claim success invalidates the quests (they are refetched)', () async {
    final repo = FakeGuideRepository(seed: [_q()], claimResult: const BadgeClaim(alreadyClaimed: false, xp: 100, coins: 50));
    final c = _c(repo);
    await c.read(questsProvider.future);
    c.listen(questsProvider, (_, _) {});
    await c.read(claimBadgeProvider.notifier).claim();
    expect(c.read(claimBadgeProvider).phase, ClaimPhase.claimed);
    await c.read(questsProvider.future);
    expect(repo.questsCalls, 2);
  });
  test('a failed claim maps the ApiException code and allows another attempt', () async {
    final repo = FakeGuideRepository(seed: [_q()], claimError: const ApiException(status: 409, code: 'quest_incomplete', message: 'x'));
    final c = _c(repo);
    c.listen(claimBadgeProvider, (_, _) {});
    await c.read(claimBadgeProvider.notifier).claim();
    expect(c.read(claimBadgeProvider).phase, ClaimPhase.failed);
    expect(c.read(claimBadgeProvider).errorCode, 'quest_incomplete');
    repo.claimError = null;
    repo.claimResult = const BadgeClaim(alreadyClaimed: true, xp: 100, coins: 50);
    await c.read(claimBadgeProvider.notifier).claim();
    expect(c.read(claimBadgeProvider).phase, ClaimPhase.claimed);
  });
  test('a second claim() while one is in flight is ignored (one request)', () async {
    final repo = FakeGuideRepository(seed: [_q()], claimResult: const BadgeClaim(alreadyClaimed: false, xp: 1, coins: 1), claimDelay: true);
    final c = _c(repo);
    c.listen(claimBadgeProvider, (_, _) {});
    final first = c.read(claimBadgeProvider.notifier).claim();
    final second = c.read(claimBadgeProvider.notifier).claim();
    repo.completeClaim();
    await Future.wait([first, second]);
    expect(repo.claimCalls, 1);
  });
  test('quest step routes', () {
    expect(questStepRoute(QuestTarget.editProfile), '/account/profile');
    expect(questStepRoute(QuestTarget.tournaments), '/tournaments');
    expect(questStepRoute(QuestTarget.matches), '/');
    expect(questStepRoute(null), isNull);
  });
}
```

```dart
// test/fakes/fake_guide_repository.dart
import 'dart:async';
import 'package:sentinelx_mobile/core/api/api_client.dart';
import 'package:sentinelx_mobile/core/api/guide_models.dart';
import 'package:sentinelx_mobile/features/guide/guide_repository.dart';

class FakeGuideRepository implements GuideRepository {
  FakeGuideRepository({this.seed = const [], this.claimResult, this.claimError, this.claimDelay = false});
  List<Quest> seed;
  BadgeClaim? claimResult;
  ApiException? claimError;
  final bool claimDelay;
  int questsCalls = 0, claimCalls = 0;
  final _gate = Completer<void>();
  void completeClaim() => _gate.complete();

  @override
  Future<List<Quest>> quests() async {
    questsCalls++;
    return seed;
  }

  @override
  Future<BadgeClaim> claim() async {
    claimCalls++;
    if (claimDelay) await _gate.future;
    if (claimError != null) throw claimError!;
    // A successful claim is reflected by the next quests() call, like the real server.
    seed = [
      for (final q in seed)
        Quest(id: q.id, steps: q.steps, totalCount: q.totalCount, allComplete: q.allComplete, claimed: true, rewardXp: q.rewardXp, rewardCoins: q.rewardCoins),
    ];
    return claimResult!;
  }
}
```

- [ ] **Step 2: Run to verify FAIL.** Step 3: implement.

```dart
// lib/features/guide/guide_repository.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';
import '../../core/api/guide_models.dart';
import '../../core/providers.dart';

abstract class GuideRepository {
  Future<List<Quest>> quests();
  Future<BadgeClaim> claim();
}

class ApiGuideRepository implements GuideRepository {
  ApiGuideRepository(this._api);
  final ApiClient _api;
  @override Future<List<Quest>> quests() async => (await _api.getGuideQuests()).quests;
  @override Future<BadgeClaim> claim() => _api.postGuideBadge();
}

final guideRepositoryProvider = Provider<GuideRepository>((ref) => ApiGuideRepository(ref.watch(apiClientProvider)));
```

```dart
// lib/features/guide/guide_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';
import '../../core/api/guide_models.dart';
import '../../core/providers.dart';
import '../progress/progress_providers.dart' show progressProvider; // adjust the import to where `progressProvider` is defined
import 'guide_repository.dart';

final questsProvider = FutureProvider.autoDispose<List<Quest>>((ref) async {
  final viewer = await ref.watch(viewerIdProvider.future);
  if (viewer == null) return const [];
  return ref.watch(guideRepositoryProvider).quests();
});

Quest? battleReady(List<Quest> quests) {
  for (final q in quests) {
    if (q.id == 'battle_ready') return q;
  }
  return null;
}

enum ClaimPhase { idle, claiming, claimed, failed }

class ClaimState {
  const ClaimState({this.phase = ClaimPhase.idle, this.errorCode, this.result});
  final ClaimPhase phase;
  final String? errorCode;
  final BadgeClaim? result;
}

class ClaimBadgeNotifier extends Notifier<ClaimState> {
  @override
  ClaimState build() => const ClaimState();

  Future<void> claim() async {
    if (state.phase == ClaimPhase.claiming) return;
    state = const ClaimState(phase: ClaimPhase.claiming);
    try {
      final result = await ref.read(guideRepositoryProvider).claim();
      if (!ref.mounted) return;
      state = ClaimState(phase: ClaimPhase.claimed, result: result);
      ref.invalidate(questsProvider);
      ref.invalidate(progressProvider); // XP and coins changed
    } catch (e) {
      if (!ref.mounted) return;
      state = ClaimState(phase: ClaimPhase.failed, errorCode: e is ApiException ? (e.isUnauthorized ? 'unauthorized' : e.code) : 'network');
    }
  }
}

final claimBadgeProvider = NotifierProvider.autoDispose<ClaimBadgeNotifier, ClaimState>(ClaimBadgeNotifier.new);
```

```dart
// lib/features/guide/quest_routes.dart
import '../../core/api/guide_models.dart';

/// Where "Take me there" goes. A null target (unknown to this app version) shows no link.
String? questStepRoute(QuestTarget? t) => switch (t) {
      QuestTarget.editProfile => '/account/profile',
      QuestTarget.tournaments => '/tournaments',
      QuestTarget.matches => '/',
      null => null,
    };
```
(`matches` goes to Home because it shows the player's fixtures; there is no separate "my matches" route yet.) Find where `progressProvider` is defined with `grep -rn "final progressProvider" lib` and fix the import line.

- [ ] **Step 4: Run** `flutter test test/features/guide && flutter analyze` → PASS. **Step 5: Mutation check:** remove the `phase == claiming` guard; the one-request test must fail; restore.
- [ ] **Step 6: Commit** (`feat(guide): quests provider and claim notifier`).

---

### Task 5: Guide UI — quest card, `/guide` screen, visitor tour, app-bar entry, mascot

**Files:**
- Create: `lib/features/guide/guide_screen.dart`, `quest_card.dart`, `visitor_tour.dart`, `guide_mascot.dart`
- Modify: `lib/router/app_router.dart` (new routes), `lib/features/home/home_screen.dart` (card), `lib/shared/widgets/sx_tab_app_bar.dart` (mascot button), `pubspec.yaml` (asset), ARB (en + fr)
- Create asset: `assets/mascot/mascot-bubble.png` (`git -C C:\Users\gorok\Videos\sentinelx show origin/main:public/mascot/mascot-bubble.png > assets\mascot\mascot-bubble.png`; verify the file opens as an image)
- Test: `test/features/guide/guide_screen_test.dart`, `quest_card_test.dart`, `test/router/guide_routes_test.dart`, extend `test/core/routing/web_links_test.dart`

**Behavior:**
- `GuideMascot({double size})` shows the equipped skin for a signed-in player (`resolveAsset(me.profile?.bubbleSkinUrl, siteUrl)` — read the import line in `lib/features/hall_of_fame/hall_of_fame_screen.dart` for `resolveAsset` and how `siteUrl` is read) with `errorBuilder` and signed-out fallback to `Image.asset('assets/mascot/mascot-bubble.png')`.
- `QuestCard` (Home, signed in only): hidden while loading, on error, when there is no `battle_ready` quest, or when it is claimed; shows title, a progress bar `doneCount/totalCount`, the first pending step's label, and a "Claim your badge" label when `allComplete`; tap pushes `/guide`. It subscribes to `appLifecycleSourceProvider` and invalidates `questsProvider` on `resumed`.
- `GuideScreen` (`/guide`): signed out -> `VisitorTour` (4 pages: what it is, the four pillars, how tournaments work, sign up) plus "Ask a question" (`/guide/chat`) and "Create account" (`/signup`) buttons; signed in -> mascot header "Hey {username}!", the quest checklist (each step: check circle, label from ARB keyed on `key` with a generic fallback for unknown keys, "Take me there" `TextButton` only when `questStepRoute(step.target) != null`, which `push`es the route), the claim button (enabled when `allComplete && !claimed`, shows progress while claiming, "Badge earned" when claimed; failure maps `ClaimState.errorCode` to ARB copy: `quest_incomplete`, `claim_in_progress`, `reward_unavailable`, `unauthorized`, anything else generic), "Ask the assistant" tile (`/guide/chat`), "Replay the tour" tile (added in Task 6, not here). Widget keys used by the tests: `quest-claim` (claim button), `tour-next` / `tour-back` (visitor tour), `guide-open` (app-bar button), `tour-create-account`, `guide-ask-assistant`.
- Routes (outside the shell): `GoRoute(path: '/guide', builder: (c, s) => const GuideScreen())` and `GoRoute(path: '/guide/chat', ...)` (Task 8 provides `ChatScreen`; until then register only `/guide`). In-app `/guide` paths pass the redirect: `resolveWebLink('/guide')` already returns `null`, asserted by a test.
- App-bar entry: in `SxTabAppBar.actions`, add before the bell an `IconButton(key: const Key('guide-open'), icon: const GuideMascot(size: 28), tooltip: l10n.guideOpen, onPressed: () => GoRouter.of(context).push('/guide'))`. In `HomeScreen`'s `AppBar.actions`, add the same button before the account button.

- [ ] **Step 1: Write failing tests**

```dart
// test/support/guide_fixtures.dart
import 'package:sentinelx_mobile/core/api/guide_models.dart';

Quest quest({int done = 1, bool claimed = false}) => Quest(
      id: 'battle_ready',
      steps: [
        QuestStep(key: 'profile_complete', done: done >= 1, target: QuestTarget.editProfile),
        QuestStep(key: 'first_tournament_entered', done: done >= 2, target: QuestTarget.tournaments),
        QuestStep(key: 'first_match_completed', done: done >= 3, target: QuestTarget.matches),
      ],
      totalCount: 3,
      allComplete: done >= 3,
      claimed: claimed,
      rewardXp: 100,
      rewardCoins: 50,
    );
```

```dart
// test/features/guide/quest_card_test.dart
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart' show AppLifecycleState;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sentinelx_mobile/core/l10n/gen/app_localizations.dart';
import 'package:sentinelx_mobile/core/lifecycle/app_lifecycle_provider.dart';
import 'package:sentinelx_mobile/core/providers.dart';
import 'package:sentinelx_mobile/features/guide/guide_repository.dart';
import 'package:sentinelx_mobile/features/guide/quest_card.dart';
import '../../fakes/fake_guide_repository.dart';
import '../../fakes/fake_realtime.dart' show FakeLifecycle;
import '../../support/guide_fixtures.dart';

Widget cardApp(FakeGuideRepository repo, {String? viewer = 'u1', FakeLifecycle? life}) {
  final router = GoRouter(routes: [
    GoRoute(path: '/', builder: (_, _) => const Scaffold(body: QuestCard())),
    GoRoute(path: '/guide', builder: (_, _) => const Scaffold(body: Text('GUIDE SCREEN'))),
  ]);
  return ProviderScope(
    overrides: <Override>[
      viewerIdProvider.overrideWith((ref) async => viewer),
      guideRepositoryProvider.overrideWithValue(repo),
      appLifecycleSourceProvider.overrideWithValue(life ?? FakeLifecycle()),
    ],
    child: MaterialApp.router(
      routerConfig: router,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    ),
  );
}

void main() {
  testWidgets('shows N of M and opens /guide on tap', (tester) async {
    await tester.pumpWidget(cardApp(FakeGuideRepository(seed: [quest(done: 1)])));
    await tester.pumpAndSettle();
    expect(find.text('1 of 3 done'), findsOneWidget);
    await tester.tap(find.byType(QuestCard));
    await tester.pumpAndSettle();
    expect(find.text('GUIDE SCREEN'), findsOneWidget);
  });
  testWidgets('hidden when claimed, when signed out and when there is no battle_ready quest', (tester) async {
    await tester.pumpWidget(cardApp(FakeGuideRepository(seed: [quest(done: 3, claimed: true)])));
    await tester.pumpAndSettle();
    expect(find.byType(LinearProgressIndicator), findsNothing);
    final signedOut = FakeGuideRepository(seed: [quest()]);
    await tester.pumpWidget(cardApp(signedOut, viewer: null));
    await tester.pumpAndSettle();
    expect(signedOut.questsCalls, 0);
    expect(find.byType(LinearProgressIndicator), findsNothing);
    await tester.pumpWidget(cardApp(FakeGuideRepository(seed: const [])));
    await tester.pumpAndSettle();
    expect(find.byType(LinearProgressIndicator), findsNothing);
  });
  testWidgets('refetches the quests when the app resumes', (tester) async {
    final repo = FakeGuideRepository(seed: [quest()]);
    final life = FakeLifecycle();
    await tester.pumpWidget(cardApp(repo, life: life));
    await tester.pumpAndSettle();
    expect(repo.questsCalls, 1);
    life.push(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(repo.questsCalls, 2);
  });
}
```

```dart
// test/features/guide/guide_screen_test.dart
// imports: as above, plus api_client.dart, guide_models.dart, guide_screen.dart, progress provider
Widget guideApp(FakeGuideRepository repo, {String? viewer = 'u1'}) => ProviderScope(
      overrides: <Override>[
        viewerIdProvider.overrideWith((ref) async => viewer),
        meProvider.overrideWith((ref) async => null),
        guideRepositoryProvider.overrideWithValue(repo),
        progressProvider.overrideWith((ref) async => throw StateError('not needed')),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const GuideScreen(),
      ),
    );

void main() {
  testWidgets('signed in: checklist with one Take me there per pending step', (tester) async {
    await tester.pumpWidget(guideApp(FakeGuideRepository(seed: [quest(done: 1)])));
    await tester.pumpAndSettle();
    expect(find.text('Complete your profile'), findsOneWidget);
    expect(find.text('Take me there'), findsNWidgets(2)); // the done step has no link
  });
  testWidgets('an unknown step key shows the generic label; an unknown target shows no link', (tester) async {
    const q = Quest(id: 'battle_ready', steps: [QuestStep(key: 'brand_new', done: false)], totalCount: 1, allComplete: false, claimed: false, rewardXp: 1, rewardCoins: 1);
    await tester.pumpWidget(guideApp(FakeGuideRepository(seed: const [q])));
    await tester.pumpAndSettle();
    expect(find.text('Complete this step'), findsOneWidget);
    expect(find.text('Take me there'), findsNothing);
  });
  testWidgets('claim is disabled until all steps are done, then claims once and shows Badge earned', (tester) async {
    final repo = FakeGuideRepository(seed: [quest(done: 2)], claimResult: const BadgeClaim(alreadyClaimed: false, xp: 100, coins: 50));
    await tester.pumpWidget(guideApp(repo));
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(find.byKey(const Key('quest-claim'))).onPressed, isNull);
    repo.seed = [quest(done: 3)];
    await tester.pumpWidget(guideApp(repo)); // a fresh scope refetches
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('quest-claim')));
    await tester.pumpAndSettle();
    expect(repo.claimCalls, 1);
    expect(find.text('Badge earned'), findsOneWidget);
  });
  testWidgets('a failed claim shows the mapped copy, never the server text, and the button stays usable', (tester) async {
    final repo = FakeGuideRepository(
      seed: [quest(done: 3)],
      claimError: const ApiException(status: 409, code: 'quest_incomplete', message: 'server text must not show'),
    );
    await tester.pumpWidget(guideApp(repo));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('quest-claim')));
    await tester.pumpAndSettle();
    expect(find.text('Finish all three steps first.'), findsOneWidget);
    expect(find.text('server text must not show'), findsNothing);
    expect(tester.widget<FilledButton>(find.byKey(const Key('quest-claim'))).onPressed, isNotNull);
  });
  testWidgets('signed out: visitor tour pages and no quest request', (tester) async {
    final repo = FakeGuideRepository(seed: [quest()]);
    await tester.pumpWidget(guideApp(repo, viewer: null));
    await tester.pumpAndSettle();
    expect(find.text('What is Sentinel X?'), findsOneWidget);
    await tester.tap(find.byKey(const Key('tour-next')));
    await tester.pumpAndSettle();
    expect(find.text('The four pillars'), findsOneWidget);
    expect(repo.questsCalls, 0);
  });
}
```

```dart
// test/router/guide_routes_test.dart (pump the real router the way the other test/router tests do)
testWidgets('/guide opens the guide screen outside the shell', (tester) async {
  await pumpRouterWithRepo(tester, initialLocation: '/guide', overrides: [
    viewerIdProvider.overrideWith((ref) async => 'u1'),
    guideRepositoryProvider.overrideWithValue(FakeGuideRepository(seed: [quest()])),
  ]);
  await tester.pumpAndSettle();
  expect(find.byType(GuideScreen), findsOneWidget);
  expect(find.byType(NavigationBar), findsNothing);
});
// test/core/routing/web_links_test.dart (append)
test('in-app guide paths are not swallowed by the redirect', () {
  expect(resolveWebLink('/guide'), isNull);
  expect(resolveWebLink('/guide/chat'), isNull);
});
```
`home_screen_test` gets one more assertion: a signed-out Home shows the guide button (`Key('guide-open')`) and no quest card. Add ARB `guideHelloNoName` "Hey there!" and use it when `/me` has no username.

The ARB keys the tests assert on are the English strings below.

- [ ] **Step 2: ARB keys (en; write natural fr for each).** `guideOpen` "Guide and assistant"; `guideTitle` "Guide"; `guideHello` "Hey {name}!" (placeholder `name`); `questBattleReadyTitle` "Battle Ready quest"; `questProgress` "{done} of {total} done" (ints); `questStepProfile_complete` "Complete your profile"; `questStepFirst_tournament_entered` "Enter your first tournament"; `questStepFirst_match_completed` "Complete your first match"; `questStepGeneric` "Complete this step"; `questTakeMeThere` "Take me there"; `questClaim` "Claim your badge"; `questClaiming` "Claiming…"; `questBadgeEarned` "Badge earned"; `questRewardLine` "{xp} XP and {coins} coins" (ints); `questErrorIncomplete` "Finish all three steps first."; `questErrorInProgress` "Your reward is still being processed. Try again in a minute."; `questErrorUnavailable` "This reward isn't available right now."; `questErrorGeneric` "Couldn't claim the badge. Try again."; `questLoadError` "Couldn't load your quest."; `guideAskAssistant` "Ask the assistant"; `guideReplayTour` "Replay the tour"; `tourSlide1Title` "What is Sentinel X?"; `tourSlide1Body` "Nigeria's home of mobile esports: compete, watch, join the community and trade gear."; `tourSlide2Title` "The four pillars"; `tourSlide2Body` "Compete in tournaments, watch Sentinel X TV, join the community and trade on the Gaming Exchange."; `tourSlide3Title` "How tournaments work"; `tourSlide3Body` "Register, pay the entry fee, play your fixtures and submit your result. An admin confirms it before the bracket updates."; `tourSlide4Title` "Ready to play?"; `tourSlide4Body` "Create an account to enter your first tournament."; `tourNext`, `tourBack`, `tourCreateAccount`. Check `messages/en.json` in the web repo for existing FourPillars/HowItWorks keys first; if the web has a namespace for them, add via `tool/gen_l10n_from_web.dart` instead (AGENTS.md rule 6).
- [ ] **Step 3: Implement the widgets and routes** as described above; `flutter gen-l10n`; add the asset to `pubspec.yaml` (`assets:\n    - assets/mascot/`).
- [ ] **Step 4: Run** `flutter test test/features/guide test/router test/core/routing && flutter analyze` → PASS.
- [ ] **Step 5: Refresh hooks.** In `lib/features/compete/registration_flow.dart`, next to each `ref.invalidate(registrationStateProvider(tournamentId))` that follows a confirmed registration (the lines at ~85, 158, 170, 176), add `ref.invalidate(questsProvider);`. Add one test that a confirmed registration invalidates the quests (extend the existing registration-flow test with a `FakeGuideRepository` counting calls).
- [ ] **Step 6: Commit** (`feat(guide): quest card, guide screen, visitor tour, mascot entry points`).

---

### Task 6: First-run coach marks

**Files:**
- Create: `lib/features/guide/coach/coach_registry.dart`, `coach_controller.dart`, `coach_host.dart`, `coach_tours.dart`
- Modify: `lib/features/home/home_screen.dart`, `lib/router/app_router.dart` (shell builder), `lib/shared/widgets/sx_tab_app_bar.dart`, `lib/features/guide/guide_screen.dart` ("Replay the tour"), ARB (en + fr)
- Test: `test/features/guide/coach/coach_controller_test.dart`, `coach_host_test.dart`

**Interfaces — Produces:**

```dart
class CoachTargetRegistry { GlobalKey keyFor(String id); Rect? rectFor(String id); }       // rectFor is null unless the target is mounted and laid out
final coachRegistryProvider = Provider<CoachTargetRegistry>((_) => CoachTargetRegistry());
class CoachTarget extends ConsumerWidget { const CoachTarget({required String id, required Widget child}); }
class CoachStep { final String targetId; final String Function(AppLocalizations) title, body; }
class CoachTour { final String id; final List<CoachStep> steps; }
const homeTour, shellTour;                                                                  // coach_tours.dart
class CoachState { final CoachTour? tour; final int index; bool get running; }
final coachControllerProvider = NotifierProvider<CoachController, CoachState>(...);
// CoachController: Future<void> maybeStart(CoachTour tour); void next(); void skip(); Future<void> resetAll();
class CoachHost extends ConsumerStatefulWidget { CoachHost({required CoachTour tour, required Widget child}) }   // starts the tour once after the first frame, paints the overlay while running
```

Rules: a tour starts only if its seen flag (`coach.<viewerId or 'guest'>.<tour.id>` in `LocalKv`) is absent **and at least one step's target resolves**; steps whose target is not mounted are skipped; the tour never starts while another is running; Next past the last step, Skip, and the system back button all mark it seen and close it; `resetAll()` removes both tours' flags for the current viewer; "Replay the tour" calls `resetAll()` then `context.go('/')`. Home tour steps: `home.fixtures`, `home.quest`, `home.guide`, `home.account`. Shell tour steps: `shell.tabs` (the whole `NavigationBar`), `appbar.bell`, `appbar.messages`, `appbar.guide`. Targets are attached with `CoachTarget(id: ..., child: ...)` around the existing widgets. The overlay is an `OverlayEntry` (dim scrim with a rounded cutout around `rectFor(...)` + a callout card with the mascot, title, body, step dots, Skip and Next/Done), wrapped in a `Semantics(scopesRoute: true, explicitChildNodes: true)` that announces the step title; it has no animation (nothing to disable under reduced motion).

- [ ] **Step 1: Write the failing controller tests**

```dart
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/core/providers.dart';
import 'package:sentinelx_mobile/core/storage/local_kv.dart';
import 'package:sentinelx_mobile/features/guide/coach/coach_controller.dart';
import 'package:sentinelx_mobile/features/guide/coach/coach_registry.dart';
import 'package:sentinelx_mobile/features/guide/coach/coach_tours.dart';
import '../../../fakes/fake_local_kv.dart';

class _Registry extends CoachTargetRegistry {
  _Registry(this.present);
  final Set<String> present;
  @override Rect? rectFor(String id) => present.contains(id) ? const Rect.fromLTWH(10, 10, 50, 50) : null;
}

ProviderContainer _c(MemoryLocalKv kv, Set<String> present, {String? viewer = 'u1'}) {
  final c = ProviderContainer(overrides: [
    localKvProvider.overrideWith((ref) async => kv),
    viewerIdProvider.overrideWith((ref) async => viewer),
    coachRegistryProvider.overrideWithValue(_Registry(present)),
  ]);
  addTearDown(c.dispose);
  return c;
}

void main() {
  final allHome = homeTour.steps.map((s) => s.targetId).toSet();
  test('starts once, then never again after it is finished (per viewer)', () async {
    final kv = MemoryLocalKv();
    final c = _c(kv, allHome);
    await c.read(coachControllerProvider.notifier).maybeStart(homeTour);
    expect(c.read(coachControllerProvider).running, isTrue);
    c.read(coachControllerProvider.notifier).skip();
    await Future<void>.delayed(Duration.zero);
    expect(kv.values.keys.any((k) => k.startsWith('coach.u1.')), isTrue);
    await c.read(coachControllerProvider.notifier).maybeStart(homeTour);
    expect(c.read(coachControllerProvider).running, isFalse);
  });
  test('the seen flag is per viewer: another account still sees the tour', () async {
    final kv = MemoryLocalKv()..values['coach.u1.${homeTour.id}'] = '1';
    final c = _c(kv, allHome, viewer: 'u2');
    await c.read(coachControllerProvider.notifier).maybeStart(homeTour);
    expect(c.read(coachControllerProvider).running, isTrue);
  });
  test('signed-out visitors use the guest key', () async {
    final kv = MemoryLocalKv();
    final c = _c(kv, allHome, viewer: null);
    await c.read(coachControllerProvider.notifier).maybeStart(homeTour);
    c.read(coachControllerProvider.notifier).skip();
    await Future<void>.delayed(Duration.zero);
    expect(kv.values.keys.any((k) => k.startsWith('coach.guest.')), isTrue);
  });
  test('does not start when none of its targets are on screen (same-page only), and does not mark it seen', () async {
    final kv = MemoryLocalKv();
    final c = _c(kv, {});
    await c.read(coachControllerProvider.notifier).maybeStart(homeTour);
    expect(c.read(coachControllerProvider).running, isFalse);
    expect(kv.values, isEmpty);
  });
  test('skips steps whose target is missing and finishes after the last present one', () async {
    final present = {homeTour.steps.first.targetId, homeTour.steps.last.targetId};
    final c = _c(MemoryLocalKv(), present);
    final n = c.read(coachControllerProvider.notifier);
    await n.maybeStart(homeTour);
    expect(c.read(coachControllerProvider).running, isTrue);
    n.next();
    n.next();
    expect(c.read(coachControllerProvider).running, isFalse);
  });
  test('resetAll clears the flags so the tours run again', () async {
    final kv = MemoryLocalKv()..values['coach.u1.${homeTour.id}'] = '1'..values['coach.u1.${shellTour.id}'] = '1';
    final c = _c(kv, allHome);
    await c.read(coachControllerProvider.notifier).resetAll();
    expect(kv.values.keys.where((k) => k.startsWith('coach.u1.')), isEmpty);
  });
  test('a storage failure never blocks or crashes the tour', () async {
    final kv = MemoryLocalKv()..failWrites = true;
    final c = _c(kv, allHome);
    final n = c.read(coachControllerProvider.notifier);
    await n.maybeStart(homeTour);
    n.skip();
    expect(c.read(coachControllerProvider).running, isFalse);
  });
}
```

- [ ] **Step 2: Write the failing host test** (`coach_host_test.dart`): pump a `MaterialApp` with a `CoachHost(tour: homeTour, child: Column([... CoachTarget(id: 'home.fixtures', ...), CoachTarget(id: 'home.account', ...)]))` and `MemoryLocalKv`; after `pumpAndSettle` the overlay shows the first present step's title (find by the ARB English text); tapping Next advances; tapping Skip removes the overlay and writes the flag; a system back (`tester.pageBack()`/`handlePopRoute`) dismisses it; the tour does not reappear on a second pump of the same app with the same kv.
- [ ] **Step 3: Run to verify FAIL.** Step 4: implement.

```dart
// lib/features/guide/coach/coach_registry.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CoachTargetRegistry {
  final _keys = <String, GlobalKey>{};
  GlobalKey keyFor(String id) => _keys.putIfAbsent(id, () => GlobalKey(debugLabel: 'coach:$id'));
  Rect? rectFor(String id) {
    final ctx = _keys[id]?.currentContext;
    final box = ctx?.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }
}

final coachRegistryProvider = Provider<CoachTargetRegistry>((_) => CoachTargetRegistry());

class CoachTarget extends ConsumerWidget {
  const CoachTarget({super.key, required this.id, required this.child});
  final String id;
  final Widget child;
  @override
  Widget build(BuildContext context, WidgetRef ref) => KeyedSubtree(key: ref.read(coachRegistryProvider).keyFor(id), child: child);
}
```

```dart
// lib/features/guide/coach/coach_tours.dart
import '../../../core/l10n/gen/app_localizations.dart';

class CoachStep {
  const CoachStep(this.targetId, this.title, this.body);
  final String targetId;
  final String Function(AppLocalizations) title, body;
}

class CoachTour {
  const CoachTour(this.id, this.steps);
  final String id;
  final List<CoachStep> steps;
}

final homeTour = CoachTour('home', [
  CoachStep('home.fixtures', (l) => l.coachFixturesTitle, (l) => l.coachFixturesBody),
  CoachStep('home.quest', (l) => l.coachQuestTitle, (l) => l.coachQuestBody),
  CoachStep('home.guide', (l) => l.coachGuideTitle, (l) => l.coachGuideBody),
  CoachStep('home.account', (l) => l.coachAccountTitle, (l) => l.coachAccountBody),
]);

final shellTour = CoachTour('shell', [
  CoachStep('shell.tabs', (l) => l.coachTabsTitle, (l) => l.coachTabsBody),
  CoachStep('appbar.bell', (l) => l.coachBellTitle, (l) => l.coachBellBody),
  CoachStep('appbar.messages', (l) => l.coachMessagesTitle, (l) => l.coachMessagesBody),
  CoachStep('appbar.guide', (l) => l.coachGuideTitle, (l) => l.coachGuideBody),
]);
```
(`const` is not possible with closures over `AppLocalizations`; the lists are `final`.)

```dart
// lib/features/guide/coach/coach_controller.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers.dart';
import '../../../core/storage/local_kv.dart';
import 'coach_registry.dart';
import 'coach_tours.dart';

class CoachState {
  const CoachState({this.tour, this.index = 0});
  final CoachTour? tour;
  final int index;
  bool get running => tour != null;
}

class CoachController extends Notifier<CoachState> {
  @override
  CoachState build() => const CoachState();

  Future<String> _scope() async => (await ref.read(viewerIdProvider.future)) ?? 'guest';
  String _key(String scope, CoachTour t) => 'coach.$scope.${t.id}';

  int? _firstPresent(CoachTour t, int from) {
    final reg = ref.read(coachRegistryProvider);
    for (var i = from; i < t.steps.length; i++) {
      if (reg.rectFor(t.steps[i].targetId) != null) return i;
    }
    return null;
  }

  Future<void> maybeStart(CoachTour tour) async {
    if (state.running) return;
    try {
      final scope = await _scope();
      final kv = await ref.read(localKvProvider.future);
      if (!ref.mounted || state.running) return;
      if (await kv.read(_key(scope, tour)) != null) return;
      final first = _firstPresent(tour, 0);
      if (first == null) return; // same-page only: nothing to point at, and it stays unseen
      state = CoachState(tour: tour, index: first);
    } catch (_) {
      // storage trouble must never block the app
    }
  }

  void next() {
    final t = state.tour;
    if (t == null) return;
    final n = _firstPresent(t, state.index + 1);
    if (n == null) {
      _finish(t);
    } else {
      state = CoachState(tour: t, index: n);
    }
  }

  void skip() {
    final t = state.tour;
    if (t != null) _finish(t);
  }

  void _finish(CoachTour t) {
    state = const CoachState();
    _markSeen(t);
  }

  Future<void> _markSeen(CoachTour t) async {
    try {
      final scope = await _scope();
      final kv = await ref.read(localKvProvider.future);
      await kv.write(_key(scope, t), '1');
    } catch (_) {}
  }

  Future<void> resetAll() async {
    try {
      final scope = await _scope();
      final kv = await ref.read(localKvProvider.future);
      for (final t in [homeTour, shellTour]) {
        await kv.remove(_key(scope, t));
      }
    } catch (_) {}
  }
}

final coachControllerProvider = NotifierProvider<CoachController, CoachState>(CoachController.new);
```

`CoachHost`: in `initState` schedule `WidgetsBinding.instance.addPostFrameCallback((_) => ref.read(coachControllerProvider.notifier).maybeStart(widget.tour))`; `ref.listen(coachControllerProvider, ...)` inserts/updates/removes an `OverlayEntry` (`Overlay.of(context, rootOverlay: true)`) built from the current step: a full-screen `CustomPaint` scrim (`SxColors`-based, with `Path.combine(PathOperation.difference, ...)` for the rounded cutout around `rectFor(step.targetId)` inflated by 6 px), the callout positioned below the cutout (above when the cutout is in the bottom half), and `PopScope(canPop: false, onPopInvokedWithResult: (_, _) => skip())`. Remove the entry in `dispose`.

- [ ] **Step 5: Wire the targets.** Home: wrap the `FixturesCard` in `CoachTarget(id: 'home.fixtures')`, the quest card in `home.quest`, the guide button in `home.guide`, the account button in `home.account`, and wrap `HomeScreen`'s `Scaffold` in `CoachHost(tour: homeTour)`. Shell (`app_router.dart`, the `StatefulShellRoute` builder): wrap the `NavigationBar` in `CoachTarget(id: 'shell.tabs')` and the `Scaffold` in `CoachHost(tour: shellTour)`; `SxTabAppBar`: wrap the bell, messages and guide buttons in `CoachTarget(id: 'appbar.bell'|'appbar.messages'|'appbar.guide')`. Guide screen: add the "Replay the tour" tile calling `await ref.read(coachControllerProvider.notifier).resetAll(); if (context.mounted) context.go('/');`.
- [ ] **Step 6: ARB (en + fr).** `coachFixturesTitle` "Your fixtures" / `Body` "Your next matches show up here. Check in when it's time."; `coachQuestTitle` "Battle Ready quest" / `Body` "Finish three steps to earn a badge and rewards."; `coachGuideTitle` "Guide and assistant" / `Body` "Quests, a quick tour and a chat assistant live here."; `coachAccountTitle` "Your account" / `Body` "Edit your profile and settings."; `coachTabsTitle` "Five tabs" / `Body` "Compete, Watch, Community, Trade and your Account."; `coachBellTitle` "Notifications" / `Body` "Match updates and rewards appear here."; `coachMessagesTitle` "Messages" / `Body` "Direct messages with other players."; plus `coachNext`, `coachDone`, `coachSkip`, `coachStepOf` ("{current} of {total}"). `flutter gen-l10n`.
- [ ] **Step 7: Run** `flutter test test/features/guide test/router && flutter analyze` → PASS. Existing router/home tests that pump Home or the shell must still pass (the host only starts when targets resolve; if an existing test now sees an overlay, override `localKvProvider` with a `MemoryLocalKv` pre-seeded with the seen flags in that test's helper rather than weakening the feature).
- [ ] **Step 8: Mutation check:** make `maybeStart` ignore the seen flag; the "starts once" test must fail; restore.
- [ ] **Step 9: Commit** (`feat(guide): first-run coach marks with per-viewer seen flags and replay`).

---

### Task 7: Chat state — repository seam and the turn state machine

**Files:**
- Create: `lib/features/support_chat/chat_repository.dart`, `chat_notifier.dart`, `chat_destinations.dart`, `test/fakes/fake_chat_repository.dart`
- Test: `test/features/support_chat/chat_notifier_test.dart`, `chat_destinations_test.dart`

**Interfaces:**
- Consumes: `ApiClient.postChatMessage/getChatHistory/deleteChatHistory`, `viewerIdProvider`, `chatDeviceIdProvider`, `appLifecycleSourceProvider`, `newIdempotencyKey`, `cleanChatText`, `ChatEvent` types.
- Produces:

```dart
abstract class ChatRepository {
  Future<ChatHistoryPage> history({String? before});
  Future<void> clear();
  Stream<ChatEvent> send({required List<ChatTurnMessage> history, required String clientTurnId, required String locale, String? deviceId});
}
final chatRepositoryProvider = Provider<ChatRepository>(...);
enum ChatPhase { idle, sending, streaming, interrupted, failed }
class ChatBubble { final String id; final bool fromUser; final String text; final bool failed; ChatBubble copyWith({String? text, bool? failed}); }
class ChatState { final List<ChatBubble> bubbles; final ChatPhase phase; final String? errorCode; final int? retryAfterSeconds; final List<ChatDestination> actions; final bool checkingAccount, historyLoaded, signedIn; final String? nextBefore; }
final chatProvider = NotifierProvider.autoDispose<ChatNotifier, ChatState>(...);
// ChatNotifier: Future<void> loadHistory(); Future<void> loadOlder(); Future<void> send(String text, {required String locale}); Future<void> retry({required String locale}); Future<void> clearHistory();
String? destinationRoute(ChatDestination d);  // tournaments -> '/tournaments', matches -> '/', profile -> '/account/profile', notifications -> '/notifications', others -> null (chip hidden until the screen exists)
```

State-machine rules (each is a test below):
1. `send` ignores blank text, text over 1,000 chars after cleaning, and any call while `sending`/`streaming`.
2. One `clientTurnId` (`newIdempotencyKey()`) per compose action; `retry` reuses it.
3. The request history is the previous bubbles (non-empty, non-failed-assistant) plus the new user bubble, **last 20 messages, total at most 8,000 chars (drop oldest), user content truncated to 1,000 and assistant content to 4,000**.
4. `ChatDelta` appends `cleanChatText(text)` to the assistant bubble and moves phase to `streaming`; `ChatStatus` sets `checkingAccount`; `ChatActions` sets `actions`; `ChatDone` ends the turn (`idle`).
5. `ChatError` before or after text: phase `failed` with `errorCode`; an empty assistant bubble is removed; the user bubble is marked `failed`.
6. A stream that ends without a terminal event, or the app pausing (`paused`/`hidden`) mid-turn, is `interrupted` (stream cancelled, partial text kept, user bubble `failed`).
7. A pre-stream `ApiException`: `failed` with its `code` (`unauthorized` for 401), `retryAfterSeconds` from `fields['retryAfterSeconds']`; any other exception: `network`.
8. A keep-alive (`ref.keepAlive()`) is held while a turn is in flight and released on any terminal state or after 90 s; mutators no-op when `!ref.mounted`.
9. Signed-out: no history load; no `viewerId`; `deviceId` is passed; nothing persisted anywhere on the device. Signed-in: `deviceId` is `null`.
10. `loadHistory` runs once when signed in, prepends server history (`h<id>` bubble ids) before any bubbles already present, sets `nextBefore`; a failure is silent (`historyLoaded = true`). `clearHistory` clears bubbles on success and sets `errorCode: 'clear_failed'` on failure (bubbles kept).

- [ ] **Step 1: Write the failing tests**

```dart
// test/fakes/fake_chat_repository.dart
import 'dart:async';
import 'package:sentinelx_mobile/core/api/chat_models.dart';
import 'package:sentinelx_mobile/features/support_chat/chat_repository.dart';

class FakeChatRepository implements ChatRepository {
  final sends = <({List<ChatTurnMessage> history, String turnId, String locale, String? deviceId})>[];
  final controllers = <StreamController<ChatEvent>>[];
  ChatHistoryPage historyPage = const ChatHistoryPage(messages: []);
  Object? historyError;
  Object? clearError;
  Object? sendError; // thrown by the stream before any event
  int clears = 0, historyCalls = 0;

  StreamController<ChatEvent> get last => controllers.last;

  @override
  Stream<ChatEvent> send({required List<ChatTurnMessage> history, required String clientTurnId, required String locale, String? deviceId}) {
    sends.add((history: history, turnId: clientTurnId, locale: locale, deviceId: deviceId));
    final c = StreamController<ChatEvent>();
    controllers.add(c);
    if (sendError != null) {
      scheduleMicrotask(() { c.addError(sendError!); c.close(); });
    }
    return c.stream;
  }
  @override Future<ChatHistoryPage> history({String? before}) async { historyCalls++; if (historyError != null) throw historyError!; return historyPage; }
  @override Future<void> clear() async { clears++; if (clearError != null) throw clearError!; }
}
```

```dart
// test/features/support_chat/chat_notifier_test.dart
import 'package:fake_async/fake_async.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/core/api/api_client.dart';
import 'package:sentinelx_mobile/core/api/chat_models.dart';
import 'package:sentinelx_mobile/core/lifecycle/app_lifecycle_provider.dart';
import 'package:sentinelx_mobile/core/providers.dart';
import 'package:sentinelx_mobile/core/storage/local_kv.dart';
import 'package:sentinelx_mobile/features/support_chat/chat_notifier.dart';
import 'package:sentinelx_mobile/features/support_chat/chat_repository.dart';
import '../../fakes/fake_chat_repository.dart';
import '../../fakes/fake_realtime.dart' show FakeLifecycle;

({ProviderContainer c, FakeChatRepository repo, FakeLifecycle life}) _setup({String? viewer = 'u1'}) {
  final repo = FakeChatRepository();
  final life = FakeLifecycle();
  final c = ProviderContainer(overrides: [
    viewerIdProvider.overrideWith((ref) async => viewer),
    chatRepositoryProvider.overrideWithValue(repo),
    appLifecycleSourceProvider.overrideWithValue(life),
    chatDeviceIdProvider.overrideWith((ref) async => 'device-abc-123'),
  ]);
  addTearDown(c.dispose);
  c.listen(chatProvider, (_, _) {}); // keep it alive for the test
  return (c: c, repo: repo, life: life);
}

Future<void> _settle() => Future<void>.delayed(Duration.zero);

void main() {
  test('happy path: user bubble, streamed assistant text, done -> idle', () async {
    final s = _setup();
    await s.c.read(viewerIdProvider.future);
    final n = s.c.read(chatProvider.notifier);
    final f = n.send('how do fees work', locale: 'en');
    await _settle();
    expect(s.c.read(chatProvider).phase, ChatPhase.sending);
    s.repo.last.add(const ChatDelta('Entry is '));
    await _settle();
    expect(s.c.read(chatProvider).phase, ChatPhase.streaming);
    s.repo.last.add(const ChatDelta('₦500.'));
    s.repo.last.add(const ChatDone(true));
    await s.repo.last.close();
    await f;
    final st = s.c.read(chatProvider);
    expect(st.phase, ChatPhase.idle);
    expect(st.bubbles.map((b) => b.text), ['how do fees work', 'Entry is ₦500.']);
  });
  test('deltas are cleaned: bidi/control characters never reach the bubble, markup stays literal', () async {
    final s = _setup();
    await s.c.read(viewerIdProvider.future);
    final f = s.c.read(chatProvider.notifier).send('hi', locale: 'en');
    await _settle();
    s.repo.last.add(const ChatDelta('a\u202Eb <b>x</b>'));
    s.repo.last.add(const ChatDone(false));
    await s.repo.last.close();
    await f;
    expect(s.c.read(chatProvider).bubbles.last.text, 'ab <b>x</b>');
  });
  test('ignores blank, over-long and concurrent sends', () async {
    final s = _setup();
    await s.c.read(viewerIdProvider.future);
    final n = s.c.read(chatProvider.notifier);
    await n.send('   ', locale: 'en');
    await n.send('x' * 1001, locale: 'en');
    expect(s.repo.sends, isEmpty);
    final f = n.send('one', locale: 'en');
    await _settle();
    await n.send('two', locale: 'en'); // ignored while in flight
    expect(s.repo.sends, hasLength(1));
    s.repo.last.add(const ChatDone(false));
    await s.repo.last.close();
    await f;
  });
  test('request history: last 20, <= 8000 chars, per-role truncation', () async {
    final s = _setup();
    s.repo.historyPage = ChatHistoryPage(messages: [
      for (var i = 0; i < 30; i++)
        ChatHistoryItem(id: '$i', role: i.isEven ? 'user' : 'assistant', content: i.isEven ? 'u' * 900 : 'a' * 4500, createdAt: DateTime.utc(2026, 10, 1, 0, i)),
    ]);
    await s.c.read(viewerIdProvider.future);
    final n = s.c.read(chatProvider.notifier);
    await n.loadHistory();
    final f = n.send('now', locale: 'fr');
    await _settle();
    final h = s.repo.sends.single.history;
    expect(h.length, lessThanOrEqualTo(20));
    expect(h.fold<int>(0, (a, m) => a + m.content.length), lessThanOrEqualTo(8000));
    expect(h.every((m) => m.content.length <= (m.role == 'user' ? 1000 : 4000)), isTrue);
    expect(h.last.content, 'now');
    expect(s.repo.sends.single.locale, 'fr');
    s.repo.last.add(const ChatDone(false));
    await s.repo.last.close();
    await f;
  });
  test('stream ends without a terminal event -> interrupted, partial text kept, retry reuses the SAME turn id', () async {
    final s = _setup();
    await s.c.read(viewerIdProvider.future);
    final n = s.c.read(chatProvider.notifier);
    final f = n.send('q', locale: 'en');
    await _settle();
    s.repo.last.add(const ChatDelta('partial'));
    await s.repo.last.close(); // EOF, no ChatDone
    await f;
    var st = s.c.read(chatProvider);
    expect(st.phase, ChatPhase.interrupted);
    expect(st.bubbles.last.text, 'partial');
    expect(st.bubbles.where((b) => b.fromUser).single.failed, isTrue);
    final firstTurn = s.repo.sends.single.turnId;
    final r = n.retry(locale: 'en');
    await _settle();
    expect(s.repo.sends, hasLength(2));
    expect(s.repo.sends.last.turnId, firstTurn);
    expect(s.c.read(chatProvider).bubbles.where((b) => b.fromUser), hasLength(1)); // no duplicate user bubble
    s.repo.last.add(const ChatDelta('full answer'));
    s.repo.last.add(const ChatDone(true));
    await s.repo.last.close();
    await r;
    st = s.c.read(chatProvider);
    expect(st.phase, ChatPhase.idle);
    expect(st.bubbles.map((b) => b.text), ['q', 'full answer']);
  });
  test('pausing the app mid-stream interrupts the turn', () async {
    final s = _setup();
    await s.c.read(viewerIdProvider.future);
    final f = s.c.read(chatProvider.notifier).send('q', locale: 'en');
    await _settle();
    s.repo.last.add(const ChatDelta('a'));
    await _settle();
    s.life.push(AppLifecycleState.paused);
    await _settle();
    expect(s.c.read(chatProvider).phase, ChatPhase.interrupted);
    await s.repo.last.close();
    await f;
  });
  test('a terminal error event fails the turn with its code and removes an empty assistant bubble', () async {
    final s = _setup();
    await s.c.read(viewerIdProvider.future);
    final f = s.c.read(chatProvider.notifier).send('q', locale: 'en');
    await _settle();
    s.repo.last.add(const ChatError('chat_truncated'));
    await s.repo.last.close();
    await f;
    final st = s.c.read(chatProvider);
    expect(st.phase, ChatPhase.failed);
    expect(st.errorCode, 'chat_truncated');
    expect(st.bubbles.map((b) => b.fromUser), [true]);
  });
  test('rate limited before the stream: failed with code and retryAfterSeconds', () async {
    final s = _setup();
    s.repo.sendError = const ApiException(status: 429, code: 'chat_rate_limited', message: 'x', fields: {'retryAfterSeconds': '42'});
    await s.c.read(viewerIdProvider.future);
    await s.c.read(chatProvider.notifier).send('q', locale: 'en');
    final st = s.c.read(chatProvider);
    expect(st.errorCode, 'chat_rate_limited');
    expect(st.retryAfterSeconds, 42);
  });
  test('401 maps to unauthorized and a non-API error maps to network', () async {
    var s = _setup();
    s.repo.sendError = const ApiException(status: 401, code: 'unauthorized', message: 'x');
    await s.c.read(viewerIdProvider.future);
    await s.c.read(chatProvider.notifier).send('q', locale: 'en');
    expect(s.c.read(chatProvider).errorCode, 'unauthorized');
    s = _setup();
    s.repo.sendError = StateError('boom');
    await s.c.read(viewerIdProvider.future);
    await s.c.read(chatProvider.notifier).send('q', locale: 'en');
    expect(s.c.read(chatProvider).errorCode, 'network');
  });
  test('signed out: no history call, device id sent, signedIn false', () async {
    final s = _setup(viewer: null);
    await s.c.read(viewerIdProvider.future);
    final n = s.c.read(chatProvider.notifier);
    await n.loadHistory();
    expect(s.repo.historyCalls, 0);
    final f = n.send('q', locale: 'en');
    await _settle();
    expect(s.repo.sends.single.deviceId, 'device-abc-123');
    s.repo.last.add(const ChatDone(false));
    await s.repo.last.close();
    await f;
  });
  test('signed in: no device id is sent', () async {
    final s = _setup();
    await s.c.read(viewerIdProvider.future);
    final f = s.c.read(chatProvider.notifier).send('q', locale: 'en');
    await _settle();
    expect(s.repo.sends.single.deviceId, isNull);
    s.repo.last.add(const ChatDone(false));
    await s.repo.last.close();
    await f;
  });
  test('history loads once, prepends, sets nextBefore, and a failure is silent', () async {
    final s = _setup();
    s.repo.historyPage = ChatHistoryPage(messages: [ChatHistoryItem(id: 'a', role: 'user', content: 'old', createdAt: DateTime.utc(2026))], nextBefore: 'cur');
    await s.c.read(viewerIdProvider.future);
    final n = s.c.read(chatProvider.notifier);
    await n.loadHistory();
    await n.loadHistory(); // second call is a no-op
    expect(s.repo.historyCalls, 1);
    expect(s.c.read(chatProvider).bubbles.single.text, 'old');
    expect(s.c.read(chatProvider).nextBefore, 'cur');
    final s2 = _setup();
    s2.repo.historyError = StateError('x');
    await s2.c.read(viewerIdProvider.future);
    await s2.c.read(chatProvider.notifier).loadHistory();
    expect(s2.c.read(chatProvider).historyLoaded, isTrue);
  });
  test('clearHistory empties on success and keeps bubbles with clear_failed on failure', () async {
    final s = _setup();
    s.repo.historyPage = ChatHistoryPage(messages: [ChatHistoryItem(id: 'a', role: 'user', content: 'old', createdAt: DateTime.utc(2026))]);
    await s.c.read(viewerIdProvider.future);
    final n = s.c.read(chatProvider.notifier);
    await n.loadHistory();
    s.repo.clearError = StateError('x');
    await n.clearHistory();
    expect(s.c.read(chatProvider).errorCode, 'clear_failed');
    expect(s.c.read(chatProvider).bubbles, isNotEmpty);
    s.repo.clearError = null;
    await n.clearHistory();
    expect(s.c.read(chatProvider).bubbles, isEmpty);
  });
  test('the in-flight keep-alive is released after 90 s even if the stream never ends', () {
    fakeAsync((async) {
      final s = _setup();
      final n = s.c.read(chatProvider.notifier);
      n.send('q', locale: 'en');
      async.flushMicrotasks();
      async.elapse(const Duration(seconds: 91));
      async.flushMicrotasks();
      expect(s.c.read(chatProvider).phase, ChatPhase.interrupted);
    });
  });
}
```

```dart
// test/features/support_chat/chat_destinations_test.dart
test('only destinations that have a screen map to a route; the rest are hidden', () {
  expect(destinationRoute(ChatDestination.tournaments), '/tournaments');
  expect(destinationRoute(ChatDestination.matches), '/');
  expect(destinationRoute(ChatDestination.profile), '/account/profile');
  expect(destinationRoute(ChatDestination.notifications), '/notifications');
  expect(destinationRoute(ChatDestination.wallet), isNull);
  expect(destinationRoute(ChatDestination.rules), isNull);
});
```
(The wallet/rules/safety/help screens do not exist in the app yet; extend this table as they ship. A chip with no route is not rendered.)

- [ ] **Step 2: Run to verify FAIL.** Step 3: implement.

```dart
// lib/features/support_chat/chat_repository.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';
import '../../core/api/chat_models.dart';
import '../../core/providers.dart';

abstract class ChatRepository {
  Future<ChatHistoryPage> history({String? before});
  Future<void> clear();
  Stream<ChatEvent> send({required List<ChatTurnMessage> history, required String clientTurnId, required String locale, String? deviceId});
}

class ApiChatRepository implements ChatRepository {
  ApiChatRepository(this._api);
  final ApiClient _api;
  @override Future<ChatHistoryPage> history({String? before}) => _api.getChatHistory(before: before);
  @override Future<void> clear() => _api.deleteChatHistory();
  @override
  Stream<ChatEvent> send({required List<ChatTurnMessage> history, required String clientTurnId, required String locale, String? deviceId}) =>
      _api.postChatMessage(messages: history, clientTurnId: clientTurnId, locale: locale, deviceId: deviceId);
}

final chatRepositoryProvider = Provider<ChatRepository>((ref) => ApiChatRepository(ref.watch(apiClientProvider)));
```

```dart
// lib/features/support_chat/chat_destinations.dart
import '../../core/api/chat_models.dart';

/// The ONLY way model output can influence navigation: a validated enum through this fixed table.
String? destinationRoute(ChatDestination d) => switch (d) {
      ChatDestination.tournaments => '/tournaments',
      ChatDestination.matches => '/',
      ChatDestination.profile => '/account/profile',
      ChatDestination.notifications => '/notifications',
      ChatDestination.wallet || ChatDestination.rules || ChatDestination.safety || ChatDestination.help => null,
    };
```

```dart
// lib/features/support_chat/chat_notifier.dart
import 'dart:async';
import 'package:flutter/widgets.dart' show AppLifecycleState;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';
import '../../core/api/chat_models.dart';
import '../../core/lifecycle/app_lifecycle_provider.dart';
import '../../core/providers.dart';
import '../../core/storage/local_kv.dart';
import '../../core/utils/idempotency_key.dart';
import 'chat_repository.dart';

enum ChatPhase { idle, sending, streaming, interrupted, failed }

class ChatBubble {
  const ChatBubble({required this.id, required this.fromUser, required this.text, this.failed = false});
  final String id;
  final bool fromUser;
  final String text;
  final bool failed;
  ChatBubble copyWith({String? text, bool? failed}) => ChatBubble(id: id, fromUser: fromUser, text: text ?? this.text, failed: failed ?? this.failed);
}

class ChatState {
  const ChatState({
    this.bubbles = const [],
    this.phase = ChatPhase.idle,
    this.errorCode,
    this.retryAfterSeconds,
    this.actions = const [],
    this.checkingAccount = false,
    this.historyLoaded = false,
    this.signedIn = false,
    this.nextBefore,
  });
  final List<ChatBubble> bubbles;
  final ChatPhase phase;
  final String? errorCode;
  final int? retryAfterSeconds;
  final List<ChatDestination> actions;
  final bool checkingAccount, historyLoaded, signedIn;
  final String? nextBefore;

  ChatState copyWith({
    List<ChatBubble>? bubbles,
    ChatPhase? phase,
    String? errorCode,
    int? retryAfterSeconds,
    bool clearError = false,
    List<ChatDestination>? actions,
    bool? checkingAccount,
    bool? historyLoaded,
    bool? signedIn,
    String? nextBefore,
  }) =>
      ChatState(
        bubbles: bubbles ?? this.bubbles,
        phase: phase ?? this.phase,
        errorCode: clearError ? null : (errorCode ?? this.errorCode),
        retryAfterSeconds: clearError ? null : (retryAfterSeconds ?? this.retryAfterSeconds),
        actions: actions ?? this.actions,
        checkingAccount: checkingAccount ?? this.checkingAccount,
        historyLoaded: historyLoaded ?? this.historyLoaded,
        signedIn: signedIn ?? this.signedIn,
        nextBefore: nextBefore ?? this.nextBefore,
      );
}

class ChatNotifier extends Notifier<ChatState> {
  static const _maxUser = 1000, _maxAssistant = 4000, _maxMessages = 20, _maxTotal = 8000;
  static const _inFlightCap = Duration(seconds: 90);

  StreamSubscription<ChatEvent>? _sub;
  KeepAliveLink? _keep;
  Timer? _cap;
  String? _turnId;
  int _seq = 0;
  bool _sawTerminal = false;
  Completer<void>? _pending; // completed whenever the current turn stops, so `_run` never hangs

  @override
  ChatState build() {
    final viewer = ref.watch(viewerIdProvider).asData?.value;
    final life = ref.watch(appLifecycleSourceProvider).changes.listen((s) {
      if ((s == AppLifecycleState.paused || s == AppLifecycleState.hidden) && _inFlight) _interrupt();
    });
    ref.onDispose(() {
      life.cancel();
      _teardown();
    });
    return ChatState(signedIn: viewer != null);
  }

  bool get _inFlight => state.phase == ChatPhase.sending || state.phase == ChatPhase.streaming;

  void _hold() {
    _keep ??= ref.keepAlive();
    _cap?.cancel();
    _cap = Timer(_inFlightCap, () {
      if (ref.mounted && _inFlight) _interrupt();
    });
  }

  void _release() {
    _cap?.cancel();
    _cap = null;
    _keep?.close();
    _keep = null;
  }

  void _teardown() {
    _cap?.cancel();
    _sub?.cancel();
    _sub = null;
    if (_pending?.isCompleted == false) _pending!.complete();
  }

  Future<void> loadHistory() async {
    if (!state.signedIn || state.historyLoaded) return;
    try {
      final page = await ref.read(chatRepositoryProvider).history();
      if (!ref.mounted) return;
      final hist = [for (final m in page.messages) ChatBubble(id: 'h${m.id}', fromUser: m.role == 'user', text: m.content)];
      state = state.copyWith(bubbles: [...hist, ...state.bubbles], historyLoaded: true, nextBefore: page.nextBefore);
    } catch (_) {
      if (ref.mounted) state = state.copyWith(historyLoaded: true);
    }
  }

  Future<void> loadOlder() async {
    final before = state.nextBefore;
    if (!state.signedIn || before == null) return;
    try {
      final page = await ref.read(chatRepositoryProvider).history(before: before);
      if (!ref.mounted) return;
      final hist = [for (final m in page.messages) ChatBubble(id: 'h${m.id}', fromUser: m.role == 'user', text: m.content)];
      state = ChatState(
        bubbles: [...hist, ...state.bubbles], phase: state.phase, errorCode: state.errorCode, retryAfterSeconds: state.retryAfterSeconds,
        actions: state.actions, checkingAccount: state.checkingAccount, historyLoaded: true, signedIn: state.signedIn, nextBefore: page.nextBefore,
      );
    } catch (_) {}
  }

  Future<void> send(String raw, {required String locale}) async {
    final text = cleanChatText(raw).trim();
    if (text.isEmpty || text.length > _maxUser || _inFlight) return;
    final seq = ++_seq;
    _turnId = newIdempotencyKey();
    state = state.copyWith(
      bubbles: [
        ...state.bubbles,
        ChatBubble(id: 'u$seq', fromUser: true, text: text),
        ChatBubble(id: 'a$seq', fromUser: false, text: ''),
      ],
      phase: ChatPhase.sending,
      clearError: true,
      actions: const [],
      checkingAccount: false,
    );
    await _run(locale: locale, userId: 'u$seq', assistantId: 'a$seq');
  }

  Future<void> retry({required String locale}) async {
    if ((state.phase != ChatPhase.failed && state.phase != ChatPhase.interrupted) || _turnId == null) return;
    final idx = state.bubbles.lastIndexWhere((b) => b.fromUser);
    if (idx < 0 || !state.bubbles[idx].failed) return;
    final user = state.bubbles[idx];
    final seq = ++_seq;
    final kept = [for (var i = 0; i <= idx; i++) i == idx ? user.copyWith(failed: false) : state.bubbles[i]];
    state = state.copyWith(
      bubbles: [...kept, ChatBubble(id: 'a$seq', fromUser: false, text: '')],
      phase: ChatPhase.sending,
      clearError: true,
      actions: const [],
      checkingAccount: false,
    );
    await _run(locale: locale, userId: user.id, assistantId: 'a$seq');
  }

  List<ChatTurnMessage> _requestHistory(String assistantId) {
    final msgs = <ChatTurnMessage>[
      for (final b in state.bubbles)
        if (b.id != assistantId && b.text.isNotEmpty)
          ChatTurnMessage(
            b.fromUser ? 'user' : 'assistant',
            b.text.length > (b.fromUser ? _maxUser : _maxAssistant) ? b.text.substring(0, b.fromUser ? _maxUser : _maxAssistant) : b.text,
          ),
    ];
    var recent = msgs.length > _maxMessages ? msgs.sublist(msgs.length - _maxMessages) : msgs;
    var total = recent.fold<int>(0, (a, m) => a + m.content.length);
    while (total > _maxTotal && recent.length > 1) {
      total -= recent.first.content.length;
      recent = recent.sublist(1);
    }
    return recent;
  }

  Future<void> _run({required String locale, required String userId, required String assistantId}) async {
    _hold();
    _sawTerminal = false;
    final history = _requestHistory(assistantId);
    final String? device = state.signedIn ? null : await ref.read(chatDeviceIdProvider.future);
    if (!ref.mounted || !_inFlight) return; // interrupted (e.g. paused) while the device id was loading
    final done = Completer<void>();
    _pending = done;
    _sub = ref
        .read(chatRepositoryProvider)
        .send(history: history, clientTurnId: _turnId!, locale: locale, deviceId: device)
        .listen(
      (e) => _onEvent(e, userId, assistantId),
      onError: (Object err) {
        if (!_sawTerminal && ref.mounted) _failWith(err, userId, assistantId);
        if (!done.isCompleted) done.complete();
      },
      onDone: () {
        if (!_sawTerminal && ref.mounted && _inFlight) _interrupt(assistantId: assistantId, userId: userId);
        if (!done.isCompleted) done.complete();
      },
      cancelOnError: true,
    );
    await done.future;
  }

  void _onEvent(ChatEvent e, String userId, String assistantId) {
    if (!ref.mounted) return;
    switch (e) {
      case ChatStatus():
        state = state.copyWith(checkingAccount: true);
      case ChatDelta(:final text):
        final t = cleanChatText(text);
        state = state.copyWith(
          bubbles: [for (final b in state.bubbles) b.id == assistantId ? b.copyWith(text: b.text + t) : b],
          phase: ChatPhase.streaming,
          checkingAccount: false,
        );
      case ChatActions(:final items):
        state = state.copyWith(actions: items);
      case ChatDone():
        _sawTerminal = true;
        state = state.copyWith(phase: ChatPhase.idle, checkingAccount: false);
        _release();
      case ChatError(:final code):
        _sawTerminal = true;
        _fail(code, userId, assistantId);
    }
  }

  void _failWith(Object err, String userId, String assistantId) {
    if (err is ApiException) {
      final retry = int.tryParse(err.fields['retryAfterSeconds'] ?? '');
      _fail(err.isUnauthorized ? 'unauthorized' : err.code, userId, assistantId, retryAfterSeconds: retry);
    } else {
      _fail('network', userId, assistantId);
    }
  }

  void _fail(String code, String userId, String assistantId, {int? retryAfterSeconds}) {
    state = state.copyWith(
      bubbles: _settle(userId, assistantId),
      phase: ChatPhase.failed,
      errorCode: code,
      retryAfterSeconds: retryAfterSeconds,
      checkingAccount: false,
    );
    _release();
  }

  /// An empty assistant bubble is removed; the user bubble is marked failed so Retry knows what to resend.
  List<ChatBubble> _settle(String userId, String assistantId) => [
        for (final b in state.bubbles)
          if (b.id == assistantId && b.text.isEmpty) ...const <ChatBubble>[] else if (b.id == userId) b.copyWith(failed: true) else b,
      ];

  void _interrupt({String? assistantId, String? userId}) {
    _sub?.cancel();
    _sub = null;
    if (_pending?.isCompleted == false) _pending!.complete();
    final lastUser = userId ?? (state.bubbles.lastIndexWhere((b) => b.fromUser) >= 0 ? state.bubbles[state.bubbles.lastIndexWhere((b) => b.fromUser)].id : '');
    final lastAssistant = assistantId ?? (state.bubbles.isNotEmpty && !state.bubbles.last.fromUser ? state.bubbles.last.id : '');
    state = state.copyWith(bubbles: _settle(lastUser, lastAssistant), phase: ChatPhase.interrupted, checkingAccount: false);
    _release();
  }

  Future<void> clearHistory() async {
    try {
      await ref.read(chatRepositoryProvider).clear();
      if (!ref.mounted) return;
      state = ChatState(signedIn: state.signedIn, historyLoaded: true);
    } catch (_) {
      if (ref.mounted) state = state.copyWith(errorCode: 'clear_failed');
    }
  }
}

final chatProvider = NotifierProvider.autoDispose<ChatNotifier, ChatState>(ChatNotifier.new);
```

- [ ] **Step 4: Run** `flutter test test/features/support_chat && flutter analyze`; fix test-harness details (not the rules above) until green. The keep-alive test uses `fakeAsync`; if `ProviderContainer` needs `ref.keepAlive` flushing, call `async.flushMicrotasks()` after each step.
- [ ] **Step 5: Mutation checks.** (a) Make `retry` generate a new `_turnId` -> the same-turn-id assertion fails; (b) delete `cleanChatText` from the delta path -> the bidi test fails; (c) delete the `_inFlight` guard in `send` -> the concurrent-send test fails. Restore each.
- [ ] **Step 6: Commit** (`feat(chat): repository seam and turn state machine with interruption, retry and keep-alive`).

---

### Task 8: Chat screen

**Files:**
- Create: `lib/features/support_chat/chat_screen.dart`, `chat_bubble_view.dart`, `chat_error_copy.dart`
- Modify: `lib/router/app_router.dart` (append `/guide/chat`), ARB (en + fr)
- Test: `test/features/support_chat/chat_screen_test.dart`, `chat_bubble_view_test.dart`, `chat_error_copy_test.dart`; extend `test/router/guide_routes_test.dart`

**Behavior:**
- AppBar: title "Assistant" (`chatTitle`), signed-in action "Clear chat" (confirm dialog, then `clearHistory`). Body: a message list (auto-scrolls to the bottom when a new bubble or delta arrives **only if the user was already near the bottom**), a typing row while `sending`/`streaming` with an empty assistant bubble (`chatTyping` "Thinking…", or `chatCheckingAccount` "Checking your account…" when `checkingAccount`), destination chips under the last assistant bubble (only for destinations with a route; tapping `context.push(route)`), an error banner, a composer (`TextField`, `maxLength: 1000`, send button disabled while busy or blank), and a footer notice (signed in: `chatRetentionNotice` "Chats are kept for 30 days."; signed out: `chatSignedOutNotice` "Chats aren't saved. Sign in for answers about your account.").
- `ChatBubbleView`: `SelectableText` (never `Text.rich` with parsed spans, never `Linkify`, no `onTap` on content), user bubbles right-aligned `SxColors.primary`, assistant left-aligned surface; a failed user bubble shows a small error icon.
- Errors via `chatErrorMessage(AppLocalizations l, String code, {required bool signedIn, int? retryAfterSeconds})`: `chat_rate_limited` -> `chatErrorRateLimited(seconds)` ("You're sending messages too fast. Try again in {seconds} s."); `chat_unavailable` -> signed out: `chatErrorUnavailableSignedOut` ("The assistant is busy right now. Sign in to keep chatting."), signed in: `chatErrorUnavailable` ("The assistant is unavailable right now. Please try again later."); `unauthorized` -> `chatErrorUnauthorized` ("Please sign in again."); `chat_truncated` -> `chatErrorTruncated` ("That answer was cut short. Try asking in a simpler way."); `network` -> `chatErrorNetwork`; `clear_failed` -> `chatErrorClear`; anything else (incl. `chat_upstream`, `internal`, unknown) -> `chatErrorGeneric`. The Retry button (`chatRetry`) shows for `failed`/`interrupted` and is disabled while a `chat_rate_limited` countdown (a `Timer.periodic` owned by the screen state, started from `retryAfterSeconds`, cancelled in `dispose`) is running; `interrupted` shows `chatInterrupted` ("The connection dropped. Tap Retry.").
- Locale: `Localizations.localeOf(context).languageCode == 'fr' ? 'fr' : 'en'`.
- On first build when signed in: `loadHistory()`; the screen waits for `viewerIdProvider` to resolve before reading `chatProvider` (spinner), so a cold start never builds the notifier as a guest. A "Load earlier" button shows at the top while `nextBefore != null`.
- Route: `GoRoute(path: '/guide/chat', builder: (c, s) => const ChatScreen())` (outside the shell, appended).

- [ ] **Step 1: Write the failing tests**

```dart
// test/features/support_chat/chat_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sentinelx_mobile/core/api/api_client.dart';
import 'package:sentinelx_mobile/core/api/chat_models.dart';
import 'package:sentinelx_mobile/core/l10n/gen/app_localizations.dart';
import 'package:sentinelx_mobile/core/lifecycle/app_lifecycle_provider.dart';
import 'package:sentinelx_mobile/core/providers.dart';
import 'package:sentinelx_mobile/core/storage/local_kv.dart';
import 'package:sentinelx_mobile/features/support_chat/chat_repository.dart';
import 'package:sentinelx_mobile/features/support_chat/chat_screen.dart';
import '../../fakes/fake_chat_repository.dart';
import '../../fakes/fake_realtime.dart' show FakeLifecycle;

Widget chatApp(FakeChatRepository repo, {String? viewer = 'u1'}) {
  final router = GoRouter(initialLocation: '/chat', routes: [
    GoRoute(path: '/chat', builder: (_, _) => const ChatScreen()),
    GoRoute(path: '/tournaments', builder: (_, _) => const Scaffold(body: Text('TOURNAMENTS SCREEN'))),
  ]);
  return ProviderScope(
    overrides: [
      viewerIdProvider.overrideWith((ref) async => viewer),
      chatRepositoryProvider.overrideWithValue(repo),
      appLifecycleSourceProvider.overrideWithValue(FakeLifecycle()),
      chatDeviceIdProvider.overrideWith((ref) async => 'device-abc-123'),
    ],
    child: MaterialApp.router(
      routerConfig: router,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    ),
  );
}

Future<void> typeAndSend(WidgetTester tester, String text) async {
  await tester.enterText(find.byKey(const Key('chat-input')), text);
  await tester.tap(find.byKey(const Key('chat-send')));
  await tester.pump();
}

void main() {
  testWidgets('send streams into the assistant bubble and the composer re-enables', (tester) async {
    final repo = FakeChatRepository();
    await tester.pumpWidget(chatApp(repo));
    await tester.pumpAndSettle();
    await typeAndSend(tester, 'how do fees work');
    expect(find.text('how do fees work'), findsOneWidget);
    repo.last.add(const ChatDelta('Entry is '));
    await tester.pump();
    repo.last.add(const ChatDelta('₦500.'));
    repo.last.add(const ChatDone(true));
    await repo.last.close();
    await tester.pumpAndSettle();
    expect(find.text('Entry is ₦500.'), findsOneWidget);
    expect(tester.widget<IconButton>(find.byKey(const Key('chat-send'))).onPressed, isNull); // empty composer
  });
  testWidgets('rate limited shows the countdown copy and Retry stays disabled until it elapses', (tester) async {
    final repo = FakeChatRepository()
      ..sendError = const ApiException(status: 429, code: 'chat_rate_limited', message: 'x', fields: {'retryAfterSeconds': '5'});
    await tester.pumpWidget(chatApp(repo));
    await tester.pumpAndSettle();
    await typeAndSend(tester, 'hi');
    await tester.pump();
    expect(find.textContaining('5 s'), findsOneWidget);
    expect(tester.widget<TextButton>(find.byKey(const Key('chat-retry'))).onPressed, isNull);
    await tester.pump(const Duration(seconds: 6));
    expect(tester.widget<TextButton>(find.byKey(const Key('chat-retry'))).onPressed, isNotNull);
  });
  testWidgets('chips show only for destinations with a route and navigate through the fixed table', (tester) async {
    final repo = FakeChatRepository();
    await tester.pumpWidget(chatApp(repo));
    await tester.pumpAndSettle();
    await typeAndSend(tester, 'where do I sign up');
    repo.last.add(const ChatDelta('See tournaments.'));
    repo.last.add(const ChatActions([ChatDestination.tournaments, ChatDestination.wallet]));
    repo.last.add(const ChatDone(false));
    await repo.last.close();
    await tester.pumpAndSettle();
    expect(find.text('Open tournaments'), findsOneWidget);
    expect(find.byKey(const Key('chat-chip-wallet')), findsNothing); // no wallet screen yet
    await tester.tap(find.text('Open tournaments'));
    await tester.pumpAndSettle();
    expect(find.text('TOURNAMENTS SCREEN'), findsOneWidget);
  });
  testWidgets('an interrupted turn shows the dropped-connection copy and Retry reuses the same turn id', (tester) async {
    final repo = FakeChatRepository();
    await tester.pumpWidget(chatApp(repo));
    await tester.pumpAndSettle();
    await typeAndSend(tester, 'q');
    repo.last.add(const ChatDelta('part'));
    await repo.last.close(); // end of stream without a terminal event
    await tester.pumpAndSettle();
    expect(find.text('The connection dropped. Tap Retry.'), findsOneWidget);
    await tester.tap(find.byKey(const Key('chat-retry')));
    await tester.pump();
    expect(repo.sends, hasLength(2));
    expect(repo.sends.last.turnId, repo.sends.first.turnId);
    repo.last.add(const ChatDone(true));
    await repo.last.close();
    await tester.pumpAndSettle();
  });
  testWidgets('signed out: notice says chats are not saved, no history request, unavailable shows the sign-in copy', (tester) async {
    final repo = FakeChatRepository()..sendError = const ApiException(status: 503, code: 'chat_unavailable', message: 'x');
    await tester.pumpWidget(chatApp(repo, viewer: null));
    await tester.pumpAndSettle();
    expect(find.text("Chats aren't saved. Sign in for answers about your account."), findsOneWidget);
    expect(repo.historyCalls, 0);
    await typeAndSend(tester, 'hi');
    await tester.pump();
    expect(find.text('The assistant is busy right now. Sign in to keep chatting.'), findsOneWidget);
    expect(repo.sends.single.deviceId, 'device-abc-123');
  });
  testWidgets('signed in: retention notice, and Clear chat asks first then empties', (tester) async {
    final repo = FakeChatRepository()
      ..historyPage = ChatHistoryPage(messages: [ChatHistoryItem(id: 'a', role: 'user', content: 'old question', createdAt: DateTime.utc(2026))]);
    await tester.pumpWidget(chatApp(repo));
    await tester.pumpAndSettle();
    expect(find.text('Chats are kept for 30 days.'), findsOneWidget);
    expect(find.text('old question'), findsOneWidget);
    await tester.tap(find.byKey(const Key('chat-clear')));
    await tester.pumpAndSettle();
    expect(repo.clears, 0); // confirmation first
    await tester.tap(find.byKey(const Key('chat-clear-confirm')));
    await tester.pumpAndSettle();
    expect(repo.clears, 1);
    expect(find.text('old question'), findsNothing);
  });
  testWidgets('blank messages are not sent and the composer enforces 1000 characters', (tester) async {
    final repo = FakeChatRepository();
    await tester.pumpWidget(chatApp(repo));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('chat-input')), '   ');
    await tester.tap(find.byKey(const Key('chat-send')));
    await tester.pump();
    expect(repo.sends, isEmpty);
    await tester.enterText(find.byKey(const Key('chat-input')), 'x' * 1500);
    final field = tester.widget<TextField>(find.byKey(const Key('chat-input')));
    expect(field.controller!.text.length, lessThanOrEqualTo(1000));
  });
}
```

```dart
// test/features/support_chat/chat_bubble_view_test.dart
testWidgets('renders markup, links and bidi characters literally as one plain selectable text with no tap handlers', (tester) async {
  const raw = '<b>hi</b> [x](https://evil.example) a‮b';
  await tester.pumpWidget(const MaterialApp(home: Scaffold(body: ChatBubbleView(text: raw, fromUser: false))));
  expect(find.byType(SelectableText), findsOneWidget);
  final st = tester.widget<SelectableText>(find.byType(SelectableText));
  expect(st.data, '<b>hi</b> [x](https://evil.example) ab'); // the widget strips unsafe characters itself too
  expect(st.textSpan, isNull);                                // no parsed spans
  expect(st.onTap, isNull);
});
```

```dart
// test/features/support_chat/chat_error_copy_test.dart
test('every known code has copy, unknown codes use the generic copy, signed-out unavailable differs', () async {
  final l = await AppLocalizations.delegate.load(const Locale('en'));
  for (final code in ['chat_rate_limited', 'chat_unavailable', 'unauthorized', 'chat_truncated', 'network', 'clear_failed', 'chat_upstream', 'internal']) {
    expect(chatErrorMessage(l, code, signedIn: true, retryAfterSeconds: 7), isNotEmpty, reason: code);
  }
  expect(chatErrorMessage(l, 'something_new', signedIn: true), chatErrorMessage(l, 'internal', signedIn: true));
  expect(chatErrorMessage(l, 'chat_unavailable', signedIn: false), isNot(chatErrorMessage(l, 'chat_unavailable', signedIn: true)));
});
```

- [ ] **Step 2: ARB keys (en; write natural fr).** `chatTitle` "Assistant"; `chatHint` "Ask about tournaments, fees or your account"; `chatSend`; `chatTyping`; `chatCheckingAccount`; `chatRetry` "Retry"; `chatInterrupted`; `chatClear` "Clear chat"; `chatClearConfirmTitle` "Clear this chat?"; `chatClearConfirmBody` "Your saved messages will be deleted."; `chatCancel`; `chatLoadEarlier` "Load earlier messages"; `chatEmptyPrompt` "Ask me anything about tournaments, fees, SX Score or how Sentinel X works."; `chatRetentionNotice`; `chatSignedOutNotice`; the `chatError*` keys above (`chatErrorRateLimited` takes an int `seconds`); `chatDestTournaments` "Open tournaments", `chatDestMatches` "Open my matches", `chatDestProfile` "Edit my profile", `chatDestNotifications` "Open notifications", `chatDestWallet`, `chatDestRules`, `chatDestSafety`, `chatDestHelp` (labels exist for every enum value so a future route needs no ARB change). `flutter gen-l10n`.
- [ ] **Step 3: Run to verify FAIL; implement** the three files and the route as specified. **Step 4: Run** `flutter test test/features/support_chat test/router && flutter analyze` → PASS.
- [ ] **Step 5: Mutation check.** Replace `SelectableText` with a widget that parses `[x](url)` into a tappable span; the bubble test must fail; restore.
- [ ] **Step 6: Commit** (`feat(chat): support chat screen with plain-text rendering, chips, notices and error copy`).

---

### Task 9: Integration, docs and device-pass checklist

**Files:** Modify `CLAUDE.md` (route map + notes), `TESTING-NOTES.md`; Test: extend `test/router/` and `test/core/routing/web_links_test.dart`.

- [ ] **Step 1: Route and redirect tests.** `/guide` and `/guide/chat` open outside the shell; `resolveWebLink('/guide')`, `resolveWebLink('/guide/chat')` return `null`; a pushed `/guide/chat` over Home does not change `currentConfiguration.uri` (assert via `.last.matchedLocation`); the app-bar guide button pushes `/guide`; signed-out Home shows the guide button but no quest card.
- [ ] **Step 2: Auth lifecycle.** Add a test with a real refreshed `Session` (same user id, new access token): `questsProvider` and `chatProvider` do not refetch or reset (follow the pattern in `test/features/messages/inbox_providers_test.dart`); a different user id resets both.
- [ ] **Step 3: Docs.** In `CLAUDE.md` add to the route map: `| /guide | Guide (quest checklist + replay tour; visitor tour when signed out) |`, `| /guide/chat | Support chat (streamed; history 30 days for signed-in players) |`, and a "Phase 5c" note paragraph: quests via `/guide/*`; chat is NDJSON streaming through `ApiClient.postChatMessage`, never executes or renders model output as anything but plain text, destination chips go through `destinationRoute`; coach marks are local-only with per-viewer seen flags; avatars are re-encoded on device (`sanitizeAvatar`) before upload; community/evidence uploads still publish GPS EXIF (open item). In `TESTING-NOTES.md` add a "Phase 5c device pass" checklist: quest steps flip as each real step completes; claim once (second tap/retry shows Badge earned, XP/coins change once); avatar upload with a GPS-tagged photo (open the uploaded file's URL and confirm no EXIF); chat signed in: wallet question shows a correct balance, streaming looks smooth, background the app mid-reply then Retry, airplane mode mid-reply, rate-limit message after rapid sends, Clear chat, 30-day notice; chat signed out: FAQ answer, no account data, no history; coach marks on first launch, skip, back, replay, TalkBack announces steps; equipped bubble skin shows on the guide button; French locale strings; and the **eval** result from the web plan (Task 14).
- [ ] **Step 4: Full verification (alone).** Check free RAM, then `flutter analyze` (clean) and the full `flutter test` (all green; the count is the baseline plus the new tests), then `flutter build apk --debug` **with and without** `android/app/google-services.json` (move it aside for the second build and restore it; `git status` must never list it), then `android\gradlew --stop`.
- [ ] **Step 5: `git checkout -- linux macos windows`, commit** (`docs: Phase 5c route map, notes and device-pass checklist; test: integration coverage`).

---

### Task 10: Whole-branch review and merge (ask before pushing)

- [ ] **Step 1: Review.** Run `/code-review high master..phase5c/guide-chat` with an **explicit range** (running it from the main checkout where `master == HEAD` reviews an empty diff). Verify each finding against the code before grading; fix with a failing test first.
- [ ] **Step 2: Rebase and re-verify.** `git fetch origin && git rebase origin/master`; re-run analyze and the full test suite; re-copy `api/openapi.json` if the web contract changed.
- [ ] **Step 3: ASK THE OWNER before pushing or merging** (report: test counts, both APK builds, the deferred list below). After approval: `git pull --rebase`, merge to `master`, push (no force-push, no PR).
- [ ] **Step 4: Report deferred and unverified items:** iOS `Info.plist` photo/camera strings (Phase 10); `sanitizeJpeg` still not applied to community/evidence uploads; wallet/rules/safety/help chip destinations have no screens yet (chips hidden); real Groq behavior, streaming over Vercel on a real network, Android lifecycle mid-stream, TalkBack on the coach overlay, OEM audio/photo-picker differences, the global cap under real abuse, and the 5a/5b device passes all remain device/staging checks.
