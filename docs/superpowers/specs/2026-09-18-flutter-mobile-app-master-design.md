# Sentinel X Mobile — Master Design (full-parity Flutter app)

**Date:** 2026-09-18
**Status:** proposed — awaiting owner review
**Repos:** this one (`sentinelx_mobile`, Flutter) + `github.com/Rex-Orokumue/sentinelx` (Next.js web, owns the database and the new mobile API)
**Supersedes:** `2026-09-18-flutter-mobile-app-phase1-design.md` — that spec is absorbed as **Phase 1** here, with the corrections in §2.4.
**Decisions locked with the owner (2026-09-18):**

| # | Decision | Choice |
|---|---|---|
| D1 | Backend access | A versioned **mobile API layer in the web repo** (`/api/mobile/v1/*`); raw row reads go direct to Supabase under RLS |
| D2 | Audience | **Everything, incl. admin.** One app; the signed-in user's role decides whether the Admin section exists, exactly as on web |
| D3 | Platforms | **Android first**, iOS after (store-policy work in §14 gates iOS) |
| D4 | State management | **Riverpod** |
| D5 | Spec home | This repo. Web-side API specs live in the web repo, one per phase |

---

## 1. Goal and non-goals

**Goal.** A native app that mirrors the whole Sentinel X platform — the four pillars (Compete / Watch / Community / Trade), the player dashboard, and the staff tooling — on the same Supabase project, same accounts, same data, same rules. "Mirrors" means feature parity and identical business outcomes, not a pixel copy: it is designed for a thumb and a 375px screen first.

**Not goals.**
- A second backend, a second database, or a second set of business rules. Any rule that exists in TypeScript today stays in TypeScript and is *called*, not re-implemented in Dart.
- Offline-first. v1 is online-required with sensible caching (§6.9). Offline result drafting is a possible later phase.
- Native video hosting. Streams and replays stay YouTube embeds.
- Coin → naira conversion, or any new money mechanic (explicitly ruled out by the coin-economy spec; the app must show the same "SX Coins cannot be exchanged for cash" disclaimer).
- Team/school/state leagues (web roadmap 21b is still unbuilt — mobile follows web, never leads it).

---

## 2. Ground truth — what the web platform is (verified 2026-09-18)

### 2.1 Size
- ~75 player-facing routes + ~40 admin routes (`app/[locale]/**`), 14 API/cron/webhook handlers.
- **183 Server Actions in 68 files.** Only **4 Postgres RPCs** exist (`jsonb_merge_notification_prefs`, `player_rank`, `increment_listing_view`, `anonymise_account`). Business logic — payments, registration, result verification, SX Score/XP, coins, wagers, wallet, KYC, escrow — lives in TypeScript, not SQL.
- 109 migrations, ~90 public tables, all with RLS enabled. 3 locales: `en`, `fr`, `pcm` (Nigerian Pidgin). ~127 production profiles at time of writing.

### 2.2 Consequence for mobile
Server Actions are a Next.js-only RPC mechanism; Flutter cannot call them. And several "obvious" screens are not table reads at all — they are **computed in TypeScript**: group standings (`lib/tournaments/standings.ts`), points-race standings, bracket tree, the 3-tab leaderboard, Hall of Fame awards, season points, wallet breakdown, earnings trend. Reading their inputs directly would mean porting the maths to Dart and letting it drift. Hence the three-tier access model in §3.

### 2.3 Live RLS audit (read-only, against the production project)
Every public table has RLS on. What that means for a Flutter client holding only the publishable key + the user's JWT:

**Directly readable by anyone (public):** `tournaments`, `games`, `game_modes`, `game_mode_formats`, `game_mode_maps`, `game_mode_match_rules`, `match_types`, `matches`, `tournament_entrants`, `tournament_stages`, `tournament_lobbies`, `lobby_entrants`, `groups`, `group_memberships`, `squads`, `squad_members`, `profiles`, `achievements`, `player_achievements`, `player_follows`, `player_store_items`, `player_challenge_progress`, `seasons`, `player_rank_snapshots`, `match_check_ins`, `match_wagers`, `community_challenges`, `community_post_images`, `best_play_nominations`, `best_play_votes`, `post_reactions`; `lobby_results` (confirmed rows only); `tv_videos` / `homepage_banners` / `store_items` (active rows only).

**Public but filtered:** `community_posts`, `post_comments` (`is_deleted = false`) — **note: not auth-gated** (see §2.4).

**Readable only when signed in:** `player_statuses`.

**Own-rows only (RLS `auth.uid() = …`):** `player_notifications`, `wallets`, `wallet_transactions`, `wallet_deposits`, `sx_coins`, `sx_coin_transactions`, `xp_events`, `sx_score_events`, `referrals`, `player_kyc`, `tournament_registrations`, `tournament_invitations`, `season_ranking_points`, `season_noshow_penalties`, `friends`, `friendly_matches`, `friendly_match_results`, `dm_threads`, `dm_messages`, `dm_blocks`, `dm_reports`, `notification_mutes`, `fcm_tokens`, `phone_verifications`, `buy_requests`, `marketplace_orders` (buyer/seller), `marketplace_listings` (active or own), `withdrawal_requests`, `chat_messages`, `game_interest`, `user_roles`, `match_results` (match participants only), `opponent_ratings`.

**Staff-only (`is_staff()` = admin or moderator; `is_admin()` = admin only):** `admin_flags`, `client_error_logs`, `dm_message_edits`, `dm_muted_players`, `platform_coin_reserve`, `tournament_fee_waivers`; withdrawals read is `is_admin()` (moderators have no financial access, matching CLAUDE.md).

**No SELECT policy at all (service-role only):** `admin_recovery_log`, `banned_identifiers`, `chat_rate_limit_events`, `retired_usernames`, `notifications`.

### 2.4 Corrections to the earlier Phase 1 spec
1. **`notifications` is not the in-app bell.** It is the outbound WhatsApp/Termii queue log (migration 011). The bell reads **`player_notifications`**, which *does* have an owner-read policy. So the "notification feed is blocked on an RLS migration" claim is wrong — **no migration is needed**; the bell can be read directly (and via Realtime) from day one.
2. **`community_posts` is publicly readable** (`is_deleted = false`), not auth-gated. Only `player_statuses` requires sign-in.
3. **Signup cannot be a bare `supabase.auth.signUp`.** The web `signup()` action also enforces the ban-evasion blocklist (`banned_identifiers`), retired usernames (`retired_usernames`), the referral `ref` metadata, and seeds `profiles.locale`. None of that runs if Flutter calls Supabase Auth directly. Signup, change-email, account deletion and other identity mutations therefore go through the API (§7). Plain `signInWithPassword` / password-reset / Google sign-in can use Supabase Auth directly.
4. **The username is claimed *after* email confirmation** (`/onboarding/username`, `claimUsername`, migration 073); signup only carries it as metadata. Mobile must implement the same onboarding gate (`resolveOnboardingGate`).
5. Several "direct read" screens are computed, not stored (§2.2) — they are Tier 2 (§3).
6. `hall_of_fame` and `rankings` tables **do not exist**; both are derived. `player_rank` is an RPC and is directly callable.

### 2.5 ⚠️ Security findings that gate this project (Phase 0 blockers)
Found during the audit above. These are **pre-existing on the web platform**, not caused by mobile, but a mobile app **ships the publishable key inside a decompilable binary and adds a second, easier client for exploiting them**, so they must be fixed before the app is released. *Findings are inferred from live policy text, column grants and trigger lists; I deliberately did not attempt to exploit any of them against production.*

| ID | Finding | Evidence | Risk |
|---|---|---|---|
| **S1** | **`profiles` PII is world-readable.** `profiles_public_read USING (true)` with `anon` SELECT on all 32 columns, including `whatsapp_number` (**69 of 127 profiles populated**), `phone`, `notification_prefs`, `referred_by`, `deletion_requested_at`, `kyc_verified`, `deleted_at`. | `pg_policies`, `information_schema.column_privileges`, count query | Anyone with the (public) anon key can enumerate players' WhatsApp numbers. Most players are minors. |
| **S2** | **Signed-in users can rewrite their own profile row, any column.** `profiles_own_update USING (auth.uid() = id)` has **no `WITH CHECK` and no column restriction**; `authenticated` has UPDATE on all 32 columns; the only trigger is `set_updated_at`. | `pg_policies`, column grants, `pg_trigger` | A user can `PATCH` their own `xp`, `sx_score`, `wins`, `total_titles`, `membership_tier`, `login_streak`, **`kyc_verified`** — bypassing every scoring rule and the withdrawal KYC check. |
| **S3** | **Direct-insert policies with no guard triggers** on money/result tables: `tournament_registrations` (`tr_own_insert`, `payment_status` defaults `'pending'` but is client-settable), `withdrawal_requests` (`wr_own_insert`), `match_results` (`mr_player_insert`), `friendly_matches`, `friendly_match_results`. No `BEFORE INSERT/UPDATE` guard exists on any of them. | `pg_policies`, `pg_trigger` (only `marketplace_listings` and `buy_requests` have status guards) | Possible self-marking of a registration as paid, self-confirming a result, or inserting withdrawal rows — to be **verified on a Supabase branch**, not prod. |

