# Mobile Phase 6a Wallet — Screens Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the player Wallet in the app: overview, transactions, Paystack deposit with confirmation polling, payout account, withdrawal request and status.

**Architecture:** A `WalletRepository` over `ApiClient` (the ten `/wallet/**` operations) behind Riverpod providers beside the screens; money writes go through the existing `writeFlowProvider` (one `Idempotency-Key` per compose action, fresh key when the amount changes); deposit reuses `PaystackCheckoutScreen` and then polls `GET /wallet/deposits/{reference}`. No money logic, fee maths or PostgREST access on the device.

**Tech Stack:** Flutter, Dart, Riverpod (manual providers), go_router, `webview_flutter` (existing), ARB l10n.

**Spec:** web `docs/superpowers/specs/2026-10-11-mobile-phase6a-wallet-design.md`. **Starts only after** the web plan (`2026-10-11-mobile-phase6a-wallet-web.md`) is merged and the production migration is applied, because `api/openapi.json` is copied from the merged web contract.

## Global Constraints

- Balance, ledger, fee and totals come only from the API; never read `wallets`/`wallet_transactions` through Supabase, never write via PostgREST, never port `computePaystackFee`.
- Money copy comes from ARB (`app_en.arb`, `app_fr.arb`, `app_pcm.arb`); run `flutter gen-l10n` and commit the generated output; add the keys to the web `messages/en.json` only if a web namespace exists (none does for wallet; mobile-authored keys go straight to the ARB files like 6d).
- Every `DateFormat` locale goes through `dateLocale()` (`lib/core/utils/date_locale.dart`); naira is formatted with one shared helper, never string-concatenated per screen.
- Screens are `ConsumerWidget`s reading providers; none constructs a repository or `ApiClient`.
- The Wallet is a player route: hidden from moderators (`roleProvider != AppRole.moderator`), as the Referrals entry already is.
- The full saved account number never exists on the device after saving; the only place it is held is the text field while the player types it, cleared on save and on dispose.
- No production writes in development or tests; device payment passes run on **staging** only (D3 must be resolved first).
- `flutter analyze` and `flutter test` clean before every commit; restore generated desktop plugin registrants if Flutter rewrites them.
- Layout verified at 320 and 375 px in `en`, `fr`, `pcm`.

## Review Focus

- A double tap on "Add money" or "Withdraw" sends one request (one key, `busy` guard). Task 4 and 6.
- A changed amount after a failed attempt mints a new key (fingerprint = amount). Task 4 and 6.
- The WebView closed before payment leaves the deposit pending and says it may still arrive; no balance is shown as updated until the poll returns `confirmed`/`already_paid`. Task 4.
- A poll that keeps returning `not_successful` stops after the backoff budget with a manual "Check again", never spins forever. Task 4.
- Withdraw is blocked with a clear next step when there is no payout account, a request is already pending, or the amount exceeds the balance (server still decides). Task 6.
- No screen text, log, or error report ever contains a full account number. Task 5.
- Signed-out and moderator users never reach any wallet screen. Task 7.

---

## File Structure

| Path | Responsibility |
|---|---|
| `api/openapi.json` | Copied byte-for-byte from the merged web contract |
| `lib/core/api/wallet_models.dart` | Response models |
| `lib/core/api/api_client.dart` (modify) | Ten methods; add ids to `usedOperations` |
| `lib/features/wallet/wallet_repository.dart` | `WalletRepository` + `ApiWalletRepository` |
| `lib/features/wallet/wallet_providers.dart` | Overview, transactions, banks, withdrawals providers; deposit controller |
| `lib/features/wallet/money_format.dart` | `formatNaira(int)` |
| `lib/features/wallet/wallet_screen.dart` | Overview |
| `lib/features/wallet/transactions_screen.dart` | Filtered, cursor-paged ledger |
| `lib/features/wallet/deposit_screen.dart` | Amount, checkout, confirming |
| `lib/features/wallet/payout_account_screen.dart` | Bank picker, resolve, save, remove |
| `lib/features/wallet/withdraw_screen.dart` | Request + status timeline |
| `lib/router/app_router.dart`, `lib/core/routing/web_links.dart` (modify) | Routes and web-link mapping |

---

### Task 1: Contract, models, client

**Files:** `api/openapi.json`, `lib/core/api/wallet_models.dart`, `lib/core/api/api_client.dart`, `test/core/api/wallet_models_test.dart`, `test/core/api/api_contract_test.dart` (existing drift check)

**Interfaces — Produces:**

