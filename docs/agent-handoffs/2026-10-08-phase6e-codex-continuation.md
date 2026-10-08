# Message for Codex — continue after Phase 6e (settings and account) while the owner's Claude limit resets

Paste everything below the line into a Codex session opened in `C:\Users\gorok\sentinelx_mobile`.

---

You are continuing a two-repo project. Phase 6e (Settings and account completion) was just built, reviewed,
merged and pushed by a Claude session. Your job is the safe, well-specified follow-up work below, **not**
anything that needs the owner's decision or touches a shared environment.

## Where things stand (2026-10-08)

- **Mobile repo** `C:\Users\gorok\sentinelx_mobile` (Flutter): `master` = `91b8057`. Tests 1526/1526, `flutter analyze` clean.
- **Web repo** `C:\Users\gorok\Videos\sentinelx` (Next.js, deployed on Vercel from `main`): `main` = `0ff7a4a`.
  Tests 2986/2986, `tsc` and `next lint` clean. Pushing to web `main` deploys to production.
- Same backend for both: Supabase project `itxubrkbropttfdackmi`, which is **production** (no staging unless the
  owner names one). The mobile app talks to the web repo's `/api/mobile/v1/*`.
- Phase 6 order the owner agreed: **6e Settings (done) → 6d Referrals → 6a Wallet → 6b Coins/store/XP → 6c Friends and friendlies.**
- What 6e built: language (en/fr/pcm), security (change email, reset link), sign-in methods (link/unlink Google),
  phone verification + `/onboarding/phone` gate, account deletion + app-wide banner. Read the design:
  `C:\Users\gorok\Videos\sentinelx\docs\superpowers\specs\2026-10-07-mobile-phase6e-settings-account-design.md`,
  and the two plans (`...-web.md` in the web repo, `...-screens.md` under this repo's `docs/superpowers/plans/`).

## Read first

1. `CLAUDE.md` and `AGENTS.md` in **both** repos. They bind you: production-database caution, "never write via
   PostgREST", copy comes from the web `messages/*.json` through `tool/gen_l10n_from_web.dart` and never hard-coded,
   `flutter analyze` and `flutter test` clean before every commit.
2. The "Settings and account (Phase 6e)" paragraph in this repo's `CLAUDE.md`: it records decisions that are not obvious
   from the code (e.g. every `DateFormat` locale must go through `dateLocale()` or Pidgin users crash; the deletion banner's
   tree shape must not change; `sessionProvider` deliberately drops auth-stream error events).

## Hard rules (do not break these, even if they would make a task easier)

- **No writes to the production database or any shared service.** Do not apply migrations, do not call the Supabase
  MCP/CLI to write, do not hit write endpoints against production, do not delete or "test" real accounts. Unit/widget
  tests with fakes only. If something can only be proved against a real server, write it into `TESTING-NOTES.md` as
  pending and move on.
- **Do not push to `main` (web) or `master` (mobile).** Work on a branch per task, make it green, push the *branch*,
  and stop. The owner merges when they are back. (Web `main` auto-deploys to production, and the mobile app version
  must not ship before the web side is deployed.)
- **Never set `enforce_phone_verification=true`** anywhere. The owner flips it, only after a released build has `/onboarding/phone`.
- Do not edit `AGENTS.md`/`CLAUDE.md` rules, permission settings, or CI config. Do not weaken or delete a test to make something pass.
- The Phase 6e migration `supabase/migrations/20261007120000_account_rate_limit_events.sql` is merged but **not applied**
  to any database. Leave it that way. The limiter fails open until the owner applies it.
- Use test usernames with the `zzqa_` prefix in anything you document.

## Environment quirks on this machine (they cost the previous session time)

- Windows. Use the **Edit/Write tools or explicit `utf-8`** for file edits; Python text-mode edits have corrupted UTF-8
  and CRLF here before.
- **Web:** `.bin` shims are missing, so `npm test` / `npx vitest` fail. Run
  `node node_modules/vitest/vitest.mjs run <paths>`, `node node_modules/typescript/bin/tsc --noEmit`,
  `node node_modules/next/dist/bin/next lint`. The full vitest run takes ~2 min.
- **Mobile:** the machine is slow and short on memory. `flutter analyze` on the whole repo can take 1-6 minutes; scope it
  (`flutter analyze lib/core test/core`) while iterating and run the whole thing once at the end. The **full**
  `flutter test` takes ~6.5 minutes: run it once, in one command, with output redirected to a file, and read the tail.
  A single test file takes ~5 s once compiled. Do not run several `flutter` commands at the same time.
- `flutter pub get` / `flutter test` regenerate `linux/`, `macos/`, `windows/` plugin-registrant files. Run
  `git checkout -- linux windows macos` before committing; they are noise.
- l10n generator (web repo is **not** a sibling directory):
  `dart run tool/gen_l10n_from_web.dart --source=C:/Users/gorok/Videos/sentinelx/messages --namespaces=<ns> --locales=en,fr[,pcm]`
  then `flutter gen-l10n`. It now writes `@key` placeholder metadata for new keys. Add copy to the web `messages/en|fr|pcm.json`
  first (insert textually; do not re-serialise those JSON files, a `JSON.stringify` round-trip is not byte-identical).
  The web `lib/i18n/message-parity.test.ts` requires identical key sets in en/fr/pcm.
- Git CRLF warnings ("LF will be replaced by CRLF") are harmless.
- Process: this project is spec → plan → code with tests first (watch each new test fail before writing the code).
  Specs go in the **web** repo's `docs/superpowers/specs/` when a feature needs endpoints; plans in `docs/superpowers/plans/`.

## Task A — fix the deferred review minors (safe, do these first; one branch + commit per item, tests first)

These came out of the Phase 6e whole-branch reviews and were deliberately left unfixed. None needs an owner decision.

**Mobile repo** (branch names `fix/6e-<slug>`):
1. **`LocaleNotifier.select` skips the server save while `meProvider` is mid-refetch.**
   `lib/features/account/settings/locale_providers.dart` (`if (ref.read(meProvider).asData?.value == null) return true;`).
   `asData` is null during a refresh, so a language picked right after a verify/deletion invalidation never reaches the server
   and is lost on next launch. Decide "signed out" from the session/viewer (or `.value`, which keeps the previous value),
   with a test that invalidates `meProvider`, picks a language mid-refetch and asserts `setLocale` was called.
2. **Phone resend flicker.** `lib/features/account/settings/phone_verify_form.dart` `_resendFromCodeStep` sets `_codeSent=false`
   during the request, re-enabling the number field and hiding the code field. Keep the code step visible and the number
   field disabled while resending; add a test that taps `phone-resend` (none exists) and asserts the code field stays.
3. **Deletion banner narrow-width risk.** `lib/features/account/settings/deletion_banner_host.dart` uses a plain `Row`.
   Make the button not able to overflow with long French/Pidgin labels at 320 px, and add 320 px widget tests in **fr and pcm**
   for the new screens (Language, Security, Sign-in methods, Phone, Delete account, banner). Fix any overflow they reveal.
4. **Typed manual-linking check.** `sign_in_methods_screen.dart` matches `e.toString().contains('manual_linking_disabled')`.
   Use a typed supabase `AuthException` code check (the app also defines its own `AuthException`; `hide` one).
5. **`GoogleLinker` ignores `linkIdentity`'s bool result** (`google_linker.dart`). If no handler could open the browser, show the
   existing link-failed copy instead of silently succeeding. Test with the fake.
6. **Wallet blocker amounts use the `en` number pattern in every locale** (`delete_account_screen.dart` `_formatAmount`). Add a
   `numberLocale()` helper next to `dateLocale()` (same fallback to `en` for `pcm`) and use it.

**Web repo** (branch names `fix/6e-<slug>`; full vitest + tsc + lint before pushing the branch):
7. **`performCancelDeletion` emails "deletion cancelled" even when nothing was pending** (`lib/settings/deletion-flow.ts`). Only send
   when the update actually matched a row that had `deletion_requested_at` set (e.g. `.select('id')` on the update). Test: no
   pending request ⇒ `{ ok: true }` and no email; pending ⇒ email.
8. **A failed OTP send still uses one of the 10 daily slots** (`lib/phone/service.ts` + `lib/rate-limit/account-limiter.ts`). Refund the
   slot when `sendWhatsAppOtp` returns a real failure (not when it is `skipped` on the web path). Test it.
9. **`POST /me/deletion/execute` has no re-auth limit.** Apply the existing `reauthGate` pattern (`lib/mobile-api/endpoints/account.ts`)
   to `deleteNow`, with a test. Low risk, do last.

After each item: run the narrow tests for it, then the repo's full suite once at the end of the batch. Write what you did
and the final test counts at the bottom of this file under a heading `## Codex results`, and list anything you could not finish.

## Task B — draft the Phase 6d (Referrals) spec, and **stop there**

Master spec §8.16 (`docs/superpowers/specs/2026-09-18-flutter-mobile-app-master-design.md`): share link/code, invited list with
status, milestone tracker (+250 coins on the referred player's first *paid* entry; bonuses at 5/10/25/50 conversions),
install-referrer capture of `ref`. Read how the web does referrals (`app/[locale]/dashboard/referrals`, `lib/referrals/*`, the signup
`referral code` handling in `lib/auth/signup-service.ts`) and write the design to
`C:\Users\gorok\Videos\sentinelx\docs\superpowers\specs\<date>-mobile-phase6d-referrals-design.md` in the same shape as the 6e spec
(ground truth table from the actual code, endpoints, mobile structure, owner decisions, what cannot be verified). Flag every
open product question as a question for the owner; **do not decide them, do not write a plan, do not write product code.**
Commit the spec on a branch and push the branch.

## Do NOT start (needs the owner)

Phases 6a/6b/6c (money: wallet, withdrawals, coins/store, staked friendlies), any plan or code for 6d, applying the migration,
the staging/device pass, a Pidgin translation pass for mobile-authored strings, merging or pushing to `main`/`master`.

## When you stop

Leave the repos with no uncommitted changes, list the branches you pushed, and fill in `## Codex results` below.

## Codex results

(Codex: fill this in.)
