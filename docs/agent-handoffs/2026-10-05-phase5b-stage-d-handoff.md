# Phase 5b Stage D running log (mobile DMs)

- Branch `phase5b/screens` from master `9c8aced`.
- Baseline (Task 0): `flutter analyze` clean, `flutter test` 965 passing.
- Contract: `api/openapi.json` equals web `origin/main` `openapi/mobile-v1.json` modulo CRLF line endings; all 15 operations present.
- Task 10 camera permission check: `image_picker_android` 0.8.13+17's manifest declares only a FileProvider and the photo-picker module service, no `CAMERA`. The camera source launches the system camera by intent, which needs no runtime permission while the app does not declare `CAMERA` itself (it does not). No manifest change.
- Task 10 finding: `img.decodeImage` throws (`RangeError`) on non-image bytes instead of returning null; `sanitizeJpeg` wraps it so callers always get `FormatException`.
- Task 17 build proof (2026-10-05, Windows, AGP 8.11.1): with `record 6.2.1` (`record_android 1.5.2`), `just_audio 0.10.6` (`audio_session 0.2.4`) and `RECORD_AUDIO` in the manifest, `flutter analyze` is clean and `flutter build apk --debug` succeeds BOTH with `android/app/google-services.json` (217 s, warm Gradle) and without it (31 s). `pubspec.lock` has no `permission_handler`. No `minSdk` change. `google-services.json` was moved aside for the second build and restored; `git status` never lists it.