```dart
class WalletOverview { final int balance; final int pendingWithdrawal; final WalletEarnings earnings;
  final List<WalletTxn> recentTransactions; final PayoutAccount? payoutAccount; final bool kycVerified;
  final ActiveWithdrawal? activeWithdrawal; factory WalletOverview.fromJson(Map<String, dynamic> j); }
class WalletEarnings { final int tournamentPrize, referral, bonus; final int? tournamentPrizeTrendPct; }
class WalletTxn { final String id, type; final String? category; final int amount; final DateTime createdAt; final String status; } // status: completed|pending|failed
class PayoutAccount { final String bankName, accountName, accountNumberMasked; }
class ActiveWithdrawal { final String id; final int amount; final DateTime requestedAt; }
class WalletTxnPage { final List<WalletTxn> items; final String? nextCursor; }
class WalletBank { final String name, code; }
class DepositStart { final String reference, authorizationUrl; final int amount, fee, total; }
enum DepositStatus { confirmed, alreadyPaid, notSuccessful, notFound }
class DepositPoll { final DepositStatus status; final int? balance; }
class Withdrawal { final String id; final int amount; final String status; /* pending|paid|rejected */ final DateTime requestedAt; final DateTime? resolvedAt; final PayoutAccount payoutAccount; }
class WithdrawalPage { final List<Withdrawal> items; final String? nextCursor; }
```

and on `ApiClient`:

```dart
Future<WalletOverview> getMyWallet();
Future<WalletTxnPage> listMyWalletTransactions({String filter = 'all', String? cursor});
Future<List<WalletBank>> listWalletBanks();
Future<String> resolvePayoutAccount({required String bankCode, required String accountNumber}); // account name
Future<PayoutAccount> setPayoutAccount({required String bankCode, required String accountNumber});
Future<void> removePayoutAccount();
Future<DepositStart> startWalletDeposit(int amount, {required String idempotencyKey});
Future<DepositPoll> getWalletDeposit(String reference);
Future<Withdrawal> requestWithdrawal(int amount, {required String idempotencyKey});
Future<WithdrawalPage> listMyWithdrawals({String? cursor});
```

- [ ] **Step 1:** Copy web `openapi/mobile-v1.json` to `api/openapi.json` untouched. Add the ten operation ids to `ApiClient.usedOperations` (`'getMyWallet': 'get /api/mobile/v1/wallet'`, … exact paths from the contract). Run `flutter test test/core/api` and see the drift check fail until the methods exist.
- [ ] **Step 2: Write the failing model test** (`wallet_models_test.dart`): parse a full overview JSON (with a null `payoutAccount`, a null `tournamentPrizeTrendPct`, a `pending` transaction), a transactions page with `nextCursor: null`, each `DepositPoll` status string (`'already_paid'` -> `DepositStatus.alreadyPaid`), and a `Withdrawal` with `resolvedAt: null`. Assert an unknown deposit status string throws `FormatException` (so a contract change fails loudly, not silently).
- [ ] **Step 3:** Implement `wallet_models.dart` and the `ApiClient` methods in the existing `_send` style (`startWalletDeposit` and `requestWithdrawal` pass `headers: {'Idempotency-Key': idempotencyKey}` and `body: {'amount': amount}`; `listMyWalletTransactions` builds `?filter=&cursor=` with `Uri` query encoding). Run tests green.
- [ ] **Step 4: Commit** `feat(wallet): API client and models for /wallet`.

---

### Task 2: Repository, providers, money format

**Files:** `lib/features/wallet/{wallet_repository,wallet_providers,money_format}.dart`, `test/features/wallet/{wallet_providers_test,money_format_test}.dart`

**Interfaces — Produces:**

```dart
abstract class WalletRepository { /* the ten methods above, same names and types */ }
final walletRepositoryProvider = Provider<WalletRepository>((ref) => ApiWalletRepository(ref.watch(apiClientProvider)));
final walletOverviewProvider = FutureProvider.autoDispose<WalletOverview?>((ref) async { /* viewerIdProvider null -> null */ });
final walletBanksProvider = FutureProvider.autoDispose<List<WalletBank>>(...);
final walletTransactionsProvider = AsyncNotifierProvider.autoDispose.family<WalletTransactionsNotifier, WalletTxnPage, String /*filter*/>(...); // loadMore() appends, de-duplicating by id
final myWithdrawalsProvider = FutureProvider.autoDispose<WithdrawalPage?>(...);
String formatNaira(int amount, {String locale}); // '₦12,500'
```