**Required action (web repo, before Phase 2 ships to any user):**
- S1: move sensitive columns out of the public read path — a `public_profiles` view / column-level `REVOKE SELECT` on `phone`, `whatsapp_number`, `notification_prefs`, `referred_by`, `deletion_requested_at`, `deleted_at`, `kyc_verified` for `anon` + `authenticated`, with an owner-only accessor (`get_my_profile()` RPC or own-row policy on a split table). Audit every web `select('*')` / `.from('profiles')` first — this will touch web code.
- S2: `REVOKE UPDATE` on `profiles` from `authenticated`, re-`GRANT UPDATE (display_name, bio, avatar_url, country, locale, whatsapp_number, notification_prefs …)` only for genuinely user-editable columns; add a `WITH CHECK`/guard trigger for the rest.
- S3: add status/`payment_status` guard triggers (the `enforce_listing_status` pattern already in the repo), or drop the direct-insert policies where Server Actions already use the service role.
- Because web Server Actions run as the *user* for many writes, each `REVOKE` needs a per-table check that the web still works. Do this on a **Supabase branch**, not production.

Owner note: these are outside "build a mobile app" in scope but inside "don't ship a public binary on top of them" — treat as Phase 0 exit criteria (§13).

---

## 3. Architecture — the three-tier access model

```
┌───────────────────────────── Flutter app ─────────────────────────────┐
│  UI (screens/widgets)  ── Riverpod providers ── Repositories          │
└───────────┬──────────────────────────┬──────────────────────┬─────────┘
   Tier 1 (reads)                Tier 2 (computed reads)   Tier 3 (ALL writes)
   supabase_flutter              dio → /api/mobile/v1      dio → /api/mobile/v1
   PostgREST + Realtime          Bearer <Supabase JWT>     Bearer <Supabase JWT>
            │                              │                       │
            ▼                              ▼                       ▼
       Supabase (RLS)            Next.js route handlers ──► shared service functions
                                            (same functions Server Actions call)
```

| Tier | Use for | Rule |
|---|---|---|
| **T1 Direct read** | Plain row reads that RLS already scopes correctly (list in §2.3): tournaments, matches, entrants, profiles (after S1), feed, comments, own wallet/coins/notifications/DMs, store catalogue, TV, banners. Plus **Realtime** subscriptions. | Read-only. Select explicit columns, never `*`. Every query lives in a repository, never in a widget. |
| **T2 Computed read** | Anything the web derives in TypeScript: group/points/stage standings, bracket tree, leaderboards (Wins/Score/Goals, per-category, per-game), season leaderboard (`season_ranking_points` is self-only under RLS), Hall of Fame, wallet breakdown/earnings trend, guide quest status, player achievements progress, chatbot. | `GET /api/mobile/v1/…`. The endpoint calls the *same* function the web page calls. Never port these to Dart. |
| **T3 Write** | **Every** mutation, without exception — including ones RLS would technically allow (reactions, DMs, follows). | `POST/PATCH/DELETE /api/mobile/v1/…`. One code path = one set of validation, scoring, notification, push and audit side-effects. The app never issues a PostgREST write. |

**Why "no direct writes" even where RLS allows them:** the side-effects (SX Score events, XP, coins, push, in-app notifications, WhatsApp, cache revalidation) live in the actions, not the database. A direct insert silently skips them — exactly the failure the web repo has already hit (`fcm_tokens` reassignment, `notifications` gaps). It also lets the app's write grants be revoked cleanly later (S2/S3).

### 3.1 Repositories and repos boundary
- **Web repo owns:** migrations, RLS, service functions, `/api/mobile/v1/*`, generated `openapi.json`, cron, webhooks (Paystack, Zolarux), push sending.
- **Mobile repo owns:** everything under `lib/`, the copy of `openapi.json`, the generated Dart client, store listings, signing.
- **The bridge is `openapi.json`.** Web CI regenerates it from the zod schemas on every API change and commits it. Mobile pins a copy in `api/openapi.json`, regenerates the Dart client, and a CI job fails if the pinned copy is older than the web repo's (`api_contract_version` header, §7.2). Two-repo changes ship API-first, app-second; the API stays backward compatible for ≥2 app releases.

### 3.2 Environments
This repo's `CLAUDE.md` notes: **there is one Supabase project (`itxubrkbropttfdackmi`), and it is production** — no staging instance. For a program that adds ~100 write endpoints this is the biggest process risk.
- **Rule:** all write-path development runs against a **Supabase branch** (`create_branch`) with seed data, never production. Read-only screens may point at prod (as the current slice does).
- Flutter flavors: `dev` (branch URL + Paystack **test** keys), `prod`. Config via `--dart-define-from-file`, not a committed `env.dart` (the current hard-coded URL/key moves to flavor files; publishable key is public by design but the *flavor split* is what matters).
- Paystack: test-mode secret on the branch deployment; live only on prod Vercel.

---

## 4. Flutter application architecture

### 4.1 Packages (all proposed; add in Phase 0, each justified)
| Concern | Package | Why |
|---|---|---|
| State/DI | `flutter_riverpod` + `riverpod_annotation` / `riverpod_generator` | D4. Async + streams fit Supabase; overrideable repositories in tests (matches the current fake-repository pattern) |
| Routing | `go_router` (already present) | Deep links, redirect guards for auth/onboarding/role |
| Supabase | `supabase_flutter` (present) | Auth, T1 reads, Realtime, Storage uploads |
| API client | `dio` + generated client (`swagger_parser` → `retrofit` + `freezed`) | Typed T2/T3 client from `openapi.json`; spike both `swagger_parser` and `openapi_generator` in Phase 0 and pick one |
| Models | `freezed` + `json_serializable` | Immutable models; replaces hand-written `fromJson` |
| Push | `firebase_core`, `firebase_messaging`, `flutter_local_notifications` | Same FCM project as web; channels on Android |
| Google sign-in | `google_sign_in` + `supabase.auth.signInWithIdToken` | Native flow (resolves open Q2 of old spec) |
| Payments | `webview_flutter` (Paystack `authorization_url`) | §6.4 |
| Video | `youtube_player_iframe` | Live/replay/TV |
| Images | `cached_network_image`, `image_picker`, `flutter_image_compress` | Avatar/post/listing uploads; the web compresses avatars (`lib/avatars/compress.ts`) |
| Audio | `record`, `just_audio` | DM voice notes (pause/review flow exists on web) |
| Share/links | `share_plus`, `url_launcher`, `app_links` | WhatsApp share (`wa.me`), App Links |
| i18n | `flutter_localizations` + ARB via `intl` | en/fr/pcm (§6.8) |
| Storage | `flutter_secure_storage`, `shared_preferences`, `drift` (optional, §6.9) | Session, prefs, cache |
| Observability | `sentry_flutter` (or Firebase Crashlytics) + reporting into `client_error_logs` | §6.10 |
| Testing | `flutter_test`, `mocktail`, `patrol` or `integration_test` | §12 |
| Lint | `flutter_lints` (present) + `custom_lint`/`riverpod_lint` | Convention enforcement |

Update this repo's `CLAUDE.md` when adopted (see §15 housekeeping).

### 4.2 Folder structure (feature-first)
```
lib/
  main.dart                   # bootstrap: Supabase, Firebase, Sentry, ProviderScope
  app.dart                    # MaterialApp.router, theme, locale
  core/
    config/                   # flavors, env, feature flags, remote config (/config)
    api/                      # generated client, dio interceptors (auth, locale, idempotency, errors)
    auth/                     # session provider, role provider, onboarding gate
    routing/                  # router, guards, deep-link + notification-link resolver
    theme/                    # tokens, ThemeData, gamey-feel widgets
    l10n/                     # ARB, locale controller
    realtime/                 # channel manager, lifecycle-aware reconnection
    push/                     # FCM registration, channels, tap routing
    storage/ cache/ errors/ analytics/ utils/ (WAT time, money, coin↔₦)
  shared/
    widgets/                  # AvatarWithFrame, TierBadge, CoinAmount, MoneyText, CountdownChip, EmptyState, SkeletonList…
    models/                   # Profile summary, Game, etc.
  features/
    <feature>/
      data/                   # repository (T1 via supabase, T2/T3 via api), DTOs
      domain/                 # models, pure logic (mirrors small pure web helpers only)
      application/            # Riverpod providers/notifiers
      presentation/           # screens, widgets
test/  integration_test/
```
Feature list = §8's domains. **Existing code moves:** `lib/data/*_repository.dart` → `features/tournaments/data/`, the three screens → `features/tournaments/presentation/`, models → `domain/`, their tests keep working by overriding the repository provider.

### 4.3 Riverpod conventions
- Repositories are `Provider`s, injected into notifiers; tests override them (replaces constructor injection in `buildAppRouter`).
- `AsyncNotifier` for screen state; `StreamProvider` for Realtime (DMs, bell, feed, match live status).
- Mutations return typed `Result<T, ApiError>`; UI maps `ApiError.code` to translated strings (the web already uses `errorCode` → i18n keys — the API keeps those codes, so **error copy is shared**).
- After a mutation, invalidate the specific providers it affects (`ref.invalidate`) — never global refreshes.
- One `sessionProvider` (Supabase auth stream) → `profileProvider` → `roleProvider` (`user_roles`) → drives the router guard and the Admin entry point.

