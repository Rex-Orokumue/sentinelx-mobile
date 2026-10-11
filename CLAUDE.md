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

- **Tripwire:** do not set `enforce_phone_verification=true` in any environment until a *released* app
  version contains the onboarding-phone screen. `/onboarding/phone` exists as of Phase 6e (the gate now reads
  `/me.profile.phoneVerifiedAt`), but a user on an older build would be stranded, and WhatsApp
  (`META_WHATSAPP_TOKEN` / `META_WHATSAPP_PHONE_NUMBER_ID`) must be live in that environment or no code can arrive
  (the API answers `phone_unavailable` and the screen says so). The owner flips the flag; this build never does.
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
  | `/notifications` | In-app bell (standalone, outside the shell; reached from the app bar bell and push taps) |
  | `/account/notifications` | Settings -> Notifications (prefs, test push, permission row) |
  | `/messages` | Direct-message inbox (standalone, outside the shell; the app bar messages bell and push taps open it) |
  | `/messages/requests` | Message requests box (declared before `:threadId`, so it is never read as an id) |
  | `/messages/:threadId` | A conversation (text, photo, sticker, voice note, reply, edit/unsend, forward) |
  | `/guide` | Guide (quest checklist + replay tour; visitor tour when signed out) |
  | `/guide/chat` | Support chat (streamed; history kept 30 days for signed-in players) |
  | `/account/language` | Settings -> Language (en / fr / pcm) |
  | `/account/security` | Settings -> Security (change email, password reset link) |
  | `/account/sign-in-methods` | Settings -> Sign-in methods (link / unlink Google) |
  | `/account/phone` | Settings -> Phone verification |
  | `/account/delete` | Settings -> Delete account (schedule, cancel, delete now) |
  | `/account/referrals` | Referrals (link, invited players, conversion and milestone history) |
  | `/account/wallet` | Wallet (balance, earnings, recent transactions, payout account) |
  | `/account/wallet/deposit` `/withdraw` `/transactions` `/payout-account` | Add money (Paystack), withdraw + status, ledger, payout account |
  | `/account/store` | Coin store: browse, buy, equip / unequip (public catalogue; moderators keep it) |
  | `/onboarding/phone` | Phone gate (reachable only while `enforcePhoneVerification` is on and the phone is unverified) |
  | `/debug` | debugTools only |

- **Store (Phase 6b).** Catalogue, ownership, price and balance come only from `/api/mobile/v1/store/**` through `StoreRepository`; purchase uses `writeFlowProvider('store-purchase:<itemId>')` (one `Idempotency-Key` per item, double-tap guarded, state refetched from the server, never assumed). SX Coins are earned only: there is no coin-purchase surface or wording anywhere. Art is bundled in `assets/store/` (the 20 web WebP files, same names) and resolved by FILE NAME by `CosmeticArt` for avatar frames and the assistant bubble; an unknown name falls back to the network URL, so new store items need no app update. Username colour and profile theme are native (`CosmeticStyle`; `theme_neon_grid` is a gradient approximation). `/me` now carries `usernameColour` and `profileTheme`, and the wallet overview carries `coinBalance`. On the web side every coin change goes through the Postgres `coin_apply` function (clamp mode for earns and `admin_deduct`, strict mode for spends) and `store_purchase` / `store_equip` are single transactions. Errors map by CODE in `store_errors.dart`.
- **Wallet (Phase 6a).** Every figure and every write goes through `WalletRepository` over `/api/mobile/v1/wallet/**`; never read `wallets`/`wallet_transactions` or write via PostgREST. The server owns balance, ledger, the Paystack fee and the payout name; the app never computes a fee. Deposit and withdrawal use `writeFlowProvider` (one `Idempotency-Key` per compose action, fresh key when the amount changes) and the deposit confirms by polling `GET /wallet/deposits/{reference}` after the existing `PaystackCheckoutScreen`, never on the WebView alone. The payout account number is typed once and held only in the field; reads return it masked. Errors are mapped by CODE in `wallet_errors.dart`, never by the server's English message. `WalletGate` wraps every wallet route (signed-out -> log-in prompt, moderator -> `/account`). The web side made `wallet_apply` / `wallet_request_withdrawal` (Postgres, service-role only) the only way to change a balance. Payouts are manual by an administrator. Real Paystack checkout needs the staging device pass in `TESTING-NOTES.md`.
- **Referrals (Phase 6d).** `/account/referrals` reads only `GET /me/referrals`; conversion and coin awards remain server-owned after a paid, non-waived entry. The current username is the share code, and `/signup?ref=` App Links pass it to the existing signup API. Android's Play Install Referrer adapter stores only a validated `ref` until signup succeeds; an explicit App Link wins. System text sharing uses a small Android channel because `share_plus` 11 conflicts with the current `package_info_plus` dependency and `share_plus` 12+ requires a newer Android Gradle plugin. Real Play attribution and verified App Links still need a physical-device pass; the public web signup link works before a Play listing exists.

