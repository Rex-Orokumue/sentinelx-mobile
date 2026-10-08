# Message for Codex — full takeover: finish Phase 6 and continue through the later phases until the owner's Claude limit resets

Paste everything below the line into a Codex session opened in `C:\Users\gorok\sentinelx_mobile`.

---

You are taking over a two-repo project from a Claude session. The owner (Rex-Orokumue) has authorised you to **finish Phase 6
and keep going through the later phases, in order, without checking in**, until their Claude usage limit resets and they hand
the work back. Make your own calls, record each one, and keep moving. The only reasons to stop are in "When to stop" below.

## Where things stand (2026-10-08)

- **Mobile repo** `C:\Users\gorok\sentinelx_mobile` (Flutter, Riverpod 3, go_router, Dio): `master` = `91b8057` plus one local docs commit.
  Tests 1526/1526, `flutter analyze` clean. Remote: `Rex-Orokumue/sentinelx-mobile`.
- **Web repo** `C:\Users\gorok\Videos\sentinelx` (Next.js, Supabase, vitest): `main` = `0ff7a4a`, tests 2986/2986, `tsc` and `next lint` clean.
  Remote: `Rex-Orokumue/sentinelx`. **Pushing web `main` deploys to production on Vercel.**
- The mobile app is a client of the web repo's `/api/mobile/v1/*`. Rule of the project: **the web leads, mobile follows** —
  endpoints and their OpenAPI contract land in the web repo first; the mobile repo re-pins `api/openapi.json` from
  `C:\Users\gorok\Videos\sentinelx\openapi\mobile-v1.json`.
- **Phases done:** 0-5 and **6e** (Settings: language en/fr/pcm, security, sign-in methods, phone verification + `/onboarding/phone` gate,
  account deletion + banner). Phase 5 device passes and the 6e device pass are *pending by the owner's choice*: never claim them complete.
- **Phase 6 order the owner agreed:** 6e (done) → **6d Referrals → 6a Wallet → 6b Coins/store/XP → 6c Friends and friendlies**.
  Then Phase 7 (Watch & Trade), 8a/8b (Admin), 9 (Android release hardening), 10 (iOS), as in the master spec's §13.
- Owner preferences: **build every feature fully for its specific purpose — no "v1/MVP" framing, no one-size-fits-all**; finished
  branches get **merged and pushed right away**, not left sitting locally.

## Read first (all of it, before writing code)

1. `CLAUDE.md` and `AGENTS.md` in **both** repos. They bind you.
2. The master design: `docs/superpowers/specs/2026-09-18-flutter-mobile-app-master-design.md` (esp. §2.5 security findings, §3 access tiers,
   §7 endpoints, §8.12-8.16 for Phase 6, §13 phases, §14 store policy, §17 open questions).
3. The Phase 6e spec and both plans (they are the template for how a phase is specified and planned):
   web `docs\superpowers\specs\2026-10-07-mobile-phase6e-settings-account-design.md`, web `plans\2026-10-07-mobile-phase6e-settings-account-web.md`,
   mobile `docs/superpowers/plans/2026-10-07-mobile-phase6e-settings-account-screens.md`.
4. The "Settings and account (Phase 6e)" paragraph in this repo's `CLAUDE.md` for decisions that are not obvious from the code.
5. `TESTING-NOTES.md` (conventions for `zzqa_` accounts and the device-pass tables).

## Hard rules (these survive the takeover; do not break them to go faster)

1. **Production data is off limits for writes and tests.** Production is Supabase `itxubrkbropttfdackmi`. A **staging** project exists:
   `https://ofxmoxpvwbemfouaowoa.supabase.co`. All write-path work, migrations-in-progress, Paystack flows and anything that creates, changes or
   deletes data runs against **staging with Paystack TEST keys**. To run the web against staging: in the web repo run
   `node node_modules\next\dist\bin\next dev`; `.env.development.local` there (git-ignored, on disk) overrides `.env.local` (production) with the staging
   URL/keys and Paystack test keys. **Vercel preview deployments use production env vars, so never test against a preview URL.**
   Unit/widget tests with fakes are always fine. Test accounts use the `zzqa_` prefix and are logged in `TESTING-NOTES.md`.
2. **Migrations:** write them, apply them to **staging** yourself, test. **Do not apply any migration to production.** A web branch whose code needs a
   migration that is not yet on production must **not** be merged to `main` (it would deploy code that 500s). Push the branch, record it under
   "Waiting on the owner" in the progress log, and move on to work that does not depend on it.
