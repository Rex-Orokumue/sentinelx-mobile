# Mobile Phase 2a (Flutter) — Browse, Register & Pay Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship the "browse and pay" half of Compete in the Flutter app: tournament list and detail (server-driven registration CTA), registration and waitlist wizard, Paystack checkout in a WebView with payment polling, season invitations (accept/decline), a games list, and minimal profile editing — backed by the seven Phase 2a web endpoints.

**Architecture:** Same shape as Phases 1/3b. Hand-written `ApiClient` methods + plain-Dart models with `fromJson`; T1 reads (tournaments, games, own invitations, own pending reference) go straight to Supabase through one small repository with explicit columns; writes go only through `/api/mobile/v1/*`. Screens are `ConsumerWidget`s reading Riverpod providers. Registration is one `Notifier` (`RegistrationFlow`) that owns the `Idempotency-Key` policy and the payment poll. New feature folder `lib/features/compete/`; the old temporary slice (`lib/data`, `lib/models`, `lib/features/tournaments`) stays untouched until Phase 2b replaces the bracket.

**Tech Stack:** Flutter (stable), Dart ^3.11, `flutter_riverpod` ^3.3, `go_router` ^17, `dio`, `supabase_flutter`, `flutter_test`. **One new dependency: `webview_flutter`** (Paystack checkout).

**Spec:** `docs/superpowers/specs/2026-09-22-mobile-phase2a-tournaments-registration-design.md` **in the web repo** (`C:\Users\gorok\Videos\sentinelx`), §4–§7 especially. Wire shapes are defined by `lib/mobile-api/endpoints/tournaments.ts`, `invitations.ts`, `payments.ts` and `me.ts` in the web repo, branch `docs/mobile-phase1-phase2a-specs` (not yet on `main`). Master spec: `docs/superpowers/specs/2026-09-18-flutter-mobile-app-master-design.md` §6.4, §8.3, §13. Read this repo's `CLAUDE.md` first.

## Global Constraints

- **Writes only through `ApiClient`.** Never write via PostgREST/Supabase. Reads of tournaments, games, the caller's own invitations and the caller's own registration row are T1 (direct Supabase, explicit column lists, never `*`). Screens never construct a repository or `ApiClient`; they read providers.
- **Every new `ApiClient` method is listed in `ApiClient.usedOperations`**; `test/core/api_contract_test.dart` checks each against `api/openapi.json`. `api/openapi.json` is a **copy** of the web repo's `openapi/mobile-v1.json` — copy it, never hand-edit it.
- **Idempotency-Key policy (spec §4.2, §6.3, exact):** `POST /register` and `POST /invitations/{id}/accept` require the header. One key per *attempt*, reused **only** when the previous outcome was a network failure (`ApiException.code == 'network'`) or `idempotency_in_progress` (409). After **any other** error response the next submit **must mint a new key** — the server replays a stored error for the same key forever. After `needs_username` is resolved, mint a new key. Waitlist and decline take no key.
- **Money is only trusted from the server.** The app never marks a registration paid. It shows "paid" only after `GET /payments/{reference}` returns `confirmed`/`already_paid`, or after `POST /register` returns `{status:'confirmed'}`.
- **Copy is never hard-coded in widgets.** Add keys to `lib/core/l10n/app_en.arb` **and** `app_fr.arb` (`test/core/l10n_test.dart` requires identical key sets), run `flutter gen-l10n`, never edit `lib/core/l10n/gen/*`. Server `error.message` strings are English and are **not shown**; map `error.code` to ARB copy (Task 2's `errorCopy`), falling back to a generic message.
- **Coin amounts come from `remoteConfigProvider`** (`coinsHalfEntry`, `coinsPerEntry`, `nairaPerCoin`); never hard-code 500/1000/0.5.
- **Do not touch** `lib/data`, `lib/models`, `lib/features/tournaments/bracket_screen.dart` (Phase 2b replaces them). The existing `/tournaments` and `/tournaments/:id` routes are re-pointed to the new screens (Task 11); the bracket route stays.
- **Mobile-first at 375px**, no horizontal overflow (long titles, 60-char names). `SxColors` only; no new colors. American spelling.
- **Testing against production is forbidden; register/accept are writes and Paystack is live money.** Device runs (deferred to the joint test round) use the staging project + Paystack test keys only.
- **Before every commit:** `flutter analyze` (no issues) and `flutter test` (all pass). Regenerate l10n after ARB edits and commit generated output. After `flutter pub get`/`flutter test` run `git checkout -- linux macos windows` before committing (plugin registrants get rewritten).

## Review Focus

Failure modes the spec implies that are easy to ship broken, most likely first. Each has a test in the task that owns the code.

1. **Double-charge via key reuse/loss.** Re-tapping Pay after a network drop must reuse the same key; re-tapping after a server error (e.g. `tournament_full`, `payment_init_failed`) must mint a new one; two rapid taps while in flight must send one request. (Task 5)
2. **Paystack return with no confirmation.** WebView closed/cancelled, callback reached but poll returns `not_successful` for 60 s, app killed mid-payment: the UI must say "not confirmed yet", never "registered", and re-opening the tournament must show `complete_payment` → resume. (Tasks 4, 5, 8)
3. **Signed-out and no-username users.** `guest` view shows "Log in to register" (never calls `/register`); `needs_username` routes to onboarding and the resubmit uses a **new** key. (Tasks 5, 8)
4. **Full vs closed.** `full` must NOT offer the waitlist (server rejects it); only `closed` does. `invitation_only` never shows a register form. (Task 8)
5. **Odd data.** Tournament with null `rules` (no rules checkbox, `agreedToRules` sent as `true` only if shown... see Task 6), null `max_players`, free fee (₦0), 300-char description, a row whose `games` join is null; unknown `view` string from a newer server → error state, not a crash. (Tasks 1, 3, 8)

## Open items found while writing this plan (spec vs. reality — owner/web decisions)

1. **Entrants list is not buildable as T1.** Spec §6.2 lists "entrants list — T1", but `tr_select` RLS on `tournament_registrations` is `auth.uid() = player_id OR is_staff()`; the web page reads it with the service role. **This plan omits the entrants list.** Fix later = a web endpoint (`GET /tournaments/{id}/entrants`); not in 2a/2b as written.
2. **"Resume payment" cannot reopen the old Paystack page.** Spec §6.4 says re-open the WebView "against the stored reference". The API stores only the reference, not the authorization URL, and no endpoint returns either. Web's own behavior for `complete_payment` is to re-run the same form, which mints a fresh reference. **This plan does the same:** poll the stored reference once (read from the caller's own row, T1); if not confirmed, reopen the wizard, prefilled, with a new key.
3. **Error code name.** Spec text says `username_required`; the real endpoint returns `needs_username`. The plan uses `needs_username`.
4. **Avatar upload (spec §6.7) is deferred.** It needs an image picker dependency and a Storage upload path decision (a write outside `/api/mobile/v1`). Task 10 covers display name, bio, country, WhatsApp and the one-time username change only.
5. **Web branch is unmerged.** All seven endpoints exist only on `docs/mobile-phase1-phase2a-specs`. Nothing here can run against a real server until that merges/deploys or the branch is run locally against staging.

---

## File Structure

