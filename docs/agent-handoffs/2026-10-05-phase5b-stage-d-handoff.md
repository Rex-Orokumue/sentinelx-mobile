# Phase 5b Stage D running log (mobile DMs)

- Branch `phase5b/screens` from master `9c8aced`.
- Baseline (Task 0): `flutter analyze` clean, `flutter test` 965 passing.
- Contract: `api/openapi.json` equals web `origin/main` `openapi/mobile-v1.json` modulo CRLF line endings; all 15 operations present.
- Task 10 camera permission check: `image_picker_android` 0.8.13+17's manifest declares only a FileProvider and the photo-picker module service, no `CAMERA`. The camera source launches the system camera by intent, which needs no runtime permission while the app does not declare `CAMERA` itself (it does not). No manifest change.
- Task 10 finding: `img.decodeImage` throws (`RangeError`) on non-image bytes instead of returning null; `sanitizeJpeg` wraps it so callers always get `FormatException`.
- Task 17 build proof (2026-10-05, Windows, AGP 8.11.1): with `record 6.2.1` (`record_android 1.5.2`), `just_audio 0.10.6` (`audio_session 0.2.4`) and `RECORD_AUDIO` in the manifest, `flutter analyze` is clean and `flutter build apk --debug` succeeds BOTH with `android/app/google-services.json` (217 s, warm Gradle) and without it (31 s). `pubspec.lock` has no `permission_handler`. No `minSdk` change. `google-services.json` was moved aside for the second build and restored; `git status` never lists it.

## Result

Branch `phase5b/screens` (from `master` `9c8aced`), Tasks 0-18 of
`docs/superpowers/plans/2026-10-05-mobile-phase5b-direct-messages-screens.md`. Baseline 965 tests; final count is in
the ledger line of the merge. `flutter analyze` clean; `flutter build apk --debug` passes with and without
`google-services.json`.

### Review (whole branch, `/code-review high master..phase5b/screens`)

The first run reviewed an EMPTY diff (it executed in the main checkout where `master == HEAD`) and was discarded. The
re-run against `master..phase5b/screens` produced 10 findings. Each was checked against the code before grading.

Fixed in one pass, each with a test that failed first (and, for four, a mutation check):
1. Delivery receipts only fired while an inbox or conversation was mounted: new app-wide `deliveryWatcherProvider`
   (mounted in `main.dart`) stamps at start, on nudges, reconnects and resumes.
2. `DeliveredThrottle` dropped triggers inside the 15 s gap: it now has a coalescing trailing call.
3. `loadOlder` was treated as "new messages" (false pill, extra `markRead`): arrivals must be newer than the newest
   row already on screen.
4. The whole conversation rebuilt every 100 ms while recording: the footer now selects only the voice phase.
5. Leaving the screen mid-send lost a failed bubble and skipped `onDone` (temp-file leak): `ThreadNotifier` holds a
   keep-alive while anything is unconfirmed; the voice controller also deletes a recording left in review on dispose.
6. Accept/Decline invalidated the inbox through a disposed `ref`: they use the container.

### Deferred (reported, not built)

- **iOS** `Info.plist` lacks `NSMicrophoneUsageDescription` / `NSCameraUsageDescription` (and `UIBackgroundModes`): iOS is
  Phase 10 per the plan; an iOS build of this branch would crash on mic/camera. Add them with the iOS phase.
- `dmNudgeProvider` is unfiltered, so every mounted thread/inbox refetches on any DM event (plan design: RLS scopes it).
  Filter by thread if event volume hurts.
- The app-bar unread badges (`unread_counts.dart`) still use supabase `.stream` and do not refetch on resume.
- Two copies of the UUID regex (`web_links.dart`, `push_tap_router.dart`); fold into one helper.
- Sanitize (`sanitizeJpeg`) is not yet applied to community/evidence uploads (they publish GPS EXIF).
- Contract gap logged for the web repo: the OpenAPI response lists omit 404/409 for these operations.

### Not verified (needs devices / staging)

Two-device DM behavior; the 20/30-message caps under simultaneous sends; PostgREST error mapping over real HTTP; voice
recording/playback on real hardware and across OEM audio-focus behavior; `realtime_client` rejoin signalling (Ruling 4);
the broadcast payload shape `realtime_client` hands to `onBroadcast` (the parser accepts both the bare payload and the
`{type,event,payload}` envelope); the typing channel under real latency and its Realtime Authorization; presence at
scale; DM push in all three app states; the web UI; iOS. The checklist is in `TESTING-NOTES.md` (Phase 5b).

