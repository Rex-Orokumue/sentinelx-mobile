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

- OpenAPI copy matches web `origin/main` byte-for-byte (`773761bf46b704b01322f5fef417e9b2bc68b6a8`).
- `flutter gen-l10n` is current.
- `flutter analyze` reports no issues.
- Baseline `flutter test` passes (965 tests on 2026-10-05).
- No production writes or live onboarding submissions were performed.

## First-submit gate bug resolution

The web endpoint and both production migrations are now live. The device failure was a client race: after a successful
POST, the screen invalidated `meProvider` and navigated before the refreshed `/me` future completed. The router could
therefore evaluate the cached incomplete profile and send the player back to `/onboarding/profile`. Commit `4a1f4cf`
waits for the real refreshed provider future before navigating. A mutation check on 2026-10-05 removed that wait and
the delayed-refetch regression failed at the expected assertion (`completed` became true while `/me` was pending).

Additional regressions cover a failed network POST staying on the form without refreshing/completing `/me`, and the
Phase 5a push/gate interaction.

## Rulings

- **Push target while profile-incomplete:** drop the original target after gating. A push to `/notifications` (or any
  other destination) first redirects to `/onboarding/profile`; successful completion goes Home. Cost if wrong: the
  player must reopen the notification rather than being resumed automatically, but no destination can bypass the
  compulsory profile gate and there is no hidden pending-navigation state to become stale.
- **Integration base:** the old `feat/profile-onboarding` branch was not merged because its equivalent commits,
  including `4a1f4cf`, were already present on `master`. Finish work continues from current `master` on
  `fix/profile-onboarding-finish`; the old pushed branch remains unchanged.

## Not yet verified

- Physical-device staging retest: one successful tap leaves onboarding.
- Fresh signup, existing incomplete account, Edit Profile round-trip, and airplane-mode failure then retry.
- Cleanup of staging user `zzqa_mobile_profile` with `anonymise_account` after verification.
- No production write verification will be performed; all remaining write-path checks must use `sentinelx-staging`.

## Source checkpoints

- Mobile branch: `feat/profile-onboarding`
- Web handoff: `docs/agent-handoffs/2026-10-03-mobile-profile-api-contract.md`
- Web contract implementation reviewed at `1568e40` (`5ae53a0`, `3350b43`, `5f911ba`)
