# AGENTS.md

Instructions for coding agents (Codex and others) working in this repository.

**Read `CLAUDE.md` in this directory first. Everything in it binds you.** It was written for Claude Code, but its
rules are repo rules. The ones most likely to bite, restated:

## Hard rules

1. **Same backend, no dev database.** The Supabase project `itxubrkbropttfdackmi` is the live production database.
   Never test writes against it. Read-only calls are safe (RLS). Staging for write-path work is `sentinelx-staging`
   (`ofxmoxpvwbemfouaowoa`) behind the web repo's staging preview deployment.
2. **All reads that need TypeScript logic, and all writes, go through the web repo's `/api/mobile/v1/*`** via
   `ApiClient`. Never write through PostgREST/`supabase_flutter` tables, even where RLS would allow it. Never call
   `supabase.auth.signUp` directly (the web signup enforces the ban list, retired usernames, referral codes).
3. **`ApiClient` is hand-written.** Every method you add must be listed in `ApiClient.usedOperations`;
   `test/core/api_contract_test.dart` checks it against `api/openapi.json`, which is a **copy** of the web repo's
   `openapi/mobile-v1.json` — re-copy it, never hand-edit it or merge its text.
4. **Riverpod, manual providers, no codegen.** Screens are `ConsumerWidget`s reading providers; they never construct a
   repository or `ApiClient`. App-wide providers are in `lib/core/providers.dart`; feature providers live beside their
   feature.
5. **The `lib/data`, `lib/models`, `lib/features/tournaments` slice is temporary** (Phase 2a/2b replace it). Do not
   build on it, extend it or reshuffle it.
6. **Copy is never hard-coded in widgets.** Strings live in `lib/core/l10n/app_en.arb` (template). Where the web repo
   has a `messages/en.json` namespace, add it there first and regenerate with `tool/gen_l10n_from_web.dart`; where it
   has none, add to `app_en.arb` directly. Run `flutter gen-l10n` and commit the output; never edit
   `lib/core/l10n/gen/*` by hand.
7. Mobile-first at 375px; use `SxColors` from `lib/core/theme/sx_colors.dart`; no new colors.

## Verification before every commit

```bash
flutter analyze   # must report no issues
flutter test      # must pass
flutter gen-l10n  # after any .arb edit; commit the generated output
```
Do not chain a push to a piped test command (`flutter test | grep … && git push` reports grep's status, not the test
runner's).

## Parallel work

Other agents work in this repo at the same time. Use your own git worktree
(`git worktree add ..\sentinelx_mobile-<name> -b <branch> origin/master`; the default branch is `master`), never the
primary checkout. Hotspot files: `lib/core/api/api_client.dart`, `lib/router/app_router.dart`, `api/openapi.json`, ARB and
generated l10n. Change them by *appended lines / new routes only*, and rebase onto `origin/master` before your final
checks. Put new API models in a new file, not in `lib/core/api/models.dart`.

## Style

American spelling in new prose/code. Match surrounding code; don't refactor beyond the task.

## Specs and plans

Feature specs that need endpoints live in the **web** repo (`C:\Users\gorok\Videos\sentinelx\docs\superpowers\specs\`);
plans for this repo live in `docs/superpowers/plans/`. Read both for your task first. Cross-agent handoffs are in
`docs/agent-handoffs/`. If a feature has no spec, stop and ask.

## Stop and ask when

- a plan step's assumption is false (an endpoint, field or file it names doesn't exist or differs);
- you'd need a write against production;
- you find a bug outside your task — note it in the PR description, don't fix it in the same PR.