| File | Responsibility |
|---|---|
| `lib/core/utils/idempotency_key.dart` (create) | `newIdempotencyKey()` — UUID v4 (byte-identical to Phase 3b's file; if 3b merged first, skip) |
| `lib/core/api/compete_models.dart` (create) | `RegView`, `RegistrationState`, `RegistrationDetails`, `RegisterOutcome` (+2 subclasses), `PaymentStatus`, `ProfileEdit` |
| `lib/core/api/api_client.dart` (modify) | 7 methods + `usedOperations`; `_send` gains optional `headers` |
| `lib/features/compete/compete_models.dart` (create) | `CompeteTournament`, `GameSummary`, `PendingInvitation`, `TournamentTab` |
| `lib/features/compete/compete_reads_repository.dart` (create) | T1 Supabase reads |
| `lib/features/compete/registration_repository.dart` (create) | Thin wrapper over the 5 registration/payment `ApiClient` calls (fake-able) |
| `lib/features/compete/compete_providers.dart` (create) | Providers for reads, registration state, filters |
| `lib/features/compete/payment_poller.dart` (create) | Pure `pollPayment()` with injectable delay |
| `lib/features/compete/registration_flow.dart` (create) | `RegistrationFlow` notifier: key policy, submit, poll, phases |
| `lib/features/compete/paystack_checkout.dart` (create) | `PaystackCheckoutScreen` (WebView) + `paystackCheckoutProvider` launcher seam |
| `lib/features/compete/error_copy.dart` (create) | `errorCopy(l10n, code)` |
| `lib/features/compete/registration_sheet.dart` (create) | Wizard bottom sheet (register + waitlist modes), validators |
| `lib/features/compete/compete_list_screen.dart` (create) | List with tabs + game filter |
| `lib/features/compete/compete_detail_screen.dart` (create) | Detail + view-state CTA |
| `lib/features/compete/invitations_screen.dart` (create) | Pending invitations, accept/decline |
| `lib/features/compete/games_screen.dart` (create) | Games catalogue |
| `lib/features/account/edit_profile_screen.dart` (create) | Minimal profile edit |
| `lib/core/l10n/app_en.arb`, `app_fr.arb` (modify) | New keys (Task 2) |
| `lib/router/app_router.dart` (modify) | Re-point tournament routes; add `/invitations`, `/games`, `/account/profile` |
| `lib/core/routing/web_links.dart` (modify) | `/games` mapping |
| `lib/features/home/home_screen.dart`, `account_screen.dart` (modify) | Entry tiles (appended) |
| `pubspec.yaml` (modify) | `webview_flutter` |
| `test/…` beside each | See tasks; shared fixtures in `test/support/compete_fixtures.dart` |

---

### Task 0: Worktree, base, contract, dependency, flavor check

**Files:** `api/openapi.json`, `pubspec.yaml`.

- [ ] **Step 1: Worktree on a green base**

```bash
cd C:\Users\gorok\sentinelx_mobile
git fetch origin
git worktree add ..\sentinelx_mobile-p2a -b phase2a/screens origin/master
cd ..\sentinelx_mobile-p2a
flutter pub get
flutter analyze && flutter test
```
Expected: clean and green. If red, stop and report. (Note: the main checkout has uncommitted `api/openapi.json` changes; the worktree starts from committed state. Do not copy those over.)

- [ ] **Step 2: Copy the contract**

```bash
copy C:\Users\gorok\Videos\sentinelx\openapi\mobile-v1.json api\openapi.json
findstr /c:"getTournamentRegistrationState" /c:"postTournamentRegister" /c:"postTournamentWaitlist" /c:"postInvitationAccept" /c:"postInvitationDecline" /c:"getPaymentStatus" /c:"patchMeProfile" api\openapi.json
```
All seven must match. The web checkout at that path is on `docs/mobile-phase1-phase2a-specs`; confirm with `git -C C:\Users\gorok\Videos\sentinelx branch --show-current`. If web has moved, re-copy from the newest branch that has all seven.

- [ ] **Step 3: Add the WebView dependency**

```bash
flutter pub add webview_flutter
flutter pub get
flutter analyze
```
Expected: analyze clean. Commit `pubspec.yaml`/`pubspec.lock` with Task 1 (do not commit plugin registrant churn).

- [ ] **Step 4: Verify the flavor points at staging (spec §2, exit item)**

Run and read `config/dev.json`. It currently holds only `{ "FLAVOR": "dev", "DEBUG_TOOLS": true }`, so a bare dev run **defaults to production URLs** (`app_config.dart`). Do not "fix" it by committing keys; the joint test round passes `--dart-define=SUPABASE_URL=...` for staging (`ofxmoxpvwbemfouaowoa`, see `docs/agent-handoffs/2026-09-25-mobile-phase3b-flutter-session-notes.md`). Record in the PR that this task saw the default is production and that no write-path testing was run without overrides.

- [ ] **Step 5: Live schema check for T1 columns (read-only)**

Confirm the columns Task 3 selects exist. Supabase MCP `execute_sql` against the **staging** project only:

```sql
select table_name, column_name from information_schema.columns
 where table_schema='public'
   and ((table_name='tournaments'  and column_name in ('id','title','slug','description','banner_url','card_image_url','status','format','competition_format','prize_pool','prize_second','prize_third','registration_fee','max_players','registration_start','registration_end','tournament_start','tournament_end','rules','invitation_only','created_at','game_id'))
     or (table_name='games' and column_name in ('id','name','slug','icon_url','active'))
     or (table_name='tournament_invitations' and column_name in ('id','tournament_id','player_id','status','expires_at','rank_at_invite'))
     or (table_name='tournament_registrations' and column_name in ('tournament_id','player_id','payment_status','paystack_reference')));
```
Expected: every listed column present (22 + 5 + 6 + 4 = 37 rows). Any missing column: stop and fix Task 3's column list before continuing.

---

### Task 1: Contract models and client methods

**Files:**
- Create: `lib/core/utils/idempotency_key.dart`, `lib/core/api/compete_models.dart`, `test/core/idempotency_key_test.dart` (skip if it exists), `test/core/compete_models_test.dart`, `test/core/api_client_compete_test.dart`
- Modify: `lib/core/api/api_client.dart`

**Interfaces:**
- Produces:

```dart
String newIdempotencyKey([Random? random]);
enum RegView { guest, canRegister, completePayment, registered, waitlisted, full, closed, ended, invitationOnly }
class RegistrationState { RegView view; int feeNaira; bool hasWaiver; bool coinDiscountEligible; bool agreementRequired; factory RegistrationState.fromJson(Map<String,dynamic>); }
class RegistrationDetails { String displayName; String whatsapp; String clubName; String? ignTag; bool agreedToRules; Map<String,Object?> toJson(); }
sealed class RegisterOutcome {}
class RegisterConfirmed extends RegisterOutcome {}
class RegisterPending extends RegisterOutcome { String authorizationUrl; String reference; }
enum PaymentStatus { confirmed, alreadyPaid, notFound, notSuccessful; bool get isPaid; }
class ProfileEdit { String displayName; String username; String whatsapp; String country; String bio; Map<String,Object?> toJson(); }
// ApiClient:
Future<RegistrationState> getTournamentRegistrationState(String tournamentId);
Future<RegisterOutcome> postTournamentRegister(String tournamentId, {required RegistrationDetails details, required int coinsUsed, required String idempotencyKey});
Future<void> postTournamentWaitlist(String tournamentId, {required RegistrationDetails details});
Future<RegisterOutcome> postInvitationAccept(String invitationId, {required String idempotencyKey});
Future<void> postInvitationDecline(String invitationId);
Future<PaymentStatus> getPaymentStatus(String reference);
Future<void> patchMeProfile(ProfileEdit edit);
```

- [ ] **Step 1: Idempotency key util**

If `lib/core/utils/idempotency_key.dart` does not exist, create it with exactly:

```dart
import 'dart:math';

final Random _secure = Random.secure();

/// A random (version 4) UUID. The API only requires a non-empty, unique-per-intent key.
String newIdempotencyKey([Random? random]) {
  final r = random ?? _secure;
  final b = List<int>.generate(16, (_) => r.nextInt(256));
  b[6] = (b[6] & 0x0f) | 0x40; // version 4
  b[8] = (b[8] & 0x3f) | 0x80; // variant 10xx
  String h(int i) => b[i].toRadixString(16).padLeft(2, '0');
  return '${h(0)}${h(1)}${h(2)}${h(3)}-${h(4)}${h(5)}-${h(6)}${h(7)}-${h(8)}${h(9)}-${h(10)}${h(11)}${h(12)}${h(13)}${h(14)}${h(15)}';
}
```

and `test/core/idempotency_key_test.dart`:

```dart
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/core/utils/idempotency_key.dart';

void main() {
  test('is a v4 UUID and differs between calls', () {
    final re = RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$');
    final a = newIdempotencyKey();
    expect(re.hasMatch(a), isTrue);
    expect(newIdempotencyKey(), isNot(a));
  });

  test('is deterministic for a seeded Random', () {
    expect(newIdempotencyKey(Random(1)), newIdempotencyKey(Random(1)));
  });
}
```

- [ ] **Step 2: Write the failing model tests** — `test/core/compete_models_test.dart`

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/core/api/compete_models.dart';

void main() {
  test('RegistrationState maps every documented view', () {
    const wire = {
      'guest': RegView.guest, 'can_register': RegView.canRegister, 'complete_payment': RegView.completePayment,
      'registered': RegView.registered, 'waitlisted': RegView.waitlisted, 'full': RegView.full,
      'closed': RegView.closed, 'ended': RegView.ended, 'invitation_only': RegView.invitationOnly,
    };
    wire.forEach((s, v) {
      final st = RegistrationState.fromJson({
        'view': s, 'feeNaira': 500, 'hasWaiver': false, 'coinDiscountEligible': true, 'agreementRequired': true,
      });
      expect(st.view, v);
      expect(st.feeNaira, 500);
      expect(st.coinDiscountEligible, isTrue);
    });
  });

  test('an unknown view from a newer server throws FormatException (surfaces as bad_response)', () {
    expect(
      () => RegistrationState.fromJson({'view': 'brand_new', 'feeNaira': 0, 'hasWaiver': false, 'coinDiscountEligible': false, 'agreementRequired': false}),
      throwsFormatException,
    );
  });

  test('parseRegisterOutcome handles confirmed and pending', () {
    expect(parseRegisterOutcome({'status': 'confirmed'}), isA<RegisterConfirmed>());
    final p = parseRegisterOutcome({'status': 'pending', 'authorizationUrl': 'https://pay.test/x', 'reference': 'ref1'});
    expect(p, isA<RegisterPending>());
    expect((p as RegisterPending).reference, 'ref1');
    expect(() => parseRegisterOutcome({'status': 'weird'}), throwsFormatException);
  });

  test('PaymentStatus parses snake_case and isPaid', () {
    expect(parsePaymentStatus('confirmed').isPaid, isTrue);
    expect(parsePaymentStatus('already_paid').isPaid, isTrue);
    expect(parsePaymentStatus('not_successful').isPaid, isFalse);
    expect(parsePaymentStatus('not_found').isPaid, isFalse);
    expect(() => parsePaymentStatus('??'), throwsFormatException);
  });

  test('RegistrationDetails omits a blank ignTag and trims nothing itself', () {
    const d = RegistrationDetails(displayName: 'Ada', whatsapp: '+2348012345678', clubName: 'FC', ignTag: '', agreedToRules: true);
    expect(d.toJson(), {'displayName': 'Ada', 'whatsapp': '+2348012345678', 'clubName': 'FC', 'agreedToRules': true});
    const d2 = RegistrationDetails(displayName: 'Ada', whatsapp: '+2348012345678', clubName: 'FC', ignTag: 'ada_10', agreedToRules: true);
    expect(d2.toJson()['ignTag'], 'ada_10');
  });

  test('ProfileEdit sends every field, empty string for blanks', () {
    const e = ProfileEdit(displayName: 'Ada', username: '', whatsapp: '', country: '', bio: '');
    expect(e.toJson(), {'displayName': 'Ada', 'username': '', 'whatsapp': '', 'country': '', 'bio': ''});
  });
}
```

- [ ] **Step 3: Run to verify failure**

Run: `flutter test test/core/compete_models_test.dart`
Expected: FAIL (`compete_models.dart` not found).

- [ ] **Step 4: Implement `lib/core/api/compete_models.dart`**

```dart
enum RegView { guest, canRegister, completePayment, registered, waitlisted, full, closed, ended, invitationOnly }

RegView _parseView(String s) => switch (s) {
      'guest' => RegView.guest,
      'can_register' => RegView.canRegister,
      'complete_payment' => RegView.completePayment,
      'registered' => RegView.registered,
      'waitlisted' => RegView.waitlisted,
      'full' => RegView.full,
      'closed' => RegView.closed,
      'ended' => RegView.ended,
      'invitation_only' => RegView.invitationOnly,
      _ => throw FormatException('Unknown registration view: $s'),
    };

class RegistrationState {
  const RegistrationState({
    required this.view,
    required this.feeNaira,
    required this.hasWaiver,
    required this.coinDiscountEligible,
    required this.agreementRequired,
  });

  factory RegistrationState.fromJson(Map<String, dynamic> j) => RegistrationState(
        view: _parseView(j['view'] as String),
        feeNaira: (j['feeNaira'] as num).toInt(),
        hasWaiver: j['hasWaiver'] as bool,
        coinDiscountEligible: j['coinDiscountEligible'] as bool,
        agreementRequired: j['agreementRequired'] as bool,
      );

  final RegView view;
  final int feeNaira;
  final bool hasWaiver;
  final bool coinDiscountEligible;
  final bool agreementRequired;
}

class RegistrationDetails {
  const RegistrationDetails({
    required this.displayName,
    required this.whatsapp,
    required this.clubName,
    this.ignTag,
    required this.agreedToRules,
  });

  final String displayName;
  final String whatsapp;
  final String clubName;
  final String? ignTag;
  final bool agreedToRules;

  Map<String, Object?> toJson() => {
        'displayName': displayName,
        'whatsapp': whatsapp,
        'clubName': clubName,
        if (ignTag != null && ignTag!.isNotEmpty) 'ignTag': ignTag,
        'agreedToRules': agreedToRules,
      };
}

sealed class RegisterOutcome {
  const RegisterOutcome();
}

class RegisterConfirmed extends RegisterOutcome {
  const RegisterConfirmed();
}

class RegisterPending extends RegisterOutcome {
  const RegisterPending({required this.authorizationUrl, required this.reference});
  final String authorizationUrl;
  final String reference;
}

RegisterOutcome parseRegisterOutcome(Object? data) {
  final j = data! as Map<String, dynamic>;
  return switch (j['status']) {
    'confirmed' => const RegisterConfirmed(),
    'pending' => RegisterPending(authorizationUrl: j['authorizationUrl'] as String, reference: j['reference'] as String),
    final other => throw FormatException('Unknown register status: $other'),
  };
}

enum PaymentStatus {
  confirmed,
  alreadyPaid,
  notFound,
  notSuccessful;

  bool get isPaid => this == confirmed || this == alreadyPaid;
}

PaymentStatus parsePaymentStatus(String s) => switch (s) {
      'confirmed' => PaymentStatus.confirmed,
      'already_paid' => PaymentStatus.alreadyPaid,
      'not_found' => PaymentStatus.notFound,
      'not_successful' => PaymentStatus.notSuccessful,
      _ => throw FormatException('Unknown payment status: $s'),
    };

class ProfileEdit {
  const ProfileEdit({
    required this.displayName,
    required this.username,
    required this.whatsapp,
    required this.country,
    required this.bio,
  });

  final String displayName;
  final String username;
  final String whatsapp;
  final String country;
  final String bio;

  Map<String, Object?> toJson() => {
        'displayName': displayName,
        'username': username,
        'whatsapp': whatsapp,
        'country': country,
        'bio': bio,
      };
}
```

- [ ] **Step 5: Run model tests**

Run: `flutter test test/core/compete_models_test.dart test/core/idempotency_key_test.dart`
Expected: PASS.

- [ ] **Step 6: Write the failing client tests** — `test/core/api_client_compete_test.dart`

```dart
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/core/api/api_client.dart';
import 'package:sentinelx_mobile/core/api/compete_models.dart';

class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.respond);
  final ResponseBody Function(RequestOptions options) respond;
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    requests.add(options);
    return respond(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _json(int status, Object body) => ResponseBody.fromString(jsonEncode(body), status,
    headers: {Headers.contentTypeHeader: [Headers.jsonContentType]});

ApiClient _client(_FakeAdapter a) => ApiClient.create(
    baseUrl: 'https://api.test', appVersion: '1.0.0', platform: 'android', accessToken: () async => 'tok', adapter: a);

const _details = RegistrationDetails(displayName: 'Ada', whatsapp: '+2348012345678', clubName: 'FC Ada', agreedToRules: true);

void main() {
  test('getTournamentRegistrationState hits the right path and parses', () async {
    final a = _FakeAdapter((_) => _json(200, {
          'data': {'view': 'can_register', 'feeNaira': 500, 'hasWaiver': false, 'coinDiscountEligible': true, 'agreementRequired': true}
        }));
    final s = await _client(a).getTournamentRegistrationState('t1');
    expect(a.requests.single.method, 'GET');
    expect(a.requests.single.path, '/api/mobile/v1/tournaments/t1/registration-state');
    expect(s.view, RegView.canRegister);
  });

  test('postTournamentRegister sends the Idempotency-Key header and body, returns pending', () async {
    final a = _FakeAdapter((_) => _json(200, {
          'data': {'status': 'pending', 'authorizationUrl': 'https://pay.test/a', 'reference': 'r1'}
        }));
    final out = await _client(a).postTournamentRegister('t1', details: _details, coinsUsed: 500, idempotencyKey: 'key-1');
    final req = a.requests.single;
    expect(req.method, 'POST');
    expect(req.path, '/api/mobile/v1/tournaments/t1/register');
    expect(req.headers['Idempotency-Key'], 'key-1');
    expect((req.data as Map)['coinsUsed'], 500);
    expect((req.data as Map)['agreedToRules'], true);
    expect(out, isA<RegisterPending>());
  });

  test('postTournamentRegister surfaces the error code and status', () async {
    final a = _FakeAdapter((_) => _json(409, {
          'error': {'code': 'tournament_full', 'message': 'This tournament is full.'}
        }));
    await expectLater(
      _client(a).postTournamentRegister('t1', details: _details, coinsUsed: 0, idempotencyKey: 'k'),
      throwsA(isA<ApiException>().having((e) => e.code, 'code', 'tournament_full').having((e) => e.status, 'status', 409)),
    );
  });

  test('postTournamentWaitlist sends no Idempotency-Key', () async {
    final a = _FakeAdapter((_) => _json(200, {'data': {'status': 'waitlisted'}}));
    await _client(a).postTournamentWaitlist('t1', details: _details);
    expect(a.requests.single.path, '/api/mobile/v1/tournaments/t1/waitlist');
    expect(a.requests.single.headers.containsKey('Idempotency-Key'), isFalse);
  });

  test('postInvitationAccept sends the key; decline does not', () async {
    final a = _FakeAdapter((o) => o.path.endsWith('/accept')
        ? _json(200, {'data': {'status': 'confirmed'}})
        : _json(200, {'data': {'status': 'declined'}}));
    final c = _client(a);
    expect(await c.postInvitationAccept('i1', idempotencyKey: 'k9'), isA<RegisterConfirmed>());
    expect(a.requests.last.headers['Idempotency-Key'], 'k9');
    await c.postInvitationDecline('i1');
    expect(a.requests.last.path, '/api/mobile/v1/invitations/i1/decline');
    expect(a.requests.last.headers.containsKey('Idempotency-Key'), isFalse);
  });

  test('getPaymentStatus parses the enum', () async {
    final a = _FakeAdapter((_) => _json(200, {'data': {'status': 'already_paid'}}));
    expect(await _client(a).getPaymentStatus('ref 1/x'), PaymentStatus.alreadyPaid);
    expect(a.requests.single.path, '/api/mobile/v1/payments/ref%201%2Fx');
  });

  test('patchMeProfile PATCHes /me/profile with every field', () async {
    final a = _FakeAdapter((_) => _json(200, {'data': {'ok': true}}));
    await _client(a).patchMeProfile(const ProfileEdit(displayName: 'Ada', username: '', whatsapp: '', country: 'NG', bio: 'hi'));
    expect(a.requests.single.method, 'PATCH');
    expect(a.requests.single.path, '/api/mobile/v1/me/profile');
    expect((a.requests.single.data as Map)['country'], 'NG');
  });
}
```

- [ ] **Step 7: Run to verify failure**

Run: `flutter test test/core/api_client_compete_test.dart`
Expected: FAIL (methods not defined).

- [ ] **Step 8: Implement client changes in `lib/core/api/api_client.dart`**

(a) Import: add `import 'compete_models.dart';` beside `import 'models.dart';`.

(b) Add to `usedOperations` (append):

```dart
    'getTournamentRegistrationState': 'get /api/mobile/v1/tournaments/{id}/registration-state',
    'postTournamentRegister': 'post /api/mobile/v1/tournaments/{id}/register',
    'postTournamentWaitlist': 'post /api/mobile/v1/tournaments/{id}/waitlist',
    'postInvitationAccept': 'post /api/mobile/v1/invitations/{id}/accept',
    'postInvitationDecline': 'post /api/mobile/v1/invitations/{id}/decline',
    'getPaymentStatus': 'get /api/mobile/v1/payments/{reference}',
    'patchMeProfile': 'patch /api/mobile/v1/me/profile',
```

(c) `_send` gains an optional `headers` parameter. Replace the signature and the `Options(...)`:

```dart
  Future<T> _send<T>(String method, String path, T Function(Object? data) parse,
      {Object? body, Map<String, String>? headers}) async {
    final Response<dynamic> res;
    try {
      res = await _dio.request<dynamic>(
        '$_base$path',
        data: body,
        options: Options(method: method, responseType: ResponseType.json, headers: headers),
      );
```

(d) Append methods before the closing `}` of the class:

```dart
  Future<RegistrationState> getTournamentRegistrationState(String tournamentId) => _send(
        'GET',
        '/tournaments/${Uri.encodeComponent(tournamentId)}/registration-state',
        (d) => RegistrationState.fromJson(d! as Map<String, dynamic>),
      );

  Future<RegisterOutcome> postTournamentRegister(
    String tournamentId, {
    required RegistrationDetails details,
    required int coinsUsed,
    required String idempotencyKey,
  }) =>
      _send(
        'POST',
        '/tournaments/${Uri.encodeComponent(tournamentId)}/register',
        parseRegisterOutcome,
        body: {...details.toJson(), 'coinsUsed': coinsUsed},
        headers: {'Idempotency-Key': idempotencyKey},
      );

  Future<void> postTournamentWaitlist(String tournamentId, {required RegistrationDetails details}) => _send(
        'POST',
        '/tournaments/${Uri.encodeComponent(tournamentId)}/waitlist',
        (_) {},
        body: details.toJson(),
      );

  Future<RegisterOutcome> postInvitationAccept(String invitationId, {required String idempotencyKey}) => _send(
        'POST',
        '/invitations/${Uri.encodeComponent(invitationId)}/accept',
        parseRegisterOutcome,
        headers: {'Idempotency-Key': idempotencyKey},
      );

  Future<void> postInvitationDecline(String invitationId) =>
      _send('POST', '/invitations/${Uri.encodeComponent(invitationId)}/decline', (_) {});

  Future<PaymentStatus> getPaymentStatus(String reference) => _send(
        'GET',
        '/payments/${Uri.encodeComponent(reference)}',
        (d) => parsePaymentStatus((d! as Map<String, dynamic>)['status'] as String),
      );

  Future<void> patchMeProfile(ProfileEdit edit) => _send('PATCH', '/me/profile', (_) {}, body: edit.toJson());
```

Note: `postInvitationAccept` has no body; if Dio sends `null` data on POST that is fine, the endpoint declares none.

- [ ] **Step 9: Run tests + contract test**

Run: `flutter test test/core/api_client_compete_test.dart test/core/api_contract_test.dart test/core/api_client_test.dart`
Expected: PASS (the contract test now also checks the 7 new operations against the re-copied `api/openapi.json`).

- [ ] **Step 10: Commit**

```bash
flutter analyze && flutter test
git checkout -- linux macos windows
git add pubspec.yaml pubspec.lock api/openapi.json lib/core/utils lib/core/api test/core
git commit -m "feat(api): Phase 2a client methods, contract models and idempotency key util"
```

---

### Task 2: Copy (ARB en + fr) and error-code copy

**Files:**
- Modify: `lib/core/l10n/app_en.arb`, `lib/core/l10n/app_fr.arb`
- Create: `lib/features/compete/error_copy.dart`, `test/features/compete/error_copy_test.dart`

**Interfaces:**
- Produces: `String errorCopy(AppLocalizations l10n, String code)` — never returns an empty string; unknown codes map to `l10n.cmpEcGeneric`.

- [ ] **Step 1: Add the keys.** Append to `app_en.arb` (before the closing brace, mind commas) and the same keys to `app_fr.arb` with the French text. Placeholders need an `@key` block like existing `updateRequiredBody`.

| Key | English | French |
|---|---|---|
| `cmpTabAll` | All | Tous |
| `cmpTabLive` | Live | En direct |
| `cmpTabUpcoming` | Upcoming | À venir |
| `cmpTabCompleted` | Completed | Terminés |
| `cmpAllGames` | All games | Tous les jeux |
| `cmpEmpty` | No tournaments here yet. | Aucun tournoi pour le moment. |
| `cmpLoadError` | Couldn't load this. Check your connection and try again. | Chargement impossible. Vérifiez votre connexion et réessayez. |
| `cmpRetry` | Try again | Réessayer |
| `cmpLoadMore` | Load more | Charger plus |
| `cmpEntryFee` | Entry fee | Frais d'inscription |
| `cmpFree` | Free | Gratuit |
| `cmpPrizePool` | Prize pool | Cagnotte |
| `cmpSecondPlace` | 2nd place | 2e place |
| `cmpThirdPlace` | 3rd place | 3e place |
| `cmpMaxPlayers` | `{count} players max` (placeholder `count` int) | `{count} joueurs maximum` |
| `cmpRules` | Rules | Règlement |
| `cmpViewBracket` | View bracket | Voir le tableau |
| `cmpShareWhatsapp` | Share on WhatsApp | Partager sur WhatsApp |
| `cmpShareText` | `Join {title} on Sentinel X: {url}` (placeholders `title`,`url` String) | `Rejoignez {title} sur Sentinel X : {url}` |
| `cmpCtaRegister` | Register | S'inscrire |
| `cmpCtaResume` | Resume payment | Reprendre le paiement |
| `cmpCtaLogin` | Log in to register | Connectez-vous pour vous inscrire |
| `cmpCtaJoinWaitlist` | Join waitlist | Rejoindre la liste d'attente |
| `cmpViewInvitations` | View my invitations | Voir mes invitations |
| `cmpStateRegistered` | You're registered. | Vous êtes inscrit. |
| `cmpStateWaitlisted` | You're on the waitlist. | Vous êtes sur la liste d'attente. |
| `cmpStateFull` | This tournament is full. | Ce tournoi est complet. |
| `cmpStateEnded` | This tournament has ended. | Ce tournoi est terminé. |
| `cmpStateInvitationOnly` | This tournament is invitation-only. | Ce tournoi est sur invitation uniquement. |
| `cmpFeeWaived` | Free entry — waiver applied | Entrée gratuite — dispense appliquée |
| `cmpFieldDisplayName` | Display name | Nom affiché |
| `cmpFieldWhatsapp` | WhatsApp number | Numéro WhatsApp |
| `cmpFieldClub` | Club name | Nom du club |
| `cmpFieldIgn` | In-game tag (optional) | Pseudo en jeu (facultatif) |
| `cmpAgreeRules` | I have read and agree to the rules | J'ai lu et j'accepte le règlement |
| `cmpCoinsTitle` | Use SX Coins | Utiliser des SX Coins |
| `cmpCoinsNone` | Don't use coins | Ne pas utiliser de pièces |
| `cmpCoinsOption` | `{coins} coins (−₦{naira})` (placeholders `coins` int, `naira` String) | `{coins} pièces (−{naira} ₦)` |
| `cmpSubmitRegister` | Continue | Continuer |
| `cmpSubmitWaitlist` | Join waitlist | Rejoindre la liste d'attente |
| `cmpSubmitting` | Working… | En cours… |
| `cmpValDisplayName` | Enter a name (1–60 characters). | Saisissez un nom (1 à 60 caractères). |
| `cmpValWhatsapp` | Enter a valid WhatsApp number. | Saisissez un numéro WhatsApp valide. |
| `cmpValClub` | Enter your club (1–60 characters). | Saisissez votre club (1 à 60 caractères). |
| `cmpValIgn` | Tag is too long (60 max). | Pseudo trop long (60 max). |
| `cmpValRules` | Please agree to the rules. | Veuillez accepter le règlement. |
| `cmpPayConfirming` | Confirming your payment… | Confirmation du paiement… |
| `cmpPaySuccess` | You're in! Payment confirmed. | C'est fait ! Paiement confirmé. |
| `cmpPayNotConfirmed` | We haven't seen your payment yet. If you were charged it will confirm shortly — check back in a minute. | Nous n'avons pas encore reçu votre paiement. Si vous avez été débité, il sera confirmé sous peu — revenez dans une minute. |
| `cmpPayCancelled` | Payment window closed. You can resume from the tournament page. | Fenêtre de paiement fermée. Vous pouvez reprendre depuis la page du tournoi. |
| `cmpConfirmedFree` | You're registered! | Vous êtes inscrit ! |
| `cmpWaitlistJoined` | You're on the waitlist. | Vous êtes sur la liste d'attente. |
| `cmpInvTitle` | My invitations | Mes invitations |
| `cmpInvEmpty` | No pending invitations. | Aucune invitation en attente. |
| `cmpInvAccept` | Accept | Accepter |
| `cmpInvDecline` | Decline | Refuser |
| `cmpInvExpires` | `Expires {date}` (placeholder `date` String) | `Expire le {date}` |
| `cmpInvDeclined` | Invitation declined. | Invitation refusée. |
| `cmpGamesTitle` | Games | Jeux |
| `cmpGamesEmpty` | No games yet. | Aucun jeu pour le moment. |
| `cmpEditProfile` | Edit profile | Modifier le profil |
| `cmpFieldBio` | Bio | Bio |
| `cmpFieldCountry` | Country | Pays |
| `cmpFieldUsername` | Username (can be changed once) | Nom d'utilisateur (modifiable une fois) |
| `cmpSave` | Save | Enregistrer |
| `cmpSaved` | Profile saved. | Profil enregistré. |
| `cmpValBio` | Bio must be 280 characters or fewer. | La bio doit faire 280 caractères maximum. |
| `cmpValCountry` | Country is too long (60 max). | Pays trop long (60 max). |
| `cmpEcGeneric` | Something went wrong. Please try again. | Une erreur est survenue. Veuillez réessayer. |
| `cmpEcNetwork` | No connection. Check your internet and try again. | Pas de connexion. Vérifiez votre internet et réessayez. |
| `cmpEcSession` | Your session expired. Please log in again. | Votre session a expiré. Reconnectez-vous. |
| `cmpEcTournamentNotFound` | Tournament not found. | Tournoi introuvable. |
| `cmpEcRulesRequired` | Please confirm you agree to the rules. | Veuillez confirmer que vous acceptez le règlement. |
| `cmpEcAlreadyRegistered` | You're already registered for this tournament. | Vous êtes déjà inscrit à ce tournoi. |
| `cmpEcTournamentFull` | This tournament is full. | Ce tournoi est complet. |
| `cmpEcInvitationOnly` | This tournament is invitation-only. | Ce tournoi est sur invitation uniquement. |
| `cmpEcRegistrationClosed` | Registration is closed. | Les inscriptions sont fermées. |
| `cmpEcInsufficientCoins` | Not enough SX Coins for this discount. | Pas assez de SX Coins pour cette réduction. |
| `cmpEcPaymentInit` | Payment couldn't be started. Please try again. | Le paiement n'a pas pu démarrer. Réessayez. |
| `cmpEcWaitlistNotOpen` | The waitlist opens once registration closes. | La liste d'attente ouvre à la fin des inscriptions. |
| `cmpEcAlreadyWaitlisted` | You're already on the waitlist. | Vous êtes déjà sur la liste d'attente. |
| `cmpEcInProgress` | Still processing your request. Please wait a moment and try again. | Traitement en cours. Patientez un instant puis réessayez. |
| `cmpEcInvitationNotFound` | Invitation not found. | Invitation introuvable. |
| `cmpEcInvitationGone` | This invitation is no longer available. | Cette invitation n'est plus disponible. |
| `cmpEcInvitationExpired` | This invitation has expired. | Cette invitation a expiré. |
| `cmpEcUsernameTaken` | That username is already taken. | Ce nom d'utilisateur est déjà pris. |
| `cmpEcUsernameLocked` | Your username has already been changed once. | Votre nom d'utilisateur a déjà été modifié une fois. |
| `cmpEcSaveFailed` | Couldn't save your profile. Please try again. | Impossible d'enregistrer votre profil. Réessayez. |
| `cmpHomeGamesTile` | Games | Jeux |
| `cmpHomeInvitationsTile` | My invitations | Mes invitations |
| `cmpAccountEditProfile` | Edit profile | Modifier le profil |

Flag the French for native review in the PR description (machine-written).

- [ ] **Step 2: Regenerate and confirm keys line up**

Run: `flutter gen-l10n && flutter test test/core/l10n_test.dart`
Expected: PASS (fr and en have identical key sets).

- [ ] **Step 3: Write the failing test** — `test/features/compete/error_copy_test.dart`

```dart
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/core/l10n/gen/app_localizations.dart';
import 'package:sentinelx_mobile/features/compete/error_copy.dart';

void main() {
  final l10n = AppLocalizationsEn();

  test('maps every registration, waitlist, invitation and profile code to specific copy', () {
    const codes = [
      'network', 'unauthorized', 'tournament_not_found', 'rules_agreement_required', 'already_registered',
      'tournament_full', 'invitation_only', 'registration_closed', 'insufficient_coins', 'payment_init_failed',
      'waitlist_not_open', 'already_on_waitlist', 'idempotency_in_progress', 'invitation_not_found',
      'invitation_no_longer_available', 'invitation_expired', 'username_taken', 'username_locked', 'save_failed',
    ];
    final seen = <String>{};
    for (final c in codes) {
      final text = errorCopy(l10n, c);
      expect(text, isNotEmpty, reason: c);
      expect(text, isNot(l10n.cmpEcGeneric), reason: '$c fell through to the generic message');
      seen.add(text);
    }
    expect(seen.length, greaterThan(15));
  });

  test('unknown and server-only codes fall back to the generic message', () {
    expect(errorCopy(l10n, 'something_new'), l10n.cmpEcGeneric);
    expect(errorCopy(l10n, 'registration_failed'), l10n.cmpEcGeneric);
    expect(errorCopy(l10n, ''), l10n.cmpEcGeneric);
  });

  // Keeps the analyzer honest about the import used above.
  test('Locale import is available', () => expect(const Locale('en').languageCode, 'en'));
}
```

- [ ] **Step 3b: Run to verify failure**

Run: `flutter test test/features/compete/error_copy_test.dart`
Expected: FAIL (`error_copy.dart` not found).

- [ ] **Step 4: Implement `lib/features/compete/error_copy.dart`**

```dart
import '../../core/l10n/gen/app_localizations.dart';

/// Maps an API error code to localized copy. Server `message` strings are English and never shown.
String errorCopy(AppLocalizations l10n, String code) => switch (code) {
      'network' => l10n.cmpEcNetwork,
      'unauthorized' => l10n.cmpEcSession,
      'tournament_not_found' => l10n.cmpEcTournamentNotFound,
      'rules_agreement_required' => l10n.cmpEcRulesRequired,
      'already_registered' => l10n.cmpEcAlreadyRegistered,
      'tournament_full' => l10n.cmpEcTournamentFull,
      'invitation_only' => l10n.cmpEcInvitationOnly,
      'registration_closed' => l10n.cmpEcRegistrationClosed,
      'insufficient_coins' => l10n.cmpEcInsufficientCoins,
      'payment_init_failed' => l10n.cmpEcPaymentInit,
      'waitlist_not_open' => l10n.cmpEcWaitlistNotOpen,
      'already_on_waitlist' => l10n.cmpEcAlreadyWaitlisted,
      'idempotency_in_progress' => l10n.cmpEcInProgress,
      'invitation_not_found' => l10n.cmpEcInvitationNotFound,
      'invitation_no_longer_available' => l10n.cmpEcInvitationGone,
      'invitation_expired' => l10n.cmpEcInvitationExpired,
      'username_taken' => l10n.cmpEcUsernameTaken,
      'username_locked' => l10n.cmpEcUsernameLocked,
      'save_failed' => l10n.cmpEcSaveFailed,
      _ => l10n.cmpEcGeneric,
    };
```

Note: the app's `ApiException` for 401 carries the server's code; `isUnauthorized` (status 401) is what callers test. Task 5 passes `'unauthorized'` explicitly for a 401 regardless of the server code.

- [ ] **Step 5: Run and commit**

Run: `flutter test test/features/compete/error_copy_test.dart test/core/l10n_test.dart`
Expected: PASS.

```bash
flutter analyze && flutter test
git checkout -- linux macos windows
git add lib/core/l10n lib/features/compete/error_copy.dart test/features/compete
git commit -m "feat(l10n): Compete 2a copy (en+fr) and API error-code copy"
```

---

### Task 3: T1 reads — models, repository, providers

**Files:**
- Create: `lib/features/compete/compete_models.dart`, `lib/features/compete/compete_reads_repository.dart`, `lib/features/compete/compete_providers.dart`, `test/features/compete/compete_models_test.dart`, `test/support/compete_fixtures.dart`, `test/fakes/fake_compete_reads.dart`
- Test: as above

**Interfaces:**
- Produces:

```dart
enum TournamentTab { all, live, upcoming, completed }
class CompeteTournament { String id, title, slug; String? description, bannerUrl, cardImageUrl, rules; String status, format, competitionFormat; int prizePool, registrationFee; int? prizeSecond, prizeThird, maxPlayers; DateTime? registrationStart, registrationEnd, tournamentStart, tournamentEnd; bool invitationOnly; String? gameName, gameSlug; factory CompeteTournament.fromJson(Map<String,dynamic>); }
class GameSummary { String id, name, slug; String? iconUrl; factory GameSummary.fromJson(...); }
class PendingInvitation { String id, tournamentId, tournamentTitle; int registrationFee; DateTime expiresAt; factory PendingInvitation.fromJson(...); }
abstract class CompeteReadsRepository {
  Future<List<CompeteTournament>> fetchTournaments({required TournamentTab tab, String? gameSlug, int page = 1});
  Future<CompeteTournament> fetchTournament(String id);
  Future<List<GameSummary>> fetchGames();
  Future<List<PendingInvitation>> fetchMyPendingInvitations(String userId);
  Future<String?> fetchMyPendingReference(String tournamentId, String userId);
}
const int kTournamentPageSize = 20;
// providers
final competeReadsRepositoryProvider = Provider<CompeteReadsRepository>(...);
final tournamentTabProvider = StateProvider<TournamentTab>  // Notifier in Riverpod 3 — see Step 6
final tournamentGameFilterProvider ...
final competeTournamentProvider = FutureProvider.autoDispose.family<CompeteTournament, String>(...);
final registrationStateProvider = FutureProvider.autoDispose.family<RegistrationState, String>(...);
final gamesProvider = FutureProvider.autoDispose<List<GameSummary>>(...);
final myInvitationsProvider = FutureProvider.autoDispose<List<PendingInvitation>>(...);
```

- [ ] **Step 1: Fixtures** — `test/support/compete_fixtures.dart`

```dart
Map<String, dynamic> tournamentRow({
  String id = 't1',
  String title = 'FC Mobile Cup',
  String status = 'registration_open',
  int registrationFee = 500,
  int? maxPlayers = 16,
  Object? games = const {'name': 'FC Mobile', 'slug': 'fc-mobile'},
  String? rules = 'Be nice.',
  bool invitationOnly = false,
}) =>
    {
      'id': id, 'title': title, 'slug': 'fc-mobile-cup', 'description': null, 'banner_url': null, 'card_image_url': null,
      'status': status, 'format': 'knockout', 'competition_format': 'knockout', 'prize_pool': 8000,
      'prize_second': null, 'prize_third': null, 'registration_fee': registrationFee, 'max_players': maxPlayers,
      'registration_start': null, 'registration_end': '2026-10-01T10:00:00Z', 'tournament_start': null,
      'tournament_end': null, 'rules': rules, 'invitation_only': invitationOnly, 'games': games,
    };
```

- [ ] **Step 2: Failing model tests** — `test/features/compete/compete_models_test.dart`

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/features/compete/compete_models.dart';

import '../../support/compete_fixtures.dart';

void main() {
  test('CompeteTournament parses a full row', () {
    final t = CompeteTournament.fromJson(tournamentRow());
    expect(t.title, 'FC Mobile Cup');
    expect(t.gameName, 'FC Mobile');
    expect(t.gameSlug, 'fc-mobile');
    expect(t.registrationEnd, DateTime.utc(2026, 10, 1, 10));
    expect(t.rules, 'Be nice.');
    expect(t.invitationOnly, isFalse);
  });

  test('tolerates a null games join, null max_players and null rules', () {
    final t = CompeteTournament.fromJson(tournamentRow(games: null, maxPlayers: null, rules: null));
    expect(t.gameName, isNull);
    expect(t.maxPlayers, isNull);
    expect(t.rules, isNull);
  });

  test('a games join returned as a one-element list is accepted', () {
    final t = CompeteTournament.fromJson(tournamentRow(games: [
      {'name': 'FC Mobile', 'slug': 'fc-mobile'}
    ]));
    expect(t.gameSlug, 'fc-mobile');
  });

  test('GameSummary and PendingInvitation parse', () {
    final g = GameSummary.fromJson({'id': 'g1', 'name': 'DLS', 'slug': 'dls', 'icon_url': null});
    expect(g.slug, 'dls');
    final i = PendingInvitation.fromJson({
      'id': 'i1', 'tournament_id': 't1', 'expires_at': '2026-10-05T00:00:00Z',
      'tournament': {'title': 'Masters', 'registration_fee': 1000},
    });
    expect(i.tournamentTitle, 'Masters');
    expect(i.registrationFee, 1000);
    final i2 = PendingInvitation.fromJson({
      'id': 'i2', 'tournament_id': 't2', 'expires_at': '2026-10-05T00:00:00Z',
      'tournament': [
        {'title': 'Masters 2', 'registration_fee': 0}
      ],
    });
    expect(i2.tournamentTitle, 'Masters 2');
  });
}
```

- [ ] **Step 3: Run to verify failure**

Run: `flutter test test/features/compete/compete_models_test.dart`
Expected: FAIL (file not found).

- [ ] **Step 4: Implement `lib/features/compete/compete_models.dart`**

```dart
enum TournamentTab { all, live, upcoming, completed }

Map<String, dynamic>? _one(Object? v) {
  if (v is Map<String, dynamic>) return v;
  if (v is List && v.isNotEmpty && v.first is Map<String, dynamic>) return v.first as Map<String, dynamic>;
  return null;
}

DateTime? _date(Object? v) => v == null ? null : DateTime.parse(v as String);

class CompeteTournament {
  const CompeteTournament({
    required this.id,
    required this.title,
    required this.slug,
    required this.description,
    required this.bannerUrl,
    required this.cardImageUrl,
    required this.status,
    required this.format,
    required this.competitionFormat,
    required this.prizePool,
    required this.prizeSecond,
    required this.prizeThird,
    required this.registrationFee,
    required this.maxPlayers,
    required this.registrationStart,
    required this.registrationEnd,
    required this.tournamentStart,
    required this.tournamentEnd,
    required this.rules,
    required this.invitationOnly,
    required this.gameName,
    required this.gameSlug,
  });

  factory CompeteTournament.fromJson(Map<String, dynamic> j) {
    final game = _one(j['games']);
    return CompeteTournament(
      id: j['id'] as String,
      title: j['title'] as String,
      slug: j['slug'] as String,
      description: j['description'] as String?,
      bannerUrl: j['banner_url'] as String?,
      cardImageUrl: j['card_image_url'] as String?,
      status: j['status'] as String,
      format: j['format'] as String,
      competitionFormat: j['competition_format'] as String,
      prizePool: (j['prize_pool'] as num).toInt(),
      prizeSecond: (j['prize_second'] as num?)?.toInt(),
      prizeThird: (j['prize_third'] as num?)?.toInt(),
      registrationFee: (j['registration_fee'] as num).toInt(),
      maxPlayers: (j['max_players'] as num?)?.toInt(),
      registrationStart: _date(j['registration_start']),
      registrationEnd: _date(j['registration_end']),
      tournamentStart: _date(j['tournament_start']),
      tournamentEnd: _date(j['tournament_end']),
      rules: j['rules'] as String?,
      invitationOnly: j['invitation_only'] as bool? ?? false,
      gameName: game?['name'] as String?,
      gameSlug: game?['slug'] as String?,
    );
  }

  final String id;
  final String title;
  final String slug;
  final String? description;
  final String? bannerUrl;
  final String? cardImageUrl;
  final String status;
  final String format;
  final String competitionFormat;
  final int prizePool;
  final int? prizeSecond;
  final int? prizeThird;
  final int registrationFee;
  final int? maxPlayers;
  final DateTime? registrationStart;
  final DateTime? registrationEnd;
  final DateTime? tournamentStart;
  final DateTime? tournamentEnd;
  final String? rules;
  final bool invitationOnly;
  final String? gameName;
  final String? gameSlug;
}

class GameSummary {
  const GameSummary({required this.id, required this.name, required this.slug, required this.iconUrl});

  factory GameSummary.fromJson(Map<String, dynamic> j) => GameSummary(
        id: j['id'] as String,
        name: j['name'] as String,
        slug: j['slug'] as String,
        iconUrl: j['icon_url'] as String?,
      );

  final String id;
  final String name;
  final String slug;
  final String? iconUrl;
}

class PendingInvitation {
  const PendingInvitation({
    required this.id,
    required this.tournamentId,
    required this.tournamentTitle,
    required this.registrationFee,
    required this.expiresAt,
  });

  factory PendingInvitation.fromJson(Map<String, dynamic> j) {
    final t = _one(j['tournament']);
    return PendingInvitation(
      id: j['id'] as String,
      tournamentId: j['tournament_id'] as String,
      tournamentTitle: t?['title'] as String? ?? '',
      registrationFee: (t?['registration_fee'] as num?)?.toInt() ?? 0,
      expiresAt: DateTime.parse(j['expires_at'] as String),
    );
  }

  final String id;
  final String tournamentId;
  final String tournamentTitle;
  final int registrationFee;
  final DateTime expiresAt;
}
```

- [ ] **Step 5: Run model tests**

Run: `flutter test test/features/compete/compete_models_test.dart`
Expected: PASS.

- [ ] **Step 6: Repository + providers**

`lib/features/compete/compete_reads_repository.dart`:

```dart
import 'package:supabase_flutter/supabase_flutter.dart';

import 'compete_models.dart';

const int kTournamentPageSize = 20;

abstract class CompeteReadsRepository {
  Future<List<CompeteTournament>> fetchTournaments({required TournamentTab tab, String? gameSlug, int page = 1});
  Future<CompeteTournament> fetchTournament(String id);
  Future<List<GameSummary>> fetchGames();
  Future<List<PendingInvitation>> fetchMyPendingInvitations(String userId);
  Future<String?> fetchMyPendingReference(String tournamentId, String userId);
}

class SupabaseCompeteReadsRepository implements CompeteReadsRepository {
  SupabaseCompeteReadsRepository(this._client);
  final SupabaseClient _client;

  static const _cols = 'id, title, slug, description, banner_url, card_image_url, status, format, '
      'competition_format, prize_pool, prize_second, prize_third, registration_fee, max_players, '
      'registration_start, registration_end, tournament_start, tournament_end, rules, invitation_only';

  @override
  Future<List<CompeteTournament>> fetchTournaments({required TournamentTab tab, String? gameSlug, int page = 1}) async {
    // Mirrors the web list page: an !inner join only when filtering by game.
    final games = gameSlug == null ? 'games(name, slug)' : 'games!inner(name, slug)';
    var q = _client.from('tournaments').select('$_cols, $games');
    if (gameSlug != null) q = q.eq('games.slug', gameSlug);
    q = switch (tab) {
      TournamentTab.live => q.eq('status', 'active'),
      TournamentTab.upcoming => q.inFilter('status', ['registration_open', 'registration_closed']),
      TournamentTab.completed => q.eq('status', 'completed'),
      TournamentTab.all => q.neq('status', 'draft'),
    };
    final from = (page - 1) * kTournamentPageSize;
    final rows = await q.order('created_at', ascending: false).range(from, from + kTournamentPageSize - 1);
    return rows.map(CompeteTournament.fromJson).toList();
  }

  @override
  Future<CompeteTournament> fetchTournament(String id) async {
    final row = await _client.from('tournaments').select('$_cols, games(name, slug)').eq('id', id).single();
    return CompeteTournament.fromJson(row);
  }

  @override
  Future<List<GameSummary>> fetchGames() async {
    final rows = await _client.from('games').select('id, name, slug, icon_url').eq('active', true).order('name');
    return rows.map(GameSummary.fromJson).toList();
  }

  @override
  Future<List<PendingInvitation>> fetchMyPendingInvitations(String userId) async {
    final rows = await _client
        .from('tournament_invitations')
        .select('id, tournament_id, expires_at, tournament:tournaments(title, registration_fee)')
        .eq('player_id', userId)
        .eq('status', 'pending')
        .gt('expires_at', DateTime.now().toUtc().toIso8601String())
        .order('expires_at');
    return rows.map(PendingInvitation.fromJson).toList();
  }

  @override
  Future<String?> fetchMyPendingReference(String tournamentId, String userId) async {
    final row = await _client
        .from('tournament_registrations')
        .select('paystack_reference')
        .eq('tournament_id', tournamentId)
        .eq('player_id', userId)
        .eq('payment_status', 'pending')
        .maybeSingle();
    return row?['paystack_reference'] as String?;
  }
}
```

`lib/features/compete/registration_repository.dart` (thin, fake-able seam over `ApiClient`):

```dart
import '../../core/api/api_client.dart';
import '../../core/api/compete_models.dart';

abstract class RegistrationRepository {
  Future<RegistrationState> registrationState(String tournamentId);
  Future<RegisterOutcome> register(String tournamentId,
      {required RegistrationDetails details, required int coinsUsed, required String idempotencyKey});
  Future<void> joinWaitlist(String tournamentId, {required RegistrationDetails details});
  Future<RegisterOutcome> acceptInvitation(String invitationId, {required String idempotencyKey});
  Future<void> declineInvitation(String invitationId);
  Future<PaymentStatus> paymentStatus(String reference);
}

class ApiRegistrationRepository implements RegistrationRepository {
  ApiRegistrationRepository(this._api);
  final ApiClient _api;

  @override
  Future<RegistrationState> registrationState(String id) => _api.getTournamentRegistrationState(id);

  @override
  Future<RegisterOutcome> register(String id,
          {required RegistrationDetails details, required int coinsUsed, required String idempotencyKey}) =>
      _api.postTournamentRegister(id, details: details, coinsUsed: coinsUsed, idempotencyKey: idempotencyKey);

  @override
  Future<void> joinWaitlist(String id, {required RegistrationDetails details}) =>
      _api.postTournamentWaitlist(id, details: details);

  @override
  Future<RegisterOutcome> acceptInvitation(String id, {required String idempotencyKey}) =>
      _api.postInvitationAccept(id, idempotencyKey: idempotencyKey);

  @override
  Future<void> declineInvitation(String id) => _api.postInvitationDecline(id);

  @override
  Future<PaymentStatus> paymentStatus(String reference) => _api.getPaymentStatus(reference);
}
```

`lib/features/compete/compete_providers.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/compete_models.dart';
import '../../core/providers.dart';
import 'compete_models.dart';
import 'compete_reads_repository.dart';
import 'registration_repository.dart';

final competeReadsRepositoryProvider =
    Provider<CompeteReadsRepository>((ref) => SupabaseCompeteReadsRepository(ref.watch(supabaseClientProvider)));

final registrationRepositoryProvider =
    Provider<RegistrationRepository>((ref) => ApiRegistrationRepository(ref.watch(apiClientProvider)));

class TournamentTabNotifier extends Notifier<TournamentTab> {
  @override
  TournamentTab build() => TournamentTab.all;
  void select(TournamentTab tab) => state = tab;
}

final tournamentTabProvider = NotifierProvider<TournamentTabNotifier, TournamentTab>(TournamentTabNotifier.new);

class GameFilterNotifier extends Notifier<String?> {
  @override
  String? build() => null;
  void select(String? slug) => state = slug;
}

final tournamentGameFilterProvider = NotifierProvider<GameFilterNotifier, String?>(GameFilterNotifier.new);

final competeTournamentProvider = FutureProvider.autoDispose.family<CompeteTournament, String>(
  (ref, id) => ref.watch(competeReadsRepositoryProvider).fetchTournament(id),
);

/// Public endpoint: works signed out (returns view `guest`). Re-read after any registration change
/// with `ref.invalidate(registrationStateProvider(id))`.
final registrationStateProvider = FutureProvider.autoDispose.family<RegistrationState, String>(
  (ref, id) => ref.watch(registrationRepositoryProvider).registrationState(id),
);

final gamesProvider = FutureProvider.autoDispose<List<GameSummary>>(
  (ref) => ref.watch(competeReadsRepositoryProvider).fetchGames(),
);

/// Empty when signed out — never queries with a null user.
final myInvitationsProvider = FutureProvider.autoDispose<List<PendingInvitation>>((ref) async {
  final me = ref.watch(meProvider).asData?.value;
  if (me == null) return const [];
  return ref.watch(competeReadsRepositoryProvider).fetchMyPendingInvitations(me.id);
});
```

Note: `RegistrationState` is exported from `core/api/compete_models.dart`; `compete_models.dart` in the feature folder has different classes — the two files have distinct names of types, so both imports coexist. If the analyzer reports an ambiguous-import lint, add `as api` to one import.

- [ ] **Step 7: Paged list provider (append to `compete_providers.dart`)**

The list needs "load more" without an infinite-scroll dependency:

```dart
class TournamentListState {
  const TournamentListState({this.items = const [], this.page = 0, this.hasMore = true, this.loadingMore = false, this.loadMoreFailed = false});
  final List<CompeteTournament> items;
  final int page;
  final bool hasMore;
  final bool loadingMore;
  final bool loadMoreFailed;
  TournamentListState copyWith({List<CompeteTournament>? items, int? page, bool? hasMore, bool? loadingMore, bool? loadMoreFailed}) =>
      TournamentListState(
        items: items ?? this.items,
        page: page ?? this.page,
        hasMore: hasMore ?? this.hasMore,
        loadingMore: loadingMore ?? this.loadingMore,
        loadMoreFailed: loadMoreFailed ?? this.loadMoreFailed,
      );
}

/// Rebuilds (and reloads page 1) whenever the tab or game filter changes.
class TournamentListNotifier extends AsyncNotifier<TournamentListState> {
  @override
  Future<TournamentListState> build() async {
    final tab = ref.watch(tournamentTabProvider);
    final game = ref.watch(tournamentGameFilterProvider);
    final rows = await ref.read(competeReadsRepositoryProvider).fetchTournaments(tab: tab, gameSlug: game, page: 1);
    return TournamentListState(items: rows, page: 1, hasMore: rows.length == kTournamentPageSize);
  }

  Future<void> loadMore() async {
    final cur = state.asData?.value;
    if (cur == null || !cur.hasMore || cur.loadingMore) return;
    state = AsyncData(cur.copyWith(loadingMore: true, loadMoreFailed: false));
    try {
      final rows = await ref.read(competeReadsRepositoryProvider).fetchTournaments(
            tab: ref.read(tournamentTabProvider),
            gameSlug: ref.read(tournamentGameFilterProvider),
            page: cur.page + 1,
          );
      if (!ref.mounted) return;
      state = AsyncData(cur.copyWith(
        items: [...cur.items, ...rows],
        page: cur.page + 1,
        hasMore: rows.length == kTournamentPageSize,
        loadingMore: false,
      ));
    } catch (_) {
      if (!ref.mounted) return;
      state = AsyncData(cur.copyWith(loadingMore: false, loadMoreFailed: true));
    }
  }
}

final tournamentListProvider = AsyncNotifierProvider.autoDispose<TournamentListNotifier, TournamentListState>(TournamentListNotifier.new);
```

- [ ] **Step 8: Fake reads + provider test** — `test/fakes/fake_compete_reads.dart`

```dart
import 'package:sentinelx_mobile/features/compete/compete_models.dart';
import 'package:sentinelx_mobile/features/compete/compete_reads_repository.dart';

class FakeCompeteReads implements CompeteReadsRepository {
  FakeCompeteReads({this.tournaments = const [], this.games = const [], this.invitations = const [], this.pendingReference, this.failNextPage = false});

  List<CompeteTournament> tournaments;
  List<GameSummary> games;
  List<PendingInvitation> invitations;
  String? pendingReference;
  bool failNextPage;
  final pagesRequested = <int>[];
  final tabsRequested = <TournamentTab>[];
  final gamesRequested = <String?>[];

  @override
  Future<List<CompeteTournament>> fetchTournaments({required TournamentTab tab, String? gameSlug, int page = 1}) async {
    tabsRequested.add(tab);
    gamesRequested.add(gameSlug);
    pagesRequested.add(page);
    if (page > 1 && failNextPage) {
      failNextPage = false;
      throw Exception('boom');
    }
    final start = (page - 1) * kTournamentPageSize;
    if (start >= tournaments.length) return const [];
    return tournaments.skip(start).take(kTournamentPageSize).toList();
  }

  @override
  Future<CompeteTournament> fetchTournament(String id) async => tournaments.firstWhere((t) => t.id == id);

  @override
  Future<List<GameSummary>> fetchGames() async => games;

  @override
  Future<List<PendingInvitation>> fetchMyPendingInvitations(String userId) async => invitations;

  @override
  Future<String?> fetchMyPendingReference(String tournamentId, String userId) async => pendingReference;
}
```

`test/features/compete/tournament_list_provider_test.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/features/compete/compete_models.dart';
import 'package:sentinelx_mobile/features/compete/compete_providers.dart';
import 'package:sentinelx_mobile/features/compete/compete_reads_repository.dart';

import '../../fakes/fake_compete_reads.dart';
import '../../support/compete_fixtures.dart';

List<CompeteTournament> _many(int n) =>
    List.generate(n, (i) => CompeteTournament.fromJson(tournamentRow(id: 't$i', title: 'T$i')));

ProviderContainer _container(FakeCompeteReads fake) {
  final c = ProviderContainer(retry: (_, _) => null, overrides: [competeReadsRepositoryProvider.overrideWithValue(fake)]);
  addTearDown(c.dispose);
  return c;
}

void main() {
  test('loads page 1, then load more appends and stops on a short page', () async {
    final fake = FakeCompeteReads(tournaments: _many(kTournamentPageSize + 3));
    final c = _container(fake);
    final first = await c.read(tournamentListProvider.future);
    expect(first.items.length, kTournamentPageSize);
    expect(first.hasMore, isTrue);
    await c.read(tournamentListProvider.notifier).loadMore();
    final s = c.read(tournamentListProvider).requireValue;
    expect(s.items.length, kTournamentPageSize + 3);
    expect(s.hasMore, isFalse);
    await c.read(tournamentListProvider.notifier).loadMore(); // no-op, no third request
    expect(fake.pagesRequested, [1, 2]);
  });

  test('a failed load-more keeps the items, flags a retry and does not loop', () async {
    final fake = FakeCompeteReads(tournaments: _many(kTournamentPageSize + 3), failNextPage: true);
    final c = _container(fake);
    await c.read(tournamentListProvider.future);
    await c.read(tournamentListProvider.notifier).loadMore();
    var s = c.read(tournamentListProvider).requireValue;
    expect(s.items.length, kTournamentPageSize);
    expect(s.loadMoreFailed, isTrue);
    expect(fake.pagesRequested, [1, 2]);
    await c.read(tournamentListProvider.notifier).loadMore(); // explicit retry succeeds
    s = c.read(tournamentListProvider).requireValue;
    expect(s.items.length, kTournamentPageSize + 3);
    expect(s.loadMoreFailed, isFalse);
  });

  test('changing the tab or game reloads from page 1', () async {
    final fake = FakeCompeteReads(tournaments: _many(2));
    final c = _container(fake);
    await c.read(tournamentListProvider.future);
    c.read(tournamentTabProvider.notifier).select(TournamentTab.live);
    await c.read(tournamentListProvider.future);
    c.read(tournamentGameFilterProvider.notifier).select('fc-mobile');
    await c.read(tournamentListProvider.future);
    expect(fake.tabsRequested, [TournamentTab.all, TournamentTab.live, TournamentTab.live]);
    expect(fake.gamesRequested, [null, null, 'fc-mobile']);
    expect(fake.pagesRequested, [1, 1, 1]);
  });
}
```

- [ ] **Step 9: Run and commit**

Run: `flutter test test/features/compete`
Expected: PASS.

```bash
flutter analyze && flutter test
git checkout -- linux macos windows
git add lib/features/compete test/features/compete test/fakes test/support
git commit -m "feat(compete): T1 reads (tournaments, games, invitations), registration repository and providers"
```

---

### Task 4: Payment poller

**Files:**
- Create: `lib/features/compete/payment_poller.dart`, `test/features/compete/payment_poller_test.dart`

**Interfaces:**
- Produces:

```dart
enum PollResult { paid, notConfirmed }
typedef PollDelay = Future<void> Function(Duration d);
Future<PollResult> pollPayment(
  Future<PaymentStatus> Function() check, {
  PollDelay delay = _realDelay,
  Duration budget = const Duration(seconds: 60),
  List<Duration> backoff = defaultBackoff,
});
const List<Duration> defaultBackoff = [1s, 2s, 3s, 5s, 5s, 8s, 8s, 13s, 15s]; // sums to 60s
```

Semantics: call `check` first; `confirmed`/`alreadyPaid` → `paid`. `notFound`/`notSuccessful` and **thrown errors** keep polling (a transient network blip must not abort a payment poll). After the elapsed total of the delays used reaches `budget`, return `notConfirmed`. Elapsed is counted from the delays actually awaited (not wall-clock), so tests with an instant fake delay are deterministic.

- [ ] **Step 1: Write the failing tests**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/core/api/compete_models.dart';
import 'package:sentinelx_mobile/features/compete/payment_poller.dart';

void main() {
  final waited = <Duration>[];
  Future<void> fakeDelay(Duration d) async => waited.add(d);
  setUp(waited.clear);

  test('returns paid immediately when the first check confirms', () async {
    final r = await pollPayment(() async => PaymentStatus.confirmed, delay: fakeDelay);
    expect(r, PollResult.paid);
    expect(waited, isEmpty);
  });

  test('already_paid counts as paid', () async {
    expect(await pollPayment(() async => PaymentStatus.alreadyPaid, delay: fakeDelay), PollResult.paid);
  });

  test('keeps polling through not_successful then succeeds', () async {
    var n = 0;
    final r = await pollPayment(
      () async => ++n < 3 ? PaymentStatus.notSuccessful : PaymentStatus.confirmed,
      delay: fakeDelay,
    );
    expect(r, PollResult.paid);
    expect(n, 3);
    expect(waited.length, 2);
  });

  test('gives up as notConfirmed once the delay budget is spent, never reporting paid', () async {
    var n = 0;
    final r = await pollPayment(() async {
      n++;
      return PaymentStatus.notSuccessful;
    }, delay: fakeDelay);
    expect(r, PollResult.notConfirmed);
    final total = waited.fold<Duration>(Duration.zero, (a, b) => a + b);
    expect(total, lessThanOrEqualTo(const Duration(seconds: 60)));
    expect(n, waited.length + 1);
  });

  test('thrown errors (network blips) are retried, not fatal', () async {
    var n = 0;
    final r = await pollPayment(() async {
      if (++n < 3) throw Exception('offline');
      return PaymentStatus.confirmed;
    }, delay: fakeDelay);
    expect(r, PollResult.paid);
  });

  test('not_found for the whole budget is notConfirmed', () async {
    expect(await pollPayment(() async => PaymentStatus.notFound, delay: fakeDelay), PollResult.notConfirmed);
  });
}
```

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/features/compete/payment_poller_test.dart`
Expected: FAIL (file not found).

- [ ] **Step 3: Implement**

```dart
import '../../core/api/compete_models.dart';

enum PollResult { paid, notConfirmed }

typedef PollDelay = Future<void> Function(Duration d);

const List<Duration> defaultBackoff = [
  Duration(seconds: 1),
  Duration(seconds: 2),
  Duration(seconds: 3),
  Duration(seconds: 5),
  Duration(seconds: 5),
  Duration(seconds: 8),
  Duration(seconds: 8),
  Duration(seconds: 13),
  Duration(seconds: 15),
];

Future<void> _realDelay(Duration d) => Future<void>.delayed(d);

/// Polls `GET /payments/{reference}` (via [check]) until paid or the ~60 s [budget] of waiting is spent.
/// The Paystack webhook is the source of truth; this only decides what the UI may say.
Future<PollResult> pollPayment(
  Future<PaymentStatus> Function() check, {
  PollDelay delay = _realDelay,
  Duration budget = const Duration(seconds: 60),
  List<Duration> backoff = defaultBackoff,
}) async {
  var spent = Duration.zero;
  var i = 0;
  while (true) {
    try {
      if ((await check()).isPaid) return PollResult.paid;
    } catch (_) {
      // Transient failure: keep polling within the budget.
    }
    final next = backoff[i < backoff.length ? i : backoff.length - 1];
    if (spent + next > budget) return PollResult.notConfirmed;
    await delay(next);
    spent += next;
    i++;
  }
}
```

- [ ] **Step 4: Run and commit**

Run: `flutter test test/features/compete/payment_poller_test.dart`
Expected: PASS.

```bash
flutter analyze && flutter test
git checkout -- linux macos windows
git add lib/features/compete/payment_poller.dart test/features/compete/payment_poller_test.dart
git commit -m "feat(compete): payment poller with backoff and a hard 60s budget"
```

---

### Task 5: `RegistrationFlow` — key policy, submit, poll

**Files:**
- Create: `lib/features/compete/registration_flow.dart`, `test/features/compete/registration_flow_test.dart`, `test/fakes/fake_registration_repository.dart`

**Interfaces:**
- Consumes: `RegistrationRepository`, `pollPayment`, `newIdempotencyKey`, `paystackCheckoutProvider` (Task 7 — this task defines the seam type in `registration_flow.dart` so Task 7 only supplies the implementation).
- Produces:

```dart
enum FlowPhase { idle, submitting, awaitingPayment, confirming, confirmed, waitlisted, notConfirmed, cancelled, failed }

class FlowState {
  final FlowPhase phase;
  final String? errorCode;               // set when phase == failed
  final Map<String, String> fieldErrors; // from ApiException.fields
  final bool needsUsername;              // errorCode == 'needs_username'
}

typedef PaystackLauncher = Future<bool> Function(String authorizationUrl);
// true  = the checkout page reached the callback URL; false = user closed the window
final paystackLauncherProvider = Provider<PaystackLauncher>((ref) => throw UnimplementedError());
final registrationFlowProvider = NotifierProvider.autoDispose.family<RegistrationFlow, FlowState, String>(RegistrationFlow.new);
// family arg = tournamentId, or 'invitation:<id>' — see submitInvitation

class RegistrationFlow extends Notifier<FlowState> {
  Future<void> submitRegister(RegistrationDetails details, {int coinsUsed = 0});
  Future<void> submitWaitlist(RegistrationDetails details);
  Future<void> submitInvitationAccept(String invitationId);
  void reset();                          // back to idle; mints a fresh key
  String get currentKey;                 // visible for tests
}
```

Key policy (implement exactly): `_key` is created lazily and cleared by `_mintNew()`. On submit: `_key ??= newIdempotencyKey()`. After a response:
- success (`confirmed` or `pending`) → `_key = null` (attempt finished; a later manual restart is a new attempt),
- `ApiException` with `code == 'network'` or `code == 'idempotency_in_progress'` → **keep** `_key`,
- any other `ApiException` → `_key = null`.
A re-entrant `submit*` while `phase == submitting | awaitingPayment | confirming` is ignored (double-tap guard).

Outcome handling for register/accept:
- `RegisterConfirmed` → `confirmed`.
- `RegisterPending(url, reference)` → phase `awaitingPayment`; `launched = await launcher(url)`; if `false` → run **one** `paymentStatus(reference)` check (the user may have paid then backed out); paid → `confirmed`, else `cancelled`. If `true` → phase `confirming`; `pollPayment(() => repo.paymentStatus(reference))` → `paid` ⇒ `confirmed`; `notConfirmed` ⇒ `notConfirmed`. On `confirmed` also `ref.invalidate(registrationStateProvider(tournamentId))`.
- Waitlist success → `waitlisted` (+ invalidate).
- `ApiException`: `status == 401` → `failed` with code `'unauthorized'`; else `failed` with `e.code`, `fieldErrors: e.fields`, `needsUsername: e.code == 'needs_username'`. Any other exception type → `failed` with `'network'`.
- The notifier must check `ref.mounted` after every `await` before writing state.

- [ ] **Step 1: Fake repository** — `test/fakes/fake_registration_repository.dart`

```dart
import 'package:sentinelx_mobile/core/api/compete_models.dart';
import 'package:sentinelx_mobile/features/compete/registration_repository.dart';

class FakeRegistrationRepository implements RegistrationRepository {
  final registerKeys = <String>[];
  final acceptKeys = <String>[];
  final waitlistCalls = <RegistrationDetails>[];
  final paymentChecks = <String>[];
  final registerCoins = <int>[];

  /// Queue of results for register(); each entry is a RegisterOutcome or an Exception to throw.
  final registerResults = <Object>[];
  final acceptResults = <Object>[];
  Object? waitlistResult;
  final paymentResults = <Object>[]; // PaymentStatus or Exception; last one repeats
  Object? stateResult;
  Future<void>? registerGate; // when set, register() awaits it (to hold a request in flight)

  Object _next(List<Object> q) => q.length > 1 ? q.removeAt(0) : q.first;

  @override
  Future<RegistrationState> registrationState(String tournamentId) async {
    final r = stateResult;
    if (r is Exception) throw r;
    return (r as RegistrationState?) ??
        const RegistrationState(view: RegView.canRegister, feeNaira: 500, hasWaiver: false, coinDiscountEligible: true, agreementRequired: true);
  }

  @override
  Future<RegisterOutcome> register(String tournamentId,
      {required RegistrationDetails details, required int coinsUsed, required String idempotencyKey}) async {
    registerKeys.add(idempotencyKey);
    registerCoins.add(coinsUsed);
    if (registerGate != null) await registerGate;
    final r = _next(registerResults);
    if (r is Exception) throw r;
    return r as RegisterOutcome;
  }

  @override
  Future<void> joinWaitlist(String tournamentId, {required RegistrationDetails details}) async {
    waitlistCalls.add(details);
    final r = waitlistResult;
    if (r is Exception) throw r;
  }

  @override
  Future<RegisterOutcome> acceptInvitation(String invitationId, {required String idempotencyKey}) async {
    acceptKeys.add(idempotencyKey);
    final r = _next(acceptResults);
    if (r is Exception) throw r;
    return r as RegisterOutcome;
  }

  @override
  Future<void> declineInvitation(String invitationId) async {}

  @override
  Future<PaymentStatus> paymentStatus(String reference) async {
    paymentChecks.add(reference);
    final r = _next(paymentResults);
    if (r is Exception) throw r;
    return r as PaymentStatus;
  }
}
```

- [ ] **Step 2: Write the failing tests** — `test/features/compete/registration_flow_test.dart`

```dart
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/core/api/api_client.dart';
import 'package:sentinelx_mobile/core/api/compete_models.dart';
import 'package:sentinelx_mobile/features/compete/compete_providers.dart';
import 'package:sentinelx_mobile/features/compete/registration_flow.dart';

import '../../fakes/fake_registration_repository.dart';

const _details = RegistrationDetails(displayName: 'Ada', whatsapp: '+2348012345678', clubName: 'FC Ada', agreedToRules: true);
const _pending = RegisterPending(authorizationUrl: 'https://pay.test/a', reference: 'ref-1');

ApiException _err(int status, String code, {Map<String, String> fields = const {}}) =>
    ApiException(status: status, code: code, message: 'x', fields: fields);

class _Rig {
  _Rig({bool launcherReturns = true, this.instantPolls = true}) : repo = FakeRegistrationRepository() {
    container = ProviderContainer(retry: (_, _) => null, overrides: [
      registrationRepositoryProvider.overrideWithValue(repo),
      paystackLauncherProvider.overrideWithValue((url) async {
        launched.add(url);
        return launcherReturns;
      }),
      pollDelayProvider.overrideWithValue((_) async {}),
    ]);
  }
  final FakeRegistrationRepository repo;
  late final ProviderContainer container;
  final launched = <String>[];
  final bool instantPolls;
  RegistrationFlow get flow => container.read(registrationFlowProvider('t1').notifier);
  FlowState get state => container.read(registrationFlowProvider('t1'));
}

void main() {
  test('zero-fee / waiver path: confirmed, no checkout opened', () async {
    final r = _Rig();
    addTearDown(r.container.dispose);
    r.repo.registerResults.add(const RegisterConfirmed());
    await r.flow.submitRegister(_details);
    expect(r.state.phase, FlowPhase.confirmed);
    expect(r.launched, isEmpty);
  });

  test('pending → checkout → poll paid → confirmed, coins forwarded', () async {
    final r = _Rig();
    addTearDown(r.container.dispose);
    r.repo.registerResults.add(_pending);
    r.repo.paymentResults.add(PaymentStatus.confirmed);
    await r.flow.submitRegister(_details, coinsUsed: 500);
    expect(r.launched, ['https://pay.test/a']);
    expect(r.repo.registerCoins, [500]);
    expect(r.repo.paymentChecks, ['ref-1']);
    expect(r.state.phase, FlowPhase.confirmed);
  });

  test('checkout returns but payment never confirms → notConfirmed, never confirmed', () async {
    final r = _Rig();
    addTearDown(r.container.dispose);
    r.repo.registerResults.add(_pending);
    r.repo.paymentResults.add(PaymentStatus.notSuccessful);
    await r.flow.submitRegister(_details);
    expect(r.state.phase, FlowPhase.notConfirmed);
  });

  test('user closes the checkout: one status check; unpaid → cancelled', () async {
    final r = _Rig(launcherReturns: false);
    addTearDown(r.container.dispose);
    r.repo.registerResults.add(_pending);
    r.repo.paymentResults.add(PaymentStatus.notSuccessful);
    await r.flow.submitRegister(_details);
    expect(r.state.phase, FlowPhase.cancelled);
    expect(r.repo.paymentChecks, ['ref-1']);
  });

  test('user closes the checkout but had already paid → confirmed', () async {
    final r = _Rig(launcherReturns: false);
    addTearDown(r.container.dispose);
    r.repo.registerResults.add(_pending);
    r.repo.paymentResults.add(PaymentStatus.alreadyPaid);
    await r.flow.submitRegister(_details);
    expect(r.state.phase, FlowPhase.confirmed);
  });

  group('Idempotency-Key policy', () {
    test('a network failure reuses the same key on retry', () async {
      final r = _Rig();
      addTearDown(r.container.dispose);
      r.repo.registerResults.addAll([_err(0, 'network'), const RegisterConfirmed()]);
      await r.flow.submitRegister(_details);
      expect(r.state.phase, FlowPhase.failed);
      expect(r.state.errorCode, 'network');
      await r.flow.submitRegister(_details);
      expect(r.repo.registerKeys.length, 2);
      expect(r.repo.registerKeys[0], r.repo.registerKeys[1]);
      expect(r.state.phase, FlowPhase.confirmed);
    });

    test('idempotency_in_progress (409) also reuses the key', () async {
      final r = _Rig();
      addTearDown(r.container.dispose);
      r.repo.registerResults.addAll([_err(409, 'idempotency_in_progress'), const RegisterConfirmed()]);
      await r.flow.submitRegister(_details);
      await r.flow.submitRegister(_details);
      expect(r.repo.registerKeys[0], r.repo.registerKeys[1]);
    });

    test('any other server error mints a NEW key for the next submit', () async {
      final r = _Rig();
      addTearDown(r.container.dispose);
      r.repo.registerResults.addAll([_err(409, 'tournament_full'), const RegisterConfirmed()]);
      await r.flow.submitRegister(_details);
      expect(r.state.errorCode, 'tournament_full');
      await r.flow.submitRegister(_details);
      expect(r.repo.registerKeys[0], isNot(r.repo.registerKeys[1]));
    });

    test('needs_username sets the flag and the resubmit uses a new key', () async {
      final r = _Rig();
      addTearDown(r.container.dispose);
      r.repo.registerResults.addAll([_err(400, 'needs_username'), const RegisterConfirmed()]);
      await r.flow.submitRegister(_details);
      expect(r.state.needsUsername, isTrue);
      await r.flow.submitRegister(_details);
      expect(r.repo.registerKeys[0], isNot(r.repo.registerKeys[1]));
    });

    test('a finished attempt does not leak its key into a later attempt', () async {
      final r = _Rig();
      addTearDown(r.container.dispose);
      r.repo.registerResults.addAll([const RegisterConfirmed(), const RegisterConfirmed()]);
      await r.flow.submitRegister(_details);
      r.flow.reset();
      await r.flow.submitRegister(_details);
      expect(r.repo.registerKeys[0], isNot(r.repo.registerKeys[1]));
    });
  });

  test('a second tap while the first request is in flight is ignored', () async {
    final r = _Rig();
    addTearDown(r.container.dispose);
    final gate = Completer<void>();
    r.repo.registerGate = gate.future;
    r.repo.registerResults.add(const RegisterConfirmed());
    final first = r.flow.submitRegister(_details);
    await Future<void>.delayed(Duration.zero);
    await r.flow.submitRegister(_details); // ignored
    gate.complete();
    await first;
    expect(r.repo.registerKeys.length, 1);
  });

  test('401 maps to the unauthorized code; field errors are kept', () async {
    final r = _Rig();
    addTearDown(r.container.dispose);
    r.repo.registerResults.add(_err(401, 'whatever'));
    await r.flow.submitRegister(_details);
    expect(r.state.errorCode, 'unauthorized');

    final r2 = _Rig();
    addTearDown(r2.container.dispose);
    r2.repo.registerResults.add(_err(400, 'validation_failed', fields: {'whatsapp': 'bad'}));
    await r2.flow.submitRegister(_details);
    expect(r2.state.fieldErrors, {'whatsapp': 'bad'});
  });

  test('a non-API exception becomes a network failure and keeps the key', () async {
    final r = _Rig();
    addTearDown(r.container.dispose);
    r.repo.registerResults.addAll([Exception('socket'), const RegisterConfirmed()]);
    await r.flow.submitRegister(_details);
    expect(r.state.errorCode, 'network');
    await r.flow.submitRegister(_details);
    expect(r.repo.registerKeys[0], r.repo.registerKeys[1]);
  });

  test('waitlist: success → waitlisted, no key involved; error → failed', () async {
    final r = _Rig();
    addTearDown(r.container.dispose);
    await r.flow.submitWaitlist(_details);
    expect(r.state.phase, FlowPhase.waitlisted);
    expect(r.repo.waitlistCalls.length, 1);
    r.flow.reset();
    r.repo.waitlistResult = _err(409, 'already_on_waitlist');
    await r.flow.submitWaitlist(_details);
    expect(r.state.errorCode, 'already_on_waitlist');
  });

  test('invitation accept uses the key policy and the same outcomes', () async {
    final r = _Rig();
    addTearDown(r.container.dispose);
    r.repo.acceptResults.addAll([_err(0, 'network'), const RegisterConfirmed()]);
    await r.flow.submitInvitationAccept('inv1');
    await r.flow.submitInvitationAccept('inv1');
    expect(r.repo.acceptKeys[0], r.repo.acceptKeys[1]);
    expect(r.state.phase, FlowPhase.confirmed);
  });
}
```

- [ ] **Step 3: Run to verify failure**

Run: `flutter test test/features/compete/registration_flow_test.dart`
Expected: FAIL (`registration_flow.dart` not found).

- [ ] **Step 4: Implement `lib/features/compete/registration_flow.dart`**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/api/compete_models.dart';
import '../../core/utils/idempotency_key.dart';
import 'compete_providers.dart';
import 'payment_poller.dart';

enum FlowPhase { idle, submitting, awaitingPayment, confirming, confirmed, waitlisted, notConfirmed, cancelled, failed }

class FlowState {
  const FlowState({this.phase = FlowPhase.idle, this.errorCode, this.fieldErrors = const {}});

  final FlowPhase phase;
  final String? errorCode;
  final Map<String, String> fieldErrors;

  bool get needsUsername => errorCode == 'needs_username';
  bool get busy => phase == FlowPhase.submitting || phase == FlowPhase.awaitingPayment || phase == FlowPhase.confirming;
}

/// Opens Paystack checkout. Completes `true` when the page reached the callback URL, `false` when the
/// user closed the window first. Supplied by Task 7; tests override it.
typedef PaystackLauncher = Future<bool> Function(String authorizationUrl);

final paystackLauncherProvider = Provider<PaystackLauncher>((ref) => throw UnimplementedError('Override paystackLauncherProvider'));

/// Overridden in tests so polling does not really wait.
final pollDelayProvider = Provider<PollDelay>((ref) => (d) => Future<void>.delayed(d));

/// Family argument: the tournament id (registration / waitlist) — the registration state of that
/// tournament is refreshed on success. Invitation accepts pass the invitation's tournament id too.
final registrationFlowProvider =
    NotifierProvider.autoDispose.family<RegistrationFlow, FlowState, String>(RegistrationFlow.new);

class RegistrationFlow extends Notifier<FlowState> {
  RegistrationFlow(this.tournamentId);
  final String tournamentId;

  String? _key;

  @override
  FlowState build() => const FlowState();

  String get currentKey => _key ??= newIdempotencyKey();

  void reset() {
    _key = null;
    state = const FlowState();
  }

  Future<void> submitRegister(RegistrationDetails details, {int coinsUsed = 0}) => _run(() async {
        final key = currentKey;
        return ref.read(registrationRepositoryProvider).register(
              tournamentId,
              details: details,
              coinsUsed: coinsUsed,
              idempotencyKey: key,
            );
      });

  Future<void> submitInvitationAccept(String invitationId) => _run(() async {
        final key = currentKey;
        return ref.read(registrationRepositoryProvider).acceptInvitation(invitationId, idempotencyKey: key);
      });

  Future<void> submitWaitlist(RegistrationDetails details) async {
    if (state.busy) return;
    state = const FlowState(phase: FlowPhase.submitting);
    try {
      await ref.read(registrationRepositoryProvider).joinWaitlist(tournamentId, details: details);
      if (!ref.mounted) return;
      state = const FlowState(phase: FlowPhase.waitlisted);
      ref.invalidate(registrationStateProvider(tournamentId));
    } catch (e) {
      if (!ref.mounted) return;
      state = _failure(e);
    }
  }

  Future<void> _run(Future<RegisterOutcome> Function() call) async {
    if (state.busy) return;
    state = const FlowState(phase: FlowPhase.submitting);
    final RegisterOutcome outcome;
    try {
      outcome = await call();
    } catch (e) {
      if (!ref.mounted) return;
      // Same key only when the request may not have been processed; every real response, error or
      // not, is stored server-side under the key and would be replayed.
      final keepKey = e is! ApiException || e.code == 'network' || e.code == 'idempotency_in_progress';
      if (!keepKey) _key = null;
      state = _failure(e);
      return;
    }
    if (!ref.mounted) return;
    _key = null; // the attempt got an answer; a later manual restart is a new attempt

    switch (outcome) {
      case RegisterConfirmed():
        _finishConfirmed();
      case RegisterPending(:final authorizationUrl, :final reference):
        await _pay(authorizationUrl, reference);
    }
  }

  Future<void> _pay(String url, String reference) async {
    state = const FlowState(phase: FlowPhase.awaitingPayment);
    final repo = ref.read(registrationRepositoryProvider);
    final reachedCallback = await ref.read(paystackLauncherProvider)(url);
    if (!ref.mounted) return;

    if (!reachedCallback) {
      // Closed early: they may still have paid. One check, no polling.
      PaymentStatus? status;
      try {
        status = await repo.paymentStatus(reference);
      } catch (_) {}
      if (!ref.mounted) return;
      if (status != null && status.isPaid) {
        _finishConfirmed();
      } else {
        state = const FlowState(phase: FlowPhase.cancelled);
      }
      return;
    }

    state = const FlowState(phase: FlowPhase.confirming);
    final result = await pollPayment(() => repo.paymentStatus(reference), delay: ref.read(pollDelayProvider));
    if (!ref.mounted) return;
    if (result == PollResult.paid) {
      _finishConfirmed();
    } else {
      state = const FlowState(phase: FlowPhase.notConfirmed);
      ref.invalidate(registrationStateProvider(tournamentId));
    }
  }

  void _finishConfirmed() {
    state = const FlowState(phase: FlowPhase.confirmed);
    ref.invalidate(registrationStateProvider(tournamentId));
  }

  FlowState _failure(Object e) {
    if (e is ApiException) {
      final code = e.isUnauthorized ? 'unauthorized' : e.code;
      return FlowState(phase: FlowPhase.failed, errorCode: code, fieldErrors: e.fields);
    }
    return const FlowState(phase: FlowPhase.failed, errorCode: 'network');
  }
}
```

Test-rig note: `_Rig` in Step 2 has an unused `instantPolls` field; delete it if `flutter analyze` flags it. `pollDelayProvider` makes `pollPayment` instant in tests; the "checkout returns but never confirms" test exhausts the 60 s budget of delays instantly.

- [ ] **Step 5: Run and fix until green**

Run: `flutter test test/features/compete/registration_flow_test.dart`
Expected: PASS (13 tests). If "second tap ignored" hangs, confirm `state.busy` is set to `submitting` synchronously before the first `await` in `_run` (it is: the assignment precedes `call()`).

- [ ] **Step 6: Commit**

```bash
flutter analyze && flutter test
git checkout -- linux macos windows
git add lib/features/compete/registration_flow.dart test/features/compete/registration_flow_test.dart test/fakes/fake_registration_repository.dart
git commit -m "feat(compete): RegistrationFlow with idempotency-key policy, payment poll, double-tap guard"
```

---

### Task 6: Registration / waitlist sheet

**Files:**
- Create: `lib/features/compete/registration_sheet.dart`, `test/features/compete/registration_sheet_test.dart`, `test/support/pump_compete.dart`

**Interfaces:**
- Consumes: `registrationFlowProvider`, `registrationStateProvider`, `errorCopy`, `remoteConfigProvider`, `meProvider`, `RegistrationValidators` (defined here).
- Produces:

```dart
enum SheetMode { register, waitlist }

class RegistrationValidators {
  static bool displayName(String v);   // trimmed length 1..60
  static bool whatsapp(String v);      // ^\+?[0-9]{10,15}$  on the trimmed value
  static bool club(String v);          // trimmed length 1..60
  static bool ign(String v);           // trimmed length <= 60 (empty ok)
}

class RegistrationSheet extends ConsumerStatefulWidget {
  const RegistrationSheet({super.key, required this.tournament, required this.state, required this.mode, this.onNeedsUsername});
  final CompeteTournament tournament;
  final RegistrationState state;   // fee, waiver, coin eligibility, agreementRequired
  final SheetMode mode;
  final VoidCallback? onNeedsUsername;   // navigate to /onboarding/username
}
Future<void> showRegistrationSheet(BuildContext context, {required CompeteTournament tournament, required RegistrationState state, required SheetMode mode, VoidCallback? onNeedsUsername});
```

Behavior (from spec §6.3, exact):
- Fields: display name (prefilled from `meProvider` profile displayName), WhatsApp (prefilled from `whatsappNumber`), club, IGN (optional). Client validation mirrors the server regexes; server re-validates and its `fields` map (keys `displayName`, `whatsapp`, `clubName`, `ignTag`) is shown under the matching field.
- Rules checkbox shown **only when `state.agreementRequired`** (server's own conditional). When shown it must be ticked; `agreedToRules` is sent as the checkbox value. When not shown, `agreedToRules` is sent as `true` (the server's check only fires when rules exist — a `false` there is harmless and `true` is the value web's action sends; see risk note below).
- Coin picker only when `mode == register && state.coinDiscountEligible`: three radio options `0`, `coinsHalfEntry`, `coinsPerEntry` from remote config, label `cmpCoinsOption(coins, naira)` where `naira = (coins * nairaPerCoin).round()`. If remote config is unavailable (`null`) hide the picker.
- `state.hasWaiver && mode == register` → banner `cmpFeeWaived`, no coin picker.
- Submit button label: `cmpSubmitRegister` or `cmpSubmitWaitlist`; disabled while `flow.busy`; shows `cmpSubmitting`.
- Phase → UI: `confirmed` → close sheet + SnackBar `cmpPaySuccess` if fee > 0 else `cmpConfirmedFree`; `waitlisted` → close + SnackBar `cmpWaitlistJoined`; `confirming` → inline "cmpPayConfirming" with progress; `notConfirmed` → inline `cmpPayNotConfirmed` + close button; `cancelled` → inline `cmpPayCancelled`; `failed` → inline `errorCopy(...)`; if `needsUsername` → close the sheet and call `onNeedsUsername`.
- The sheet's `dispose` does **not** reset the flow while `busy` (a payment in progress survives the sheet closing); it resets when closed in a terminal phase.

Risk note (Review Focus #5): the web action's `agreedToRules` handling when `rules` is empty was not re-read for this plan. Task 6 Step 1 verifies it before coding.

- [ ] **Step 1: Verify the rules-agreement server rule (read-only, 2 minutes)**

```bash
findstr /n /c:"agreedToRules" /c:"rules_agreement_required" C:\Users\gorok\Videos\sentinelx\lib\tournaments\register-service.ts
```
Read the surrounding lines. Expected: the check is `if (tournament.rules && !input.agreedToRules) → rules_agreement_required`. If instead it is unconditional, then `agreementRequired: false` states must still send `true`, which this plan already does; if it is conditional the plan is also correct. Record which it is in the PR. If the check is something else, stop and adjust the "send `true` when hidden" rule.

- [ ] **Step 2: Test pump helper** — `test/support/pump_compete.dart`

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/core/l10n/gen/app_localizations.dart';

Future<void> pumpCompete(WidgetTester tester, Widget home, {List<Override> overrides = const [], Size size = const Size(375, 800)}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    retry: (_, _) => null,
    overrides: overrides,
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: home),
    ),
  ));
}
```

- [ ] **Step 3: Write the failing tests** — `test/features/compete/registration_sheet_test.dart`

Overrides used by every test: `registrationRepositoryProvider` (FakeRegistrationRepository), `paystackLauncherProvider` (records URL, returns true), `pollDelayProvider` (instant), `remoteConfigProvider` (a `RemoteConfig` with `coinsHalfEntry: 500, coinsPerEntry: 1000, nairaPerCoin: 0.5`; build it with `RemoteConfig.fromJson` using the same JSON map as `api_client_test.dart`'s `_configData`), `meProvider` (a `MeResponse` with a profile whose displayName `Ada` and whatsappNumber `+2348012345678`).

```dart
// Skeleton — helper names below are defined at the top of the test file.
void main() {
  testWidgets('validates before submitting: no request is made with a bad number', (tester) async {
    final env = await _pump(tester, mode: SheetMode.register, state: _canRegister());
    await tester.enterText(find.byKey(const Key('reg-whatsapp')), '123');
    await tester.enterText(find.byKey(const Key('reg-club')), 'FC Ada');
    await tester.tap(find.byKey(const Key('reg-agree')));
    await tester.tap(find.byKey(const Key('reg-submit')));
    await tester.pumpAndSettle();
    expect(find.text('Enter a valid WhatsApp number.'), findsOneWidget);
    expect(env.repo.registerKeys, isEmpty);
  });

  testWidgets('rules checkbox is required when agreementRequired, hidden when not', (tester) async {
    var env = await _pump(tester, mode: SheetMode.register, state: _canRegister());
    expect(find.byKey(const Key('reg-agree')), findsOneWidget);
    await _fill(tester);
    await tester.tap(find.byKey(const Key('reg-submit')));
    await tester.pumpAndSettle();
    expect(find.text('Please agree to the rules.'), findsOneWidget);
    expect(env.repo.registerKeys, isEmpty);

    env = await _pump(tester, mode: SheetMode.register, state: _canRegister(agreementRequired: false));
    expect(find.byKey(const Key('reg-agree')), findsNothing);
  });

  testWidgets('coin picker shows three options from remote config and forwards the choice', (tester) async {
    final env = await _pump(tester, mode: SheetMode.register, state: _canRegister(coins: true));
    expect(find.text("Don't use coins"), findsOneWidget);
    expect(find.text('500 coins (−₦250)'), findsOneWidget);
    expect(find.text('1000 coins (−₦500)'), findsOneWidget);
    await _fill(tester);
    await tester.tap(find.text('500 coins (−₦250)'));
    env.repo.registerResults.add(const RegisterConfirmed());
    await tester.tap(find.byKey(const Key('reg-submit')));
    await tester.pumpAndSettle();
    expect(env.repo.registerCoins, [500]);
  });

  testWidgets('no coin picker when ineligible or when a waiver applies; waiver banner shown', (tester) async {
    await _pump(tester, mode: SheetMode.register, state: _canRegister(coins: false));
    expect(find.text("Don't use coins"), findsNothing);
    await _pump(tester, mode: SheetMode.register, state: _canRegister(coins: false, waiver: true));
    expect(find.text('Free entry — waiver applied'), findsOneWidget);
  });

  testWidgets('waitlist mode: no coin picker, calls the waitlist endpoint, closes with a message', (tester) async {
    final env = await _pump(tester, mode: SheetMode.waitlist, state: _canRegister(coins: true));
    expect(find.text("Don't use coins"), findsNothing);
    await _fill(tester);
    await tester.tap(find.byKey(const Key('reg-submit')));
    await tester.pumpAndSettle();
    expect(env.repo.waitlistCalls.length, 1);
    expect(find.text("You're on the waitlist."), findsOneWidget);
  });

  testWidgets('a server error is shown as localized copy, not the server message; the button re-enables', (tester) async {
    final env = await _pump(tester, mode: SheetMode.register, state: _canRegister());
    env.repo.registerResults.add(const ApiException(status: 409, code: 'tournament_full', message: 'RAW SERVER TEXT'));
    await _fill(tester);
    await tester.tap(find.byKey(const Key('reg-submit')));
    await tester.pumpAndSettle();
    expect(find.text('This tournament is full.'), findsOneWidget);
    expect(find.text('RAW SERVER TEXT'), findsNothing);
    expect(tester.widget<FilledButton>(find.byKey(const Key('reg-submit'))).onPressed, isNotNull);
  });

  testWidgets('server field errors appear under the matching field', (tester) async {
    final env = await _pump(tester, mode: SheetMode.register, state: _canRegister());
    env.repo.registerResults.add(const ApiException(status: 400, code: 'validation_failed', message: 'x', fields: {'clubName': 'Club is required'}));
    await _fill(tester);
    await tester.tap(find.byKey(const Key('reg-submit')));
    await tester.pumpAndSettle();
    expect(find.text('Club is required'), findsOneWidget);
  });

  testWidgets('needs_username closes the sheet and calls onNeedsUsername', (tester) async {
    var routed = false;
    final env = await _pump(tester, mode: SheetMode.register, state: _canRegister(), onNeedsUsername: () => routed = true);
    env.repo.registerResults.add(const ApiException(status: 400, code: 'needs_username', message: 'x'));
    await _fill(tester);
    await tester.tap(find.byKey(const Key('reg-submit')));
    await tester.pumpAndSettle();
    expect(routed, isTrue);
  });

  testWidgets('paid flow: opens checkout with the URL, ends with the success snackbar', (tester) async {
    final env = await _pump(tester, mode: SheetMode.register, state: _canRegister());
    env.repo.registerResults.add(const RegisterPending(authorizationUrl: 'https://pay.test/a', reference: 'r1'));
    env.repo.paymentResults.add(PaymentStatus.confirmed);
    await _fill(tester);
    await tester.tap(find.byKey(const Key('reg-submit')));
    await tester.pumpAndSettle();
    expect(env.launched, ['https://pay.test/a']);
    expect(find.text("You're in! Payment confirmed."), findsOneWidget);
  });

  testWidgets('not confirmed after checkout says so and never claims success', (tester) async {
    final env = await _pump(tester, mode: SheetMode.register, state: _canRegister());
    env.repo.registerResults.add(const RegisterPending(authorizationUrl: 'https://pay.test/a', reference: 'r1'));
    env.repo.paymentResults.add(PaymentStatus.notSuccessful);
    await _fill(tester);
    await tester.tap(find.byKey(const Key('reg-submit')));
    await tester.pumpAndSettle();
    expect(find.textContaining("haven't seen your payment"), findsOneWidget);
    expect(find.textContaining('Payment confirmed'), findsNothing);
  });

  testWidgets('fits 375px with a 60-char display name and long club (no overflow)', (tester) async {
    await _pump(tester, mode: SheetMode.register, state: _canRegister(coins: true));
    await tester.enterText(find.byKey(const Key('reg-club')), 'C' * 60);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
```

Define in the same file: `_pump` (builds the override list above, pumps a button that calls `showRegistrationSheet(...)`, taps it, `pumpAndSettle`, returns an `_Env{repo, launched}`), `_fill` (enters valid WhatsApp `+2348012345678`, club `FC Ada`, ticks `reg-agree` if present), `_canRegister({bool coins = false, bool waiver = false, bool agreementRequired = true})` returning a `RegistrationState` with `feeNaira: 500`, `_tournament` from `tournamentRow()`. Widget keys the implementation must expose: `reg-display-name`, `reg-whatsapp`, `reg-club`, `reg-ign`, `reg-agree`, `reg-submit`.

- [ ] **Step 4: Run to verify failure**

Run: `flutter test test/features/compete/registration_sheet_test.dart`
Expected: FAIL (`registration_sheet.dart` not found).

- [ ] **Step 5: Implement `lib/features/compete/registration_sheet.dart`**

Requirements (all covered by Step 3's tests):
- `RegistrationValidators` exactly as in the Interfaces block (`RegExp(r'^\+?[0-9]{10,15}$')`).
- A `ConsumerStatefulWidget` with a `GlobalKey<FormState>`, four `TextEditingController`s (disposed in `dispose`), `_agreed`, `_coins` (int, default 0). Prefill in `initState` from `ref.read(meProvider).asData?.value?.profile` (guard nulls).
- Wrap content in `Padding(padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom))` inside a `SingleChildScrollView` so the keyboard never hides the submit button; `showModalBottomSheet(isScrollControlled: true, useSafeArea: true)`.
- `ref.listen(registrationFlowProvider(tournament.id), …)` handles the terminal phases: `confirmed`/`waitlisted` → `Navigator.of(context).pop()` then a `ScaffoldMessenger` SnackBar with the matching copy (capture the messenger **before** the pop); `failed && needsUsername` → pop then `widget.onNeedsUsername?.call()`.
- Inline status area (below the button) renders by phase: `confirming` → `LinearProgressIndicator` + `cmpPayConfirming`; `notConfirmed` → `cmpPayNotConfirmed`; `cancelled` → `cmpPayCancelled`; `failed` (not needs-username) → `errorCopy(l10n, code)`; field errors: `fieldErrors['displayName'|'whatsapp'|'clubName'|'ignTag']` shown as the `errorText` of the matching `TextFormField`.
- Client validator messages use the `cmpVal*` keys. Rules: when `state.agreementRequired && !_agreed` show `cmpValRules` (a `Text` under the checkbox, set by `_submit` — checkbox is not a FormField).
- `_submit`: run `_formKey.currentState!.validate()` and the rules check; on success call `flow.submitRegister(details, coinsUsed: _coins)` or `flow.submitWaitlist(details)`. Build details with trimmed values; `agreedToRules: state.agreementRequired ? _agreed : true`.
- Coin options built from `ref.watch(remoteConfigProvider).asData?.value` (hide when null); reset `_coins` to 0 when the picker is hidden.
- `PopScope`/`onClosing`: when the sheet is dismissed and the flow is **not busy**, call `ref.read(registrationFlowProvider(id).notifier).reset()`; if busy leave it running.
- Every button/field ≥ 48px tall (Material defaults); no fixed widths.

- [ ] **Step 6: Run and fix until green**

Run: `flutter test test/features/compete/registration_sheet_test.dart`
Expected: PASS (10 tests).

- [ ] **Step 7: Commit**

```bash
flutter analyze && flutter test
git checkout -- linux macos windows
git add lib/features/compete/registration_sheet.dart test/features/compete/registration_sheet_test.dart test/support/pump_compete.dart
git commit -m "feat(compete): registration and waitlist sheet with validation, coin picker and payment states"
```

---

### Task 7: Paystack checkout WebView

**Files:**
- Create: `lib/features/compete/paystack_checkout.dart`, `test/features/compete/paystack_checkout_test.dart`
- Modify: `lib/main.dart` or the place `ProviderScope` overrides are built — **only if** the launcher needs a `BuildContext`/`Navigator` (see Step 3); otherwise provide it through a provider that reads `routerProvider`.

**Interfaces:**
- Produces:

```dart
bool isPaystackCallback(Uri uri);   // path ends with /api/paystack/callback
class PaystackCheckoutScreen extends StatefulWidget { const PaystackCheckoutScreen({super.key, required this.authorizationUrl}); }
// Pops with `true` when the callback URL is reached, `false`/null when the user backs out.
Future<bool> openPaystackCheckout(BuildContext context, String authorizationUrl);
```

`registrationFlowProvider` needs a `PaystackLauncher` with no `BuildContext`. Supply it as: `paystackLauncherProvider.overrideWith((ref) => (url) => openPaystackCheckout(ref.read(rootNavigatorKeyProvider).currentContext!, url))` — this requires a root navigator key. Check whether `app_router.dart` already has one (`grep -n navigatorKey lib/router/app_router.dart lib/main.dart lib/app.dart`). It currently has none, so this task adds `final rootNavigatorKeyProvider = Provider((ref) => GlobalKey<NavigatorState>())` in `lib/core/providers.dart`, passes it as `navigatorKey:` to `GoRouter(...)` in `buildAppRouter` (new optional parameter `GlobalKey<NavigatorState>? navigatorKey`, wired from `routerProvider`), and overrides the launcher in `lib/app.dart`/`main.dart`'s `ProviderScope`. Locate the real file with `grep -rn "ProviderScope(" lib/`.

The callback rule: Paystack redirects the browser to `${SITE_URL}/api/paystack/callback?reference=…` (verified in the web repo, `register-service.ts:195`). The WebView **intercepts** that navigation and does not load it (the app polls `GET /payments/{reference}` instead; the callback route would only redirect to the website).

- [ ] **Step 1: Failing tests** — `test/features/compete/paystack_checkout_test.dart`

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/features/compete/paystack_checkout.dart';

void main() {
  test('recognizes the callback URL on the site host regardless of query and trailing slash', () {
    expect(isPaystackCallback(Uri.parse('https://sentinelxesports.com.ng/api/paystack/callback?reference=abc')), isTrue);
    expect(isPaystackCallback(Uri.parse('https://sentinelxesports.com.ng/api/paystack/callback/')), isTrue);
    expect(isPaystackCallback(Uri.parse('http://192.168.1.157:3000/api/paystack/callback?reference=abc&trxref=abc')), isTrue);
  });

  test('does not treat Paystack or lookalike URLs as the callback', () {
    expect(isPaystackCallback(Uri.parse('https://checkout.paystack.com/abc123')), isFalse);
    expect(isPaystackCallback(Uri.parse('https://checkout.paystack.com/api/paystack/callback')), isFalse);
    expect(isPaystackCallback(Uri.parse('https://sentinelxesports.com.ng/tournaments/x')), isFalse);
  });
}
```

Note on the second test: the second assertion means the check must be **host-restricted**: the host must not be a `paystack.com` domain. Implement as `path` matches AND `!host.endsWith('paystack.com')` (a callback on Paystack's own domain is never ours). The app does not know the site host in a pure function, so exclude by Paystack's domain rather than allow-listing ours (dev runs use a LAN IP).

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/features/compete/paystack_checkout_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement**

```dart
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../core/l10n/gen/app_localizations.dart';

bool isPaystackCallback(Uri uri) {
  final host = uri.host.toLowerCase();
  if (host == 'paystack.com' || host.endsWith('.paystack.com')) return false;
  final path = uri.path.endsWith('/') ? uri.path.substring(0, uri.path.length - 1) : uri.path;
  return path == '/api/paystack/callback';
}

class PaystackCheckoutScreen extends StatefulWidget {
  const PaystackCheckoutScreen({super.key, required this.authorizationUrl});
  final String authorizationUrl;

  @override
  State<PaystackCheckoutScreen> createState() => _PaystackCheckoutScreenState();
}

class _PaystackCheckoutScreenState extends State<PaystackCheckoutScreen> {
  late final WebViewController _controller;
  var _loading = true;
  var _done = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onPageFinished: (_) {
          if (mounted) setState(() => _loading = false);
        },
        onNavigationRequest: (request) {
          if (isPaystackCallback(Uri.parse(request.url))) {
            if (!_done && mounted) {
              _done = true;
              Navigator.of(context).pop(true);
            }
            return NavigationDecision.prevent;
          }
          return NavigationDecision.navigate;
        },
      ))
      ..loadRequest(Uri.parse(widget.authorizationUrl));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).appName),
        leading: IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.of(context).pop(false)),
      ),
      body: Stack(children: [
        WebViewWidget(controller: _controller),
        if (_loading) const Center(child: CircularProgressIndicator()),
      ]),
    );
  }
}