### 4.4 Navigation
Mirror `lib/nav/*`:
- **Bottom tab bar, 5 tabs:** Compete · Watch · Community · Trade · Account (four pillars + account), same as web's unified mobile nav. Each tab keeps its own nav stack (`StatefulShellRoute`).
- **Auth/onboarding gates as router redirects:** logged-out → public routes only (a subset, like web); `username == null` → `/onboarding/username`; phone gate present but **off** (`ENFORCE_PHONE_VERIFICATION=false` on web — the app reads this from `/config`, never hard-codes it).
- **Admin:** visible only when `roleProvider` ∈ {admin, moderator}; entered from Account. Admin routes additionally guard on role in the router, and **every admin API call re-checks the role server-side** (CLAUDE.md rule 3 — hiding UI is convenience, not security).
- **Notification/deep-link resolution:** web notification `link` values are route paths (`/dashboard`, `/matches/…`). One resolver maps a web path (locale prefix stripped) to a go_router location; used by push taps, bell taps, App Links and in-content links.
- Web `/[locale]/…` prefix: the resolver strips `fr`/`pcm` prefixes.

### 4.5 Design system
- Tokens from the web: background `#0B0B0F`, primary violet `#7C3AED`, accent text `#A78BFA`; Barlow Condensed (display) + Inter (body) via `google_fonts` bundled offline; HSL token names from `tailwind.config.ts` ported to a `SxColors` extension (single source of truth, generated by script from the web tokens so they cannot drift).
- **"Gamey feel" concept** (project north-star): every stat/badge/progress is *glow + icon + oversized number + tier colour + animated fill* — implemented once as `StatTile`, `TierBadge`, `XpBar`, `RankChip`, `CoinAmount` in `shared/widgets`.
- Two tier systems, never conflated: **`sentinel_tier`** (SX Score: ≥900 Elite, 750–899 Trusted, 600–749 Developing, <600 At Risk) vs **`membership_tier`** (XP: Recruit 0, Guardian 1 000, Elite 5 000, Sentinel 15 000, Legend 50 000).
- Avatar frames (`equipped_avatar_border` → art), username colours, themes and chat-bubble skins are store cosmetics and must render everywhere the avatar/name renders (`AvatarWithFrame` is used by every list). Frame artwork (`public/coin-items/*.webp`) is copied into app assets, keyed by slug (`frameUrlFor`, `bubbleSkinUrlFor`).
- Mascot poses and the visual-bible assets are copied into `assets/`; sizes budgeted for mobile data.
- Accessibility: min 48dp targets, dynamic type, contrast ≥ AA on the dark ground, semantic labels on icon-only buttons.

---

## 5. Cross-cutting rules the app must honour (unchanged from web)

1. **Money and scores are server-authoritative.** The client displays; it never computes what a server owns. Naira in kobo integers over the wire, displayed via one `Money` formatter. Coin ↔ naira shown together everywhere: **1 coin = ₦0.50** (constants come from `/config`, not hard-coded).
2. **Bracket/table updates only after admin confirmation** (rule 5). The app never optimistically updates standings.
3. **Every SX Score change is logged** server-side; the app just renders `sx_score_events` history.
4. **Timezone: WAT (`Africa/Lagos`, UTC+1, no DST).** All times are UTC on the wire, rendered WAT (mirrors `lib/format.ts`). Full-day matches are date-only, not timestamps.
5. **Locale:** UI locale from device → user setting → `profiles.locale`; server-sent copy (notifications) is already localized by `profiles.locale`.
6. **Coins disclaimer** on every coin surface: "SX Coins cannot be exchanged for cash. They are earned by competing and spent on the platform."
7. **Admin final say:** automation may only *detect/flag*; the app's admin screens expose the explicit resolving action (memory: `feedback_admin_final_say`).
8. **Protect players who are minors:** no new data collection beyond web; camera/mic/storage permissions requested just-in-time with explanation; no analytics SDK receives PII.

---

## 6. Platform capabilities

### 6.1 Authentication & session
- **Sign-in:** email+password → `supabase.auth.signInWithPassword` (direct). After login call `POST /v1/session/start` which runs the server side of `login()` semantics: daily-login coins/streak (`lib/login/actions.ts`), cancel-pending-deletion grace handling, restriction/suspension checks (`lib/settings/restriction.ts`). *Phase 1 task: read web `login()` and confirm exactly which of these it performs; the endpoint must reproduce them.*
- **Sign-up:** `POST /v1/auth/signup` (server-side: blocklist, retired usernames, referral `ref`, locale seeding). Wizard mirrors the web multi-step signup.
- **Google:** native `google_sign_in` → `signInWithIdToken`. Google-only accounts (~43% of users) have no email identity/password; "set a password" goes through the existing reset flow, and the app must never infer "has a password" from `auth.identities` (documented gotcha).
- **Email links:** Supabase templates point at `{{ .SiteURL }}/auth/confirm?token_hash=…&type=…&next=…` (a web URL). Android **App Links** claim `https://sentinelxesports.com.ng/auth/confirm`; the app takes `token_hash`+`type` and calls `verifyOtp` itself; without the app installed the existing web flow runs unchanged. Recovery links route to an in-app reset-password screen; `email_change` returns to Settings. Requires `assetlinks.json` on the web domain (web repo task) and no template change.
- **Onboarding gate:** username claim (`POST /v1/onboarding/username` → `claimUsername`), then phone (feature-flagged). Onboarding quests/guide (§8.20).
- **Tokens:** Supabase session persisted by `supabase_flutter` (secure storage); API interceptor attaches `Authorization: Bearer`, refreshes on 401 once, else signs out.
- **Sign-out** unregisters the FCM token for this device (§6.2) before clearing the session.
- **Account deletion:** request / cancel / delete-now with the 15-day grace (anonymise-in-place); note `profiles.id → auth.users` FK deliberately dropped — never re-add.

### 6.2 Push notifications
- The web already sends via `firebase-admin` (`lib/notifications/fcm.ts`) with 25 push types (17 have user-toggleable prefs, `status_removed` is always delivered). Mobile registers a **native FCM token** into the same `fcm_tokens` table.
- **Do not write `fcm_tokens` directly from the app.** The web route documents why: one physical device carries its token across accounts, and a second account's upsert hits `fcm_tokens_owner`'s `USING` clause (`42501`) permanently. Registration goes through **`POST /v1/devices`** (service-role reassignment, `player_id` from the verified JWT), with `platform`, `app_version`, `locale`. The web cookie-based device logic is not reused.
- **Payload contract:** push `data` carries `type` and `link` (web route path). `notification` block for display; Android channels: `matches`, `social`, `messages`, `money`, `admin`. Verify in Phase 5 that the existing send path emits an Android-compatible payload (today it targets web push).
- **Preferences:** the same `notification_prefs.push.*` keys and per-post / per-type mutes (`notification_mutes`); toggles call the existing `updatePushPrefs` semantics via API. WhatsApp prefs are shown but managed by the same endpoint.
- Foreground: in-app banner + bell increment; background/terminated tap → resolver (§4.4). Permission prompt is contextual (after first registration / first DM), not at launch (Android 13+ `POST_NOTIFICATIONS`).

### 6.3 Realtime
Web uses Supabase Realtime for: community feed, DM conversation + presence, messages bell, notification bell. Mobile mirrors these with one `RealtimeManager`: subscribe when a screen is visible, unsubscribe on dispose, resubscribe on app resume and connectivity return, and **refetch on reconnect** (never assume no gap). DM `UPDATE` events (edit/unsend/read receipts) and RLS windows (10-minute edit/unsend) are covered by API + server RLS; the client only reflects.

### 6.4 Payments (Paystack)
Money rules are unchanged: ₦500 entry (per-tournament fee), ₦ wallet deposits, ₦ staked friendlies, escrow purchases. **Never trust the client.**
1. App calls `POST /v1/tournaments/{id}/register` (or deposit/stake/escrow init) with an `Idempotency-Key`.
2. Server creates the pending row + Paystack transaction and returns `{ authorization_url, reference, callback_url }`.
3. App opens `authorization_url` in a `WebView` (or Custom Tab), intercepting navigation to `callback_url` to close the sheet.
4. App then polls `GET /v1/payments/{reference}` (server verifies with Paystack) with backoff up to ~60 s and shows *Processing…* / *Confirmed* / *Failed*. The **webhook remains the source of truth** that confirms the registration/deposit; the app never marks anything paid.
5. Abandonment: coin-discount refunds are handled by the existing `refund-abandoned-coin-discounts` cron — no client logic.
- Free entry via ≥1 000 coins skips Paystack entirely (server-side, same path as web).
- Prize/wallet withdrawals are **manual by admin** because Paystack Transfer API is not yet enabled; the app shows the request queue and status, and the manual-payout messaging. KYC is payout-account-only (BVN disabled; guardian/NIN redesign is a known future need).

### 6.5 Media & uploads
Avatars, post images, status media, listing images, DM images/voice notes, match result screenshots/recordings. Uploads go to Supabase Storage. Because storage-path/RLS conventions and moderation rules are enforced in actions, the app uploads through **signed upload URLs issued by the API** (`POST /v1/uploads/sign` with purpose + size + mime), then submits the resulting path in the mutation. Client-side: compress images (avatar target mirrors web `compress.ts`), cap video length/size for result recordings (chunked upload, resumable, Wi-Fi hint), strip EXIF. Known constraint: OG/share cards fetch avatars through the Supabase image-transform endpoint because large EXIF/ICC PNGs blank Satori — compressing on-device avoids feeding it oversized files.

### 6.6 Sharing & deep links
- WhatsApp share buttons on tournament, match win, bracket, post, profile pages (v1.0 requirement): `share_plus` + `https://wa.me/?text=` fallback, using the canonical site URL (single `SITE_URL` from `/config`; never re-declared).
- Branded match/post cards: share the server-rendered OG image URL (`/api/matches/[id]/card`), which the API already exposes.
- App Links for `sentinelxesports.com.ng` paths: `/tournaments/*`, `/matches/*`, `/players/*`, `/community/*`, `/exchange/*`, `/seasons/*`, `/auth/confirm`, and locale-prefixed variants. `assetlinks.json` (web repo). iOS Universal Links later.
- "Join our WhatsApp Community" link is pinned in the header (config-driven).

