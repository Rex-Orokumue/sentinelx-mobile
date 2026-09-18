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
- **Riverpod** for state management (decided 2026-09-18, master spec D4)
- All writes and all TypeScript-computed reads go through the web repo's `/api/mobile/v1/*`
  (three-tier access model, master spec §3) — **never write via PostgREST**, even where RLS allows it

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

## Commands

```bash
flutter pub get
flutter run
flutter doctor   # run this first if anything's unclear about the environment
```