Future<bool> openPaystackCheckout(BuildContext context, String authorizationUrl) async {
  final result = await Navigator.of(context, rootNavigator: true).push<bool>(
    MaterialPageRoute(fullscreenDialog: true, builder: (_) => PaystackCheckoutScreen(authorizationUrl: authorizationUrl)),
  );
  return result ?? false;
}
```

Then wire the launcher (the `rootNavigatorKeyProvider` plan above) and add a smoke test that `buildAppRouter(navigatorKey: key)` accepts the key and existing router tests still pass (`flutter test test/router`).

- [ ] **Step 4: Run and commit**

Run: `flutter test test/features/compete/paystack_checkout_test.dart test/router`
Expected: PASS. (The WebView itself is exercised only in the joint device round — `webview_flutter` has no widget-test platform; that is a known limitation, recorded in Task 12's checklist.)

```bash
flutter analyze && flutter test
git checkout -- linux macos windows
git add lib test pubspec.yaml pubspec.lock
git commit -m "feat(compete): Paystack checkout WebView that intercepts the callback URL"
```

---

### Task 8: Tournament list and detail screens

**Files:**
- Create: `lib/features/compete/compete_list_screen.dart`, `lib/features/compete/compete_detail_screen.dart`, `test/features/compete/compete_list_screen_test.dart`, `test/features/compete/compete_detail_screen_test.dart`

**Interfaces:**
- Consumes: `tournamentListProvider`, `tournamentTabProvider`, `tournamentGameFilterProvider`, `gamesProvider`, `competeTournamentProvider`, `registrationStateProvider`, `showRegistrationSheet`, `competeReadsRepositoryProvider` (for the resume check), `meProvider`, `registrationRepositoryProvider`.
- Produces:

```dart
class CompeteListScreen extends ConsumerWidget {
  const CompeteListScreen({super.key, required this.onTournamentTap});
  final void Function(CompeteTournament t) onTournamentTap;
}
class CompeteDetailScreen extends ConsumerWidget {
  const CompeteDetailScreen({super.key, required this.tournamentId, required this.onViewBracket, required this.onLogin, required this.onNeedsUsername, required this.onViewInvitations});
}
```

**List behavior:** `SxTabAppBar`-free plain `AppBar(title: navTournaments)`. `SegmentedButton`/`TabBar`-style chips for the 4 tabs (`cmpTabAll/Live/Upcoming/Completed`); a horizontally scrolling `ChoiceChip` row for games (`cmpAllGames` + one per `gamesProvider` entry; hidden while games load/fail); rows show title, game name (omit when null), prize (`₦{prizePool}`), fee (`cmpFree` when 0 else `₦{fee}`), a status chip. `RefreshIndicator` re-runs `ref.invalidate(tournamentListProvider)`. End of list: a `cmpLoadMore` button while `hasMore` (`loadMoreFailed` shows `cmpRetry` styling); empty → `cmpEmpty`; error → `cmpLoadError` + `cmpRetry`.

**Detail behavior:** loads `competeTournamentProvider(id)` (error → `cmpLoadError` + retry; never a raw exception string) and `registrationStateProvider(id)` (its error must **not** hide the tournament — show details with a retry row where the CTA would be). Sections: banner image (skip when null, `errorBuilder` on `Image.network`), title, game, status, prizes (1st/2nd/3rd when set), fee (`cmpFree` when 0), `cmpMaxPlayers` when not null, description (when not null), rules (collapsed `ExpansionTile`, when not null), a "View bracket" button (`cmpViewBracket`, key `view-bracket-button` — kept from the old screen), WhatsApp share (`cmpShareWhatsapp`, opens `https://wa.me/?text=<urlencoded cmpShareText(title, '${siteUrl}/tournaments/${slug}')>` via `url_launcher`; `siteUrl` from `remoteConfigProvider`, hidden when null).