### 6.7 YouTube
Live streams/replays: `youtube_player_iframe` in Match Centre and TV. Admin pastes URLs on web/in admin mobile; URL parsing rules from `lib/matches/youtube.ts` (video id extraction, live vs replay) are mirrored in a tiny pure Dart helper with the same test vectors (the one exception to "don't port logic", justified because it is pure and has unit-test vectors).

### 6.8 Internationalisation
Base `en`; `fr`; `pcm`. ARB files **generated from `messages/{en,fr,pcm}.json`** by a script (namespaces: `common, notifications, nav, exchangeNav, auth, accountDeletion, emailChange, signInMethods, home, account, footer, terms, privacy, refundPolicy, rules, communityRules, safety, escrow, tournamentGuide, tournamentFaqs, about, contact, help, howItWorks, legalCommon`). Per the roadmap, web i18n parts 3–5 (core public pages, dashboard, admin) are **not re-verified as done**; the app therefore treats un-translated keys as `en` fallback and adds keys as those web parts land. Long legal text renders from the same markdown/prose source via `flutter_markdown`.

### 6.9 Caching & offline
Riverpod `keepAlive` in-memory caches + HTTP ETag/`If-None-Match` on T2 GETs. Persisted (drift/`shared_preferences`): session, locale, last home payload, tournament list, own fixtures and wallet balance (stale-while-revalidate with a "Last updated" chip). Writes never queue offline in v1; a submit failing on flaky data shows a retry with the same `Idempotency-Key`. Data-cost sensitivity is a stated product concern (players pay for mobile data): WebP art, image size variants, no autoplay video.

