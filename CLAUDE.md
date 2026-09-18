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
- `go_router` for navigation
- No state-management package chosen yet — don't add one without discussing it first

## How this project is spec'd

Same convention as the web repo: `docs/superpowers/specs/` (design decisions, one file
per feature) and `docs/superpowers/plans/` (implementation plans, written from a spec
before code is touched). Read the relevant spec before writing code for a feature. If a
feature has no spec yet, write one first — don't freelance the design inline in a PR.

**Current spec:** `docs/superpowers/specs/2026-09-18-flutter-mobile-app-phase1-design.md`
— Phase 1 scope (auth + read-only screens: tournaments, brackets, match centre, rankings,
profiles, hall of fame, TV, community reads). Everything requiring a write beyond auth
(registration/payment, wallet, exchange, wagers, DMs, admin) is explicitly out of scope
for Phase 1 — each of those needs a corresponding `app/api/*` route added to the **web**
repo before mobile can touch it, and gets its own spec when that phase starts.

## Key facts from the web repo, relevant here

- Auth is Supabase Auth directly — no need to port `lib/auth/actions.ts` (Next.js Server
  Actions, not callable from Flutter). `supabase_flutter`'s own `signInWithPassword` /
  `signUp` methods work against the same `auth.users` table.
- `handle_new_user()` trigger reads `raw_user_meta_data->>'username'` at signup to create
  the `profiles` row — the Flutter signup call must set that same metadata key.
- Confirmed-public-read tables (`USING (true)`): `tournaments`, `profiles`, `matches`,
  `game_modes`/`game_mode_formats`/`game_mode_maps`/`match_types`.
- `notifications` has RLS enabled with **no policies** — unreadable until a
  `notifications_own_read` policy is added. Don't build the notification feed until that's
  fixed (web repo migration, not a mobile-side problem).
- `community_posts` requires `auth.uid() IS NOT NULL` — no anonymous read.

## Commands

```bash
flutter pub get
flutter run
flutter doctor   # run this first if anything's unclear about the environment
```