3. **Money paths reuse the web's existing services exactly.** Wallet, deposits, withdrawals, KYC, escrow, staked friendlies and coin spending already exist and are
   correct on the web. Extract their logic into shared services (as 6e did) and have both the web action and the mobile endpoint call them; never re-implement
   money logic. Every money-moving endpoint takes an `Idempotency-Key` (`defineEndpoint({ idempotent: true })` exists), is covered by tests including a retry, and
   a decline must never leak (see the DM rule in `CLAUDE.md`).
4. **No ₦→coin purchase path in the app.** Master spec §14/§17-Q5: if the web has any way to turn money into coins, **do not expose it in the app**; write what
   you found into the progress log. Coins are earned-only and cosmetic-only on mobile (Play Billing / Apple IAP would otherwise apply).
5. **Never set `enforce_phone_verification=true`.** The owner flips it, after a released build contains `/onboarding/phone` and WhatsApp (`META_WHATSAPP_*`) is live in prod.
6. **Do not publish anything**: no Play Console / App Store Connect / TestFlight uploads, no store listings, no developer-account creation, no DNS or Vercel
   settings, no GitHub repo settings. Phases 9/10 are *code-side only*.
7. Never write via PostgREST from the app (`CLAUDE.md`). Copy is never hard-coded: add to the web `messages/en|fr|pcm.json` first, then regenerate.
8. Do not edit `AGENTS.md`/`CLAUDE.md` *rules*, permission settings, CI config, or secrets files. (You *should* append the new-phase notes and route-map rows to
   `CLAUDE.md`, as every phase does.) Never weaken or delete a test to make something pass. Never `git push --force`, never rewrite pushed history.
9. Do not add attribution trailers that claim Claude wrote your commits; sign your own.

## Merging and pushing

The owner's standing preference is to merge and push finished work immediately, and with the takeover that is **authorised** — under these conditions:
- Work on a branch per slice (`phase6d/...`, `fix/6e-...`), TDD, and merge to `main`/`master` only when **all** of this is true: the repo's full test suite passes,
  `flutter analyze` (mobile) or `tsc` + `next lint` (web) is clean, you have done a separate review pass over the whole diff against the spec (read it cold, check the plan's
  Review Focus items, and fix what you find, test first), and — for web — the merge does not depend on an unapplied production migration (rule 2).
- Merge web **before** the mobile change that needs it, and re-pin `api/openapi.json` from the merged web contract. Merge with `--no-ff`, verify the merged tree equals
  the tested tree (`git rev-parse HEAD^{tree}`), then push. If a push is rejected, investigate; never force.
- If a change alters the behaviour of an *existing* web action or endpoint, it needs a characterisation test written first and a note in the progress log.

## Process for every phase (this is what the project does; follow it)

1. **Spec** in the web repo (`docs\superpowers\specs\<date>-mobile-phase<N>-<name>-design.md`) when the phase needs endpoints: ground-truth table read from the *actual web code*
   (cite files), the endpoint list with error codes, the mobile structure (routes, providers, screens), rulings with "cost if wrong", what cannot be verified, and the open
   product questions you decided (see "Decisions"). Commit it.
2. **Plans**: one for the web side, one for the mobile side (`docs/superpowers/plans/`), bite-sized TDD tasks with real code, exact commands and Expected lines.
3. **Implement** with tests first: write the test, run it and watch it fail for the right reason, write the minimum code, run it green, commit. One logical commit per task.
4. **Verify** the whole repo (commands below), do the cold review pass, fix, re-verify.
5. **Land** (merge + push as above), update `CLAUDE.md` (route map rows, a short "what is not obvious" paragraph), add a **device-pass table with every item `pending`** to
   `TESTING-NOTES.md` (you cannot run a phone), and update the progress log.

## Decisions: you make them, and you write them down

When the spec or master spec leaves a product or design question open, **decide it yourself**: prefer whatever the web does today; otherwise the safer and more
reversible option. Record every decision as `Ruling: <what> — <why> — <cost if wrong>` in the phase spec/plan and in the progress log, then continue. Do not ask the
owner and do not stall. The questions you may **not** decide yourself are in "When to stop".

## Environment quirks on this machine (they cost the previous session time)

- Windows. Use your editor/patch tools or explicit `utf-8`; Python text-mode edits have corrupted UTF-8 and CRLF here before.
- **Web:** `.bin` shims are missing, so `npm test` / `npx vitest` / `npm run lint` fail. Use `node node_modules/vitest/vitest.mjs run <paths>`,
  `node node_modules/typescript/bin/tsc --noEmit`, `node node_modules/next/dist/bin/next lint`. Full vitest ≈ 2 min. `npm run openapi` ≈
  `node node_modules/vitest/vitest.mjs run lib/mobile-api/openapi.test.ts -u` (then check the diff only adds what you expect).