- [ ] **Step 1: Failing tests.** `money_format_test`: `formatNaira(0) == '₦0'`, `1250000 == '₦1,250,000'`, negative `-3000 == '−₦3,000'` (true minus sign), identical output for `en`, `fr`, `pcm` (grouping is `,`; use `NumberFormat` with the `en` pattern for all three because `dateLocale()`-style fallbacks exist only for dates; document why). `wallet_providers_test` with a fake repository: signed-out viewer -> overview `null` without calling the repository; transactions `loadMore()` appends page 2 and drops a duplicated id; a failed `loadMore` keeps existing items and surfaces the error without clearing them; changing the filter family key does not reuse another filter's list.
- [ ] **Step 2:** Run red, implement, run green.
- [ ] **Step 3: Commit** `feat(wallet): repository, providers and naira format`.

---

### Task 3: Overview screen + ARB copy

**Files:** `lib/features/wallet/wallet_screen.dart`, `lib/core/l10n/app_{en,fr,pcm}.arb`, `test/features/wallet/wallet_screen_test.dart`

- [ ] **Step 1: Add copy** with the keys the screens in Tasks 3 to 6 need, prefix `wallet`: title, balance, pending withdrawal, add money, withdraw, transactions, see all, earnings (prize, referral, bonus, trend with `{pct}`), no transactions yet, payout account, none yet, verified, loading failed, retry, manual-payout notice ("Withdrawals are paid out by an administrator, not instantly."), deposit (amount, min `{min}`, fee, total, continue, confirming, check again, may still arrive, success, failed), payout (bank, account number, resolve, confirm name, save, remove, remove confirm, errors: `accountUnresolvable`, `unknownBank`, `alreadyVerified`, `payoutUnavailable`), withdraw (amount, available, request, pending exists, kyc required, insufficient, submitted, timeline `pending`/`paid`/`rejected`), errors: `rateLimited` with `{seconds}`, `pendingDeletion`, `emailRequired`, `paymentUnavailable`, `generic`, `network`. Write `en` first, then `fr` and `pcm` in the existing register (`pcm` uses "abeg", "don", "dey", "no fit"). Run `flutter gen-l10n`.
- [ ] **Step 2: Failing widget tests:** loading shows a progress indicator; error shows retry that refetches; balance and pending render through `formatNaira`; null `tournamentPrizeTrendPct` hides the trend (no `0%`); empty transactions show the empty state; payout account shows `accountNumberMasked` and never any 10-digit string (assert `find.textContaining(RegExp(r'\d{10}'))` is empty); "Withdraw" is disabled with the kyc hint when `payoutAccount == null`; at 320 px width with `fr` and `pcm` there is no overflow (`tester.takeException() == null`).
- [ ] **Step 3:** Implement `WalletScreen` (balance hero, quick actions, earnings, recent 5, payout summary, manual-payout notice). Use only existing theme colors. Run green. **Commit** `feat(wallet): overview screen and copy`.

---

### Task 4: Deposit flow

**Files:** `lib/features/wallet/{deposit_screen,deposit_controller}.dart` (controller may live in `wallet_providers.dart`), `test/features/wallet/deposit_flow_test.dart`

**Interfaces — Consumes:** `paystackLauncherProvider` (`Future<bool> Function(String authorizationUrl)`), `writeFlowProvider('wallet-deposit')`, `getWalletDeposit`.

- [ ] **Step 1: Failing tests** with fakes for the repository and `paystackLauncherProvider`:
  - Entering `99` shows the min-amount validation and makes no call; `150.5` and empty are rejected by the numeric formatter.
  - Tap Continue twice quickly -> `startWalletDeposit` called once; the same key is reused on a network retry; after a failure and a **changed amount** a different key is used (fingerprint = amount).
  - Launcher returns `true`: the screen shows "confirming", polls `getWalletDeposit(reference)` with backoff (1 s, 2 s, 4 s, 8 s, then stops; use `fakeAsync`), shows success and invalidates `walletOverviewProvider` on `confirmed`/`already_paid`.
  - Poll keeps returning `not_successful`: after the budget, shows the "may still arrive" copy with a **Check again** button that polls once more; no infinite timer remains (`tester.pumpAndSettle` completes).
  - Launcher returns `false` (WebView closed): no polling storm; shows the pending note and a Check again button; the overview is not invalidated.
  - `429 rate_limited` shows the `{seconds}` copy; `account_pending_deletion`, `email_required`, `payment_unavailable` show their strings; no raw server message is displayed.
- [ ] **Step 2:** Run red; implement `DepositScreen` (amount field, server-returned fee/total shown only after start returns, never computed locally) and the polling controller (cancel on dispose); run green.
- [ ] **Step 3: Commit** `feat(wallet): deposit via Paystack with confirmation polling`.

---

### Task 5: Payout account

**Files:** `lib/features/wallet/payout_account_screen.dart`, `test/features/wallet/payout_account_test.dart`

