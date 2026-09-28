# Tournament registration fields contract fix

- Branch: `fix/tournament-registration-fields-contract`
- Worktree: `C:\Users\gorok\sentinelx_mobile-regfields`
- Implementation HEAD: `76a8e60` (`fix(compete): enforce registration field length`)
- Base: `31b20e0`
- Verification: `flutter gen-l10n` completed successfully
- Verification: `flutter analyze` → `No issues found! (ran in 88.1s)`
- Verification: `flutter test --no-pub` → `+555: All tests passed!`
- Fresh-context review: one Important finding (missing 120-character server limit), fixed test-first in `76a8e60`; no Critical or Minor findings remained

## Changed

- Re-copied `api/openapi.json` byte-for-byte from the web repository's current `openapi/mobile-v1.json`.
- Added the public tournament registration-fields client call, its operation registry entry, and a focused API model/parser.
- Replaced fixed `clubName`/`ignTag` request properties with `registrationDetails: Map<String, String>` for register and waitlist while preserving register idempotency headers.
- Rendered the server catalogue in order with server labels/placeholders, type-specific keyboards, client-side required/length/pattern validation, and defensive malformed-regex handling.
- Added catalogue loading and explicit retry UI, and treated flat `validation_failed` responses as form-level errors.
- Removed dead club/IGN validators and English/French ARB keys, then regenerated localization output.
- Added model, API, widget, retry, validation, request-map, malformed-pattern, and 120/121-character boundary coverage.
- Checked bracket/standings UI; no literal `Club` column label exists, so the backward-compatible `clubName` wire field remains unchanged.

## Rulings

- The copied OpenAPI contract did not make `api_contract_test.dart` fail: that test checks only operations already declared by `ApiClient`, not unimplemented server operations. Cost if wrong: none to runtime behavior; focused red tests were used for every new client/model/UI behavior instead.
- The older design spec names a game-scoped registration-fields endpoint, but the verified live OpenAPI and server implementation expose `/tournaments/{id}/registration-fields`. The implementation follows the live tournament-scoped contract. Cost if wrong: catalogue fetches would fail, but the copied authoritative contract and client contract test both confirm this route.
- Reused existing localized `cmpLoadError` and `cmpRetry` strings instead of adding duplicate registration-specific chrome. Cost if wrong: wording is generic rather than registration-specific, but remains localized and consistent with Compete fetch failures.
- The fresh reviewer identified the server's universal trimmed 120-character maximum; the client now rejects 121 characters with a generic server-equivalent label message and accepts 120.

## Not verified

- No live registration or waitlist write was attempted against production.
- No live-server registration submission was performed.
- No emulator or physical-device run was performed.
- No production-device behavior was verified.
- Generated desktop plugin registrants touched by Flutter commands were restored before commit.
