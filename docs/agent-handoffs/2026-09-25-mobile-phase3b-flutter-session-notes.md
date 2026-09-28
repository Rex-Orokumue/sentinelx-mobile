# Mobile Phase 3b (Flutter) session notes — 2026-09-25

Code was changed in two new worktrees; nothing is pushed. No secrets are recorded here.

## Where things are

| What | Where |
|---|---|
| 3b Flutter plan (untracked) | `C:\Users\gorok\sentinelx_mobile\docs\superpowers\plans\2026-09-25-mobile-phase3b-flutter-screens.md` |
| 3b code | worktree `C:\Users\gorok\sentinelx_mobile-p3b`, branch `phase3b/screens`, HEAD `e0fb47a` |
| 3a base (Tasks 1-3 only) | worktree `C:\Users\gorok\sentinelx_mobile-p3a`, branch `phase3a/screens`, HEAD `94bc284` |
| Ledgers (git-ignored) | `<worktree>\.superpowers\sdd\<plan-name>\progress.md` in each worktree |
| Web 3b endpoints (unpushed) | `C:\Users\gorok\Videos\sentinelx-p3b-web`, branch `phase3b/web-endpoints`, HEAD `0411d12` |

`phase3b/screens` = 3a's 4 commits + 9 3b commits on top of `origin/master` 765e844. Do not delete either worktree.

## Verified (this session)

- `flutter analyze` clean; `flutter test` 209/209 pass in the p3b worktree.
- `api/openapi.json` is byte-identical to the web worktree's `openapi/mobile-v1.json` (all 11 3b operations; contract test passes).
- Production returns 404 for `/api/mobile/v1/players`, `/players/ada`, `/me/progress` (200 for `/config`): the 3b endpoints are deployed nowhere, which is why the app showed nothing on the Players screen.

## What was built

- **3a base (partial, by decision):** `progress_models.dart`, five client methods (`getRankings`… `getHallOfFame`, NOT in `usedOperations`), `PlayerAvatar` + `resolveAsset`, 35 ARB keys en+fr. The 3a screens (Tasks 4-9) are NOT built.
- **3b, Tasks 0-9 of the plan:** models, 11 client methods + `Idempotency-Key` header support, en+fr copy and code-label maps, players directory (debounced search), optimistic follow controller (rollback, same-key retry, double-tap guard, dispose guard), profile + followers/following screens, My progress + 3 cursor-paged histories, routes, `resolveWebLink` for `/players...`, Home "Players" tile, Account "My progress" tile.
- **Not done — Task 10 steps 2-5:** device run, staging follow round trip, 10-profile web comparison, TESTING-NOTES.md, push/PR.

## Rulings made (also in the ledgers)

1. 3a contract not copied, 3a methods not in `usedOperations` (no 3a web endpoints exist). The 3a completion run must append those entries.
2. French parity: `test/core/l10n_test.dart` needs fr == en keys, so all new keys are also in `app_fr.arb` (machine-written French, needs native review). The 3a plan's "English only" line is wrong.
3. Follow controller got `ref.mounted` guards (test proves it fails without).
4. Frame image base URL = `appConfigProvider.apiBaseUrl` (no separate site URL in `AppConfig`).
5. Several plan tests were fixed (lazy lists, cascade lambda, shared provider scope); coin row subtitle split into two Texts.
6. Live CHECK-list query skipped; label maps use migrations <=064 with a humanized fallback.

Deferred minors: My progress shows the sign-in prompt if `meProvider` errors; profile Follow button acts as "Follow" if `/me/follows` fails; French needs native review. Final review was a self-review only (no fresh reviewer).

## Device test setup (plan B: local web dev server against staging)

- Web `.env.local` points at PRODUCTION. Safe override file created: `C:\Users\gorok\Videos\sentinelx-p3b-web\.env.development.local` (gitignored; Next loads it after `.env.local`). It holds the staging Supabase URL + anon key and (added by the owner) the staging service-role key. Never run the dev server without it; never paste that key anywhere.
- Staging: project `ofxmoxpvwbemfouaowoa`, URL `https://ofxmoxpvwbemfouaowoa.supabase.co`. Staging publishable key: `sb_publishable_Hr_IJdf3zPQafgrm_WcWrQ_6uOJQqQL` (public).
- Dev server: `cd C:\Users\gorok\Videos\sentinelx-p3b-web && npm run dev` (port 3000). Check `http://localhost:3000/api/mobile/v1/players` returns 200 before touching the phone.
- App must be RESTARTED (dart-defines are compile-time), phone `R5CTA1NBG1W`, PC LAN IP was `192.168.1.157` (re-check with `ipconfig`):

```
flutter run -d R5CTA1NBG1W --dart-define-from-file=config/dev.json ^
  --dart-define=API_BASE_URL=http://192.168.1.157:3000 ^
  --dart-define=SUPABASE_URL=https://ofxmoxpvwbemfouaowoa.supabase.co ^
  --dart-define=SUPABASE_PUBLISHABLE_KEY=sb_publishable_Hr_IJdf3zPQafgrm_WcWrQ_6uOJQqQL
```
- Run it from `C:\Users\gorok\sentinelx_mobile-p3b`. Another agent had a `flutter run` on that phone: confirm it has stopped before restarting; do not kill it unasked. Phone must be on the same Wi-Fi; allow port 3000 in Windows Firewall.
- Sign in with a staging QA account whose username starts `zzqa_` (create one on staging if none exists); log it in TESTING-NOTES.md and remove it with `anonymise_account` afterward.

## Still open

1. Run the device checks (Home -> Players -> profile; locked tiles only; My progress + histories; Follow/Unfollow round trip, then confirm on web and exactly one `new_follower` notification).
2. Task 10 step 4: compare 10 profiles + one account's histories against the web/DB; record tables in the PR.
3. Update TESTING-NOTES.md.
4. Push sequencing (needs owner OK): web 3b stack sits on unpushed 3a extraction + 2a/2b; mobile 3b sits on partial 3a. Nothing merges cleanly until the web side lands.
5. Optional: a fresh-context whole-branch review (skipped).
6. Later: build the 3a Flutter screens (its Tasks 4-9), append its `usedOperations`, add profile links from 3a rows.

## Gotchas

- `flutter pub get`/`flutter test` rewrite tracked plugin registrants (linux/macos/windows); run `git checkout -- linux macos windows` before committing.
- Lists are lazy: widget tests must `scrollUntilVisible` for anything below the fold.
- Python on Windows needs `C:\...` paths; bash heredocs choke on quote-heavy content (use the Write tool).
