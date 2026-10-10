# Phase 6d referrals — mobile implementation plan

**Spec:** web `docs/superpowers/specs/2026-10-10-mobile-phase6d-referrals-design.md`. Start after the web endpoint and OpenAPI contract are merged. Use a dedicated mobile worktree branch from current `origin/master`.

## Task 1 — API model, repository and provider

1. Copy web `openapi/mobile-v1.json` to mobile `api/openapi.json` without editing it. Add `getMyReferrals` to `ApiClient.usedOperations`, a method for `GET /me/referrals`, and referral response models in a new file. Write a contract/model test first and see it fail. The repository uses `ApiClient`; the feature provider lives beside the screen. Run focused tests green and commit.

## Task 2 — Screen and navigation

1. Add localized copy directly to `app_en.arb`, `app_fr.arb`, `app_pcm.arb`; run `flutter gen-l10n` and commit generated output with the screen. Do not hard-code copy in widgets.
2. Add `lib/features/account/referrals/` screen with loading, retry, empty, invited list, status, total/converted/earned counts, next milestone progress, history, and username/link copy and platform share actions. No mobile award logic. Write focused widget tests first, including 320 and 375 px en/fr/pcm, zero invites, all milestones complete, and copy/share feedback. Use existing theme colors only.
3. Add `/account/referrals` route, Account-hub entry for players, and `/dashboard/referrals` web-link mapping. Test player navigation and moderator exclusion. Run focused tests green and commit.

## Task 3 — Incoming and deferred referral links

1. Add a failing `resolveWebLink` test for `/signup?ref=<encoded>` and a cold-start incoming-link test. Add the `/signup` Android App Link path, preserving `ref` in the in-app route. Never accept unrelated external hosts.
2. Add an install-referrer adapter behind an injectable interface, with a fake for tests. Use Play Install Referrer on Android, decode only the `ref` query key, validate the username-shaped value, and store it until signup succeeds. Test explicit App Link precedence, no referrer, malformed referrer, app restart persistence and successful-signup clearing. Do not report the value to analytics or logs.
3. Pass the selected value to existing `SignupScreen.initialRef`; `AuthRepository.signUp` already sends it through `/auth/signup`. Run focused tests green and commit.

## Review focus and final gate

- Read the diff cold: no direct PostgREST write, no client-side coin awards, no copy in widgets, no new colors, no unrelated router rewrite. Check that a returning user cannot accidentally overwrite an explicit signup link with an old stored referrer.
- Rebase onto current `origin/master`. Run `flutter gen-l10n` after ARB edits, then `flutter analyze --no-pub` and `flutter test --no-pub` serially. Expected: no issues and all tests pass. Restore generated desktop plugin registrants if Flutter changes them. Merge `--no-ff`, verify tree equality and push `master`. Add a Phase 6d device-pass table to `TESTING-NOTES.md` with all checks pending, and log the slice in `docs/agent-handoffs/codex-progress.md`.
