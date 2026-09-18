# Flutter Mobile App — Phase 1 (Auth + Read Surfaces) — design

**Date:** 2026-09-18
**Status:** **absorbed** into `2026-09-18-flutter-mobile-app-master-design.md` as its Phase 1 — read that spec first. Known corrections (master §2.4): `notifications` is not the bell (`player_notifications` is, and is already readable — no RLS migration needed); `community_posts` is public-read; signup cannot be a bare `supabase.auth.signUp`; several "direct read" screens are computed in TypeScript and need API reads.
**Builds on:** the existing Next.js/Supabase platform as-is. No new backend concepts —
this phase is entirely "point a new client at what already exists."

---

## 1. What this is, and what it deliberately is not

A native Flutter app, installable on Android/iOS, backed by the **same Supabase project**
as the website (`itxubrkbropttfdackmi`) — not a second backend. Phase 1 is scoped to the
subset of the platform that needs **zero new server code**: anything the web app currently
reads through a public or `auth.uid()`-scoped RLS policy, Flutter reads the same way via
`supabase_flutter`.

This phase explicitly does **not** cover registration+payment, wallet/coins, Gaming
Exchange/escrow, DMs, wagers, or admin — those all currently run through Next.js **Server
Actions**, which are a React/Next-only RPC mechanism Flutter cannot call. Each needs its
own small `app/api/*` route before it can be a later phase. That work is out of scope here
(§9) and should be its own spec per feature, matching how everything else in this repo is
speced.

## 2. Why Supabase-direct is safe for these surfaces — verified, not assumed

Checked directly against the live migrations rather than inferred from table names:

```sql
-- 001_initial_schema.sql
tournaments_public_read  ON tournaments FOR SELECT USING (true);
profiles_public_read     ON profiles    FOR SELECT USING (true);
matches_public_read      ON matches     FOR SELECT USING (true);

-- 20260912090000_game_modes.sql
game_modes_public_read, gmf_public_read, gmm_public_read,
match_types_public_read  -- all USING (true)

-- 056_phase3_social_feed.sql
community_posts_read     -- auth-gated per current spec, not USING(true)
```

So tournaments, brackets (derived from `matches`), player profiles, and the game
mode/format/map catalogue are open reads today — Flutter can query them with the
`anon`/`authenticated` key with no new policy work.

**One real gap found, not hypothetical:** `notifications` has RLS **enabled with zero
policies** (`get_advisors` security scan, 2026-09-18). That means it is currently
unreadable by anyone except service-role server code — the in-app bell only works today
because it's rendered server-side in Next.js. Flutter querying it directly will get an
empty result set, silently, not an error. This needs an `authenticated`-scoped
`notifications_own_read` policy (`auth.uid() = user_id`) added before the mobile
notification feed can ship — a small, self-contained migration, not a redesign.

**Not yet checked, and must be before build, table by table:** `hall_of_fame`, `rankings`
aggregates, `tv_videos`, `seasons`. `seasons_select` exists but its condition wasn't read
here — confirm it's `USING (true)` or equivalent before relying on it, the same way
`notifications` turned out not to be.

## 3. Scope — what ships in Phase 1

| Screen | Data source | New backend work |
|---|---|---|
| Home (hero, live tournament, upcoming, leaderboard) | Supabase direct | None, pending §2's remaining checks |
| Tournament list / detail (read-only, no registration) | Supabase direct | None |
| Bracket page | Supabase direct (`matches`) | None |
| Match Centre (read-only — YouTube embed, stats, comments read) | Supabase direct | None |
| Rankings / Leaderboard | Supabase direct | Confirm RLS (§2) |
| Player profile | Supabase direct | None |
| Hall of Fame | Supabase direct | Confirm RLS (§2) |
| Sentinel X TV | Supabase direct | Confirm RLS (§2) |
| Community feed (read-only) | Supabase direct, `auth.uid() IS NOT NULL` | Requires sign-in, no anonymous read |
| Auth — email/password, Google sign-in | `supabase_flutter` Auth directly | None — same Supabase Auth instance, not a port of `lib/auth/actions.ts`'s Server Actions |
| Push notification registration | New: `POST /api/notifications/fcm-token` already exists and is transport-agnostic | Confirm it accepts a mobile-issued FCM token the same as web's; likely yes, verify in build |

## 4. Auth — reuse the instance, don't port the Server Actions

`lib/auth/actions.ts` (login/signup/reset) is Next.js Server Actions — not portable to
Flutter as code, but irrelevant to be, because auth is Supabase Auth itself, and
`supabase_flutter` has its own native `signInWithPassword` / `signUp` / OAuth methods
against the **same project**. A user created on web logs into the mobile app with the same
credentials — nothing to sync, one `auth.users` table.

**What does need attention:** the `handle_new_user()` trigger that writes `profiles` from
signup metadata (`raw_user_meta_data->>'username'`) must receive that metadata however
signup happens on mobile — confirm the Flutter signup call sets the same metadata key the
trigger reads, or it silently produces a profile with no username, the same class of bug
this pattern already had to be careful about on web (§CLAUDE.md Authentication).

Email verification links point at `{{ .SiteURL }}/auth/confirm` — a **web URL**. On mobile,
either accept that email verification opens a browser tab (fine, and simplest for Phase 1),
or add deep-linking later. Not solving this now — Phase 1 assumes browser-based email
verification, same flow as web.

## 5. Non-goals for this phase

- **Registration + payment.** Reuses `app/api/paystack/*` as-is — its own follow-up spec,
  not bundled here because it's a different risk profile (money) and deserves its own
  review.
- **Wallet, coins, Gaming Exchange/escrow, wagers, friendly matches, DMs, admin.** All
  currently Server-Action-only. Each becomes its own thin `app/api` route + spec when its
  phase comes, following this repo's existing pattern of one spec per feature.
- **Offline support / local caching.** Phase 1 assumes network-connected use; a cache layer
  is a legitimate later phase, not assumed here.
- **Push notification *delivery* UI beyond token registration.** The bell/feed itself is
  blocked on the RLS gap in §2 regardless of client.

## 6. Compatibility

Nothing here touches the web app or the schema — Phase 1 is entirely additive on the
client side, except the one `notifications` RLS policy in §2, which is a strict expansion
(adds an owner-scoped read) and cannot break the current server-side rendering path.

## 7. Open questions

1. **Confirm remaining RLS surfaces** (`hall_of_fame`, `rankings`, `tv_videos`, `seasons`)
   before build — §2 checked three tables directly; the rest are stated as "likely public"
   by pattern, not verified the same way, and `notifications` is proof that pattern isn't
   reliable enough to skip the check.
2. **Google sign-in on mobile** — the web flow (`2026-07-28-google-sign-in`) is browser
   OAuth; native Google Sign-In on Flutter uses a different SDK-level flow against the same
   Supabase Auth provider. Needs its own short design pass, not assumed identical.
3. **Which screen ships first for a real device test** — recommend Tournament List → Detail
   → Bracket as the vertical slice, since it's the smallest fully-connected path from
   install to something useful on screen.