### 6.10 Observability
- Crashes/exceptions → Sentry (or Crashlytics) **and** `POST /v1/errors` → existing `client_error_logs` table (the same table the web's `error.tsx`/`global-error.tsx` write; check it first for any "app crashed" report).
- Redact PII; attach `app_version`, `platform`, `route`, `flavor`.
- Admin sees mobile errors in the same place as web errors.

### 6.11 Remote config / kill-switch
`GET /v1/config` (unauthenticated, cacheable): `min_supported_app_version`, `latest_version`, `maintenance` banner, `site_url`, `coins` constants, `enforce_phone_verification`, `features{}` flags per phase, `whatsapp_community_url`, `paystack_public_key`. The app blocks with an "Update required" screen below the minimum — the safety net for a fleet of installed binaries that can't be hot-fixed.

---

## 7. Mobile API layer (web repo) — spec

### 7.1 Extraction pattern (per domain, done just-in-time before that domain's screens)
1. For each Server Action, split into a pure-ish **service function** `service(ctx, input) → Result` where `ctx = { userClient, adminClient?, userId, role }`. It contains validation (zod schema, already present), DB work, scoring/coin/XP/notification side-effects.
2. The Server Action becomes a thin wrapper: build ctx from cookies → call service → `revalidatePath`/`redirect`.
3. The API route becomes a thin wrapper: build ctx from the bearer token → call the *same* service → JSON.
4. The existing service/unit tests (`*.test.ts`) keep passing untouched; each new route adds a contract test. **Web behaviour must not change** — extraction is a pure refactor per domain, merged separately from the endpoint.

### 7.2 Conventions
- **Base:** `/api/mobile/v1`. Route Handlers under `app/api/mobile/v1/…` (excluded from `next-intl` middleware and from the page-oriented middleware guard — these do their own auth).
- **Auth:** `Authorization: Bearer <access_token>`. The handler calls `supabase.auth.getUser(token)` (network-verified — same rationale as the middleware timeout incident: the boundary is the handler's own verification, not a cookie), then builds an RLS-scoped client from that JWT. `requireStaff`/`requireAdmin` equivalents take the same bearer path. Public GETs allow anonymous.
- **Envelope:** `{ "data": … }` or `{ "error": { "code": "username_taken", "message": "…", "fields": { "email": "invalid_email" } } }`. `code` reuses the web's existing `errorCode` strings so translations are shared. HTTP: 200/201/204, 400 validation, 401 unauth, 403 forbidden/role, 404, 409 conflict/idempotency, 422 business-rule, 429 rate limit, 5xx.
- **Idempotency:** `Idempotency-Key` header required on money/score/state-creating POSTs (register, deposit init, withdraw, escrow purchase, wager, stake pay, submit result, create post). New table `api_idempotency_keys(key, user_id, route, response, created_at)`; replay returns the stored response; TTL 24 h.
- **Pagination:** cursor (`?cursor=&limit=`), consistent with the existing `load-more` actions.
- **Caching:** T2 GETs send `ETag`; public ones `Cache-Control: s-maxage`.
- **Rate limits:** per-user + per-IP; stricter on auth/OTP/chat (reuse `chat_rate_limit_events` pattern).
- **Version handshake:** every response carries `X-Api-Version`; app sends `X-App-Version`, `X-Platform`. Breaking changes → `/v2`; `/v1` supported ≥2 app releases.
- **Contract:** every route registers a zod request/response schema in a registry; `npm run openapi` emits `openapi.json` via zod's JSON-Schema export; CI fails if it is stale.

### 7.3 Endpoint catalogue
Legend: **T1** = app reads directly (no endpoint), **T2** = computed read endpoint, **T3** = write endpoint. "Action" = the existing Server Action the service is extracted from.

**Session & identity**
| Endpoint | Tier | Action / source |
|---|---|---|
| `GET /config` | T2 (public) | new |
| `POST /auth/signup` | T3 | `signup` |
| `POST /auth/resend-confirmation` | T3 | `resendConfirmation` |
| `POST /auth/request-reset` | T3 | `requestReset` |
| `POST /auth/change-email` | T3 | `changeEmail` (+ `verifyPassword`) |
| `POST /auth/unlink-google` | T3 | `unlinkGoogle` |
| `POST /session/start` | T3 | login side-effects (`lib/login/actions.ts`) |
| `POST /onboarding/username` | T3 | `claimUsername` |
| `POST /phone/request-code`, `/phone/confirm` | T3 | `requestPhoneCode`, `confirmPhoneCode` |
| `POST /devices`, `DELETE /devices/{token}` | T3 | new (wraps fcm-token route logic) |
| `POST /errors` | T3 | `logClientError` |
| `POST /uploads/sign` | T3 | new |

**Compete**
| Endpoint | Tier | Action / source |
|---|---|---|
| tournaments list/detail, entrants, stages, lobbies, matches | T1 | tables |
| `GET /tournaments/{id}/standings` (groups, round-robin, points-race, stage) | T2 | `standings.ts`, `points-standings.ts`, `stage-standing.ts` |
| `GET /tournaments/{id}/bracket` | T2 | `bracket-view.ts`, `bracket-tree.ts` |
| `GET /tournaments/{id}/results` | T2 | `results.ts`, `champions.ts` |
| `GET /tournaments/{id}/registration-state` (can-register, eligibility, fee, coin-discount options, waitlist, squad requirement) | T2 | `readiness.ts`, `entrants.ts`, `stage-entry.ts`, `season-placement.ts` |
| `POST /tournaments/{id}/register` (+coin discount tier, agreement, fields: display name, WhatsApp, club, IGN tag) | T3 | `registerForTournament` |
| `POST /tournaments/{id}/waitlist` | T3 | `joinWaitlist` |
| `POST /squads`, `GET /squads/lookup?code=`, `POST /squads/{id}/members/…` | T3/T2 | `createSquad`, `lookupSquadByCode`, `removeSquadMember`, `moveSquadMember` |
| `POST /invitations/{id}/accept|decline` | T3 | `acceptMastersInvitation`, `declineMastersInvitation` |
| `GET /payments/{reference}` | T2 | verify (Paystack) |

**Match centre**
| Endpoint | Tier | Action / source |
|---|---|---|
| match, players, stream URL, check-ins, wagers | T1 | tables |
| `GET /matches/{id}/centre` (stats, replay, my-role, can-submit, deadlines, wager window state) | T2 | `participant.ts`, `check-in.ts`, `wagers/market.ts`, `noshow-eligibility.ts` |
| `POST /matches/{id}/check-in` | T3 | `checkInToMatch` |
| `POST /matches/{id}/result` (score, screenshot, recording URL / WhatsApp recording path) | T3 | `submitMatchResult` |
| `POST /matches/{id}/rating` | T3 | opponent rating (in scoring) |
| `POST /matches/{id}/wager` | T3 | `placeWager` |
| `POST /lobbies/{id}/result` | T3 | `submitLobbyResult` |

**Progress & discovery**
| Endpoint | Tier | Source |
|---|---|---|
| `GET /home` (banners, live tournament, upcoming, leaderboard teaser, hall-of-fame teaser, stats) | T2 | `lib/home/*`, `banners` |
| `GET /rankings?category&game&tab=wins\|score\|goals` | T2 | `rankings/leaderboard.ts`, `game-breakdown.ts` |
| `GET /seasons/{slug}` (standings, provisional live standings, tier labels) | T2 | `seasons/data.ts`, `points-aggregate.ts` |
| `GET /hall-of-fame` | T2 | `hall-of-fame/awards.ts`, `tournament-results.ts` |
| `GET /players/{username}` (profile aggregate: season rank, XP bar, achievements rarity-sorted **without leaking locked names**, posts, stats per game) | T2 | profile page queries |
| `GET /me/summary` (dashboard: fixtures, banners for qualify/eliminate, streak, quests) | T2 | dashboard queries, `guide/quest-status` |
| `POST /players/{id}/follow`, `DELETE …` | T3 | `followPlayer`, `unfollowPlayer` |

**Community**
| Endpoint | Tier | Action |
|---|---|---|
| feed, comments, reactions, challenges, best-play, statuses | T1 (+Realtime) | tables |
| `GET /community/feed` (ranked/boosted/pinned ordering, cursor) | T2 | `feed-query.ts`, `load-more-action.ts` |
| `POST /posts`, `DELETE /posts/{id}`, `POST /posts/{id}/boost` | T3 | `createPost`, `deletePost`, `boostPost` |
| `POST /posts/{id}/comments`, `DELETE …` | T3 | `createComment`, `deleteComment` |
| `PUT /posts/{id}/reaction` | T3 | `toggleReaction` |
| `POST /statuses`, `DELETE`, `POST /statuses/{id}/view`, `GET /statuses/{id}/viewers` | T3/T2 | `postStatus`, `deleteStatus`, `recordStatusView`, `getStatusViewers` |
| `POST /best-play/{id}/vote` | T3 | `castBestPlayVote` |

**Messages**
| Endpoint | Tier | Action |
|---|---|---|
| threads, messages, blocks, mutes | T1 + Realtime + presence | tables |
| `POST /dm/conversations`, `/messages`, `PATCH /messages/{id}` (edit), `DELETE` (unsend), `POST /messages/{id}/forward`, `/threads/{id}/read`, `/delivered`, `/block`, `/report` | T3 | `startConversation`, `sendMessage`, `editMessage`, `unsendMessage`, `forwardMessage`, `markThreadRead`, `markAllThreadsDelivered`, `blockUser`, `unblockUser`, `reportConversation` |

**Notifications**
| Endpoint | Tier | Action |
|---|---|---|
| bell list | T1 (`player_notifications` self-read) + Realtime | table |
| `POST /notifications/read`, `/notifications/read-all` | T3 | `markNotificationRead`, `markAllNotificationsRead` |
| `PUT /notification-mutes` | T3 | `mutePost/unmutePost/muteType/unmuteType` |
| `PATCH /me/notification-prefs` | T3 | `updatePushPrefs`, `updateWhatsappPrefs`, `updateAchievementSharingPrefs` |

**Money**
| Endpoint | Tier | Action |
|---|---|---|
| wallet, transactions, coins, XP, SX events | T1 | own-row tables |
| `GET /wallet/summary` (breakdown, earnings trend) | T2 | `wallet/breakdown.ts`, `earnings-trend.ts` |
| `POST /wallet/deposit` → Paystack url | T3 | `initiateWalletDeposit` |
| `POST /wallet/withdraw` | T3 | `requestWalletWithdrawal` |
| `POST /kyc/resolve-account`, `/kyc/submit`, `DELETE /kyc/payout-account` | T3 | `resolveAccountName`, `submitKyc`, `removePayoutAccount` |
| `GET /referrals` | T2 | referral stats/milestones |
| `GET /store`, `POST /store/{id}/purchase`, `POST /store/{id}/equip` | T1/T3 | `purchaseStoreItem`, `equipStoreItem` |
| `GET/POST /friends…`, `POST /friendlies…` (send/accept/decline/pay-stake/submit-result) | T3 | `sendFriendRequest`, `acceptFriendRequest`, `removeFriend`, `sendChallenge`, `acceptChallenge`, `declineChallenge`, `payStake`, `submitFriendlyResult` |

**Watch & Trade**
| Endpoint | Tier | Action |
|---|---|---|
| TV videos | T1 | `tv_videos` |
| listings, images | T1 | `marketplace_listings`, `listing_images` |
| `POST /exchange/listings`, `DELETE /exchange/listings/{id}` | T3 | `createListing`, `removeListing` |
| `POST /exchange/listings/{id}/purchase` → escrow url | T3 | `initiateEscrowPurchase` |
| `GET /exchange/orders` (buyer/seller state, escrow status) | T2 | `orders.ts`, `escrow.ts` |
| `POST /exchange/requests`, `DELETE …` | T3 | `createBuyRequest`, `cancelBuyRequest` |

**Account & help**
| Endpoint | Tier | Action |
|---|---|---|
| `PATCH /me/profile` (bio, avatar, display name, one-time username change, country, locale) | T3 | `updateProfile` |
| `POST /me/deletion`, `DELETE /me/deletion`, `POST /me/deletion/now` | T3 | `requestAccountDeletion`, `cancelAccountDeletion`, `deleteAccountNow` |
| `GET /guide/quests`, `POST /guide/badge` | T2/T3 | `getQuestStatus`, `claimBattleReadyBadge` |
| `GET /chat/history`, `POST /chat` (streaming) | T2/T3 | `getChatHistory`, `/api/chat` |

**Admin (all `requireStaff`/`requireAdmin` enforced server-side)** — see §8.24, one endpoint per existing admin action (≈75). Catalogue is generated from `lib/admin|tournaments|matches|wallet|exchange|community|tv|games|banners|seasons|messages|friendly-matches|scoring` `*admin-actions.ts` files.

---

## 8. Feature specification by domain

Format: **Web routes → mobile screens · data · mobile notes.** "Phase" refers to §13.

### 8.1 Shell, navigation, home (Phase 1)
- **Routes:** `/` → **Home**: banner carousel (`homepage_banners`), live tournament card, upcoming events, top-of-leaderboard teaser, hall-of-fame teaser, "why Sentinel X"/CTA. Pull-to-refresh.
- **Header:** logo, WhatsApp community link, notification bell (unread count, realtime), messages bell.
- **Bottom tabs** (§4.4). Account tab → sign-in prompt when logged out.
- **Not built on web (do not build):** `/coming-soon` pattern is for unbuilt pillars — the app uses the same `features` flag from `/config`.

### 8.2 Auth & onboarding (Phase 1)
- **Screens:** Login, Signup wizard (username → email → password, live username-availability hint, referral code from link), "check your email" + resend, Forgot password, Reset password (from App Link), Google sign-in button, Onboarding username, Onboarding phone (behind flag).
- **Notes:** error copy from shared `errorCode`s; `blocked_details` deliberately generic (no blocklist probing); signup seeds locale. Referral: `?ref=` from install referrer/deep link stored until signup.

### 8.3 Tournaments — list, detail, registration (Phase 2)
- **Routes:** `/tournaments`, `/tournaments/[slug]` → **List** (current / upcoming / past tabs; game filter; status chips; live registration countdown), **Detail** (banner, prize pool + 1st/2nd/3rd split, format, game/mode/format/map/rules, sponsored-data perk + WhatsApp claim, Markdown rules, agreement checkbox, registration CTA, deadline countdown, entrants list, WhatsApp share).
- **Registration flow (bottom sheet wizard):** per-tournament fields (display name, WhatsApp, club, IGN tag) → rules agreement → **coin discount picker** (Half 500 coins = ₦250 off / Free 1 000 coins; only for fees ≥ ₦500; one tier max; not for free tournaments; shows ₦ equivalent) → Paystack WebView (§6.4) or instant confirm for free/coin entry → confirmation screen with next steps.
- **States:** full → **Waitlist** (join / promoted notification); already registered; registration closed; fee waived (waiver, admin-granted); invitation-only (Masters/Elite Cup invitations w/ cascade + accept/decline + expiry); team formats → **Squad** creation (share code, join by code, roster, member moves) — needed once web phase 6/7 of team-vs-team lands.
- **Slug URL-safe & unique** (rule 7); routes use slug, API uses id.
- **Tournament formats the UI must render:** knockout (with groups), `round_robin` (single table, no knockout — Circuit Cup), points-race lobbies (FF/PUBG), team-vs-team (squads), multi-stage tournaments. Grouping rule reminder: ≤8 straight knockout; 9–16 → 2 groups; 17–32 → 4; 33–64 → 8; top 2 advance; groups 2–8 players (`validGroupCounts`).

### 8.4 Bracket & standings (Phase 2)
- **Routes:** `/tournaments/[slug]/bracket`, `/results` → **Bracket** screen: tabs for Groups (tables with P/W/D/L/GF/GA/GD/Pts and qualify line) and Knockout (horizontally-scrolling round columns per the existing slice, pinch-zoom), Round-robin table, **Points-race** standings (lobbies, per-lobby results, totals), **Results** page (champions, podium, prize split). Brackets show only after publish (`registration_closed` → published); never before registration closes.
- Data via T2 `/bracket` & `/standings` (never recompute). Match cards deep-link to Match Centre. Live updates: subscribe to `matches` changes for the tournament and refetch.
- **Existing slice:** the current `BracketScreen`/`BracketMatch` keep working as the T1 fallback; migrate to T2 once the endpoint exists so group tables and knockout tree share the web's logic.

### 8.5 Match Centre & result flow (Phase 2)
- **Route:** `/matches/[id]` → **Match Centre:** Player/Team A vs B header (avatars w/ frames, SX tiers), status (scheduled/live/completed/disputed), full-day vs timed schedule (date-only handling), countdown, YouTube embed (live) or replay, score, stats, community wager widget (window logic; min 50 / max 2 000 coins), check-in, WhatsApp fixture-coordination button, share (OG match card).
- **Player actions:** **Check-in**; **Submit result** (score + screenshot + screen recording or URL, or send recording via WhatsApp — web #30); **rate opponent** (1–5 → ±SX); dispute state shows both submissions to the involved players. **Winner submits** (per the verification flow); admin confirms — the UI never advances the bracket itself.
- **No-show:** eligible players see a "claim no-show" hint per `noshow-eligibility`; resolution is admin/cron only.
- **Lobby matches** (`/lobbies/[id]`): Lobby room (room ID/password visible to entrants only, per web), result submission form.

### 8.6 Player dashboard (Phase 2, extended in 6)
- **Routes:** `/dashboard`, `/dashboard/{tournaments,matches,friends,friendlies,marketplace,profile→settings,referrals,wallet…}` → **Home-for-players** ("My Sentinel X"): next fixture card with countdown & one-tap check-in, qualify/eliminate banner, active registrations, submit-result prompts, streak & daily login, quests (§8.20), wallet/coins/XP tiles (gamey stat tiles), recent notifications. Sub-screens for the rest, each as its own section below.

### 8.7 Rankings, seasons, Hall of Fame (Phase 3)
- **Rankings:** category tabs (football/fighting/shooter, "All football"), per-game sub-filter chips, 3 metric tabs (Wins / Score / Goals), rank-trend arrows (`player_rank_snapshots`), streaks, search, paginated. All T2.
- **Seasons `/seasons/[slug]`:** multi-game tabs, standings, live provisional standings, tier labels (`season-tier-labels.ts` — DLS Community Club/Masters, FC Mobile Circuit Cup/Elite Cup) served from the API (code-level constant on web, not a DB table), invitation state for Masters/Elite.
- **Hall of Fame:** season champions, MVP, Golden Boot, Best Goal, per-game/category awards, tournament results; permanent pages.

### 8.8 Player profile (Phase 3)
- **Routes:** `/players`, `/players/[username]` (+ `/followers`, `/following`) → **Directory** (search), **Profile** (avatar+frame, display name, username colour, bio, SX Score + `sentinel_tier` badge, XP bar + `membership_tier`, season rank, W/L/GF/GA/titles per game, achievements showcase **rarity-sorted, locked achievements do not leak name/description**, match history, community posts, follow/unfollow + "Follows you" indicator, message button, share).
- **Own profile edit** lives in Settings (§8.19). Deleted/anonymised accounts render as tombstones, never crash.

### 8.9 Community (Phase 4)
- **Routes:** `/community`, `/community/[postId]`, `/community-rules` → **Feed** (media-first, post types manual/match_result/achievement/announcement, pinned & boosted, 4-emoji reactions, threaded comments, weekly challenges rail, Best Play of the Week voting, status stories row, top members, upcoming events, gallery), **Post detail**, **Compose** (text + image(s), boost for 200 coins), **Statuses** (24 h stories with viewer list and friend-only notifications), **Weekly challenges** progress, **Best Play** vote.
- Public read (§2.4); write/react require sign-in. Realtime new-post/reaction updates. Moderation: report/delete own; staff pin/announce/delete.
- **Coin wagering** surface sits in Match Centre (§8.5).

### 8.10 Direct messages (Phase 5)
- **Routes:** `/messages`, `/messages/[threadId]` → **Inbox** (threads, unread, presence dot), **Conversation** (realtime, text/images/voice notes with pause-review, stickers, reply, edit & unsend within 10 min, forward, delivered/read receipts, typing/presence), **Block/Report/Mute**, **Requests** rules via `dm_can_message`. Start from profile. Optimistic send + retry (mirror web). Push for DMs (bug fixed 2026-09-13; the payload must carry thread id).
- Known-untested on web (manual QA skipped): realtime UPDATE, swipe gesture, RLS edit window — the app gets its own integration tests for these (§12).

### 8.11 Notifications (Phase 5)
- **Bell drawer:** grouped list from `player_notifications` (type, title, body, link, read), mark read / read all, load-more, per-post and per-type mute, deep-link on tap. Types include tier_upgraded, fixture reminders, result confirmed, prize credited, new follower, DMs, bracket released, wager settled, etc.; the app renders unknown future types with title/body/link generically (forward compatible).
- **Settings → Notifications:** push prefs (17 keys), WhatsApp prefs, achievement-sharing prefs.
- WhatsApp Business/Termii is server-side (ready-to-activate, no-op until keys/templates set); app only exposes the prefs.

### 8.12 Wallet, deposits, withdrawals, KYC (Phase 6)
- **Routes:** `/dashboard/wallet`, `/deposit`, `/withdraw`, `/transactions`, `/payment-methods` → **Wallet** (balance, earnings breakdown, trend chart, coin balance side-by-side with ₦ equiv), **Deposit** (Paystack WebView), **Withdraw** (KYC gate → payout account → request → status timeline; "paid out manually by admin" messaging), **Transactions** (filter/paginate), **Payment methods** (resolve account name via Paystack, save/remove payout account).
- KYC = payout-account verification only (BVN disabled). Minors: no BVN prompt.

### 8.13 Coins, XP, SX Score, achievements (Phase 3 display, Phase 6 spend)
- Coin ledger (`sx_coin_transactions`), earn sources & spend destinations (§ web economy spec), disclaimer tooltip on every coin surface.
- **XP/membership tier** progress and history (`xp_events`); **SX Score** history (`sx_score_events`).
- **Achievements** catalogue with categories, rarity, locked-state redaction, share-to-feed toggle.
- **Daily login** +5 / streak bonuses at 7 and 30 days (via `/session/start`).

### 8.14 Store (Phase 6)
- **Route:** `/store` → **Store grid** (avatar borders, themes, username colours, bubble skins; ~23 items), item preview with the real frame art, coin price + ₦ equivalent, purchase, equip/unequip, "owned" state. Equipped items appear everywhere (§4.5). *Store art exists as WebP in the web `public/coin-items/`; import into assets.*
- Policy risk (§14): Apple IAP rules do not apply to earned-only coins, but store copy must state coins cannot be bought with money *if that is true today* — verify in Phase 6 whether any ₦→coin purchase path exists.

### 8.15 Friends & friendlies (Phase 6)
- **Routes:** `/dashboard/friends`, `/dashboard/friendlies`, `/dashboard/friendlies/[id]` → Friend list/requests, **Challenge** (free, or **staked** in ₦ *or* coins — symmetric, one currency per challenge), **Match Room** (accept → pay stake (Paystack escrow for ₦, instant for coins) → play → both submit results → admin confirms/disputes), history, SX integration. Coin stakes settle instantly.

### 8.16 Referrals (Phase 6)
- **Route:** `/dashboard/referrals` → share link/code, invited list with status, milestone tracker (+250 coins on referred player's first *paid* entry; bonuses at 5/10/25/50 conversions). Install-referrer captures `ref`.

### 8.17 Watch — Sentinel X TV (Phase 7)
- **Route:** `/tv` → tabs Live / Highlights / Finals / Replays from `tv_videos`; YouTube player; share; live badge synced with `matches.is_live`.

### 8.18 Trade — Gaming Exchange (Phase 7)
- **Routes:** `/exchange`, `/exchange/[id]`, `/exchange/new`, `/exchange/requests/new`, `/escrow`, `/dashboard/marketplace` → **Catalogue** (filters by game/category/price, sort, merchandising/featured), **Listing detail** (multi-image gallery, seller, escrow explainer), **Create listing** (multi-image, requires admin approval → pending), **Buy** (escrow via Zolarux — opens the escrow hosted flow; webhook drives state), **My Listings / Orders / Sales**, **Buy requests** (create/cancel), state badges.
- Admin approve/remove lives in Admin (§8.24). This pillar carries the highest store-policy risk (§14).

### 8.19 Settings & account (Phase 2 minimal, Phase 6 complete)
- **Route:** `/dashboard/settings` → **Profile** (display name, bio, country, avatar upload compressed, one-time username change), **Notifications** (§8.11), **Language** (en/fr/pcm), **Security** (change email needs current password; Google link/unlink; set password via reset flow), **Sign-in methods**, **Phone verification**, **KYC/payout**, **Account & data**: delete account (request → 15-day grace → cancel or delete-now).
- Deletion tombstones, `retired_usernames`, ban-evasion `banned_identifiers` are server-side.

### 8.20 Guide, quests, chatbot, help, static pages (Phase 1 static; Phase 5 guide/chat)
- **Static (Phase 1):** About, Contact, Help, How it works, Tournament guide, Tournament FAQs, Rules, Community rules, Safety, Escrow, Games, Terms, Privacy, Refund policy — rendered from shared markdown via the legal `DocShell` pattern (sticky ToC, anchored sections, summary, pills). Content sourced from the web repo's translated messages, not re-typed.
- **Guide/onboarding quests:** 3-step quest (profile complete → first tournament entered → first match completed), "Battle Ready" badge claim, spotlight tours on first run.
- **Support chatbot** (Groq-backed on the server, single tool `get_account_snapshot`): chat tab with history, streamed replies, rate-limited; the equipped bubble skin changes the mascot.

### 8.21 Games (Phase 2)
- **Route:** `/games` → games list driven by `games.active` (DLS and EA FC Mobile are the active games today; Free Fire / PUBG Mobile mode catalogues exist but public activation follows web's team-vs-team phases 6–7; others shown as coming soon), category taxonomy (football/fighting/shooter), per-game interest ("notify me", `game_interest`), game icons/emoji. Multi-game everywhere (tournament filters, rankings, HoF, seasons).

### 8.22 Legal & compliance content (Phase 1)
- Terms includes **§8 Community Wagering (coins-only)**; Privacy; Refund Policy; app-store privacy label/data-safety form derived from real data flows (§14).

### 8.23 Deep-link only web routes (Phase 1)
`/offline`, `/coming-soon` have no mobile equivalent; the app has native offline/empty states.

### 8.24 Admin section (Phase 8) — role-aware
Visible to `admin` and `moderator`. Full parity per D2, mapped from `/admin/*`; sub-role limits per CLAUDE.md: **moderators get no financial actions and no player bans**, enforced by API, mirrored by hiding controls.

| Web route | Mobile screen(s) | Primary actions (existing Server Actions) | Sub-phase |
|---|---|---|---|
| `/admin` overview | Overview with live-aggregation stat cards + admin bell + badges over pending queues | — (no table; aggregation queries) | 8a |
| `/admin/results`, `/admin/matches/[id]/review` | Result review queue → review screen (both submissions, screenshots, recordings, score mismatch flag) | `confirmResult`, `disputeResult`, `updateMatch`, no-show: `declareNoShowWinner`, `markBothNoShow`, `resolvePendingNoShowMatches` | 8a |
| `/admin/players`, `/admin/players/[id]` | Player search & detail (flags, economy tools) | flag conduct/cheating; `grantCoins`, `deductCoins`, `grantXp`, `manuallyUnlockAchievement`, `recomputeAllAction` | 8a |
| `/admin/wallet` | Withdrawal queue (admin only) | `resolveWalletWithdrawal`, `adminCreditWallet`, `manualCreditWallet` | 8a |
| `/admin/messages` | DM reports & muting | `resolveDmReport`, `setMessagingMuted` | 8a |
| `/admin/community`, `/challenges` | Moderation, announcements, pin, delete post/status, Best Play nomination/confirmation, weekly challenges CRUD | `createAnnouncement`, `togglePin`, `adminDeletePost`, `adminDeleteStatus`, `nominateBestPlay`, `confirmBestPlayWinner`, `createChallenge`, `updateChallenge`, `toggleChallengeActive` | 8a |
| `/admin/exchange`, `/requests` | Listing approval queue, order tools, buy-request handling | `approveListing`, `removeListingAdmin`, `deleteListingAdmin`, `cancelOrderAdmin`, `markListingSoldAdmin`, `setListingMerchandising`, `markBuyRequestInProgress/Fulfilled`, `closeBuyRequest` | 8a |
| `/admin/friendlies` | Confirm/dispute friendly results | `confirmFriendlyResult`, `disputeFriendlyResult` | 8a |
| `/admin/tv`, `/banners`, `/store`, `/games`, `/referrals` | Content CRUD | `addVideo/updateVideo/toggleVideoActive/deleteVideo`, banner CRUD, `createStoreItem/updateStoreItem/toggleStoreItemActive`, `createGame/toggleGameActive`; referrals read-only analytics | 8a |
| `/admin/account-recovery` | Release username / clear banned identifier | `releaseUsername`, `clearBannedIdentifier` | 8a |
| `/admin/tournaments`, `/new`, `/[id]/edit` | Tournament list + create/edit form (all fields, prize split, rules Markdown, manual knockout pairing toggle, sponsored perk), open/cancel/delete | `createTournament`, `updateTournament`, `deleteTournament`, `openRegistration`, `cancelTournament`, `refundRegistration`, `recomputeStandings` | 8b |
| `/admin/tournaments/[id]/registrations`, `/invitations` | Registrations list (search), disqualify/substitute/remove, waitlist promote, waivers, season invitations & cascade | registrations-admin actions, waiver actions, `sendInvitations`, `cascadeNextInvitation`, `manuallyAddInvitee` | 8b |
| `/admin/tournaments/[id]/bracket`, `/matches`, `/results` | Close registration → generate → **override group count** (`validGroupCounts`) → move player between groups → publish; knockout pairing editor; round schedule; assign slots; stream URL; toggle live | `closeRegistration`, `reopenRegistration`, `generateBracket`, `publishBracket`, `movePlayerToGroup`, `createKnockoutRound`, `swapKnockoutPairing`, `updateMatch`, `toggleMatchLive`, `advanceKnockout`, `completeTournamentIfFinal`, `creditThirdPlacePrize` | 8b |
| `/admin/tournaments/[id]/stages`, `/lobbies`, `/squads` | Stage builder, lobby generation & room details, lobby confirm/dispute, squads | `createStage/updateStage/deleteStage`, `openStage`, `generateNextRound`, `updateLobbyDetails`, `confirmLobby`, `disputeLobbyResult` | 8b |

Admin UX on mobile: queue-first, big-tap confirm/dispute with reason capture, deep-links from admin push types (`result_needs_review`, `result_disputed`, `result_no_submission`, `withdrawal_pending`, `exchange_listing_pending`, `noshow_needs_decision`).

---

## 9. Data model reference (what Flutter models must cover)
Core: `profiles`, `games`, `game_modes/formats/maps/match_rules`, `tournaments`, `tournament_registrations`, `tournament_entrants`, `tournament_stages`, `tournament_lobbies`, `lobby_entrants`, `lobby_results`, `groups`, `group_memberships`, `squads`, `squad_members`, `matches`, `match_results`, `match_check_ins`, `match_wagers`, `opponent_ratings`, `seasons`, `season_ranking_points`, `tournament_invitations`.
Progress/economy: `sx_score_events`, `xp_events`, `sx_coins`, `sx_coin_transactions`, `store_items`, `player_store_items`, `achievements`, `player_achievements`, `community_challenges`, `player_challenge_progress`, `wallets`, `wallet_transactions`, `wallet_deposits`, `player_kyc`, `referrals`.
Social: `community_posts`, `post_comments`, `post_reactions`, `community_post_images`, `player_statuses`, `status_views`, `player_follows`, `friends`, `friendly_matches`, `friendly_match_results`, `dm_threads`, `dm_messages`, `dm_blocks`, `dm_reports`, `player_notifications`, `notification_mutes`, `fcm_tokens`, `best_play_nominations`, `best_play_votes`.
Trade/content: `marketplace_listings`, `listing_images`, `marketplace_orders`, `buy_requests`, `tv_videos`, `homepage_banners`.
Admin: `user_roles`, `admin_flags`, `client_error_logs`, `withdrawal_requests` (legacy), `tournament_fee_waivers`.
Models are generated from `openapi.json` wherever an endpoint exists; T1 read models are hand-written `freezed` classes with `fromJson` tests against recorded fixtures.

---

## 10. Security & privacy requirements
- **No secrets in the app.** Only the publishable key and Paystack *public* key. All Paystack/Zolarux/Termii/Groq/Firebase-admin secrets stay in the web deployment.
- Bearer tokens only over HTTPS; certificate pinning not required v1 (revisit).
- **S1–S3 (§2.5) fixed before public release.**
- RLS remains the backstop for T1 reads; every T3 service re-authorizes (ownership, role, state) — never trusts the client's claimed ids.
- Obfuscate release builds (`--obfuscate --split-debug-info`), Play Integrity for Play builds (fraud signal on payment routes), root-detection **not** enforced (false positives, poor value).
- Screenshot/recording data (match evidence) stored in private buckets with signed URLs; only participants + staff can read.
- PII minimization: the profile API returns only the columns the requester is entitled to; phone/WhatsApp never in public payloads.
- Minors: age-appropriate copy; no gambling-style UX; coin wagering surface carries the disclaimer; store data-safety form accurate.

---

## 11. Compatibility & migration of existing mobile code
- The vertical slice (tournament list/detail/bracket) is kept and moved (§4.2); its fake-repository tests remain valid via provider overrides.
- The hard-coded `SupabaseEnv` moves to flavor `--dart-define`s.
- `buildAppRouter(repository:)` is replaced by a Riverpod-provided `GoRouter`; `app_router_test.dart` is adapted, not deleted.
- Nothing in this spec changes web behaviour except: (a) the S1–S3 security migrations, (b) additive `/api/mobile/v1` handlers, (c) service-function extraction (pure refactor, per domain), (d) `assetlinks.json`, (e) new tables `api_idempotency_keys`.

---

## 12. Testing strategy
- **Unit:** pure helpers (Money/coin formatting, WAT time, YouTube URL, route resolver, tier mappers) with test vectors copied from web tests (`format.test.ts`, `tiers.test.ts`, `value.test.ts`).
- **Repository tests:** fixtures recorded from real responses; T1 queries verified against a Supabase branch in CI (read-only).
- **Widget tests:** every screen with fake repositories (existing pattern) incl. loading/empty/error/locked/role states.
- **Contract tests:** generated client vs a local Next.js dev server on the branch DB; fail on schema drift.
- **Integration (device/emulator):** the golden paths per phase — signup→onboarding→register→pay (Paystack test)→bracket→submit result; DM send/edit/unsend/read with two sessions; push tap routing; deep links; role-gated admin visibility. **Assert a control first** (a step known to work) so headless flakiness isn't read as a pass; wait for hydration; assert every step (lessons from the web headless-Chrome drills).
- **Security regression:** with a non-staff JWT, every admin endpoint returns 403; S2/S3 attempts (patch own `xp`, insert own paid registration) are rejected — run on the branch DB.
- **Money-path tests** (Paystack test mode): idempotent replays, abandoned checkout refunds, webhook-before-poll and poll-before-webhook orderings.
- **Beta:** Play Console internal → closed track with real players before public.

CI (GitHub Actions): `flutter analyze`, `flutter test`, contract check, build APK/AAB per flavor, size budget.

---

## 13. Delivery phases

Each phase ends with a shippable, testable app. **Each phase gets its own implementation plan** (`docs/superpowers/plans/`) written from this spec, and — where it needs endpoints — its own web-repo API spec. Sizes: S ≈ days, M ≈ 1–2 wks, L ≈ 3–4 wks, XL ≈ 5+ wks (single developer, indicative only).

| Phase | Scope | New web work | Exit criteria | Size |
|---|---|---|---|---|
| **0 Foundation & security** | Flavors, Riverpod migration of existing slice, theme/tokens, i18n scaffold, api client pipeline (`openapi.json` → Dart), router w/ guards + link resolver, `/config`, Sentry + `/errors`, CI. **Web:** S1–S3 fixed on a branch then prod; bearer-auth helper; API scaffolding; `assetlinks.json`; Supabase branch env. | Yes (auth helper, `/config`, `/errors`, security migrations) | S1–S3 closed and verified on branch; an authenticated round-trip through a bearer endpoint from a device; CI green; existing slice unchanged | L |
| **1 Auth, shell, home, static** | Login/signup/reset/Google, onboarding gate, tabs, home, static/legal pages, `/session/start`, App Links for email | `signup`, `session/start`, `onboarding`, `home` endpoints | New user can sign up (email + Google), confirm via App Link, claim username, land on Home; ban/retired-username checks proven | L |
| **2 Compete core** | Tournaments list/detail, registration (+coin discount, waitlist, waivers, invitations), Paystack WebView, bracket/standings (T2), match centre, check-in, result submission, dashboard fixtures, games, minimal settings | Extraction of `tournaments`, `matches`, `scoring` services; endpoints in §7.3 Compete/Match | Full loop on branch: register+pay → published bracket → play → submit result → (admin on web) confirm → standings update; idempotency proven | XL |
| **3 Progress & profiles** | Rankings, seasons, hall of fame, player profiles, follow, achievements/XP/SX displays, coin ledger view | `rankings`, `seasons`, `hall-of-fame`, `players` endpoints | Numbers match the web page for a sample of 10 players/season; locked achievements never leak | L |
| **4 Community** | Feed, post detail, compose, reactions, comments, challenges, best play, statuses, boost, coin wagering | community services + endpoints | Feed parity + realtime; moderation delete works; boost/wager coin ledger correct | L |
| **5 Messages, notifications, push, guide** | DMs (full feature set), bell, prefs/mutes, FCM native, deep-link taps, guide quests, support chatbot | dm/notification services, `/devices`, push payload audit | Two-device DM test incl. edit/unsend/read; push received in all 3 app states; notification tap routes correctly | XL |
| **6 Money & social economy** | Wallet, deposit, withdraw, payment methods/KYC, transactions, referrals, store + equip, friends, friendlies (free+staked) | wallet/kyc/coins/friendly services | Paystack test-mode deposit + staked friendly end-to-end; withdrawal request → admin queue; store purchase + equip appears app-wide | XL |
| **7 Watch & Trade** | TV, Exchange catalogue/listing/escrow/orders/buy requests | exchange services, Zolarux escrow init | Escrow purchase completes on branch; webhook state reflected | L |
| **8a Admin — queues & moderation** | Result review, players, wallet queue, DM reports, community moderation, exchange approvals, friendlies, content CRUD, recovery | admin services (≈50 actions) | Moderator vs admin permission matrix verified (moderators blocked from money/bans) | XL |
| **8b Admin — tournament builders** | Tournament CRUD, registrations, bracket generation/override/move/publish, pairing editor, stages, lobbies, squads, scheduling | admin tournament services (≈25 actions) | Samuel can run a full tournament from a phone | XL |
| **9 Release hardening (Android)** | Perf, a11y, size, crash-free target, store listing, data-safety form, closed beta → production, monitoring dashboards | — | ≥99.5% crash-free sessions in closed beta; Play review passed | L |
| **10 iOS** | Apple review resolution (§14), Universal Links, APNs via FCM, TestFlight, App Store | AASA file | App Store approved | L |

**Ordering rationale:** money-touching flows (Phases 2, 6) come with the most branch-based testing time; admin is last because Samuel keeps using the web meanwhile, and the queue-first admin screens (8a) ship before the builders (8b). Phase 0's security fixes are also the single highest-value item for the *web* platform, independent of mobile.

**Web-parity dependencies (mobile follows web, never leads):** (a) team-vs-team public rendering (web phase 6) and the catalogue flip (phase 7) must land before mobile renders squads/team matches in Phase 2/8b; (b) web i18n parts 3–5 unverified; (c) 21b leagues unbuilt → not in mobile.

---

## 14. Store policy & compliance (decide before Phase 9 / Phase 10)
**Google Play (Android launch)**
- **Real-money gaming / gambling policy:** Sentinel X is skill-based tournaments with entry fees and prize pools, plus **coin** wagering (coins-only, no cash-out, legally reasoned in the coin-economy spec). Play's "Real-Money Gambling, Games, and Contests" policy has region-specific licensing/eligibility requirements; Nigeria is a listed regulated market for some categories. **Action:** obtain a written policy reading (Play Console pre-launch/policy support) for skill-based paid tournaments and for the coin-wagering widget; be prepared to ship a build with wagering hidden via the `features` flag.
- **User-generated content:** in-app report/block (exists for DMs and posts), moderation SLA, community rules link — required.
- **Data safety form:** collects email, username, WhatsApp number (optional), payment via Paystack (no card data in-app), device tokens, photos/video uploads, crash logs.
- **Children/families:** most players are minors; the app must not target under-13 (Play "Families" policy) — age gate at signup or ToS 13+ statement and copy consistent with the existing safety/terms pages. **Open item for the owner** (legal), not solved here.
- **Payments:** Paystack for real-world services/tournament fees is permitted; coins earned-only and cosmetic-only. If any ₦→coin purchase path exists, Play Billing would apply — verify in Phase 6.

**Apple (iOS)**
- **3.1.1 In-app purchase / virtual currency:** cosmetics bought with earned coins are fine; any ₦→coin purchase would require IAP. Entry fees and prize payouts for real-world tournaments are generally acceptable under 3.1.3(e)/5.3 *if* licensed and geo-restricted appropriately.
- **5.3 Gambling:** coin wagering is the review risk; ship with wagering hidden on iOS if Apple objects.
- **5.1.1(v) Account deletion in-app:** already built (15-day grace + delete-now).
- **Guideline 1.2 UGC:** report/block/moderation, present.
- Peer-to-peer exchange with escrow may be read as marketplace/financial service — prepare licensing explanation.
- Sign in with Apple is **required if any third-party social login (Google) is offered** on iOS — add to Phase 10 scope (`sign_in_with_apple` + Supabase Apple provider).

---

## 15. Housekeeping when this spec is approved
1. Update `CLAUDE.md` in this repo: state management = Riverpod (was "not chosen"); current spec pointers; three-tier rule; "never write via PostgREST"; correct the `notifications`/`community_posts` notes (§2.4); note the prod-only DB and the branch rule.
2. Mark `2026-09-18-flutter-mobile-app-phase1-design.md` as absorbed into this spec.
3. Web repo: open a tracking entry in `ROADMAP.md` ("Mobile app — API layer & security prerequisites") and write the Phase 0 web spec (bearer auth helper, `/config`, `/errors`, `/devices`, idempotency table, OpenAPI pipeline, S1–S3 fixes).
4. Save a project memory in the web repo's memory for S1–S3 (security finding) and the `notifications` vs `player_notifications` clarification.

---

## 16. Risks

| Risk | Impact | Mitigation |
|---|---|---|
| S1–S3 security gaps (§2.5) | PII leak, score/KYC tampering, possible payment bypass | Phase 0 hard gate; fix + verify on a branch |
| **Only one Supabase project (prod)** | Write-path development can corrupt live data | Supabase branches + Paystack test keys; dev flavor never points at prod for writes |
| Service extraction touches 183 actions | Regression on the live web app | Per-domain, pure-refactor PRs, existing unit tests as the safety net, web smoke checks before each merge |
| Concurrent sessions in the web repo (documented merge races) | Lost/staged-file collisions | Worktrees for API work; verify branch + `git diff --cached` before each commit |
| Store rejection over wagering/escrow/minors | Launch blocked | Feature flags per surface (`/config`), Android first, policy reading up front (§14) |
| Two-repo contract drift | Broken app for installed users | Generated `openapi.json`, CI staleness check, min-version gate, 2-release compat window |
| Paystack Transfer still not enabled | Withdrawals stay manual | UI copy sets expectations; no client change when it is enabled |
| Migration numbering collisions | Failed deploys | Timestamp-prefixed migrations only (web CLAUDE.md rule) |
| Team-vs-team not finished on web | Squads UI blocked | Sequence mobile after web phase 6/7; flag off until then |

---

## 17. Open questions (owner decisions; none block Phase 0)
1. **Age gate / minimum age** for the app listing (13+ statement vs hard gate) — legal input needed (§14).
2. **Crash tool:** Sentry vs Firebase Crashlytics (default: Sentry + `client_error_logs`).
3. **API client generator:** `swagger_parser`+retrofit vs `openapi_generator` — decided by a Phase 0 spike, criteria: freezed output, null-safety fidelity, error envelope support.
4. **Play Integrity** on payment endpoints: enforce vs signal-only (default: signal-only).
5. **Does any ₦→coin purchase path exist?** (affects §14 IAP analysis) — confirm against the web code in Phase 6.
6. **Web i18n parts 3–5 status** — confirm before Phase 2 to size the ARB work.
7. **Moderator scope on mobile** — confirm moderators should get 8a queues but never the wallet screen (default per CLAUDE.md: yes).