- **Mobile:** slow and short on memory. Scope `flutter analyze` while iterating (e.g. `flutter analyze lib/features/x test/features/x`); run the whole thing once at the end
  (1-6 min). The **full** `flutter test` ≈ 6.5 min: run it once, in a single command, output redirected to a file, and read the tail. A single test file ≈ 5 s once compiled.
  Never run two `flutter` commands at once. A command that exceeds ~10 minutes in the foreground gets moved to the background; plan around that.
- `flutter pub get` / `flutter test` regenerate `linux/`, `macos/`, `windows/` plugin-registrant files: `git checkout -- linux windows macos` before committing.
- l10n: `dart run tool/gen_l10n_from_web.dart --source=C:/Users/gorok/Videos/sentinelx/messages --namespaces=<ns> --locales=en,fr[,pcm]` then `flutter gen-l10n`.
  It writes `@key` placeholder metadata for new keys. Insert new copy into the web `messages/*.json` **textually** (a `JSON.stringify` round-trip is not byte-identical).
  Web `lib/i18n/message-parity.test.ts` needs identical key sets in en/fr/pcm. Reuse existing web namespaces where the copy already exists (the 6e work reused
  `accountDeletion`, `emailChange`, `signInMethods`).
- **Pidgin (`pcm`):** Flutter's Material/Cupertino ship no `pcm`; `appLocalizationsDelegates` already falls back to English, and **every `DateFormat` locale must go through
  `dateLocale()`** (add a `numberLocale()` sibling when you format numbers). New screens must be checked at 320-375 px in en, fr and pcm.
- Sessions: `sessionProvider` deliberately drops auth-stream error events; do not undo that.
- Git CRLF warnings ("LF will be replaced by CRLF") are harmless. Untracked scratch dirs like `.superpowers/` are not yours to commit.
- Android application id is `ng.com.sentinelxesports.app`. The Google-link redirect scheme is `ng.com.sentinelxesports.app://link-callback`.

## The work, in order

### Step 0 — the 6e leftovers (small, do these first; one branch + commit each, test first)

Deferred minors from the Phase 6e reviews:

**Mobile**
1. `LocaleNotifier.select` skips the server save while `meProvider` is mid-refetch (`lib/features/account/settings/locale_providers.dart`, `asData` is null during a refresh).
   Decide "signed out" from the session/viewer or `.value`; test: invalidate `meProvider`, pick a language mid-refetch, assert `setLocale` was called.
2. Phone resend flicker (`phone_verify_form.dart` `_resendFromCodeStep` flips `_codeSent=false`): keep the code step visible and the number field disabled while resending; add a
   test that taps `phone-resend` (none exists).
3. Deletion banner (`deletion_banner_host.dart`) uses a plain `Row`: make long fr/pcm labels unable to overflow at 320 px; add 320 px **fr and pcm** widget tests for Language,
   Security, Sign-in methods, Phone, Delete account and the banner; fix whatever they reveal.
4. `sign_in_methods_screen.dart` matches `e.toString().contains('manual_linking_disabled')`: use a typed supabase `AuthException` code check (the app also defines its own
   `AuthException`; `hide` one).
5. `google_linker.dart` ignores `linkIdentity`'s bool result: show the existing link-failed copy when no handler could open the browser. Test with the fake.
6. `delete_account_screen.dart` `_formatAmount` uses the `en` number pattern in every locale: add `numberLocale()` next to `dateLocale()` and use it.

**Web**
7. `performCancelDeletion` (`lib/settings/deletion-flow.ts`) emails "deletion cancelled" even when nothing was pending: only email when the update actually matched a row that had
   `deletion_requested_at` set. Tests: nothing pending ⇒ `{ ok: true }`, no email; pending ⇒ email.
8. A failed OTP send still consumes one of the 10 daily slots (`lib/phone/service.ts`, `lib/rate-limit/account-limiter.ts`): refund the slot on a real send failure (not on the web's
   `skipped` path). Test it.
9. `POST /me/deletion/execute` has no re-auth limit: apply the existing `reauthGate` pattern (`lib/mobile-api/endpoints/account.ts`) to `deleteNow`, with a test.

### Step 1 — Phase 6d: Referrals (master §8.16), then 6a, 6b, 6c

Do them in this order: **6d → 6a → 6b → 6c**, each through the full process above, each merged before the next starts.

