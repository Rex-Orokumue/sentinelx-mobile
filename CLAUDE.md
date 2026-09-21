# CLAUDE.md

## What is this?

Sentinel X mobile — native Flutter app for the same Sentinel X platform as
`github.com/Rex-Orokumue/sentinelx` (Next.js web). **Same backend, not a new one:**
Supabase project `itxubrkbropttfdackmi` — the live production database, no separate
dev/staging instance. Be careful with writes; read-only ops are safe by construction (RLS).

## Tech stack

- Flutter (stable channel), Dart
- `supabase_flutter` — talks to the Supabase project directly, same as the website's
  `@supabase/supabase-js`
- `go_router` for navigation — provider-owned via `routerProvider` (`lib/router/app_router.dart`);
  incoming full web URLs (App Links, later push/bell taps) are rewritten to in-app paths by a
  top-level `redirect` that calls `resolveWebLink()` (`lib/core/routing/web_links.dart`)
- **Riverpod** for state management (decided 2026-09-18, master spec D4) — manual providers only,
  no codegen. App-wide providers live in `lib/core/providers.dart` (config, Supabase client,
  session, `ApiClient`, remote config, `/me`, role, error reporter); feature-specific providers
  live beside their feature (e.g. `lib/features/tournaments/tournaments_providers.dart`). Screens
  are `ConsumerWidget`s that read through these providers — they never construct a repository or
  API client themselves. New cross-cutting infrastructure (config, api, auth, gate, theme, l10n,
  routing, errors) goes under `lib/core/`.
- All writes and all TypeScript-computed reads go through the web repo's `/api/mobile/v1/*`
  (three-tier access model, master spec §3) — **never write via PostgREST**, even where RLS allows it
- The existing `lib/data`/`lib/models`/`lib/features/tournaments` slice (Riverpod-backed as of
  Phase 0C) is **temporary** — it reads Supabase directly and is replaced wholesale by the
  API-backed feature in Phase 2. Don't build further on it; don't reshuffle it into
  `features/tournaments/{data,domain,application,presentation}/` early.

## How this project is spec'd

Same convention as the web repo: `docs/superpowers/specs/` (design decisions, one file
per feature) and `docs/superpowers/plans/` (implementation plans, written from a spec
before code is touched). Read the relevant spec before writing code for a feature. If a
feature has no spec yet, write one first — don't freelance the design inline in a PR.

**Current spec:** `docs/superpowers/specs/2026-09-18-flutter-mobile-app-master-design.md`
— full-parity, role-aware app (players + admin), Android first then iOS, delivered in
phases 0–10. It **absorbs** the earlier `…-phase1-design.md` as its Phase 1 (with
corrections, master spec §2.4). Each phase gets its own plan in `docs/superpowers/plans/`,
and each phase needing endpoints gets its own spec in the **web** repo first.

## Key facts from the web repo, relevant here

- Auth is Supabase Auth directly — no need to port `lib/auth/actions.ts` (Next.js Server
  Actions, not callable from Flutter). `supabase_flutter`'s own `signInWithPassword` /
  `signUp` methods work against the same `auth.users` table.
- `handle_new_user()` trigger reads `raw_user_meta_data->>'username'` at signup to create
  the `profiles` row — the Flutter signup call must set that same metadata key.
- Confirmed-public-read tables (`USING (true)`): `tournaments`, `profiles`, `matches`,
  `game_modes`/`game_mode_formats`/`game_mode_maps`/`match_types`.
- The in-app bell is **`player_notifications`** (owner-read policy exists, readable directly +
  Realtime). `notifications` is the WhatsApp/Termii outbound log with no policies — not the bell.
- `community_posts` / `post_comments` are publicly readable (`is_deleted = false`); only
  `player_statuses` requires sign-in.
- **Do not call `supabase.auth.signUp` directly** — the web signup also enforces the ban
  blocklist, retired usernames, referral code and locale seeding; use `POST /auth/signup`.
- **Security findings S1–S3** (master spec §2.5): `profiles` PII is public-read and
  self-update is unrestricted. Do not build anything that widens reliance on direct `profiles`
  reads, and do not test writes against production.
- **Environment:** one Supabase project (production), on the **Free plan** — no branching.
  All write-path work and S1–S3 verification need a non-production database (master spec §3.2).

## Phase 1 notes

- **Tripwire:** do not set `enforce_phone_verification=true` in any environment until a shipped app
  version has the onboarding-phone screen — flipping it today strands signed-in app users at a gate
  route that doesn't exist.
- **Route map** (Home is outside the tab bar; the shell owns the 5 tabs; `resolveWebLink` maps the web
  `/` to Home, so Phase 5's push/bell taps can rely on that):

  | Path | Screen |
  |---|---|
  | `/` | Home (standalone) |
  | `/login` `/signup` `/signup/check-email` `/forgot-password` `/reset-password` | Auth |
  | `/onboarding/username` | Username claim |
  | `/tournaments` `/tournaments/:id` `/tournaments/:id/bracket` | Compete tab (existing slice, unmoved) |
  | `/tv` `/community` `/exchange` | Watch / Community / Trade tabs (coming soon) |
  | `/account` | Account tab |
  | `/debug` | debugTools only |

- **Copy comes from ARB, never hard-coded.** Auth screens read error/notice copy from the
  `auth.errors`/`auth.notices` ARB keys generated by `tool/gen_l10n_from_web.dart`. To add copy, add it
  to the web repo's `messages/en.json` first, then regenerate.
- **Static pages.** Terms is wired via `StaticPageScreen`. Privacy, RefundPolicy, Rules, CommunityRules,
  Safety, Escrow follow the identical pattern — run `gen_l10n_from_web.dart` for that namespace and write
  the section manifest by inspecting the real ARB keys (don't guess section counts; the Terms plan's
  guesses were wrong in many places). About/Contact/Help/HowItWorks/TournamentGuide/TournamentFaqs need
  bespoke screens — marketing/FAQ content, not ToC prose.
- **Testing against production:** signup-flow test accounts use a `zzqa_` username prefix and plus-addressed
  emails, are logged in `TESTING-NOTES.md`, and are removed with `anonymise_account` after verification.

## Commands

```bash
flutter pub get
flutter run
flutter doctor   # run this first if anything's unclear about the environment
flutter analyze  # must be clean before every commit
flutter test     # must be clean before every commit
flutter gen-l10n # regenerate lib/core/l10n/gen/* after editing an .arb file; commit the output
```
