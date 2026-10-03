# sentinelx_mobile

Sentinel X mobile app — "Nigeria's Home of Mobile Esports." Flutter client for the platform built
by the web repo `sentinelx` (Next.js). See `CLAUDE.md` for the architecture rules and
`docs/superpowers/specs/2026-09-18-flutter-mobile-app-master-design.md` for the master design spec.

## Setup

```powershell
flutter pub get
```

## Running

```powershell
# Points at production (Supabase + API) with debug tools off, no --dart-define needed.
flutter run

# Dev flavor: debug tools on (adds the /debug route), still points at the production
# Supabase project (no staging DB exists — see the spec's §3.2 risk).
flutter run --dart-define-from-file=config/dev.json

# Point the API base at a local Next.js dev server from an Android emulator:
flutter run --dart-define-from-file=config/dev.json --dart-define=API_BASE_URL=http://10.0.2.2:3000
```

## Testing and analysis

```powershell
flutter test
flutter analyze
```

Both must be clean before every commit (this repo has no remote and no CI — this is the gate).

## Localization

```powershell
flutter gen-l10n
```

Regenerates `lib/core/l10n/gen/*` from `lib/core/l10n/app_{en,fr}.arb`. Commit the generated files.

## Keeping the API contract in sync

The typed `ApiClient` (`lib/core/api/api_client.dart`) is checked against a pinned copy of the web
repo's OpenAPI contract by `test/core/api_contract_test.dart`. When the web repo's
`/api/mobile/v1` endpoints change:

```powershell
Copy-Item C:\Users\gorok\Videos\sentinelx\openapi\mobile-v1.json api\openapi.json
flutter test
```

If the contract test fails, the client and the web contract have drifted — fix `ApiClient` to match.

## Push notifications (Phase 5a)

Push uses Firebase Cloud Messaging through one interface, `PushGateway` (`lib/core/notifications/push/`); only
`firebase_push_gateway.dart` imports Firebase. Everything else, and every test, uses a fake.

- **Config file:** `android/app/google-services.json` (Firebase project `sentinelx-f061e`, the web's existing
  project). It is **untracked and excluded locally** (`.git/info/exclude`) on purpose: it holds project ids and a
  restricted API key, and whether it is ever committed is the owner's call. A new git worktree does not contain
  untracked files - copy it from the main checkout into `android/app/` before a live-path build.
- **No file, no problem:** `android/app/build.gradle.kts` applies the `com.google.gms.google-services` Gradle plugin
  only when that file exists, and `Firebase.initializeApp()` failing at runtime yields a disabled gateway (the app
  starts normally with push off). CI and fresh clones build and pass tests without the file.
  Verify both paths with `flutter build apk --debug` (once with the file, once with it temporarily moved aside).
- **Staging:** the defaults point at production. To exercise push (and any write) against staging, run with
  `--dart-define=SUPABASE_URL=... --dart-define=SUPABASE_PUBLISHABLE_KEY=... --dart-define=API_BASE_URL=...` for the
  staging project (`ofxmoxpvwbemfouaowoa`) and its web preview deployment. Do not commit keys.
- **Channels** (created at startup, versioned): `matches_v1`, `social_v1`, `messages_v1`, `money_v1`, `admin_v1`. The
  web sender's table (`lib/notifications/channels.ts`) must list the same ids; a change needs a new id, never an edit.
