# Mobile profile onboarding handoff — 2026-10-03

## Completed

- Copied the finalized web `openapi/mobile-v1.json` exactly into `api/openapi.json`.
- Added the `/me` profile-completion fields and `POST /onboarding/profile` to the hand-written mobile API client and operation allowlist.
- Added the compulsory gate and `/onboarding/profile` route after username and optional phone onboarding.
- Added reusable canonical-country and game-interest fields.
- Added localized English/French onboarding copy and regenerated Flutter localization output.
- Added the compulsory profile form with country, WhatsApp, explicit WhatsApp consent, and at least one game interest.
- Updated Account → Edit Profile to edit and submit the same country, game-interest, and consent values.

## Verification

- OpenAPI copy matches the web worktree byte-for-byte apart from allowed line-ending normalization.
- `flutter gen-l10n` is current.
- `flutter analyze` reports no issues.
- `flutter test` passes (767 tests at handoff time).
- No production writes or live onboarding submissions were performed.

## Rollout dependency

The mobile code is ready for integration, but the live write path must remain inactive until the web profile-contract branch is merged/deployed and both required database migrations are applied to production. Any end-to-end write-path test before that point must target `sentinelx-staging` through the web staging preview; never test it against the production Supabase project.

## Device follow-up: first successful submit did not leave the gate

Physical-device staging run on 2026-10-03 using Samsung SM-S9010 (Android 16):

- The player tapped profile onboarding submit once.
- The server returned `POST /api/mobile/v1/onboarding/profile 200`, followed by `GET /api/mobile/v1/me 200` and `GET /api/mobile/v1/home 200`.
- Despite those successful responses, the app returned to or remained on the profile onboarding screen.
- The player tapped submit once more. A second `POST /api/mobile/v1/onboarding/profile 200` was recorded, followed again by successful `/me` and Home requests; the player then left onboarding.
- No Flutter/Dart exception, Dio/API exception, or fatal Android application error appeared in the captured logs.

This is unresolved. Revisit the success sequence around `ref.invalidate(meProvider)`, `onCompleted()`, the router refresh listener, and the gate's observation of the refreshed `/me`. Add instrumentation or a regression test for a successful first submit being redirected back to `/onboarding/profile`. Do not dismiss this as a double-tap: the player confirmed one tap per request.

## Source checkpoints

- Mobile branch: `feat/profile-onboarding`
- Web handoff: `docs/agent-handoffs/2026-10-03-mobile-profile-api-contract.md`
- Web contract implementation reviewed at `1568e40` (`5ae53a0`, `3350b43`, `5f911ba`)