- [ ] **Step 1: Failing tests:** bank picker lists `walletBanksProvider` and is searchable; a 9-digit number disables Resolve; Resolve shows the returned account name for the player to confirm before Save is enabled; changing the number or bank after resolving clears the confirmed name; `account_unresolvable`, `unknown_bank`, `already_verified`, `payout_unavailable` and `rate_limited` each show their localized string; Save success invalidates the overview and the number field is cleared; the saved state shows only `bankName`, `accountName`, `accountNumberMasked`; Remove asks for confirmation then calls `removePayoutAccount`; an error report/log capture (`ErrorReporter` fake) never contains the typed account number after a failure.
- [ ] **Step 2:** Run red; implement; run green; **Commit** `feat(wallet): payout account screen`.

---

### Task 6: Withdraw + status, transactions screen

**Files:** `withdraw_screen.dart`, `transactions_screen.dart`, tests `withdraw_test.dart`, `transactions_screen_test.dart`

- [ ] **Step 1: Failing tests (withdraw):** no payout account -> request disabled and a link opens the payout screen; `activeWithdrawal != null` -> amount entry disabled with the "already pending" copy; amount above `balance` shows the insufficient message before any call; double tap sends once; changed amount after failure -> new key; server `insufficient_balance` / `withdrawal_pending` / `kyc_required` / `account_pending_deletion` map to copy; success shows the submitted state and refreshes overview and `myWithdrawalsProvider`; the timeline renders `pending`/`paid`/`rejected` with no admin note text.
- [ ] **Step 2: Failing tests (transactions):** four filter chips switch lists; scrolling to the end calls `loadMore`; a load-more failure shows an inline retry row and keeps the list; each row shows signed amount (credits green `+`, debits `−`), category label, date via `dateLocale()`, and a status chip for `pending`/`failed`; empty state per filter; pull-to-refresh refetches.
- [ ] **Step 3:** Run red; implement; run green; **Commit** `feat(wallet): withdraw, status timeline and transactions`.

---

### Task 7: Routes, entry points, web links

**Files:** `lib/router/app_router.dart`, `lib/core/routing/web_links.dart`, `lib/features/account/account_screen.dart`, `test/router/wallet_routes_test.dart`, `test/core/routing/web_links_test.dart`

- [ ] **Step 1: Failing tests:** `resolveWebLink` maps `/dashboard/wallet` -> `/account/wallet`, `/dashboard/wallet/deposit` -> `/account/wallet/deposit`, `/dashboard/wallet/withdraw` -> `/account/wallet/withdraw`, `/dashboard/wallet/transactions` -> `/account/wallet/transactions`, `/dashboard/wallet/payment-methods` -> `/account/wallet/payout-account`; the Paystack callback path `/api/paystack/callback` is **not** mapped (the WebView intercepts it). Signed-out visitors to any `/account/wallet/**` are sent to `/login` with the return path; a moderator is redirected to `/account`; the Account hub shows a Wallet row for players only.
- [ ] **Step 2:** Add the five nested routes under `/account/wallet`, the hub entry (same pattern as `onOpenReferrals`), and the mappings. Run green; **Commit** `feat(wallet): routes, hub entry and web links`.

---

### Task 8: Final gate and handoff

- [ ] **Step 1:** Cold read the diff: no `Supabase.instance` / PostgREST in `lib/features/wallet`, no `*.from(` of wallet tables, no hard-coded copy, no `double` money, no local fee maths, no raw server message shown (`grep -rn "message" lib/features/wallet` and confirm only code-keyed copy), no logging of typed numbers.
- [ ] **Step 2:** `git fetch origin master`, rebase. `flutter gen-l10n`, then serially `flutter analyze --no-pub` and `flutter test --no-pub`. Expected: no issues, all pass. Merge `--no-ff`, verify tree equality, push `master`.
- [ ] **Step 3:** Add a Phase 6a device-pass table to `TESTING-NOTES.md`, all rows **pending**, **staging only**: (1) overview loads on staging; (2) payout account: resolve + save with the Paystack sandbox bank `001`; (3) deposit ₦100 end to end with a Paystack test card and see the balance rise once; (4) close the WebView mid-payment, confirm no credit until Paystack confirms; (5) airplane mode on Continue then retry -> one `wallet_deposits` row; (6) withdraw -> one `withdrawal_requests` row and one ledger debit, second request refused; (7) admin marks it paid on the web admin and the timeline updates; (8) fr/pcm at 320 px. Log the slice in `docs/agent-handoffs/codex-progress.md` and update CLAUDE.md's route map with the five `/account/wallet/**` routes and a "Wallet (Phase 6a)" note.