**CTA by `RegView` (exact, spec §6.4; key `reg-cta`):**

| view | UI |
|---|---|
| `guest` | button `cmpCtaLogin` → `onLogin` |
| `canRegister` | button `cmpCtaRegister` → register sheet (+ waiver banner text `cmpFeeWaived` above when `hasWaiver`) |
| `completePayment` | button `cmpCtaResume`. On tap: read own pending reference (`competeReadsRepositoryProvider.fetchMyPendingReference(id, me.id)`); if non-null call `registrationRepositoryProvider.paymentStatus(ref)`; if paid → `ref.invalidate(registrationStateProvider(id))`; else open the register sheet. Any error in the pre-check is swallowed → open the sheet |
| `registered` | text `cmpStateRegistered`, no button |
| `waitlisted` | text `cmpStateWaitlisted`, no button |
| `full` | text `cmpStateFull`, **no waitlist button** |
| `closed` | button `cmpCtaJoinWaitlist` → waitlist sheet |
| `ended` | text `cmpStateEnded` |
| `invitationOnly` | text `cmpStateInvitationOnly` + button `cmpViewInvitations` → `onViewInvitations` |

- [ ] **Step 1: Failing list tests** — `compete_list_screen_test.dart`

Using `FakeCompeteReads` + `pumpCompete`, cover: rows render title/game/prize/fee (`Free` for fee 0); a row with a null `games` join renders without a game line and without throwing; tapping a row calls `onTournamentTap` with that tournament; tapping the `Live` tab requests `TournamentTab.live` page 1 (assert `fake.tabsRequested.last`); tapping a game chip requests that slug; `Load more` appears only when 20 rows were returned and loads page 2; a failed page 2 keeps the rows and shows a retry; empty list → `No tournaments here yet.`; a thrown `fetchTournaments` → `Couldn't load this…` and no exception text; pull-to-refresh re-fetches (`fling` down on the list, `pagesRequested` grows); a 60-char title at 375px has no overflow (`tester.takeException()` is null).

