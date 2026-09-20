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