- **Push (Phase 5a).** Firebase sits behind `PushGateway` (`lib/core/notifications/push/`); push is never required
  to boot (a failed `Firebase.initializeApp()` yields a disabled gateway). `android/app/google-services.json` is
  untracked by design and the Gradle plugin is applied only when it exists - keep both build paths working. The
  notification permission is asked once, at the first confirmed stake (register / waitlist / invitation accept), and
  only when the OS status is `notDetermined`. A push tap on a link `resolveWebLink` cannot map opens `/notifications`.
- **Direct messages (Phase 5b).** Every viewer-specific read and every write goes through `/api/mobile/v1/messages/**`
  (`MessagesRepository` over `ApiClient`); realtime is only a **nudge** that refetches the loaded window - content and
  signed media URLs never come from a realtime payload. The bell screen, DM nudge, `dm-online` presence and
  `dm-typing:<id>` broadcast channels go through the lifecycle-aware hub in `lib/core/realtime/` (counter signals,
  backoff, channels dropped on pause); the app-bar unread BADGES (`unread_counts.dart`) still use supabase's own
  `.stream` and do not refetch on resume (deferred). Sends and forwards carry one `Idempotency-Key` per compose action, reused by every retry;
  per-thread operations run through `ThreadActionQueue`. **Photos are sanitized client-side** (`sanitizeJpeg`: long edge
  <= 1600 px, JPEG, EXIF/GPS stripped) because `image_picker`'s native resize copies the original EXIF back, GPS included;
  the same fix is still owed to community/evidence uploads (see the handoff). `permission_handler` is rejected (it breaks
  the Android build on AGP 8.11.1); microphone permission goes through `record`. A decline must look identical to a
  block to the sender - never add "declined" copy. There is no Android App Link for `/messages`: DM links reach the app
  through push `data.threadId`. Presence is mounted app-wide from `main.dart`.
- **Guide, coach marks and support chat (Phase 5c).** Quests come from `/api/mobile/v1/guide/*` (`ApiClient.getGuideQuests` /
  `postGuideBadge`), keyed on `viewerIdProvider` so a token refresh never refetches. The chat is NDJSON streaming through
  `ApiClient.postChatMessage` over a `ChatRepository` seam; model output is untrusted and is only ever shown as plain
  selectable text (`cleanChatText` strips control and bidi characters), never parsed, linked or executed, and the only way
  it influences navigation is a validated destination enum through `destinationRoute` (chips for screens that do not exist
  yet are hidden). A turn interrupted by backgrounding or a dropped connection shows Retry and reuses the same
  `clientTurnId`. Signed-out chat sends no bearer and an anonymous `X-Device-Id` (`chatDeviceIdProvider`), and persists
  nothing. Coach marks are local-only (`LocalKv`, per-viewer `coach.<viewer or guest>.<tour>` seen flags; a tour never starts
  unless a target is on screen). Avatars are re-encoded on the device (`sanitizeAvatar`: 400 px square JPEG, EXIF/GPS removed)
  before upload; community and evidence uploads still publish GPS EXIF (open item). The five Phase 5c operations live in
  `ApiClient.pendingContractOperations` until `api/openapi.json` is re-copied from the web repo - then fold them into
  `usedOperations` so the drift check covers them.
- **Settings and account (Phase 6e).** Every account write goes through `AccountRepository` over `/api/mobile/v1/me/*`
  (`getMyAccount`, deletion x3, phone code/confirm, `postMyEmail`, `deleteGoogleIdentity`, `putMyLocale`); never call
  `supabase.auth.updateUser` / `unlinkIdentity` (they skip the password re-auth, ban blocklist and deletion guards). The
  only direct Supabase auth call is `linkIdentity` (`google_linker.dart`), returning through
  `ng.com.sentinelxesports.app://link-callback` (Android intent filter); that URL must be allowlisted in Supabase and
  Manual Linking enabled, else the link reports `linking_unavailable`. `pcm` (Pidgin) is fully translated as of 2026-10-11
  (the mobile-authored `ntf*`, `cmp*`, `dm*`, ... strings were machine-drafted, not native-reviewed: have a Pidgin speaker
  review them; new keys still fall back to English until added to `app_pcm.arb`). Material/Widgets/
  Cupertino ship no `pcm`, so `appLocalizationsDelegates` (`lib/core/l10n/fallback_delegates.dart`) load English for them,
  and **every `DateFormat` locale must go through `dateLocale()`** (`lib/core/utils/date_locale.dart`) or Pidgin users crash.
  `localeProvider` is seeded from `/me.locale`, cached in `LocalKv` (`app.locale`), and a stale `/me` never overrides a
  choice made this session. The pending-deletion banner (`DeletionBannerHost`) keeps its child at a fixed tree position
  (Column + Expanded) so the Navigator is never re-parented: do not change that shape. Delete-now always ends on `/login`,
  even when the server has already deleted the auth user and `signOut` fails. `tool/gen_l10n_from_web.dart` now writes
  `@key` placeholder metadata for keys that lack it; pass `--source=C:/Users/gorok/Videos/sentinelx/messages` (the web repo
  is not a sibling directory).
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