- [ ] **Step 2: Failing detail tests** — `compete_detail_screen_test.dart`

Cover, with a `FakeRegistrationRepository` whose `stateResult` is set per test:
1. each of the nine views renders exactly the row's UI from the table above (nine small tests or one loop) — assert the presence/absence of `reg-cta`, and text;
2. `full` has **no** `Join waitlist` text (Review Focus #4);
3. `guest` tap calls `onLogin` and never calls `register` (`repo.registerKeys` empty);
4. `canRegister` tap opens the sheet (find `reg-submit`);
5. `closed` tap opens the sheet in waitlist mode (submit label `Join waitlist`);
6. `completePayment` with `fake.pendingReference == 'r1'` and `paymentResults: [confirmed]` does NOT open the sheet and refreshes state; with `notSuccessful` it opens the sheet; with a throwing `paymentStatus` it opens the sheet;
7. `invitationOnly` has no register button but a `View my invitations` button calling `onViewInvitations`;
8. registration-state failure still shows the tournament title and a retry;
9. null `rules` → no rules section; null `max_players` → no "players max" line; fee 0 → `Free`;
10. an unknown `view` string (state provider throws `FormatException`) → error row, no crash;
11. 375px, 300-char description: no overflow.

- [ ] **Step 3: Run to verify failure**

Run: `flutter test test/features/compete/compete_list_screen_test.dart test/features/compete/compete_detail_screen_test.dart`
Expected: FAIL (screens not found).

- [ ] **Step 4: Implement both screens to satisfy the behavior above**, using the widget keys in the test. Money formatting helper `String naira(int v) => '₦$v'` lives privately in each file (thousands separators are out of scope; the web shows the same plain integer). Dates are not shown in 2a except `registrationEnd` as `MaterialLocalizations.of(context).formatMediumDate(...)` when set.

- [ ] **Step 5: Run and commit**

Run: `flutter test test/features/compete`
Expected: PASS.

```bash
flutter analyze && flutter test
git checkout -- linux macos windows
git add lib/features/compete test/features/compete
git commit -m "feat(compete): tournament list and detail with server-driven registration CTA"
```

---

### Task 9: Invitations screen

**Files:**
- Create: `lib/features/compete/invitations_screen.dart`, `test/features/compete/invitations_screen_test.dart`

**Interfaces:**
- Consumes: `myInvitationsProvider`, `registrationFlowProvider(<tournamentId>)`, `registrationRepositoryProvider.declineInvitation`, `errorCopy`.
- Produces: `class InvitationsScreen extends ConsumerWidget { const InvitationsScreen({super.key}); }`

Behavior: `AppBar(cmpInvTitle)`; a list of pending invitations (title, `cmpInvExpires(date)`, fee or `cmpFree`), each with **Accept** (`cmpInvAccept`, key `inv-accept-<id>`) and **Decline** (`cmpInvDecline`, key `inv-decline-<id>`); empty → `cmpInvEmpty`. Accept → `registrationFlowProvider(inv.tournamentId).notifier.submitInvitationAccept(inv.id)` (same key policy, same Paystack launcher and poll); on `confirmed` → `ref.invalidate(myInvitationsProvider)` + SnackBar (`cmpPaySuccess` when fee > 0 else `cmpConfirmedFree`); `notConfirmed`/`cancelled` → SnackBar with those texts and the list stays (the invitation is claimed server-side but payment is pending — spec §5.5 message); `failed` → SnackBar `errorCopy`. Decline → `declineInvitation`, then invalidate + SnackBar `cmpInvDeclined`; errors → `errorCopy`. While an accept/decline is in flight that row's buttons are disabled (other rows are not). Signed out → the provider returns an empty list and the screen shows `cmpInvEmpty` (the route is only linked when signed in).

- [ ] **Step 1: Failing tests** (`FakeCompeteReads(invitations: [...])`, `FakeRegistrationRepository`, launcher + poll overrides):
  - lists invitations with expiry and fee; empty state text;
  - accept free invitation → repo got one `acceptKeys` entry; row disappears after refresh (fake returns an empty list on the second read — set `invitations = []` inside the accept fake via a callback, or call `ref.invalidate` after mutating `fake.invitations`);
  - accept paid invitation → launcher URL recorded, poll `confirmed` → success snackbar;
  - accept fails with network → snackbar `No connection…`; second tap reuses the **same** key (`acceptKeys[0] == acceptKeys[1]`);
  - accept fails with `invitation_expired` → `This invitation has expired.`; a second tap uses a **new** key;
  - decline calls `declineInvitation` once and shows `Invitation declined.`;
  - double-tapping Accept sends one request;
  - `invitation_no_longer_available`, `invitation_not_found` show their copy.

- [ ] **Step 2: Run to verify failure, implement, run again**

Run: `flutter test test/features/compete/invitations_screen_test.dart`
Expected: FAIL first, then PASS.

- [ ] **Step 3: Commit**

```bash
flutter analyze && flutter test
git checkout -- linux macos windows
git add lib/features/compete/invitations_screen.dart test/features/compete/invitations_screen_test.dart
git commit -m "feat(compete): season invitations screen with accept (idempotent) and decline"
```

---

### Task 10: Games list and profile editing

**Files:**
- Create: `lib/features/compete/games_screen.dart`, `lib/features/account/edit_profile_screen.dart`, `test/features/compete/games_screen_test.dart`, `test/features/account/edit_profile_screen_test.dart`
- Modify: `lib/core/providers.dart` (append `profileRepository`—see below) **or** call `ApiClient.patchMeProfile` through a small provider in `lib/features/account/profile_providers.dart` (create). Use the second: `final profileEditorProvider = Provider<Future<void> Function(ProfileEdit)>((ref) => (e) => ref.read(apiClientProvider).patchMeProfile(e));` so tests override one function.

**Games screen:** `AppBar(cmpGamesTitle)`, list of games from `gamesProvider` (icon via `Image.network` with `errorBuilder`, name), empty → `cmpGamesEmpty`, error → `cmpLoadError` + `cmpRetry`. Display-only (spec §6.6): no tap action.

**Edit profile screen:** fields display name (required, ≤60), username (only editable when not yet changed — the API only says "changed once"; the screen cannot know, so it always shows the field, labelled `cmpFieldUsername`, prefilled with the current username, and sends `''` when unchanged from the prefill — the server treats `''` as "no change"), WhatsApp (empty or `^\+?[0-9]{10,15}$`), country (≤60), bio (≤280 with a counter). Save → `profileEditor(ProfileEdit(...))`; success → `ref.invalidate(meProvider)` + SnackBar `cmpSaved` + pop; error codes `username_taken`, `username_locked`, `save_failed`, `network` mapped through `errorCopy`; validation messages use `cmpValDisplayName`, `cmpValWhatsapp`, `cmpValBio`, `cmpValCountry`. Button disabled while saving. Signed out → `SizedBox.shrink` (route is only linked when signed in).

- [ ] **Step 1: Failing tests**
  - games: renders names; empty; error shows `Couldn't load this…` (no exception text); a game with a null `icon_url` and one with a broken URL render without throwing;
  - edit profile: prefilled from `meProvider`; invalid WhatsApp blocks the call (`editor` never invoked); 281-char bio blocked; unchanged username is sent as `''`, changed username is sent verbatim; `username_taken` shows `That username is already taken.`; save disables the button while in flight (use a `Completer`); success invalidates `meProvider` (assert the fake `meProvider` is re-read — count builds) and pops.

- [ ] **Step 2: Run to verify failure, implement, run again**

Run: `flutter test test/features/compete/games_screen_test.dart test/features/account`
Expected: FAIL first, then PASS.

- [ ] **Step 3: Commit**

```bash
flutter analyze && flutter test
git checkout -- linux macos windows
git add lib test
git commit -m "feat(compete): games list and minimal profile editing"
```

---

### Task 11: Routes, deep links, entry points

**Files:**
- Modify: `lib/router/app_router.dart`, `lib/core/routing/web_links.dart`, `lib/features/home/home_screen.dart`, `lib/features/account/account_screen.dart`, `test/router/*`, `test/core/web_links_test.dart`, `test/features/home_screen_test.dart`, `test/features/account_screen_test.dart`, `test/features/tournament_list_screen_test.dart`, `test/features/tournament_detail_screen_test.dart`, `test/support/pump_app.dart`

Routes (added/changed only):

| Path | Change |
|---|---|
| `/tournaments` | builder → `CompeteListScreen(onTournamentTap: (t) => context.push('/tournaments/${t.id}'))` |
| `/tournaments/:id` | builder → `CompeteDetailScreen(tournamentId: id, onViewBracket: () => context.push('/tournaments/$id/bracket'), onLogin: () => context.push('/login'), onNeedsUsername: () => context.push('/onboarding/username'), onViewInvitations: () => context.push('/invitations'))` |
| `/tournaments/:id/bracket` | **unchanged** (old `BracketScreen`; Phase 2b replaces it) |
| `/invitations` | new, top-level (outside the tab shell), `InvitationsScreen()` |
| `/games` | new, top-level, `GamesScreen()` |
| `/account/profile` | new, under the Account branch, `EditProfileScreen()` |

`resolveWebLink`: `/games` → `/games`; `/dashboard/invitations`-style paths are **not** guessed — read the existing `web_links.dart` cases and the web dashboard route names, and add only paths that exist on the web (check `app/[locale]/dashboard` folders). `/tournaments/<slug>` web links: the app routes by **id**, but web links carry a **slug**. Add a `resolveWebLink` case that keeps `/tournaments/<slug>` as `/tournaments/<slug>` only if the detail screen can load by slug. It cannot (it reads `.eq('id', …)`). **Decision for this task:** extend `SupabaseCompeteReadsRepository.fetchTournament` to accept either: if the argument matches a UUID regex use `.eq('id', …)`, else `.eq('slug', …)`; add a unit test for both branches with a recording fake `SupabaseClient` is heavy, so test the pure helper `bool looksLikeUuid(String)` (exported from `compete_reads_repository.dart`) instead, and cover the slug path in the device round. `registrationStateProvider(id)` must then use the **resolved tournament's id**, so the detail screen watches `competeTournamentProvider(idOrSlug)` first and passes `tournament.id` to the registration providers.

Entry points (append only): Home gets two tiles (`cmpHomeGamesTile` → `/games`, `cmpHomeInvitationsTile` → `/invitations`, the latter only when signed in — read how the 3b plan/`HomeScreen` decides signed-in state and mirror it); Account gets `cmpAccountEditProfile` → `/account/profile` (signed in only).

- [ ] **Step 1: Update the old slice's tests that pointed at the temporary screens**

`test/features/tournament_list_screen_test.dart` and `tournament_detail_screen_test.dart` test the **old** screens, which are no longer routed. Delete the two test files **and** the two old screen files `lib/features/tournaments/tournament_list_screen.dart`, `tournament_detail_screen.dart` (they have no other users — verify with `grep -rn "TournamentListScreen\|TournamentDetailScreen" lib test`). Keep `bracket_screen.dart`, `tournaments_providers.dart`'s `bracketProvider`, `lib/data`, `lib/models` (Phase 2b). Update `test/support/pump_app.dart`'s `pumpRouterWithRepo` only if a remaining test still needs it.

- [ ] **Step 2: Failing router tests** — extend `test/router/` (find the existing router test file with `ls test/router`) with: `/tournaments` renders `CompeteListScreen`; `/tournaments/t1` renders `CompeteDetailScreen`; `/invitations`, `/games`, `/account/profile` resolve; the bracket route still resolves. Add `web_links_test.dart` cases for `/games` (and slug detail links if you add them).

- [ ] **Step 3: Run to verify failure, implement, run again**

Run: `flutter test test/router test/core/web_links_test.dart test/features`
Expected: FAIL first, then PASS.

- [ ] **Step 4: Commit**

```bash
flutter analyze && flutter test
git checkout -- linux macos windows
git add lib test
git commit -m "feat(router): wire Compete 2a screens, invitations, games and profile edit; retire old list/detail"
```

---

### Task 12: Whole-branch verification and the deferred device checklist

**Files:**
- Create: `docs/agent-handoffs/2026-09-26-mobile-phase2a-flutter-notes.md` (untracked handoff note, same format as the 3b note)
- Modify: `TESTING-NOTES.md` (append the checklist below as "pending")

- [ ] **Step 1: Run the full gates**

```bash
flutter analyze
flutter test
```
Expected: no issues; all tests pass. Record the test count in the handoff note.

- [ ] **Step 2: Contract drift check**

```bash
fc api\openapi.json C:\Users\gorok\Videos\sentinelx\openapi\mobile-v1.json
```
Expected: "no differences". If they differ, re-copy from the newest web branch that has all seven 2a operations and re-run Step 1.

- [ ] **Step 3: Self-review against the spec**

Walk spec §6.1–§6.7 and §7 once with this plan open; list any deviation in the handoff note (the five "Open items" above are already known — add any new ones).

- [ ] **Step 4: Write the deferred device checklist into `TESTING-NOTES.md`** (do **not** run it now; the owner chose to build everything first and test on the phone later). Setup: staging Supabase + web dev server on the branch with Paystack **test** keys (see `docs/agent-handoffs/2026-09-25-mobile-phase3b-flutter-session-notes.md` for the exact staging launch command), a staging QA account with a `zzqa_` username.

  1. Browse: list tabs (All/Live/Upcoming/Completed), game filter, load more, open a tournament, open one **by web link slug**.
  2. Register — full price → Paystack test card → WebView closes on callback → "Payment confirmed" → state shows `registered`.
  3. Register with coin discount (half and full) → correct fee in Paystack / `confirmed` when discounted to zero.
  4. Register with a fee waiver (create one on staging) → `confirmed` with no WebView.
  5. Close the WebView mid-payment → "Payment window closed" → tournament shows `Resume payment` → resume works.
  6. Airplane-mode toggle during submit → retry uses the same key: confirm **one** `api_idempotency_keys` row and **one** registration row on staging.
  7. Signed out: `Log in to register`. Account with no username: routed to onboarding then registration succeeds with a **new** key.
  8. Full tournament: no waitlist button. Closed tournament: waitlist join works; second join shows "already on the waitlist".
  9. Invitations: accept (free and paid) and decline.
  10. Games list; edit profile (display name, bio, country, one-time username change; a second change shows the locked message).
  11. 375px screens: no overflow on any of the above.

- [ ] **Step 5: Write the handoff note** (`docs/agent-handoffs/2026-09-26-mobile-phase2a-flutter-notes.md`): where the worktree/branch is, HEAD, test counts, the five open items, what is verified vs. not (WebView and every live-server behavior are **not** verified), and "nothing pushed". Do not commit the note or the plan (they are untracked by repo convention — see `docs/agent-handoffs/README.md`). Commit only `TESTING-NOTES.md`:

```bash
git add TESTING-NOTES.md
git commit -m "docs: pending device checklist for Phase 2a"
```

- [ ] **Step 6: Report** the branch, HEAD, test counts and open items to the owner. **Do not push** and do not open a PR without the owner's OK.

---

## Self-review (run against the spec)

- **Spec coverage.** §6.1 list → Tasks 3, 8; §6.2 detail → Task 8 (entrants: omitted, open item 1); §6.3 wizard incl. key policy and `needs_username` → Tasks 5, 6; §6.4 nine views → Task 8; §6.5 invitations → Task 9; §6.6 games → Task 10; §6.7 settings → Task 10 (avatar upload deferred, open item 4); §4.3 header requirements → Tasks 1, 5; §5.1–§5.7 endpoints → Task 1; §7 exit criteria → Task 12 (live proofs deferred to the joint device round; idempotency server-side proofs belong to the web plan).
- **Placeholder scan.** No TODO/TBD. Two places describe UI by requirements plus tests rather than full widget code (Task 6 Step 5, Task 8 Step 4, and the small screens in Tasks 9–10); the tests in each task are complete and pin every behavior, and the state/logic layers (Tasks 1, 3, 4, 5) are fully coded. If the executor wants full widget code in the plan, ask before starting Task 6.
- **Type consistency.** `RegistrationState`/`RegView`/`RegisterOutcome`/`PaymentStatus`/`RegistrationDetails`/`ProfileEdit` (core/api/compete_models.dart) vs `CompeteTournament`/`GameSummary`/`PendingInvitation`/`TournamentTab` (features/compete/compete_models.dart) — distinct names, no collisions. `registrationFlowProvider` family arg is the tournament id everywhere (Tasks 5, 6, 8, 9). `paystackLauncherProvider` is defined in Task 5 and implemented in Task 7. `pollDelayProvider` is defined in Task 5 and used by tests in Tasks 6, 8, 9.
- **Review Focus coverage.** #1 → Task 5 tests; #2 → Tasks 4, 5, 6, 8; #3 → Tasks 5, 8; #4 → Task 8 test 2, 7; #5 → Tasks 3, 8.