- **6d Referrals:** `/dashboard/referrals` parity. Share link/code, invited list with status, milestone tracker (+250 coins on the referred player's first *paid* entry; bonuses at
  5/10/25/50 conversions), install-referrer capture of `ref` (signup already accepts `initialRef`/`ref`). Read the web's referral code (`app/[locale]/dashboard/referrals`,
  `lib/referrals/*`, `lib/auth/signup-service.ts`) for ground truth.
- **6a Wallet (§8.12):** wallet balance and earnings breakdown, transactions (filter/paginate), deposit through the **Paystack WebView** (the app already has a Paystack launcher from
  Phase 2: `lib/features/compete/paystack_checkout.dart`, `paystackLauncherProvider`, and `GET /payments/{reference}` polling), payout accounts / payment methods (Paystack account-name
  resolve, save/remove), KYC = payout-account verification only (BVN disabled; minors get no BVN prompt), withdrawal request → status timeline ("paid out manually by admin" copy).
  Moderators must never see the wallet screen. Staging + Paystack **test** keys only.
- **6b Coins, XP, SX Score, achievements (§8.13) and Store (§8.14):** the coin ledger already displays (Phase 3); add the earn/spend surfaces, XP/tier history, SX Score history,
  achievements catalogue (locked-state redaction, share-to-feed toggle), daily login, and the **Store** (~23 cosmetics: avatar borders, themes, username colours, bubble skins;
  import the WebP art from the web `public/coin-items/` into assets; preview, coin price, purchase, equip/unequip, "owned"; equipped items show app-wide, §4.5). Honour rule 4.
- **6c Friends and friendlies (§8.15):** friend list/requests, challenge (free, or staked in ₦ **or** coins — one currency per challenge), Match Room (accept → pay stake: Paystack escrow
  for ₦, instant for coins → play → both submit results → admin confirms/disputes), history. Coin stakes settle instantly. Reuse the web's friendly-match services; money rules as above.

When a phase needs an admin action that the app does not have yet (e.g. confirming a friendly result), the admin lands in Phase 8; the player-side flow must still be complete and
correct, and you note the dependency in the progress log.

### Step 2 — Phase 7 (Watch & Trade), 8a/8b (Admin), 9 and 10 (code-side only)

Same process, in this order, from master §8.17-8.18, §8.24, §13, §14:
- **7 Watch (`/tv`) & Trade (Exchange):** TV tabs Live/Highlights/Finals/Replays from `tv_videos` with a YouTube player; Exchange catalogue/listing/escrow/orders/buy requests (Zolarux
  escrow init). Trade carries the highest store-policy risk (§14): build it behind a remote-config feature flag that defaults **off** so it can be hidden on a store without a release.
- **8a Admin queues & moderation, 8b tournament builders:** role-aware (moderators vs admins; moderators are blocked from money/bans/wallet; verify with a permission-matrix test).
  Re-check every admin call server-side; the app's role display is not authorisation.
- **9 Release hardening (Android), code-side only:** performance, accessibility (TalkBack, text scale, contrast), size, error reporting, data-safety-form *inputs* written as a doc,
  monitoring hooks, a crash-free checklist. No store submission.
- **10 iOS, code-side only:** only what can be done on Windows (Universal Links `apple-app-site-association` on the web side, URL scheme, usage strings, APNs-via-FCM wiring notes).
  If it needs a Mac, write down exactly what remains and skip it.

## Progress log (the owner and Claude will read this when they are back)

Create and keep updating `docs/agent-handoffs/codex-progress.md` in this repo (commit it, push with your merges). Append, in order, after every landed slice:
`date · phase/slice · branch → merge SHAs (web, mobile) · test counts (web vitest, mobile flutter) · rulings made · open items`. Keep three standing sections at the top:
**Waiting on the owner** (branches pushed but not merged because of an unapplied production migration; anything needing a console or account), **Rulings** (every one),
and **Not verified** (everything that needs a real device or a real production service).

## When to stop (and only then)

Stop and leave a clear note at the top of the progress log if you hit:
- something that would **change or delete production data**, or need production credentials you were not given;
- a **security-sensitive** decision (auth, payments authorisation, KYC data handling, anything that widens what `profiles`/PII exposes — master §2.5 findings S1-S3 still apply);
- an action **outside the two repos** that is hard to undo (publishing, store consoles, DNS, billing, a repo setting);
- a plan so broken that every path forward is a guess (re-read the spec first; most "ambiguities" are rulings you can make).
Otherwise decide, write it down, and continue. If the machine runs out of memory, finish the current commit, then stop and say so in the log.

## Codex results

(Codex: do not write here; use `docs/agent-handoffs/codex-progress.md`. This file is the brief.)
