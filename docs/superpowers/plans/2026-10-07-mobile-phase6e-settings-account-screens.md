# Mobile Phase 6e — Settings and account completion (Flutter screens) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship the rest of Settings in the app: language (en/fr/pcm), security (change email, reset password), sign-in methods (link/unlink Google), phone verification (screen and onboarding gate), and account deletion (grace, cancel, delete now, app-wide banner).

**Architecture:** One `AccountRepository` seam over `ApiClient` carries the nine new operations; Riverpod providers (`myAccountProvider`, `localeProvider`) feed small screens under `lib/features/account/settings/`. Copy comes from the web `messages/*.json` through `tool/gen_l10n_from_web.dart`; Pidgin (`pcm`) is a new ARB locale with `en` fallbacks for the framework widgets and for date formatting. Screens never construct repositories; they read providers, like the rest of the app.

**Tech Stack:** Flutter, Dart, `flutter_riverpod` 3 (manual providers), `go_router`, `dio`, `supabase_flutter` (`linkIdentity`), `intl`, `flutter_test`.

**Spec:** web repo `C:\Users\gorok\Videos\sentinelx\docs\superpowers\specs\2026-10-07-mobile-phase6e-settings-account-design.md` (sections 3.2, 3.3, 3.6). **Web plan (must land first):** `C:\Users\gorok\Videos\sentinelx\docs\superpowers\plans\2026-10-07-mobile-phase6e-settings-account-web.md`. This plan consumes its contract (Tasks 7 and 7b) and its copy (Task 8).

## Global Constraints

- Work on branch `phase6e/settings-account` in this repo (from `master`); merge and push to `origin/master` when green (owner preference).
- `flutter analyze` and `flutter test` must both be clean before every commit; `flutter gen-l10n` after any `.arb` edit, and commit the generated output (`lib/core/l10n/gen/*`).
- **Never write via PostgREST;** every write goes through `ApiClient` -> `/api/mobile/v1/*`. Do not call `supabase.auth.updateUser` or `unlinkIdentity` from the app (they would skip the password re-auth, ban blocklist and deletion guards). The only direct Supabase auth call added here is `linkIdentity` (an auth operation the server cannot perform on the user's behalf).
- Server error text is never shown; screens map `ApiException.code` to ARB copy. Unknown codes map to the generic message.
- Copy is never hard-coded: add to the web `messages/*.json` first, then regenerate. Reused web namespaces: `accountDeletion`, `emailChange`, `signInMethods`; new namespace `mobileSettings` (web plan Task 8).
- Route map additions (update `CLAUDE.md` in Task 10): `/account/language`, `/account/security`, `/account/sign-in-methods`, `/account/phone`, `/account/delete`, `/onboarding/phone`.
- `enforce_phone_verification` is **not** flipped by this phase. `/onboarding/phone` ships; the owner flips the flag after an app version containing it is released.
- Production is the only database (the app points at it unless built against staging): deletion, email change and OTP tests run on **staging** with `zzqa_` accounts only, recorded in `TESTING-NOTES.md`.
- `permission_handler` is rejected (breaks the Android build on AGP 8.11.1); this plan needs no new permissions.
- Android application id is `ng.com.sentinelxesports.app`; the Google-link redirect is `ng.com.sentinelxesports.app://link-callback`.

## Review Focus

- Selecting **Pidgin** must not crash any existing screen: Community post dates, match dates and the Material widgets (text fields, pickers) all run under a locale intl and Material do not ship (`pcm`).
- A stale `/me.locale` arriving after the user picked a language must not flip the app back; a failed save must revert both the UI and the cached value.
- **Delete-now** ends signed out on `/login` even when the server has already deleted the auth user (so `signOut` may itself fail); a failed delete must keep the user signed in with the blockers shown.
- A **verified** user must never be sent to `/onboarding/phone` when the flag flips; an unverified one must be redirected from every route, and a non-gated user opening `/onboarding/phone` must be sent home.
- Phone code resend: a 429 `phone_cooldown` starts the countdown from the server's `retryAfterSeconds`; `phone_unavailable` shows the fixed "unavailable" message and no retry loop.
- The pending-deletion **banner must not rebuild the Navigator** when it appears or disappears (a changing widget-tree shape above the router would reset the navigation stack).
- Returning from the Google link browser round-trip, cancelled or failed, must leave the screen usable with no error flash; success refreshes the Google row.

---

### Task 1: Contract re-pin, account models, and `ApiClient` operations

**Files:**
- Modify: `api/openapi.json` (copy from the web repo), `lib/core/api/api_client.dart`, `lib/core/api/models.dart`
- Create: `lib/core/api/account_models.dart`
- Test: `test/core/account_models_test.dart`, `test/core/api_client_account_test.dart`, `test/core/api_contract_test.dart` (existing, must keep passing)

**Interfaces:**
- Consumes: web contract operations `getMyAccount`, `postAccountDeletion`, `deleteAccountDeletion`, `postAccountDeletionExecute`, `postPhoneCode`, `postPhoneConfirm`, `postMyEmail`, `deleteGoogleIdentity`, `putMyLocale`, plus `profile.phoneVerifiedAt` on `getMe`.
- Produces: `MyAccount`, `DeletionState`, `DeletionTicket`, `DeletionBlocker`, `AccountSignIn`, `AccountPhone`, `PhoneCodeTicket` (all in `account_models.dart`); `ApiException.details`; `ApiClient.getMyAccount()`, `postAccountDeletion()`, `deleteAccountDeletion()`, `postAccountDeletionExecute(String username)`, `postPhoneCode(String phone)`, `postPhoneConfirm(String code)`, `postMyEmail({required String email, required String password})`, `deleteGoogleIdentity(String password)`, `putMyLocale(String locale)`; `MeProfile.phoneVerifiedAt`.

- [ ] **Step 1: Re-pin the web contract**

Run (PowerShell): `Copy-Item C:\Users\gorok\Videos\sentinelx\openapi\mobile-v1.json api\openapi.json`
Then: `git diff --stat api/openapi.json` shows additions only (nine operations, `details` on `ApiError`, `phoneVerifiedAt`). If the web plan's Task 7b/7 are not merged yet, stop and finish them first.

- [ ] **Step 2: Write the failing model tests**

```dart
// test/core/account_models_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/core/api/account_models.dart';

void main() {
  test('MyAccount parses a full response', () {
    final a = MyAccount.fromJson({
      'deletion': {'requestedAt': '2026-10-05T00:00:00.000Z', 'dueAt': '2026-10-20T00:00:00.000Z', 'daysRemaining': 13},
      'signIn': {'email': 'a@b.com', 'pendingEmail': 'n@b.com', 'passwordIdentity': true, 'google': false},
      'phone': {'masked': '••••678', 'verifiedAt': '2026-10-01T00:00:00.000Z'},
      'locale': 'fr',
    });
    expect(a.deletion!.daysRemaining, 13);
    expect(a.deletion!.dueAt, DateTime.utc(2026, 10, 20));
    expect(a.signIn.pendingEmail, 'n@b.com');
    expect(a.signIn.passwordIdentity, isTrue);
    expect(a.signIn.google, isFalse);
    expect(a.phone!.masked, '••••678');
    expect(a.locale, 'fr');
  });

  test('MyAccount parses the empty case', () {
    final a = MyAccount.fromJson({
      'deletion': null,
      'signIn': {'email': null, 'pendingEmail': null, 'passwordIdentity': false, 'google': true},
      'phone': null,
      'locale': null,
    });
    expect(a.deletion, isNull);
    expect(a.phone, isNull);
    expect(a.signIn.email, isNull);
    expect(a.locale, isNull);
  });

  test('PhoneCodeTicket and DeletionTicket parse ISO times', () {
    expect(PhoneCodeTicket.fromJson({'expiresAt': '2026-10-07T10:10:00.000Z', 'resendAt': '2026-10-07T10:01:00.000Z'}).resendAt,
        DateTime.utc(2026, 10, 7, 10, 1));
    expect(DeletionTicket.fromJson({'requestedAt': '2026-10-07T00:00:00.000Z', 'dueAt': '2026-10-22T00:00:00.000Z'}).dueAt,
        DateTime.utc(2026, 10, 22));
  });

  test('DeletionBlocker keeps amount or count and ignores unknown codes gracefully', () {
    final list = DeletionBlocker.listFrom({
      'blockers': [
        {'code': 'wallet_balance', 'amount': 5000},
        {'code': 'pending_withdrawal', 'count': 2},
        {'code': 'something_new_from_the_server', 'count': 1},
      ],
    });
    expect(list.map((b) => b.code), ['wallet_balance', 'pending_withdrawal', 'something_new_from_the_server']);
    expect(list[0].amount, 5000);
    expect(list[1].count, 2);
  });

  test('DeletionBlocker.listFrom tolerates missing or malformed details', () {
    expect(DeletionBlocker.listFrom(const {}), isEmpty);
    expect(DeletionBlocker.listFrom({'blockers': 'nope'}), isEmpty);
    expect(DeletionBlocker.listFrom({'blockers': [1, null]}), isEmpty);
  });
}
```

- [ ] **Step 3: Run and confirm failure**

Run: `flutter test test/core/account_models_test.dart`
Expected: FAIL (file `account_models.dart` missing).

- [ ] **Step 4: Implement the models**

```dart
// lib/core/api/account_models.dart

DateTime _utc(String iso) => DateTime.parse(iso).toUtc();

class DeletionState {
  const DeletionState({required this.requestedAt, required this.dueAt, required this.daysRemaining});
  factory DeletionState.fromJson(Map<String, dynamic> j) => DeletionState(
        requestedAt: _utc(j['requestedAt'] as String),
        dueAt: _utc(j['dueAt'] as String),
        daysRemaining: (j['daysRemaining'] as num).toInt(),
      );
  final DateTime requestedAt;
  final DateTime dueAt;
  final int daysRemaining;
}

class DeletionTicket {
  const DeletionTicket({required this.requestedAt, required this.dueAt});
  factory DeletionTicket.fromJson(Map<String, dynamic> j) =>
      DeletionTicket(requestedAt: _utc(j['requestedAt'] as String), dueAt: _utc(j['dueAt'] as String));
  final DateTime requestedAt;
  final DateTime dueAt;
}

/// One reason an account cannot be deleted yet. [code] is open-ended: an unknown code from a newer server
/// is kept (the screen shows a generic line for it) rather than dropped.
class DeletionBlocker {
  const DeletionBlocker({required this.code, this.amount, this.count});
  final String code;
  final num? amount;
  final int? count;

  static List<DeletionBlocker> listFrom(Map<String, dynamic> details) {
    final raw = details['blockers'];
    if (raw is! List) return const [];
    return [
      for (final item in raw)
        if (item is Map<String, dynamic> && item['code'] is String)
          DeletionBlocker(
            code: item['code'] as String,
            amount: item['amount'] as num?,
            count: (item['count'] as num?)?.toInt(),
          ),
    ];
  }
}

class AccountSignIn {
  const AccountSignIn({required this.email, required this.pendingEmail, required this.passwordIdentity, required this.google});
  factory AccountSignIn.fromJson(Map<String, dynamic> j) => AccountSignIn(
        email: j['email'] as String?,
        pendingEmail: j['pendingEmail'] as String?,
        passwordIdentity: j['passwordIdentity'] as bool,
        google: j['google'] as bool,
      );
  final String? email;
  final String? pendingEmail;

  /// A hint, not truth: a Google user who set a password through the reset flow has no email identity.
  final bool passwordIdentity;
  final bool google;
}

class AccountPhone {
  const AccountPhone({required this.masked, required this.verifiedAt});
  factory AccountPhone.fromJson(Map<String, dynamic> j) =>
      AccountPhone(masked: j['masked'] as String, verifiedAt: _utc(j['verifiedAt'] as String));
  final String masked;
  final DateTime verifiedAt;
}

class MyAccount {
  const MyAccount({required this.deletion, required this.signIn, required this.phone, required this.locale});
  factory MyAccount.fromJson(Map<String, dynamic> j) => MyAccount(
        deletion: j['deletion'] == null ? null : DeletionState.fromJson(j['deletion'] as Map<String, dynamic>),
        signIn: AccountSignIn.fromJson(j['signIn'] as Map<String, dynamic>),
        phone: j['phone'] == null ? null : AccountPhone.fromJson(j['phone'] as Map<String, dynamic>),
        locale: j['locale'] as String?,
      );
  final DeletionState? deletion;
  final AccountSignIn signIn;
  final AccountPhone? phone;
  final String? locale;
}

class PhoneCodeTicket {
  const PhoneCodeTicket({required this.expiresAt, required this.resendAt});
  factory PhoneCodeTicket.fromJson(Map<String, dynamic> j) =>
      PhoneCodeTicket(expiresAt: _utc(j['expiresAt'] as String), resendAt: _utc(j['resendAt'] as String));
  final DateTime expiresAt;
  final DateTime resendAt;
}
```

Run: `flutter test test/core/account_models_test.dart`
Expected: PASS.

- [ ] **Step 5: Add `phoneVerifiedAt` to `MeProfile`** (failing test first)

Append to `test/core/onboarding_gate_test.dart` is Task 8's job; here add to the existing `MeProfile` parsing a test in `test/core/account_models_test.dart`:

```dart
// add import: import 'package:sentinelx_mobile/core/api/models.dart';
  test('MeProfile parses phoneVerifiedAt and tolerates its absence (older server)', () {
    Map<String, dynamic> base() => {
          'username': 'ada', 'displayName': null, 'avatarUrl': null, 'whatsappNumber': null, 'country': null, 'locale': 'en',
          'membershipTier': null, 'kycVerified': false, 'deletionRequestedAt': null, 'profileCompletedAt': null,
          'consentWhatsappUpdates': false, 'gameInterests': <dynamic>[], 'bubbleSkinUrl': null,
        };
    expect(MeProfile.fromJson(base()).phoneVerifiedAt, isNull);
    expect(MeProfile.fromJson({...base(), 'phoneVerifiedAt': '2026-10-01T00:00:00.000Z'}).phoneVerifiedAt, '2026-10-01T00:00:00.000Z');
  });
```

Run: `flutter test test/core/account_models_test.dart` -> FAIL (`phoneVerifiedAt` getter missing). Then in `lib/core/api/models.dart` `MeProfile`: add constructor param `this.phoneVerifiedAt,` (after `this.profileCompletedAt,`), `phoneVerifiedAt: j['phoneVerifiedAt'] as String?,` in `fromJson` (after `profileCompletedAt`), and field `final String? phoneVerifiedAt;` (after `profileCompletedAt`'s field). Run again -> PASS.

- [ ] **Step 6: Write the failing `ApiClient` tests**

```dart
// test/core/api_client_account_test.dart
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/core/api/account_models.dart';
import 'package:sentinelx_mobile/core/api/api_client.dart';

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

ResponseBody _json(int status, Object body) =>
    ResponseBody.fromString(jsonEncode(body), status, headers: {Headers.contentTypeHeader: [Headers.jsonContentType]});
ApiClient _client(_FakeAdapter a) =>
    ApiClient.create(baseUrl: 'https://api.test', appVersion: '1.0.0', platform: 'android', accessToken: () async => 'tok', adapter: a);
_FakeAdapter _ok(Object? data) => _FakeAdapter((_) => _json(200, {'data': data}));

void main() {
  test('getMyAccount: GET /me/account with the bearer, parsed', () async {
    final a = _ok({
      'deletion': null,
      'signIn': {'email': 'a@b.com', 'pendingEmail': null, 'passwordIdentity': true, 'google': false},
      'phone': null,
      'locale': 'en',
    });
    final acct = await _client(a).getMyAccount();
    expect(a.requests.single.method, 'GET');
    expect(a.requests.single.uri.path, '/api/mobile/v1/me/account');
    expect(a.requests.single.headers['Authorization'], 'Bearer tok');
    expect(acct.signIn.email, 'a@b.com');
  });

  test('postAccountDeletion sends the literal DELETE', () async {
    final a = _ok({'requestedAt': '2026-10-07T00:00:00.000Z', 'dueAt': '2026-10-22T00:00:00.000Z'});
    final t = await _client(a).postAccountDeletion();
    expect(a.requests.single.method, 'POST');
    expect(a.requests.single.uri.path, '/api/mobile/v1/me/deletion');
    expect(a.requests.single.data, {'confirm': 'DELETE'});
    expect(t.dueAt, DateTime.utc(2026, 10, 22));
  });

  test('deleteAccountDeletion: DELETE /me/deletion', () async {
    final a = _ok({'ok': true});
    await _client(a).deleteAccountDeletion();
    expect(a.requests.single.method, 'DELETE');
    expect(a.requests.single.uri.path, '/api/mobile/v1/me/deletion');
  });

  test('postAccountDeletionExecute sends the typed username', () async {
    final a = _ok({'ok': true});
    await _client(a).postAccountDeletionExecute('Rex');
    expect(a.requests.single.uri.path, '/api/mobile/v1/me/deletion/execute');
    expect(a.requests.single.data, {'username': 'Rex'});
  });

  test('postPhoneCode and postPhoneConfirm', () async {
    final a = _ok({'expiresAt': '2026-10-07T10:10:00.000Z', 'resendAt': '2026-10-07T10:01:00.000Z'});
    final ticket = await _client(a).postPhoneCode('08012345678');
    expect(a.requests.single.uri.path, '/api/mobile/v1/me/phone/code');
    expect(a.requests.single.data, {'phone': '08012345678'});
    expect(ticket.resendAt, DateTime.utc(2026, 10, 7, 10, 1));

    final b = _ok({'verifiedAt': '2026-10-07T10:02:00.000Z'});
    final at = await _client(b).postPhoneConfirm('123456');
    expect(b.requests.single.uri.path, '/api/mobile/v1/me/phone/confirm');
    expect(b.requests.single.data, {'code': '123456'});
    expect(at, DateTime.utc(2026, 10, 7, 10, 2));
  });

  test('postMyEmail returns sentTo', () async {
    final a = _ok({'sentTo': 'n@b.com'});
    final sentTo = await _client(a).postMyEmail(email: 'N@b.com', password: 'pw');
    expect(a.requests.single.uri.path, '/api/mobile/v1/me/email');
    expect(a.requests.single.data, {'email': 'N@b.com', 'password': 'pw'});
    expect(sentTo, 'n@b.com');
  });

  test('deleteGoogleIdentity sends the password in a DELETE body', () async {
    final a = _ok({'ok': true});
    await _client(a).deleteGoogleIdentity('pw');
    expect(a.requests.single.method, 'DELETE');
    expect(a.requests.single.uri.path, '/api/mobile/v1/me/identities/google');
    expect(a.requests.single.data, {'password': 'pw'});
  });

  test('putMyLocale', () async {
    final a = _ok({'locale': 'pcm'});
    expect(await _client(a).putMyLocale('pcm'), 'pcm');
    expect(a.requests.single.method, 'PUT');
    expect(a.requests.single.uri.path, '/api/mobile/v1/me/locale');
    expect(a.requests.single.data, {'locale': 'pcm'});
  });

  test('error envelopes surface code, fields and details', () async {
    final a = _FakeAdapter((_) => _json(409, {
          'error': {
            'code': 'deletion_blocked',
            'message': 'blocked',
            'details': {'blockers': [{'code': 'wallet_balance', 'amount': 5}]},
          },
        }));
    try {
      await _client(a).postAccountDeletion();
      fail('expected ApiException');
    } on ApiException catch (e) {
      expect(e.status, 409);
      expect(e.code, 'deletion_blocked');
      expect(DeletionBlocker.listFrom(e.details).single.code, 'wallet_balance');
    }
  });

  test('a 429 carries retryAfterSeconds in fields', () async {
    final a = _FakeAdapter((_) => _json(429, {'error': {'code': 'phone_cooldown', 'message': 'wait', 'fields': {'retryAfterSeconds': '40'}}}));
    try {
      await _client(a).postPhoneCode('08012345678');
      fail('expected ApiException');
    } on ApiException catch (e) {
      expect(e.fields['retryAfterSeconds'], '40');
    }
  });
}
```

- [ ] **Step 7: Run and confirm failure**

Run: `flutter test test/core/api_client_account_test.dart`
Expected: FAIL (methods and `details` missing).

- [ ] **Step 8: Implement in `lib/core/api/api_client.dart`**

Add `import 'account_models.dart';` with the other model imports. In `ApiException` add the field (keep the constructor otherwise unchanged):

```dart
class ApiException implements Exception {
  const ApiException({
    required this.status,
    required this.code,
    required this.message,
    this.fields = const {},
    this.details = const {},
  });

  final int status;
  final String code;
  final String message;
  final Map<String, String> fields;

  /// Structured, code-specific data (for example deletion blockers). Never shown to the user directly.
  final Map<String, dynamic> details;
```

In `_send`, where the error envelope is decoded, parse and pass `details`:

```dart
      final details = err['details'] is Map<String, dynamic> ? err['details'] as Map<String, dynamic> : const <String, dynamic>{};
      throw ApiException(
        status: status,
        code: err['code'] as String? ?? 'unknown',
        message: err['message'] as String? ?? 'Request failed',
        fields: fields,
        details: details,
      );
```

Add to `usedOperations`:

```dart
    'getMyAccount': 'get /api/mobile/v1/me/account',
    'postAccountDeletion': 'post /api/mobile/v1/me/deletion',
    'deleteAccountDeletion': 'delete /api/mobile/v1/me/deletion',
    'postAccountDeletionExecute': 'post /api/mobile/v1/me/deletion/execute',
    'postPhoneCode': 'post /api/mobile/v1/me/phone/code',
    'postPhoneConfirm': 'post /api/mobile/v1/me/phone/confirm',
    'postMyEmail': 'post /api/mobile/v1/me/email',
    'deleteGoogleIdentity': 'delete /api/mobile/v1/me/identities/google',
    'putMyLocale': 'put /api/mobile/v1/me/locale',
```

Add the methods next to `patchMeProfile`:

```dart
  Future<MyAccount> getMyAccount() => _send('GET', '/me/account', (d) => MyAccount.fromJson(d! as Map<String, dynamic>));

  Future<DeletionTicket> postAccountDeletion() =>
      _send('POST', '/me/deletion', (d) => DeletionTicket.fromJson(d! as Map<String, dynamic>), body: {'confirm': 'DELETE'});

  Future<void> deleteAccountDeletion() => _send('DELETE', '/me/deletion', (_) {});

  Future<void> postAccountDeletionExecute(String username) =>
      _send('POST', '/me/deletion/execute', (_) {}, body: {'username': username});

  Future<PhoneCodeTicket> postPhoneCode(String phone) =>
      _send('POST', '/me/phone/code', (d) => PhoneCodeTicket.fromJson(d! as Map<String, dynamic>), body: {'phone': phone});

  Future<DateTime> postPhoneConfirm(String code) => _send(
        'POST',
        '/me/phone/confirm',
        (d) => DateTime.parse((d! as Map<String, dynamic>)['verifiedAt'] as String).toUtc(),
        body: {'code': code},
      );

  Future<String> postMyEmail({required String email, required String password}) => _send(
        'POST',
        '/me/email',
        (d) => (d! as Map<String, dynamic>)['sentTo'] as String,
        body: {'email': email, 'password': password},
      );

  Future<void> deleteGoogleIdentity(String password) =>
      _send('DELETE', '/me/identities/google', (_) {}, body: {'password': password});

  Future<String> putMyLocale(String locale) =>
      _send('PUT', '/me/locale', (d) => (d! as Map<String, dynamic>)['locale'] as String, body: {'locale': locale});
```

- [ ] **Step 9: Run the API tests and the contract test**

Run: `flutter test test/core/api_client_account_test.dart test/core/account_models_test.dart test/core/api_contract_test.dart test/core/api_client_test.dart`
Expected: PASS (the contract test now covers the nine new operations).

- [ ] **Step 10: Commit**

```bash
git add api/openapi.json lib/core/api test/core/account_models_test.dart test/core/api_client_account_test.dart
git commit -m "feat(api): account, deletion, phone, email, Google unlink and locale operations

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

### Task 2: Copy pipeline and the Pidgin ARB locale

**Files:**
- Modify: `tool/gen_l10n_from_web.dart`, `tool/gen_l10n_from_web_test.dart`, `lib/core/l10n/app_en.arb`, `lib/core/l10n/app_fr.arb`, `test/core/l10n_test.dart`
- Create: `lib/core/l10n/app_pcm.arb`
- Regenerate: `lib/core/l10n/gen/*`

**Interfaces:**
- Produces: ARB keys `mobileSettings*`, `accountDeletion*`, `emailChange*`, `signInMethods*` (en, fr, pcm); locale `pcm` in `AppLocalizations.supportedLocales`; generator support for `{placeholder}` metadata.

**Why the generator changes:** it writes plain strings, but `gen-l10n` rejects a message that uses `{date}` without an `@key` placeholder block. The new copy has many (`{date}`, `{days}`, `{count}`, `{amount}`, `{seconds}`, `{masked}`, `{email}`, `{username}`). Teaching the tool to write that metadata (for keys that have none yet) is cheaper and safer than hand-editing ~20 blocks.

- [ ] **Step 1: Write the failing generator tests** (append to `tool/gen_l10n_from_web_test.dart`; keep its existing imports and add what is missing):

```dart
  group('placeholderMetadata', () {
    test('adds a String placeholder block for each {name}, in order of appearance, deduplicated', () {
      final meta = placeholderMetadata({
        'accountDeletionPendingBody': 'Deleted on {date} — {days} days left ({date})',
        'plain': 'no placeholders',
      }, existing: {});
      expect(meta.keys, ['@accountDeletionPendingBody']);
      final ph = (meta['@accountDeletionPendingBody'] as Map)['placeholders'] as Map;
      expect(ph.keys.toList(), ['date', 'days']);
      expect((ph['date'] as Map)['type'], 'String');
    });

    test('never overwrites metadata a developer already wrote', () {
      final meta = placeholderMetadata({'k': 'Hi {name}'}, existing: {'@k': {'placeholders': {'name': {'type': 'int'}}}});
      expect(meta, isEmpty);
    });

    test('ignores ICU plural arms and braces that are not simple placeholders', () {
      final meta = placeholderMetadata({'k': 'Have {count, plural, one{# item} other{# items}}'}, existing: {});
      final ph = (meta['@k'] as Map)['placeholders'] as Map;
      expect(ph.keys.toList(), ['count']);
      expect((ph['count'] as Map)['type'], 'num');
    });
  });
```

- [ ] **Step 2: Run and confirm failure**

Run: `dart test tool/gen_l10n_from_web_test.dart`
Expected: FAIL (`placeholderMetadata` undefined).

- [ ] **Step 3: Implement in `tool/gen_l10n_from_web.dart`**

Add above `mergeIntoArb`:

```dart
final _simplePlaceholder = RegExp(r'\{(\w+)\}');
final _pluralPlaceholder = RegExp(r'\{(\w+)\s*,\s*(?:plural|select)\b');

/// `@key` blocks for messages that contain placeholders and have none yet. gen-l10n refuses a `{name}`
/// without one. Simple placeholders are Strings (callers format numbers and dates themselves); an ICU
/// plural's argument is a num. Metadata a developer already wrote is never replaced.
Map<String, Object> placeholderMetadata(Map<String, String> additions, {required Map<String, dynamic> existing}) {
  final out = <String, Object>{};
  additions.forEach((key, value) {
    if (existing.containsKey('@$key')) return;
    final names = <String, String>{};
    for (final m in _pluralPlaceholder.allMatches(value)) {
      names[m.group(1)!] = 'num';
    }
    for (final m in _simplePlaceholder.allMatches(value)) {
      names.putIfAbsent(m.group(1)!, () => 'String');
    }
    if (names.isEmpty) return;
    out['@$key'] = {
      'placeholders': {for (final e in names.entries) e.key: {'type': e.value}},
    };
  });
  return out;
}
```

Change `mergeIntoArb` to merge the metadata (replace its body's `merged` line):

```dart
void mergeIntoArb(String path, Map<String, String> additions) {
  final file = File(path);
  final existing = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  final merged = {...existing, ...additions, ...placeholderMetadata(additions, existing: existing)};
  final encoder = const JsonEncoder.withIndent('  ');
  file.writeAsStringSync('${encoder.convert(merged)}\n');
}
```

Also replace the `Skipping $locale: no $target …` message with `'Skipping $locale: no $target in this repo (create it with {"@@locale": "$locale"} first).'`.

- [ ] **Step 4: Run and confirm pass**

Run: `dart test tool/gen_l10n_from_web_test.dart`
Expected: PASS (existing tests plus the three new).

- [ ] **Step 5: Create the Pidgin ARB shell**

Write `lib/core/l10n/app_pcm.arb`:

```json
{
  "@@locale": "pcm"
}
```

- [ ] **Step 6: Generate the copy**

Run (PowerShell, from the repo root):

```powershell
dart run tool/gen_l10n_from_web.dart --source=C:/Users/gorok/Videos/sentinelx/messages --namespaces=mobileSettings,accountDeletion,emailChange,signInMethods --locales=en,fr,pcm
dart run tool/gen_l10n_from_web.dart --source=C:/Users/gorok/Videos/sentinelx/messages --namespaces=common,nav,home,auth,terms --locales=pcm
```

The second command gives Pidgin the web-derived namespaces the English file already carries. Expected output: `Merged N keys into lib/core/l10n/app_en.arb`, `…app_fr.arb`, `…app_pcm.arb` and a second line for pcm.

- [ ] **Step 7: Update the l10n parity test** (`test/core/l10n_test.dart`): keep the en/fr exact-match test and add the Pidgin rule. Mobile-authored strings (`ntf*`, `cmp*`, `dm*`, …) have no web source and no Pidgin translation yet, so `pcm` must be a **subset** of `en` (a stray key means a web key `en` never imported); everything it lacks falls back to English at runtime.

```dart
  test('Pidgin is a subset of the English template; missing keys fall back to English', () {
    final en = _keys('lib/core/l10n/app_en.arb');
    final pcm = _keys('lib/core/l10n/app_pcm.arb');
    expect(pcm.difference(en), isEmpty, reason: 'delete these from app_pcm.arb: web keys en never imported');
    expect(pcm, isNotEmpty);
  });
```

Run: `flutter test test/core/l10n_test.dart`
Expected: the en/fr test PASSES; if the Pidgin test fails, it lists the extra keys: delete exactly those keys (and their `@` blocks) from `app_pcm.arb` and rerun. If the en/fr test fails, the web `en.json` and `fr.json` disagree on the new namespaces; fix on the web side.

- [ ] **Step 8: Regenerate Dart and verify**

Run: `flutter gen-l10n && flutter analyze`
Expected: generation succeeds with no placeholder errors (a "placeholder not defined" error means a `{x}` form the generator regex missed; extend `placeholderMetadata` and its test, rerun Steps 4-8). `analyze` is clean. Confirm `AppLocalizations.supportedLocales` contains `Locale('pcm')` in `lib/core/l10n/gen/app_localizations.dart`.

- [ ] **Step 9: Commit**

```bash
git add tool lib/core/l10n test/core/l10n_test.dart
git commit -m "feat(l10n): Pidgin locale, settings copy and generated placeholder metadata

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

### Task 3: Pidgin-safe runtime (framework fallbacks and date formats)

Selecting `pcm` would otherwise crash: Material/Widgets/Cupertino delegates do not support it (no `MaterialLocalizations` -> text fields throw) and `DateFormat.yMMMd('pcm')` throws `ArgumentError: Invalid locale`.

**Files:**
- Create: `lib/core/l10n/fallback_delegates.dart`, `lib/core/utils/date_locale.dart`
- Modify: `lib/app.dart`, `lib/features/community/post_card.dart:62`, `lib/features/community/post_detail_screen.dart:273`, `lib/features/match/match_format.dart:28`
- Test: `test/core/pcm_runtime_test.dart`

**Interfaces:**
- Produces: `appLocalizationsDelegates` (`List<LocalizationsDelegate<dynamic>>`), `String dateLocale(String localeName)`.

- [ ] **Step 1: Write the failing tests**

```dart
// test/core/pcm_runtime_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/core/l10n/fallback_delegates.dart';
import 'package:sentinelx_mobile/core/l10n/gen/app_localizations.dart';
import 'package:sentinelx_mobile/core/utils/date_locale.dart';
import 'package:intl/intl.dart';

void main() {
  test('dateLocale keeps locales intl knows and falls back to English for Pidgin', () {
    expect(dateLocale('en'), 'en');
    expect(dateLocale('fr'), 'fr');
    expect(dateLocale('pcm'), 'en');
    // The point of the helper: the unguarded call throws.
    expect(() => DateFormat.yMMMd('pcm'), throwsA(anything));
    expect(DateFormat.yMMMd(dateLocale('pcm')).format(DateTime.utc(2026, 10, 7)), isNotEmpty);
  });

  testWidgets('a Pidgin app builds Material widgets and reads Pidgin strings', (tester) async {
    late AppLocalizations l10n;
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('pcm'),
      localizationsDelegates: appLocalizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(builder: (context) {
        l10n = AppLocalizations.of(context);
        return const Scaffold(body: TextField());
      }),
    ));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(l10n.localeName, 'pcm');
  });

  testWidgets('a locale with no delegate support still gets framework strings in English', (tester) async {
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('pcm'),
      localizationsDelegates: appLocalizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(builder: (context) {
        expect(MaterialLocalizations.of(context).okButtonLabel, 'OK');
        return const SizedBox();
      }),
    ));
    await tester.pumpAndSettle();
  });
}
```

- [ ] **Step 2: Run and confirm failure**

Run: `flutter test test/core/pcm_runtime_test.dart`
Expected: FAIL (files missing).

- [ ] **Step 3: Implement**

```dart
// lib/core/l10n/fallback_delegates.dart
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'gen/app_localizations.dart';

/// Material, Widgets and Cupertino ship no Pidgin (`pcm`). Without a delegate for a locale the framework
/// cannot find MaterialLocalizations and any TextField or picker throws. This wraps each Global delegate so
/// an unsupported locale loads English instead; the app's own strings still come from [AppLocalizations].
class _FallbackDelegate<T> extends LocalizationsDelegate<T> {
  const _FallbackDelegate(this._inner);
  final LocalizationsDelegate<T> _inner;

  @override
  bool isSupported(Locale locale) => true;

  @override
  Future<T> load(Locale locale) => _inner.load(_inner.isSupported(locale) ? locale : const Locale('en'));

  @override
  bool shouldReload(covariant LocalizationsDelegate<T> old) => false;
}

final List<LocalizationsDelegate<dynamic>> appLocalizationsDelegates = [
  AppLocalizations.delegate,
  _FallbackDelegate<MaterialLocalizations>(GlobalMaterialLocalizations.delegate),
  _FallbackDelegate<WidgetsLocalizations>(GlobalWidgetsLocalizations.delegate),
  _FallbackDelegate<CupertinoLocalizations>(GlobalCupertinoLocalizations.delegate),
];
```

```dart
// lib/core/utils/date_locale.dart
import 'package:intl/intl.dart';

/// `DateFormat` has no data for Pidgin (`pcm`) and throws `Invalid locale` if asked. Dates in Pidgin render
/// with English formats. Use this around every `AppLocalizations.localeName` passed to a DateFormat.
String dateLocale(String localeName) => DateFormat.localeExists(localeName) ? localeName : 'en';
```

In `lib/app.dart` replace the `localizationsDelegates: const [...]` list with `localizationsDelegates: appLocalizationsDelegates,` and import `'core/l10n/fallback_delegates.dart'` (drop the now-unused `flutter_localizations` and `AppLocalizations.delegate` references only if the analyzer flags them; `AppLocalizations` is still used for `supportedLocales`).

Wrap the three existing call sites (add `import '../../core/utils/date_locale.dart';` to each):

- `lib/features/community/post_card.dart:62`: `DateFormat.yMMMd(dateLocale(l10n.localeName)).add_Hm().format(created)`
- `lib/features/community/post_detail_screen.dart:273`: `DateFormat.yMMMd(dateLocale(l10n.localeName)).add_Hm().format(t)`
- `lib/features/match/match_format.dart:28`: `final f = DateFormat.yMMMd(dateLocale(l10n.localeName));`

Run `grep -rn "DateFormat\|NumberFormat" lib --include=*.dart | grep -v l10n/gen` once more and wrap any other locale-bearing call found.

- [ ] **Step 4: Run and confirm pass**

Run: `flutter test test/core/pcm_runtime_test.dart test/features/community test/features/match`
Expected: PASS (existing community and match tests are unaffected for `en`/`fr`).

- [ ] **Step 5: Analyze and commit**

Run: `flutter analyze` -> clean.

```bash
git add lib/app.dart lib/core/l10n/fallback_delegates.dart lib/core/utils/date_locale.dart lib/features/community lib/features/match test/core/pcm_runtime_test.dart
git commit -m "fix(l10n): Pidgin-safe framework delegates and date formats

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

### Task 4: `AccountRepository`, providers, error copy, and the locale notifier

**Files:**
- Create: `lib/features/account/settings/account_repository.dart`, `lib/features/account/settings/account_error_copy.dart`, `lib/features/account/settings/locale_providers.dart`
- Create: `test/fakes/fake_account_repository.dart`
- Modify: `lib/app.dart` (watch `localeProvider`)
- Test: `test/features/account/settings/account_repository_test.dart`, `account_error_copy_test.dart`, `locale_providers_test.dart`

**Interfaces:**
- Consumes: `ApiClient` methods (Task 1), `meProvider`, `viewerIdProvider`, `localKvProvider`.
- Produces:
  - `abstract class AccountRepository { Future<MyAccount> account(); Future<DeletionTicket> requestDeletion(); Future<void> cancelDeletion(); Future<void> deleteNow(String username); Future<PhoneCodeTicket> requestPhoneCode(String phone); Future<DateTime> confirmPhoneCode(String code); Future<String> changeEmail({required String email, required String password}); Future<void> unlinkGoogle(String password); Future<String> setLocale(String locale); }`
  - `accountRepositoryProvider` (`Provider<AccountRepository>`), `myAccountProvider` (`FutureProvider.autoDispose<MyAccount?>`, null when signed out)
  - `String emailChangeErrorCopy(AppLocalizations, String code)`, `unlinkErrorCopy`, `phoneErrorCopy`, `genericAccountErrorCopy`
  - `localeProvider` (`NotifierProvider<LocaleNotifier, Locale?>`), `LocaleNotifier.select(String code) -> Future<bool>`, `supportedLocaleCodes`
  - `FakeAccountRepository` (test double used by every later task)

- [ ] **Step 1: Write the fake**

```dart
// test/fakes/fake_account_repository.dart
import 'package:sentinelx_mobile/core/api/account_models.dart';
import 'package:sentinelx_mobile/features/account/settings/account_repository.dart';

MyAccount testAccount({
  DeletionState? deletion,
  String? email = 'ada@example.com',
  String? pendingEmail,
  bool passwordIdentity = true,
  bool google = false,
  AccountPhone? phone,
  String? locale = 'en',
}) =>
    MyAccount(
      deletion: deletion,
      signIn: AccountSignIn(email: email, pendingEmail: pendingEmail, passwordIdentity: passwordIdentity, google: google),
      phone: phone,
      locale: locale,
    );

/// Records every call; set a `*Error` to make that call throw it, or `*Result` to change what it returns.
class FakeAccountRepository implements AccountRepository {
  MyAccount accountResult = testAccount();
  final calls = <String>[];
  Object? accountError;
  Object? deletionError;
  Object? cancelError;
  Object? deleteNowError;
  Object? phoneCodeError;
  Object? phoneConfirmError;
  Object? emailError;
  Object? unlinkError;
  Object? localeError;
  PhoneCodeTicket phoneTicket = PhoneCodeTicket(
    expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 10)),
    resendAt: DateTime.now().toUtc().add(const Duration(seconds: 60)),
  );
  String? lastEmail;
  String? lastPassword;
  String? lastLocale;
  String? lastPhone;
  String? lastCode;
  String? lastUsername;

  @override
  Future<MyAccount> account() async {
    calls.add('account');
    if (accountError != null) throw accountError!;
    return accountResult;
  }

  @override
  Future<DeletionTicket> requestDeletion() async {
    calls.add('requestDeletion');
    if (deletionError != null) throw deletionError!;
    final now = DateTime.now().toUtc();
    return DeletionTicket(requestedAt: now, dueAt: now.add(const Duration(days: 15)));
  }

  @override
  Future<void> cancelDeletion() async {
    calls.add('cancelDeletion');
    if (cancelError != null) throw cancelError!;
  }

  @override
  Future<void> deleteNow(String username) async {
    calls.add('deleteNow');
    lastUsername = username;
    if (deleteNowError != null) throw deleteNowError!;
  }

  @override
  Future<PhoneCodeTicket> requestPhoneCode(String phone) async {
    calls.add('requestPhoneCode');
    lastPhone = phone;
    if (phoneCodeError != null) throw phoneCodeError!;
    return phoneTicket;
  }

  @override
  Future<DateTime> confirmPhoneCode(String code) async {
    calls.add('confirmPhoneCode');
    lastCode = code;
    if (phoneConfirmError != null) throw phoneConfirmError!;
    return DateTime.now().toUtc();
  }

  @override
  Future<String> changeEmail({required String email, required String password}) async {
    calls.add('changeEmail');
    lastEmail = email;
    lastPassword = password;
    if (emailError != null) throw emailError!;
    return email.toLowerCase();
  }

  @override
  Future<void> unlinkGoogle(String password) async {
    calls.add('unlinkGoogle');
    lastPassword = password;
    if (unlinkError != null) throw unlinkError!;
  }

  @override
  Future<String> setLocale(String locale) async {
    calls.add('setLocale');
    lastLocale = locale;
    if (localeError != null) throw localeError!;
    return locale;
  }
}
```

- [ ] **Step 2: Write the failing repository and error-copy tests**

```dart
// test/features/account/settings/account_repository_test.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/core/providers.dart';
import 'package:sentinelx_mobile/features/account/settings/account_repository.dart';

import '../../../fakes/fake_account_repository.dart';

void main() {
  ProviderContainer container(FakeAccountRepository repo, {String? viewer = 'u1'}) => ProviderContainer(
        retry: (_, _) => null,
        overrides: [
          accountRepositoryProvider.overrideWithValue(repo),
          viewerIdProvider.overrideWith((ref) async => viewer),
        ],
      );

  test('myAccountProvider loads the account for a signed-in viewer', () async {
    final repo = FakeAccountRepository();
    final c = container(repo);
    addTearDown(c.dispose);
    final a = await c.read(myAccountProvider.future);
    expect(a!.signIn.email, 'ada@example.com');
    expect(repo.calls, ['account']);
  });

  test('myAccountProvider is null and makes no request when signed out', () async {
    final repo = FakeAccountRepository();
    final c = container(repo, viewer: null);
    addTearDown(c.dispose);
    expect(await c.read(myAccountProvider.future), isNull);
    expect(repo.calls, isEmpty);
  });
}
```

```dart
// test/features/account/settings/account_error_copy_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/core/l10n/gen/app_localizations_en.dart';
import 'package:sentinelx_mobile/features/account/settings/account_error_copy.dart';

void main() {
  final l10n = AppLocalizationsEn();

  test('email change codes map to the shared web copy', () {
    expect(emailChangeErrorCopy(l10n, 'wrong_password'), l10n.emailChangeErrorsWrongPassword);
    expect(emailChangeErrorCopy(l10n, 'google_only'), l10n.emailChangeErrorsGoogleOnly);
    expect(emailChangeErrorCopy(l10n, 'same_email'), l10n.emailChangeErrorsSameEmail);
    expect(emailChangeErrorCopy(l10n, 'email_banned'), l10n.emailChangeErrorsEmailBanned);
    expect(emailChangeErrorCopy(l10n, 'email_in_use'), l10n.emailChangeErrorsEmailInUse);
    expect(emailChangeErrorCopy(l10n, 'failed'), l10n.emailChangeErrorsFailed);
    expect(emailChangeErrorCopy(l10n, 'validation_failed'), l10n.emailChangeErrorsInvalidEmail);
  });

  test('unlink codes map to the sign-in methods copy', () {
    expect(unlinkErrorCopy(l10n, 'wrong_password'), l10n.signInMethodsErrorsWrongPassword);
    expect(unlinkErrorCopy(l10n, 'last_identity'), l10n.signInMethodsErrorsLastIdentity);
    expect(unlinkErrorCopy(l10n, 'not_linked'), l10n.signInMethodsErrorsNotLinked);
    expect(unlinkErrorCopy(l10n, 'linking_unavailable'), l10n.mobileSettingsLinkingUnavailable);
    expect(unlinkErrorCopy(l10n, 'failed'), l10n.signInMethodsErrorsFailed);
  });

  test('phone codes map to the mobile settings copy', () {
    expect(phoneErrorCopy(l10n, 'phone_invalid'), l10n.mobileSettingsPhoneErrorInvalid);
    expect(phoneErrorCopy(l10n, 'phone_cooldown'), l10n.mobileSettingsPhoneErrorCooldown);
    expect(phoneErrorCopy(l10n, 'phone_daily_limit'), l10n.mobileSettingsPhoneErrorDailyLimit);
    expect(phoneErrorCopy(l10n, 'phone_send_failed'), l10n.mobileSettingsPhoneErrorSendFailed);
    expect(phoneErrorCopy(l10n, 'phone_unavailable'), l10n.mobileSettingsPhoneUnavailable);
    expect(phoneErrorCopy(l10n, 'phone_code_invalid'), l10n.mobileSettingsPhoneErrorCodeInvalid);
    expect(phoneErrorCopy(l10n, 'phone_code_missing'), l10n.mobileSettingsPhoneErrorCodeMissing);
    expect(phoneErrorCopy(l10n, 'phone_code_expired'), l10n.mobileSettingsPhoneErrorCodeExpired);
    expect(phoneErrorCopy(l10n, 'phone_code_wrong'), l10n.mobileSettingsPhoneErrorCodeWrong);
    expect(phoneErrorCopy(l10n, 'phone_attempts_exceeded'), l10n.mobileSettingsPhoneErrorAttempts);
  });

  test('shared fallbacks: rate limit, network and anything unknown', () {
    for (final f in [emailChangeErrorCopy, unlinkErrorCopy, phoneErrorCopy]) {
      expect(f(l10n, 'reauth_rate_limited'), l10n.mobileSettingsReauthRateLimited);
      expect(f(l10n, 'network'), l10n.mobileSettingsNetworkError);
      expect(f(l10n, 'a_code_from_the_future'), l10n.mobileSettingsGenericError);
    }
    expect(genericAccountErrorCopy(l10n, 'network'), l10n.mobileSettingsNetworkError);
    expect(genericAccountErrorCopy(l10n, 'x'), l10n.mobileSettingsGenericError);
  });
}
```

- [ ] **Step 3: Run and confirm failure**

Run: `flutter test test/features/account/settings/account_repository_test.dart test/features/account/settings/account_error_copy_test.dart`
Expected: FAIL (files missing).

- [ ] **Step 4: Implement the repository and providers**

```dart
// lib/features/account/settings/account_repository.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/account_models.dart';
import '../../../core/api/api_client.dart';
import '../../../core/providers.dart';

/// Everything the Settings screens read and write. A seam over [ApiClient] so screens are tested against a
/// fake; there is no direct Supabase access here (every write is a Tier 3 API call).
abstract class AccountRepository {
  Future<MyAccount> account();
  Future<DeletionTicket> requestDeletion();
  Future<void> cancelDeletion();
  Future<void> deleteNow(String username);
  Future<PhoneCodeTicket> requestPhoneCode(String phone);
  Future<DateTime> confirmPhoneCode(String code);
  Future<String> changeEmail({required String email, required String password});
  Future<void> unlinkGoogle(String password);
  Future<String> setLocale(String locale);
}

class ApiAccountRepository implements AccountRepository {
  ApiAccountRepository(this._api);
  final ApiClient _api;

  @override
  Future<MyAccount> account() => _api.getMyAccount();
  @override
  Future<DeletionTicket> requestDeletion() => _api.postAccountDeletion();
  @override
  Future<void> cancelDeletion() => _api.deleteAccountDeletion();
  @override
  Future<void> deleteNow(String username) => _api.postAccountDeletionExecute(username);
  @override
  Future<PhoneCodeTicket> requestPhoneCode(String phone) => _api.postPhoneCode(phone);
  @override
  Future<DateTime> confirmPhoneCode(String code) => _api.postPhoneConfirm(code);
  @override
  Future<String> changeEmail({required String email, required String password}) => _api.postMyEmail(email: email, password: password);
  @override
  Future<void> unlinkGoogle(String password) => _api.deleteGoogleIdentity(password);
  @override
  Future<String> setLocale(String locale) => _api.putMyLocale(locale);
}

final accountRepositoryProvider = Provider<AccountRepository>((ref) => ApiAccountRepository(ref.watch(apiClientProvider)));

/// The caller's account (deletion, sign-in methods, phone). Null when signed out, with no request made.
/// Keyed on [viewerIdProvider] so a token refresh never refetches and a different user never sees the last
/// user's data.
final myAccountProvider = FutureProvider.autoDispose<MyAccount?>((ref) async {
  final viewer = await ref.watch(viewerIdProvider.future);
  if (viewer == null) return null;
  return ref.watch(accountRepositoryProvider).account();
});
```

```dart
// lib/features/account/settings/account_error_copy.dart
import '../../../core/l10n/gen/app_localizations.dart';

/// Server error codes become localized copy here; the server's English `message` is never shown. Codes
/// shared by every Settings call (rate limit, no network, unknown) fall through to [genericAccountErrorCopy].
String genericAccountErrorCopy(AppLocalizations l10n, String code) => switch (code) {
      'reauth_rate_limited' => l10n.mobileSettingsReauthRateLimited,
      'network' => l10n.mobileSettingsNetworkError,
      _ => l10n.mobileSettingsGenericError,
    };

String emailChangeErrorCopy(AppLocalizations l10n, String code) => switch (code) {
      'wrong_password' => l10n.emailChangeErrorsWrongPassword,
      'google_only' => l10n.emailChangeErrorsGoogleOnly,
      'same_email' => l10n.emailChangeErrorsSameEmail,
      'email_banned' => l10n.emailChangeErrorsEmailBanned,
      'email_in_use' => l10n.emailChangeErrorsEmailInUse,
      'failed' => l10n.emailChangeErrorsFailed,
      'validation_failed' => l10n.emailChangeErrorsInvalidEmail,
      _ => genericAccountErrorCopy(l10n, code),
    };

String unlinkErrorCopy(AppLocalizations l10n, String code) => switch (code) {
      'wrong_password' => l10n.signInMethodsErrorsWrongPassword,
      'last_identity' => l10n.signInMethodsErrorsLastIdentity,
      'not_linked' => l10n.signInMethodsErrorsNotLinked,
      'linking_unavailable' => l10n.mobileSettingsLinkingUnavailable,
      'failed' => l10n.signInMethodsErrorsFailed,
      _ => genericAccountErrorCopy(l10n, code),
    };

String phoneErrorCopy(AppLocalizations l10n, String code) => switch (code) {
      'phone_invalid' => l10n.mobileSettingsPhoneErrorInvalid,
      'phone_cooldown' => l10n.mobileSettingsPhoneErrorCooldown,
      'phone_daily_limit' => l10n.mobileSettingsPhoneErrorDailyLimit,
      'phone_send_failed' => l10n.mobileSettingsPhoneErrorSendFailed,
      'phone_unavailable' => l10n.mobileSettingsPhoneUnavailable,
      'phone_code_invalid' => l10n.mobileSettingsPhoneErrorCodeInvalid,
      'phone_code_missing' => l10n.mobileSettingsPhoneErrorCodeMissing,
      'phone_code_expired' => l10n.mobileSettingsPhoneErrorCodeExpired,
      'phone_code_wrong' => l10n.mobileSettingsPhoneErrorCodeWrong,
      'phone_attempts_exceeded' => l10n.mobileSettingsPhoneErrorAttempts,
      _ => genericAccountErrorCopy(l10n, code),
    };
```

- [ ] **Step 5: Run and confirm pass**

Run: `flutter test test/features/account/settings/account_repository_test.dart test/features/account/settings/account_error_copy_test.dart`
Expected: PASS.

- [ ] **Step 6: Write the failing locale-notifier tests**

```dart
// test/features/account/settings/locale_providers_test.dart
import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/core/api/api_client.dart';
import 'package:sentinelx_mobile/core/api/models.dart';
import 'package:sentinelx_mobile/core/providers.dart';
import 'package:sentinelx_mobile/core/storage/local_kv.dart';
import 'package:sentinelx_mobile/features/account/settings/account_repository.dart';
import 'package:sentinelx_mobile/features/account/settings/locale_providers.dart';

import '../../../fakes/fake_account_repository.dart';
import '../../../fakes/fake_local_kv.dart';

MeResponse _me(String? locale) => MeResponse(
      id: 'u1', email: 'a@b.com', roles: const [], isStaff: false, isAdmin: false,
      profile: MeProfile(
        username: 'ada', displayName: 'Ada', avatarUrl: null, whatsappNumber: null, country: null, locale: locale,
        membershipTier: null, kycVerified: false, deletionRequestedAt: null,
      ),
    );

Future<void> _settle() => Future<void>.delayed(Duration.zero);

void main() {
  late FakeAccountRepository repo;
  late MemoryLocalKv kv;
  late ProviderContainer c;
  late bool signedIn;
  late String? serverLocale;

  ProviderContainer make() => ProviderContainer(
        retry: (_, _) => null,
        overrides: [
          accountRepositoryProvider.overrideWithValue(repo),
          localKvProvider.overrideWith((ref) async => kv),
          meProvider.overrideWith((ref) async => signedIn ? _me(serverLocale) : null),
        ],
      );

  setUp(() {
    repo = FakeAccountRepository();
    kv = MemoryLocalKv();
    signedIn = true;
    serverLocale = 'fr';
  });

  test('starts with the server locale and caches it for the next cold start', () async {
    c = make();
    addTearDown(c.dispose);
    c.listen(localeProvider, (_, _) {});
    await c.read(meProvider.future);
    await _settle();
    expect(c.read(localeProvider), const Locale('fr'));
    expect(kv.values['app.locale'], 'fr');
  });

  test('uses the cached locale before /me answers (signed out or cold start)', () async {
    signedIn = false;
    kv.values['app.locale'] = 'pcm';
    c = make();
    addTearDown(c.dispose);
    c.listen(localeProvider, (_, _) {});
    await _settle();
    await _settle();
    expect(c.read(localeProvider), const Locale('pcm'));
  });

  test('ignores a cached or server value it does not support', () async {
    kv.values['app.locale'] = 'de';
    serverLocale = 'es';
    c = make();
    addTearDown(c.dispose);
    c.listen(localeProvider, (_, _) {});
    await c.read(meProvider.future);
    await _settle();
    expect(c.read(localeProvider), isNull);
  });

  test('select saves to the server, updates state and the cache', () async {
    c = make();
    addTearDown(c.dispose);
    c.listen(localeProvider, (_, _) {});
    await c.read(meProvider.future);
    expect(await c.read(localeProvider.notifier).select('pcm'), isTrue);
    expect(c.read(localeProvider), const Locale('pcm'));
    expect(repo.lastLocale, 'pcm');
    expect(kv.values['app.locale'], 'pcm');
  });

  test('a failed save reverts both the UI and the cache', () async {
    c = make();
    addTearDown(c.dispose);
    c.listen(localeProvider, (_, _) {});
    await c.read(meProvider.future);
    await _settle();
    repo.localeError = const ApiException(status: 500, code: 'locale_save_failed', message: 'x');
    expect(await c.read(localeProvider.notifier).select('pcm'), isFalse);
    expect(c.read(localeProvider), const Locale('fr'));
    expect(kv.values['app.locale'], 'fr');
  });

  test('signed out: select is local only and makes no request', () async {
    signedIn = false;
    c = make();
    addTearDown(c.dispose);
    c.listen(localeProvider, (_, _) {});
    await c.read(meProvider.future);
    expect(await c.read(localeProvider.notifier).select('fr'), isTrue);
    expect(repo.calls, isEmpty);
    expect(kv.values['app.locale'], 'fr');
  });

  test('a stale /me locale arriving after the user chose does not flip the app back', () async {
    c = make();
    addTearDown(c.dispose);
    c.listen(localeProvider, (_, _) {});
    await c.read(localeProvider.notifier).select('pcm');
    await c.read(meProvider.future); // /me says 'fr' (stale)
    await _settle();
    expect(c.read(localeProvider), const Locale('pcm'));
  });

  test('rejects a locale the app does not ship', () async {
    c = make();
    addTearDown(c.dispose);
    c.listen(localeProvider, (_, _) {});
    expect(await c.read(localeProvider.notifier).select('de'), isFalse);
    expect(repo.calls, isEmpty);
  });
}
```

- [ ] **Step 7: Run and confirm failure**

Run: `flutter test test/features/account/settings/locale_providers_test.dart`
Expected: FAIL (file missing).

- [ ] **Step 8: Implement the notifier**

```dart
// lib/features/account/settings/locale_providers.dart
import 'dart:async';
import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../core/storage/local_kv.dart';
import 'account_repository.dart';

const supportedLocaleCodes = {'en', 'fr', 'pcm'};
const _cacheKey = 'app.locale';

/// The app language. Null means "no choice yet": MaterialApp then follows the device and falls back to
/// English. Seeded from the server (`/me.locale`) and cached locally so the first frame after a cold start is
/// already right and signed-out use still remembers the choice.
class LocaleNotifier extends Notifier<Locale?> {
  // Set once the user picks a language this session so a slower, stale /me response cannot undo it. Cleared
  // on sign-out so the next account's saved language applies.
  var _chosen = false;

  @override
  Locale? build() {
    ref.listen(meProvider, (_, next) {
      final me = next.asData?.value;
      if (next.hasValue && me == null) {
        _chosen = false;
        return;
      }
      final code = me?.profile?.locale;
      if (!_chosen && code != null && supportedLocaleCodes.contains(code)) {
        state = Locale(code);
        unawaited(_write(code));
      }
    }, fireImmediately: true);
    unawaited(_restore());
    return null;
  }

  Future<void> _restore() async {
    try {
      final kv = await ref.read(localKvProvider.future);
      final code = await kv.read(_cacheKey);
      if (ref.mounted && state == null && code != null && supportedLocaleCodes.contains(code)) {
        state = Locale(code);
      }
    } catch (_) {
      // Storage unavailable: the app simply starts in the device language.
    }
  }

  Future<void> _write(String? code) async {
    try {
      final kv = await ref.read(localKvProvider.future);
      if (code == null) {
        await kv.remove(_cacheKey);
      } else {
        await kv.write(_cacheKey, code);
      }
    } catch (_) {}
  }

  /// Optimistic. Returns false when the code is not shipped or the server refused; in the second case the
  /// previous language (and cached value) is restored. Signed out, the choice is local only.
  Future<bool> select(String code) async {
    if (!supportedLocaleCodes.contains(code)) return false;
    final previous = state;
    _chosen = true;
    state = Locale(code);
    await _write(code);
    if (ref.read(meProvider).asData?.value == null) return true;
    try {
      await ref.read(accountRepositoryProvider).setLocale(code);
      return true;
    } catch (_) {
      if (ref.mounted) {
        state = previous;
        await _write(previous?.languageCode);
      }
      return false;
    }
  }
}

final localeProvider = NotifierProvider<LocaleNotifier, Locale?>(LocaleNotifier.new);
```

In `lib/app.dart` add `locale: ref.watch(localeProvider),` to `MaterialApp.router` and import `'features/account/settings/locale_providers.dart'`. Also start it once in `main.dart` after the other `container.listen` lines (it must be alive before the first frame's locale matters, and `watch` in `SentinelXApp.build` already keeps it alive, so no extra line is needed).

- [ ] **Step 9: Run and confirm pass**

Run: `flutter test test/features/account/settings && flutter analyze`
Expected: PASS, clean.

- [ ] **Step 10: Commit**

```bash
git add lib/features/account/settings lib/app.dart test/fakes/fake_account_repository.dart test/features/account/settings
git commit -m "feat(account): account repository seam, error copy and persisted language

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

### Task 5: Settings hub, routes, and the Language screen

**Files:**
- Modify: `lib/features/account/account_screen.dart`, `lib/router/app_router.dart`
- Create: `lib/features/account/settings/language_screen.dart`
- Test: `test/features/account/settings/language_screen_test.dart`, `test/features/account/settings/account_hub_test.dart`

**Interfaces:**
- Consumes: `localeProvider.notifier.select`, `meProvider`.
- Produces: routes `/account/language`, `/account/security`, `/account/sign-in-methods`, `/account/phone`, `/account/delete` (screens added in later tasks; this task wires the hub and Language and registers the other routes as they land); `AccountScreen` callbacks `onOpenLanguage`, `onOpenSecurity`, `onOpenSignInMethods`, `onOpenPhone`, `onOpenDeleteAccount`.

- [ ] **Step 1: Write the failing language test**

```dart
// test/features/account/settings/language_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/core/api/api_client.dart';
import 'package:sentinelx_mobile/core/api/models.dart';
import 'package:sentinelx_mobile/core/l10n/fallback_delegates.dart';
import 'package:sentinelx_mobile/core/l10n/gen/app_localizations.dart';
import 'package:sentinelx_mobile/core/providers.dart';
import 'package:sentinelx_mobile/features/account/settings/account_repository.dart';
import 'package:sentinelx_mobile/features/account/settings/language_screen.dart';
import 'package:sentinelx_mobile/features/account/settings/locale_providers.dart';

import '../../../fakes/fake_account_repository.dart';
import '../../../fakes/fake_local_kv.dart';
import 'package:sentinelx_mobile/core/storage/local_kv.dart';

MeResponse _me() => MeResponse(
      id: 'u1', email: 'a@b.com', roles: const [], isStaff: false, isAdmin: false,
      profile: MeProfile(
        username: 'ada', displayName: 'Ada', avatarUrl: null, whatsappNumber: null, country: null, locale: 'en',
        membershipTier: null, kycVerified: false, deletionRequestedAt: null,
      ),
    );

Future<void> _pump(WidgetTester tester, FakeAccountRepository repo) async {
  await tester.pumpWidget(ProviderScope(
    retry: (_, _) => null,
    overrides: [
      accountRepositoryProvider.overrideWithValue(repo),
      localKvProvider.overrideWith((ref) async => MemoryLocalKv()),
      meProvider.overrideWith((ref) async => _me()),
    ],
    child: Consumer(builder: (context, ref, _) {
      return MaterialApp(
        locale: ref.watch(localeProvider),
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const LanguageScreen(),
      );
    }),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('lists the three languages with the current one selected', (tester) async {
    await _pump(tester, FakeAccountRepository());
    expect(find.text('English'), findsOneWidget);
    expect(find.text('Français'), findsOneWidget);
    expect(find.text('Pidgin'), findsOneWidget);
    expect(tester.widget<RadioListTile<String>>(find.byKey(const Key('language-en'))).checked, isTrue);
  });

  testWidgets('choosing a language saves it and the whole app switches', (tester) async {
    final repo = FakeAccountRepository();
    await _pump(tester, repo);
    await tester.tap(find.byKey(const Key('language-fr')));
    await tester.pumpAndSettle();
    expect(repo.lastLocale, 'fr');
    expect(tester.widget<RadioListTile<String>>(find.byKey(const Key('language-fr'))).checked, isTrue);
  });

  testWidgets('a failed save shows the failure message and keeps the old language', (tester) async {
    final repo = FakeAccountRepository()..localeError = const ApiException(status: 500, code: 'locale_save_failed', message: 'x');
    await _pump(tester, repo);
    await tester.tap(find.byKey(const Key('language-pcm')));
    await tester.pumpAndSettle();
    expect(find.text(AppLocalizations.of(tester.element(find.byType(LanguageScreen))).mobileSettingsLanguageSaveFailed), findsOneWidget);
    expect(tester.widget<RadioListTile<String>>(find.byKey(const Key('language-en'))).checked, isTrue);
  });
}
```

- [ ] **Step 2: Run and confirm failure**

Run: `flutter test test/features/account/settings/language_screen_test.dart`
Expected: FAIL (screen missing).

- [ ] **Step 3: Implement the screen**

```dart
// lib/features/account/settings/language_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/gen/app_localizations.dart';
import 'locale_providers.dart';

/// Settings -> Language (`/account/language`). The language names are shown in their own language on
/// purpose, so someone who cannot read the current one can still find theirs.
class LanguageScreen extends ConsumerWidget {
  const LanguageScreen({super.key});

  Future<void> _choose(BuildContext context, WidgetRef ref, String code) async {
    final messenger = ScaffoldMessenger.of(context);
    final failed = AppLocalizations.of(context).mobileSettingsLanguageSaveFailed;
    final ok = await ref.read(localeProvider.notifier).select(code);
    if (!ok) {
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(SnackBar(content: Text(failed)));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final current = ref.watch(localeProvider)?.languageCode ?? Localizations.localeOf(context).languageCode;
    final options = <(String, String)>[
      ('en', l10n.mobileSettingsLanguageEnglish),
      ('fr', l10n.mobileSettingsLanguageFrench),
      ('pcm', l10n.mobileSettingsLanguagePidgin),
    ];
    return Scaffold(
      appBar: AppBar(title: Text(l10n.mobileSettingsLanguageTitle)),
      body: RadioGroup<String>(
        groupValue: current,
        onChanged: (code) {
          if (code != null) _choose(context, ref, code);
        },
        child: ListView(
          children: [
            for (final (code, label) in options)
              RadioListTile<String>(key: Key('language-$code'), value: code, title: Text(label)),
          ],
        ),
      ),
    );
  }
}
```

(`RadioGroup` is the current Flutter API for radio groups; if the installed Flutter is older and `RadioGroup` is undefined, use `groupValue:`/`onChanged:` on each `RadioListTile` instead. The test's `checked` read works for both.)

- [ ] **Step 4: Run and confirm pass**

Run: `flutter test test/features/account/settings/language_screen_test.dart`
Expected: PASS. If `RadioListTile.checked` is not a public getter in this Flutter version, assert with `tester.widget<RadioListTile<String>>(...).value == groupValue` via the parent `RadioGroup`'s `groupValue` instead.

- [ ] **Step 5: Write the failing hub test**

```dart
// test/features/account/settings/account_hub_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/core/api/models.dart';
import 'package:sentinelx_mobile/core/l10n/gen/app_localizations.dart';
import 'package:sentinelx_mobile/core/providers.dart';
import 'package:sentinelx_mobile/features/account/account_screen.dart';

MeResponse _me() => MeResponse(
      id: 'u1', email: 'a@b.com', roles: const [], isStaff: false, isAdmin: false,
      profile: MeProfile(
        username: 'ada', displayName: 'Ada', avatarUrl: null, whatsappNumber: null, country: null, locale: 'en',
        membershipTier: null, kycVerified: false, deletionRequestedAt: null,
      ),
    );

void main() {
  testWidgets('the signed-in hub offers every settings destination and scrolls on a small phone', (tester) async {
    tester.view.physicalSize = const Size(320, 480);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final opened = <String>[];
    await tester.pumpWidget(ProviderScope(
      retry: (_, _) => null,
      overrides: [meProvider.overrideWith((ref) async => _me())],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: AccountScreen(
          onLogIn: () {},
          onSignUp: () {},
          onLogoTap: () {},
          onEditProfile: () => opened.add('profile'),
          onOpenNotifications: () => opened.add('notifications'),
          onOpenLanguage: () => opened.add('language'),
          onOpenSecurity: () => opened.add('security'),
          onOpenSignInMethods: () => opened.add('sign-in-methods'),
          onOpenPhone: () => opened.add('phone'),
          onOpenDeleteAccount: () => opened.add('delete'),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull); // no overflow on a 320x480 screen

    for (final (key, name) in [
      ('account-language', 'language'),
      ('account-security', 'security'),
      ('account-sign-in-methods', 'sign-in-methods'),
      ('account-phone', 'phone'),
      ('account-delete', 'delete'),
    ]) {
      await tester.ensureVisible(find.byKey(Key(key)));
      await tester.tap(find.byKey(Key(key)));
      await tester.pump();
      expect(opened.last, name);
    }
  });
}
```

- [ ] **Step 6: Run and confirm failure**

Run: `flutter test test/features/account/settings/account_hub_test.dart`
Expected: FAIL (constructor params and keys missing).

- [ ] **Step 7: Update `AccountScreen`**

Add the five optional callbacks to the widget and constructor (keep the existing ones):

```dart
    this.onOpenLanguage,
    this.onOpenSecurity,
    this.onOpenSignInMethods,
    this.onOpenPhone,
    this.onOpenDeleteAccount,
```
```dart
  final VoidCallback? onOpenLanguage;
  final VoidCallback? onOpenSecurity;
  final VoidCallback? onOpenSignInMethods;
  final VoidCallback? onOpenPhone;
  final VoidCallback? onOpenDeleteAccount;
```

In `build`, wrap the body so it scrolls: change `child: Center(child: me.when(` to `child: Center(child: SingleChildScrollView(child: me.when(` and add one closing `)` after the `me.when(...)` call (before the closing of `Center`). Then, in the signed-in `Column`, after the `account-notifications` `ListTile` and before the sign-out `TextButton`, insert:

```dart
                      if (widget.onOpenLanguage != null)
                        ListTile(
                          key: const Key('account-language'),
                          title: Text(l10n.mobileSettingsHubLanguage),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: widget.onOpenLanguage,
                        ),
                      if (widget.onOpenSecurity != null)
                        ListTile(
                          key: const Key('account-security'),
                          title: Text(l10n.mobileSettingsHubSecurity),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: widget.onOpenSecurity,
                        ),
                      if (widget.onOpenSignInMethods != null)
                        ListTile(
                          key: const Key('account-sign-in-methods'),
                          title: Text(l10n.mobileSettingsHubSignInMethods),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: widget.onOpenSignInMethods,
                        ),
                      if (widget.onOpenPhone != null)
                        ListTile(
                          key: const Key('account-phone'),
                          title: Text(l10n.mobileSettingsHubPhone),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: widget.onOpenPhone,
                        ),
                      if (widget.onOpenDeleteAccount != null)
                        ListTile(
                          key: const Key('account-delete'),
                          title: Text(l10n.mobileSettingsHubDeleteAccount),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: widget.onOpenDeleteAccount,
                        ),
```

- [ ] **Step 8: Wire the hub and the Language route in `lib/router/app_router.dart`**

In the `/account` route's `AccountScreen(...)` add:

```dart
                  onOpenLanguage: () => context.push('/account/language'),
                  onOpenSecurity: () => context.push('/account/security'),
                  onOpenSignInMethods: () =>
                      context.push('/account/sign-in-methods'),
                  onOpenPhone: () => context.push('/account/phone'),
                  onOpenDeleteAccount: () => context.push('/account/delete'),
```

and add the first sub-route beside `profile`/`notifications`:

```dart
                  GoRoute(
                    path: 'language',
                    builder: (context, state) => const LanguageScreen(),
                  ),
```

with `import '../features/account/settings/language_screen.dart';`. The other four routes (`security`, `sign-in-methods`, `phone`, `delete`) are added by Tasks 6-9 as each screen lands; until then the hub's tiles for them would push unknown routes, so **do not merge until Task 9** (all tasks stay on the feature branch).

- [ ] **Step 9: Run and confirm pass**

Run: `flutter test test/features/account test/router && flutter analyze`
Expected: PASS, clean. Existing `account-edit-profile`, `account-progress`, `account-notifications`, `account-sign-out` keys are unchanged.

- [ ] **Step 10: Commit**

```bash
git add lib/features/account lib/router/app_router.dart test/features/account
git commit -m "feat(account): settings hub and Language screen

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

### Task 6: Security screen (change email, reset password)

**Files:**
- Create: `lib/features/account/settings/password_sheet.dart`, `lib/features/account/settings/security_screen.dart`
- Modify: `lib/router/app_router.dart` (route `security`)
- Test: `test/features/account/settings/security_screen_test.dart`

**Interfaces:**
- Consumes: `myAccountProvider`, `accountRepositoryProvider`, `authRepositoryProvider.requestReset`, error copy (Task 4).
- Produces: `Future<String?> askForPassword(BuildContext context, {required String title, required String confirmLabel, required Future<String?> Function(String password) onSubmit})` in `password_sheet.dart` (reused by Task 7); route `/account/security`.

- [ ] **Step 1: Write the failing tests**

```dart
// test/features/account/settings/security_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/core/api/api_client.dart';
import 'package:sentinelx_mobile/core/auth/auth_providers.dart';
import 'package:sentinelx_mobile/core/auth/auth_repository.dart';
import 'package:sentinelx_mobile/core/l10n/gen/app_localizations.dart';
import 'package:sentinelx_mobile/core/providers.dart';
import 'package:sentinelx_mobile/features/account/settings/account_repository.dart';
import 'package:sentinelx_mobile/features/account/settings/security_screen.dart';

import '../../../fakes/fake_account_repository.dart';

class _FakeAuth implements AuthRepository {
  String? resetFor;
  Object? resetError;
  @override
  Future<void> requestReset(String email) async {
    if (resetError != null) throw resetError!;
    resetFor = email;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

Future<AppLocalizations> _pump(WidgetTester tester, FakeAccountRepository repo, _FakeAuth auth) async {
  tester.view.physicalSize = const Size(375, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    retry: (_, _) => null,
    overrides: [
      accountRepositoryProvider.overrideWithValue(repo),
      authRepositoryProvider.overrideWithValue(auth),
      viewerIdProvider.overrideWith((ref) async => 'u1'),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const SecurityScreen(),
    ),
  ));
  await tester.pumpAndSettle();
  return AppLocalizations.of(tester.element(find.byType(SecurityScreen)));
}

Future<void> _openSheetAndFill(WidgetTester tester, {String email = 'new@example.com', String password = 'pw'}) async {
  await tester.tap(find.byKey(const Key('security-change-email')));
  await tester.pumpAndSettle();
  await tester.enterText(find.byKey(const Key('security-new-email')), email);
  await tester.enterText(find.byKey(const Key('security-password')), password);
}

void main() {
  testWidgets('shows the current address and a pending change', (tester) async {
    final repo = FakeAccountRepository()..accountResult = testAccount(pendingEmail: 'next@example.com');
    final l10n = await _pump(tester, repo, _FakeAuth());
    expect(find.text('ada@example.com'), findsOneWidget);
    expect(find.text(l10n.emailChangePending('next@example.com')), findsOneWidget);
    expect(find.text(l10n.emailChangePendingHint), findsOneWidget);
  });

  testWidgets('submitting sends the email and password, then tells the user to check the inbox', (tester) async {
    final repo = FakeAccountRepository();
    final l10n = await _pump(tester, repo, _FakeAuth());
    await _openSheetAndFill(tester);
    await tester.tap(find.byKey(const Key('security-submit')));
    await tester.pumpAndSettle();
    expect(repo.lastEmail, 'new@example.com');
    expect(repo.lastPassword, 'pw');
    expect(find.text(l10n.emailChangeSent('new@example.com')), findsOneWidget);
  });

  testWidgets('a wrong password stays on the sheet with the inline message', (tester) async {
    final repo = FakeAccountRepository()..emailError = const ApiException(status: 400, code: 'wrong_password', message: 'x');
    final l10n = await _pump(tester, repo, _FakeAuth());
    await _openSheetAndFill(tester);
    await tester.tap(find.byKey(const Key('security-submit')));
    await tester.pumpAndSettle();
    expect(find.text(l10n.emailChangeErrorsWrongPassword), findsOneWidget);
    expect(find.byKey(const Key('security-password')), findsOneWidget); // still on the sheet
  });

  testWidgets('empty fields never reach the server', (tester) async {
    final repo = FakeAccountRepository();
    await _pump(tester, repo, _FakeAuth());
    await tester.tap(find.byKey(const Key('security-change-email')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('security-submit')));
    await tester.pumpAndSettle();
    expect(repo.calls.where((c) => c == 'changeEmail'), isEmpty);
  });

  testWidgets('a rate limit shows the too-many-attempts message', (tester) async {
    final repo = FakeAccountRepository()
      ..emailError = const ApiException(status: 429, code: 'reauth_rate_limited', message: 'x', fields: {'retryAfterSeconds': '300'});
    final l10n = await _pump(tester, repo, _FakeAuth());
    await _openSheetAndFill(tester);
    await tester.tap(find.byKey(const Key('security-submit')));
    await tester.pumpAndSettle();
    expect(find.text(l10n.mobileSettingsReauthRateLimited), findsOneWidget);
  });

  testWidgets('reset password emails a link to the current address', (tester) async {
    final auth = _FakeAuth();
    final l10n = await _pump(tester, FakeAccountRepository(), auth);
    await tester.tap(find.byKey(const Key('security-reset-password')));
    await tester.pumpAndSettle();
    expect(auth.resetFor, 'ada@example.com');
    expect(find.text(l10n.mobileSettingsSecurityResetSent), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run and confirm failure**

Run: `flutter test test/features/account/settings/security_screen_test.dart`
Expected: FAIL (screen missing).

- [ ] **Step 3: Implement the shared password sheet**

```dart
// lib/features/account/settings/password_sheet.dart
import 'package:flutter/material.dart';

/// A bottom sheet that collects a password and runs [onSubmit] with it. [onSubmit] returns null on success
/// (the sheet closes and the sheet's future completes with `true`) or the message to show inline (the sheet
/// stays open so the user can retype). The password lives only in the sheet's controller.
Future<bool> askForPassword(
  BuildContext context, {
  required String title,
  required String passwordLabel,
  required String confirmLabel,
  required String cancelLabel,
  required Future<String?> Function(String password) onSubmit,
}) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => _PasswordSheet(
      title: title,
      passwordLabel: passwordLabel,
      confirmLabel: confirmLabel,
      cancelLabel: cancelLabel,
      onSubmit: onSubmit,
    ),
  );
  return result ?? false;
}

class _PasswordSheet extends StatefulWidget {
  const _PasswordSheet({
    required this.title,
    required this.passwordLabel,
    required this.confirmLabel,
    required this.cancelLabel,
    required this.onSubmit,
  });
  final String title;
  final String passwordLabel;
  final String confirmLabel;
  final String cancelLabel;
  final Future<String?> Function(String password) onSubmit;

  @override
  State<_PasswordSheet> createState() => _PasswordSheetState();
}

class _PasswordSheetState extends State<_PasswordSheet> {
  final _controller = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_controller.text.isEmpty || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final error = await widget.onSubmit(_controller.text);
    if (!mounted) return;
    if (error == null) {
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _busy = false;
        _error = error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(widget.title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          TextField(
            key: const Key('password-sheet-field'),
            controller: _controller,
            obscureText: true,
            autofocus: true,
            decoration: InputDecoration(labelText: widget.passwordLabel),
            onSubmitted: (_) => _submit(),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, key: const Key('password-sheet-error'), style: const TextStyle(color: Colors.redAccent)),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              TextButton(onPressed: _busy ? null : () => Navigator.of(context).pop(false), child: Text(widget.cancelLabel)),
              const Spacer(),
              FilledButton(key: const Key('password-sheet-confirm'), onPressed: _busy ? null : _submit, child: Text(widget.confirmLabel)),
            ],
          ),
        ],
      ),
    );
  }
}
```

(The Security screen below does not use this sheet for change-email: that flow needs two fields. The sheet is used by Task 7's unlink. Keep it here because Task 7 depends on it and it is general.)

- [ ] **Step 4: Implement the Security screen**

```dart
// lib/features/account/settings/security_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/auth/auth_providers.dart';
import '../../../core/l10n/gen/app_localizations.dart';
import 'account_error_copy.dart';
import 'account_repository.dart';

/// Settings -> Security (`/account/security`): change email (needs the current password; nothing changes
/// until the link in the new inbox is opened) and password reset (the link goes to the current inbox, which
/// proves ownership - there is no "set password" endpoint on purpose).
class SecurityScreen extends ConsumerStatefulWidget {
  const SecurityScreen({super.key});

  @override
  ConsumerState<SecurityScreen> createState() => _SecurityScreenState();
}

class _SecurityScreenState extends ConsumerState<SecurityScreen> {
  String? _sentTo;
  bool _resetBusy = false;
  String? _resetMessage;

  Future<void> _resetPassword(String email) async {
    final l10n = AppLocalizations.of(context);
    setState(() {
      _resetBusy = true;
      _resetMessage = null;
    });
    String message;
    try {
      await ref.read(authRepositoryProvider).requestReset(email);
      message = l10n.mobileSettingsSecurityResetSent;
    } catch (e) {
      message = genericAccountErrorCopy(l10n, e is ApiException ? e.code : 'unknown');
    }
    if (!mounted) return;
    setState(() {
      _resetBusy = false;
      _resetMessage = message;
    });
  }

  Future<void> _changeEmail() async {
    final sent = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _ChangeEmailSheet(),
    );
    if (sent != null && mounted) {
      setState(() => _sentTo = sent);
      ref.invalidate(myAccountProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final account = ref.watch(myAccountProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.mobileSettingsSecurityTitle)),
      body: account.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(genericAccountErrorCopy(l10n, e is ApiException ? e.code : 'unknown')),
            TextButton(onPressed: () => ref.invalidate(myAccountProvider), child: Text(l10n.accountRetry)),
          ]),
        ),
        data: (a) {
          if (a == null) return Center(child: Text(l10n.ntfSignedOut));
          final email = a.signIn.email;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(l10n.mobileSettingsSecurityEmailRow, style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 4),
              Text(email ?? ''),
              if (a.signIn.pendingEmail != null) ...[
                const SizedBox(height: 8),
                Text(l10n.emailChangePending(a.signIn.pendingEmail!)),
                Text(l10n.emailChangePendingHint, style: Theme.of(context).textTheme.bodySmall),
              ],
              if (_sentTo != null) ...[
                const SizedBox(height: 8),
                Text(l10n.emailChangeSent(_sentTo!), key: const Key('security-sent')),
                Text(l10n.emailChangeSentSpam, style: Theme.of(context).textTheme.bodySmall),
              ],
              const SizedBox(height: 8),
              OutlinedButton(
                key: const Key('security-change-email'),
                onPressed: _changeEmail,
                child: Text(l10n.mobileSettingsSecurityChangeEmail),
              ),
              const Divider(height: 32),
              Text(l10n.mobileSettingsSecurityPasswordRow, style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 4),
              Text(l10n.mobileSettingsSecuritySetPasswordHint, style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 8),
              OutlinedButton(
                key: const Key('security-reset-password'),
                onPressed: (_resetBusy || email == null) ? null : () => _resetPassword(email),
                child: Text(l10n.mobileSettingsSecuritySetPassword),
              ),
              if (_resetMessage != null) ...[
                const SizedBox(height: 8),
                Text(_resetMessage!, key: const Key('security-reset-message')),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _ChangeEmailSheet extends ConsumerStatefulWidget {
  const _ChangeEmailSheet();

  @override
  ConsumerState<_ChangeEmailSheet> createState() => _ChangeEmailSheetState();
}

class _ChangeEmailSheetState extends ConsumerState<_ChangeEmailSheet> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    final email = _email.text.trim();
    if (email.isEmpty || _password.text.isEmpty || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final sentTo = await ref.read(accountRepositoryProvider).changeEmail(email: email, password: _password.text);
      if (mounted) Navigator.of(context).pop(sentTo);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = emailChangeErrorCopy(l10n, e is ApiException ? e.code : 'unknown');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.emailChangeTitle, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            TextField(
              key: const Key('security-new-email'),
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              decoration: InputDecoration(labelText: l10n.emailChangeNewLabel),
            ),
            const SizedBox(height: 8),
            TextField(
              key: const Key('security-password'),
              controller: _password,
              obscureText: true,
              decoration: InputDecoration(labelText: l10n.emailChangePasswordLabel, helperText: l10n.emailChangePasswordHint, helperMaxLines: 4),
              onSubmitted: (_) => _submit(),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, key: const Key('security-error'), style: const TextStyle(color: Colors.redAccent)),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                TextButton(onPressed: _busy ? null : () => Navigator.of(context).pop(), child: Text(l10n.emailChangeCancel)),
                const Spacer(),
                FilledButton(
                  key: const Key('security-submit'),
                  onPressed: _busy ? null : _submit,
                  child: Text(_busy ? l10n.emailChangeSending : l10n.emailChangeSubmit),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
```

Note: `l10n.accountRetry` and `l10n.ntfSignedOut` already exist in the ARB (used by `AccountScreen` and the notification settings screen).

- [ ] **Step 5: Add the route** in `lib/router/app_router.dart` beside `language`:

```dart
                  GoRoute(
                    path: 'security',
                    builder: (context, state) => const SecurityScreen(),
                  ),
```
with `import '../features/account/settings/security_screen.dart';`.

- [ ] **Step 6: Run and confirm pass**

Run: `flutter test test/features/account/settings/security_screen_test.dart && flutter analyze`
Expected: PASS, clean. (`mobileSettingsSecurityTitle` is the key generated from `mobileSettings.securityTitle`.)

- [ ] **Step 7: Commit**

```bash
git add lib/features/account/settings lib/router/app_router.dart test/features/account/settings/security_screen_test.dart
git commit -m "feat(account): Security screen with change email and password reset

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

### Task 7: Sign-in methods (link and unlink Google)

**Files:**
- Create: `lib/features/account/settings/google_linker.dart`, `lib/features/account/settings/sign_in_methods_screen.dart`
- Modify: `lib/router/app_router.dart` (route `sign-in-methods`), `android/app/src/main/AndroidManifest.xml`, `test/core/web_links_test.dart`
- Test: `test/features/account/settings/sign_in_methods_screen_test.dart`

**Interfaces:**
- Consumes: `askForPassword` (Task 6), `myAccountProvider`, `accountRepositoryProvider.unlinkGoogle`, `unlinkErrorCopy`.
- Produces: `abstract class GoogleLinker { Future<void> link(); }`, `googleLinkerProvider`, route `/account/sign-in-methods`.

- [ ] **Step 1: Write the failing tests**

```dart
// test/features/account/settings/sign_in_methods_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/core/api/api_client.dart';
import 'package:sentinelx_mobile/core/l10n/gen/app_localizations.dart';
import 'package:sentinelx_mobile/core/providers.dart';
import 'package:sentinelx_mobile/features/account/settings/account_repository.dart';
import 'package:sentinelx_mobile/features/account/settings/google_linker.dart';
import 'package:sentinelx_mobile/features/account/settings/sign_in_methods_screen.dart';

import '../../../fakes/fake_account_repository.dart';

class _FakeLinker implements GoogleLinker {
  int calls = 0;
  Object? error;
  @override
  Future<void> link() async {
    calls++;
    if (error != null) throw error!;
  }
}

Future<AppLocalizations> _pump(WidgetTester tester, FakeAccountRepository repo, _FakeLinker linker) async {
  tester.view.physicalSize = const Size(375, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    retry: (_, _) => null,
    overrides: [
      accountRepositoryProvider.overrideWithValue(repo),
      googleLinkerProvider.overrideWithValue(linker),
      viewerIdProvider.overrideWith((ref) async => 'u1'),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const SignInMethodsScreen(),
    ),
  ));
  await tester.pumpAndSettle();
  return AppLocalizations.of(tester.element(find.byType(SignInMethodsScreen)));
}

void main() {
  testWidgets('not linked: shows Link Google and starts the browser round-trip', (tester) async {
    final linker = _FakeLinker();
    final l10n = await _pump(tester, FakeAccountRepository(), linker);
    expect(find.text(l10n.signInMethodsNotLinked), findsOneWidget);
    await tester.tap(find.byKey(const Key('signin-link-google')));
    await tester.pumpAndSettle();
    expect(linker.calls, 1);
    expect(find.byKey(const Key('signin-link-error')), findsNothing); // a cancelled round-trip shows no error
  });

  testWidgets('a link attempt that throws shows the link-failed message', (tester) async {
    final linker = _FakeLinker()..error = StateError('launch failed');
    final l10n = await _pump(tester, FakeAccountRepository(), linker);
    await tester.tap(find.byKey(const Key('signin-link-google')));
    await tester.pumpAndSettle();
    expect(find.text(l10n.signInMethodsLinkFailed), findsOneWidget);
  });

  testWidgets('coming back from the browser round-trip refetches the account so a successful link shows', (tester) async {
    final repo = FakeAccountRepository();
    await _pump(tester, repo, _FakeLinker());
    final before = repo.calls.where((c) => c == 'account').length;
    await tester.tap(find.byKey(const Key('signin-link-google')));
    await tester.pumpAndSettle();
    repo.accountResult = testAccount(google: true); // what the refetch will see after a successful link
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(repo.calls.where((c) => c == 'account').length, before + 1);
    expect(find.byKey(const Key('signin-link-google')), findsNothing);
    expect(find.byKey(const Key('signin-unlink-google')), findsOneWidget);
  });

  testWidgets('resuming the app without a link attempt does not refetch', (tester) async {
    final repo = FakeAccountRepository();
    await _pump(tester, repo, _FakeLinker());
    final before = repo.calls.where((c) => c == 'account').length;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(repo.calls.where((c) => c == 'account').length, before);
  });

  testWidgets('linked with a password: Unlink asks for the password then calls the server', (tester) async {
    final repo = FakeAccountRepository()..accountResult = testAccount(google: true, passwordIdentity: true);
    final l10n = await _pump(tester, repo, _FakeLinker());
    expect(find.text(l10n.signInMethodsLinked), findsWidgets);
    await tester.tap(find.byKey(const Key('signin-unlink-google')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('password-sheet-field')), 'pw');
    repo.accountResult = testAccount(google: false, passwordIdentity: true); // what the refetch will see
    await tester.tap(find.byKey(const Key('password-sheet-confirm')));
    await tester.pumpAndSettle();
    expect(repo.calls, contains('unlinkGoogle'));
    expect(repo.lastPassword, 'pw');
    expect(find.byKey(const Key('signin-link-google')), findsOneWidget); // refreshed: now offers Link
  });

  testWidgets('a wrong password stays on the sheet', (tester) async {
    final repo = FakeAccountRepository()
      ..accountResult = testAccount(google: true)
      ..unlinkError = const ApiException(status: 400, code: 'wrong_password', message: 'x');
    final l10n = await _pump(tester, repo, _FakeLinker());
    await tester.tap(find.byKey(const Key('signin-unlink-google')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('password-sheet-field')), 'nope');
    await tester.tap(find.byKey(const Key('password-sheet-confirm')));
    await tester.pumpAndSettle();
    expect(find.text(l10n.signInMethodsErrorsWrongPassword), findsOneWidget);
  });

  testWidgets('the only sign-in method cannot be unlinked and says why', (tester) async {
    final repo = FakeAccountRepository()..accountResult = testAccount(google: true, passwordIdentity: false);
    final l10n = await _pump(tester, repo, _FakeLinker());
    expect(find.byKey(const Key('signin-unlink-google')), findsNothing);
    expect(find.text(l10n.signInMethodsOnlyMethod), findsOneWidget);
  });
}
```

Add one case to `test/core/web_links_test.dart` (inside its existing `main`, using that file's `resolveWebLink` import):

```dart
  test('the Google link-callback deep link maps to no in-app route (supabase_flutter consumes it)', () {
    expect(resolveWebLink('ng.com.sentinelxesports.app://link-callback/?code=abc'), isNull);
  });
```

- [ ] **Step 2: Run and confirm failure**

Run: `flutter test test/features/account/settings/sign_in_methods_screen_test.dart test/core/web_links_test.dart`
Expected: the screen test FAILS (missing files); the web-links case should already PASS (confirm it does: custom-scheme host is not a site host, so it returns null). If it does not, fix `resolveWebLink` to return null for non-http(s) schemes before continuing.

- [ ] **Step 3: Implement the linker**

```dart
// lib/features/account/settings/google_linker.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/providers.dart';

/// Starts Supabase's browser OAuth link flow for Google. The only direct Supabase auth call in Settings:
/// linking is an auth operation the server cannot perform for the user. supabase_flutter itself consumes the
/// `ng.com.sentinelxesports.app://link-callback` deep link and exchanges the code; the screen refetches the
/// account when the app resumes.
abstract class GoogleLinker {
  Future<void> link();
}

class SupabaseGoogleLinker implements GoogleLinker {
  SupabaseGoogleLinker(this._auth);
  final GoTrueClient _auth;

  static const redirectTo = 'ng.com.sentinelxesports.app://link-callback';

  @override
  Future<void> link() async {
    await _auth.linkIdentity(OAuthProvider.google, redirectTo: redirectTo);
  }
}

final googleLinkerProvider = Provider<GoogleLinker>((ref) => SupabaseGoogleLinker(ref.watch(supabaseClientProvider).auth));
```

- [ ] **Step 4: Implement the screen**

```dart
// lib/features/account/settings/sign_in_methods_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/l10n/gen/app_localizations.dart';
import 'account_error_copy.dart';
import 'account_repository.dart';
import 'google_linker.dart';
import 'password_sheet.dart';

/// Settings -> Sign-in methods (`/account/sign-in-methods`).
class SignInMethodsScreen extends ConsumerStatefulWidget {
  const SignInMethodsScreen({super.key});

  @override
  ConsumerState<SignInMethodsScreen> createState() => _SignInMethodsScreenState();
}

class _SignInMethodsScreenState extends ConsumerState<SignInMethodsScreen> with WidgetsBindingObserver {
  bool _awaitingLink = false;
  String? _linkError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Coming back from the browser round-trip (success, cancel or failure alike) refetches the account; the
  // Google row then shows whatever actually happened. A cancelled attempt leaves it "Not linked" with no
  // error, which is the intended quiet outcome.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _awaitingLink) {
      _awaitingLink = false;
      ref.invalidate(myAccountProvider);
    }
  }

  Future<void> _link() async {
    final l10n = AppLocalizations.of(context);
    setState(() => _linkError = null);
    try {
      _awaitingLink = true;
      await ref.read(googleLinkerProvider).link();
    } catch (e) {
      _awaitingLink = false;
      if (!mounted) return;
      final unavailable = e.toString().contains('manual_linking_disabled');
      setState(() => _linkError = unavailable ? l10n.mobileSettingsLinkingUnavailable : l10n.signInMethodsLinkFailed);
    }
  }

  Future<void> _unlink() async {
    final l10n = AppLocalizations.of(context);
    final done = await askForPassword(
      context,
      title: l10n.signInMethodsUnlinkConfirm,
      passwordLabel: l10n.signInMethodsPasswordLabel,
      confirmLabel: l10n.signInMethodsUnlinkConfirm,
      cancelLabel: l10n.signInMethodsCancel,
      onSubmit: (password) async {
        try {
          await ref.read(accountRepositoryProvider).unlinkGoogle(password);
          return null;
        } catch (e) {
          return unlinkErrorCopy(l10n, e is ApiException ? e.code : 'unknown');
        }
      },
    );
    if (done) ref.invalidate(myAccountProvider);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final account = ref.watch(myAccountProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.signInMethodsTitle)),
      body: account.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(genericAccountErrorCopy(l10n, e is ApiException ? e.code : 'unknown')),
            TextButton(onPressed: () => ref.invalidate(myAccountProvider), child: Text(l10n.accountRetry)),
          ]),
        ),
        data: (a) {
          if (a == null) return Center(child: Text(l10n.ntfSignedOut));
          final google = a.signIn.google;
          // Mirrors the web: Google can only go if another way in is known to exist.
          final canUnlink = google && a.signIn.passwordIdentity;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(l10n.signInMethodsIntro),
              const SizedBox(height: 16),
              ListTile(
                title: Text(l10n.signInMethodsEmailPassword),
                subtitle: Text(a.signIn.passwordIdentity ? l10n.signInMethodsLinked : l10n.signInMethodsNotSet),
              ),
              ListTile(
                title: Text(l10n.signInMethodsGoogle),
                subtitle: Text(google ? l10n.signInMethodsLinked : l10n.signInMethodsNotLinked),
                trailing: google
                    ? (canUnlink
                        ? TextButton(key: const Key('signin-unlink-google'), onPressed: _unlink, child: Text(l10n.signInMethodsUnlink))
                        : null)
                    : FilledButton(key: const Key('signin-link-google'), onPressed: _link, child: Text(l10n.signInMethodsLink)),
              ),
              if (google && !canUnlink) Text(l10n.signInMethodsOnlyMethod),
              if (google && canUnlink) ...[
                const SizedBox(height: 8),
                Text(l10n.signInMethodsUnlinkExplain, style: Theme.of(context).textTheme.bodySmall),
              ],
              if (_linkError != null) ...[
                const SizedBox(height: 8),
                Text(_linkError!, key: const Key('signin-link-error'), style: const TextStyle(color: Colors.redAccent)),
              ],
            ],
          );
        },
      ),
    );
  }
}
```

- [ ] **Step 5: Add the route and the Android deep-link filter**

`lib/router/app_router.dart` (beside `security`; import `../features/account/settings/sign_in_methods_screen.dart`):

```dart
                  GoRoute(
                    path: 'sign-in-methods',
                    builder: (context, state) => const SignInMethodsScreen(),
                  ),
```

`android/app/src/main/AndroidManifest.xml`: inside the existing `<activity>` (after the `autoVerify` https filter), add:

```xml
            <!-- Google account linking: the Supabase OAuth round-trip returns here (see google_linker.dart).
                 The redirect URL must also be allowlisted in the Supabase Auth settings. -->
            <intent-filter>
                <action android:name="android.intent.action.VIEW"/>
                <category android:name="android.intent.category.DEFAULT"/>
                <category android:name="android.intent.category.BROWSABLE"/>
                <data android:scheme="ng.com.sentinelxesports.app" android:host="link-callback"/>
            </intent-filter>
```

- [ ] **Step 6: Run and confirm pass**

Run: `flutter test test/features/account/settings/sign_in_methods_screen_test.dart test/core/web_links_test.dart && flutter analyze`
Expected: PASS, clean.

- [ ] **Step 7: Commit**

```bash
git add lib/features/account/settings lib/router/app_router.dart android/app/src/main/AndroidManifest.xml test/features/account/settings/sign_in_methods_screen_test.dart test/core/web_links_test.dart
git commit -m "feat(account): sign-in methods with Google link and unlink

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

### Task 8: Phone verification (screen, onboarding gate, redirect)

**Files:**
- Create: `lib/features/account/settings/phone_verify_form.dart`, `lib/features/account/settings/phone_screen.dart`, `lib/features/onboarding/onboarding_phone_screen.dart`
- Modify: `lib/core/auth/onboarding_gate.dart`, `lib/router/auth_redirect.dart`, `lib/router/app_router.dart`
- Test: `test/features/account/settings/phone_verify_form_test.dart`, `test/features/account/settings/phone_screen_test.dart`, `test/core/onboarding_gate_test.dart`, `test/router/auth_redirect_test.dart`

**Interfaces:**
- Consumes: `accountRepositoryProvider`, `myAccountProvider`, `meProvider`, `phoneErrorCopy`, `MeProfile.phoneVerifiedAt`.
- Produces: `PhoneVerifyForm({required VoidCallback onVerified})`; `PhoneScreen`; `OnboardingPhoneScreen`; `resolveOnboardingGate` honours `phoneVerifiedAt`; `evaluateAuthRedirect` routes the `phone` gate; routes `/account/phone` and `/onboarding/phone`.

- [ ] **Step 1: Write the failing gate and redirect tests**

Append to `test/core/onboarding_gate_test.dart` (extend `_me` with a `phoneVerifiedAt` named param: add `String? phoneVerifiedAt` to its signature and `phoneVerifiedAt: phoneVerifiedAt,` to the `MeProfile(...)` call):

```dart
  test('phone gate on and the phone is verified: falls through to the profile gate', () {
    expect(
      resolveOnboardingGate(_me(username: 'ada', phoneVerifiedAt: '2026-10-01T00:00:00.000Z'), _config(enforcePhone: true)),
      OnboardingGate.profile,
    );
  });
  test('phone gate on, verified and profile complete: no gate at all', () {
    expect(
      resolveOnboardingGate(
        _me(username: 'ada', phoneVerifiedAt: '2026-10-01T00:00:00.000Z', profileCompletedAt: '2026-10-02T00:00:00.000Z'),
        _config(enforcePhone: true),
      ),
      OnboardingGate.none,
    );
  });
  test('phone gate off: an unverified phone never gates', () {
    expect(resolveOnboardingGate(_me(username: 'ada'), _config()), OnboardingGate.profile);
  });
```

Append to `test/router/auth_redirect_test.dart` (use that file's existing helper for building an `AuthGateSnapshot`; the calls below show the snapshot explicitly):

```dart
  group('phone gate', () {
    const gated = AuthGateSnapshot(isLoading: false, isSignedIn: true, onboardingGate: OnboardingGate.phone);
    const free = AuthGateSnapshot(isLoading: false, isSignedIn: true, onboardingGate: OnboardingGate.none);

    test('every route redirects to /onboarding/phone while gated', () {
      expect(evaluateAuthRedirect(gated, '/'), '/onboarding/phone');
      expect(evaluateAuthRedirect(gated, '/tournaments'), '/onboarding/phone');
      expect(evaluateAuthRedirect(gated, '/account/phone'), '/onboarding/phone');
    });
    test('the gate screen itself and the always-exempt routes are reachable', () {
      expect(evaluateAuthRedirect(gated, '/onboarding/phone'), isNull);
      expect(evaluateAuthRedirect(gated, '/reset-password'), isNull);
    });
    test('a verified or non-gated user opening /onboarding/phone is sent home', () {
      expect(evaluateAuthRedirect(free, '/onboarding/phone'), '/');
    });
  });
```

- [ ] **Step 2: Run and confirm failure**

Run: `flutter test test/core/onboarding_gate_test.dart test/router/auth_redirect_test.dart`
Expected: FAIL (verified user still gets `phone`; `/` is not redirected).

- [ ] **Step 3: Fix the gate and the redirect**

`lib/core/auth/onboarding_gate.dart` — replace the phone branch and its stale comment:

```dart
  if (me.profile?.username == null) return OnboardingGate.username;
  // Mirrors the web order: username, then phone (only when enforced AND not yet verified), then profile.
  // phoneVerifiedAt comes from /me; a server too old to send it reads as unverified, which is harmless
  // while enforcePhoneVerification is false (the only state shipped today).
  if ((config?.enforcePhoneVerification ?? false) && me.profile?.phoneVerifiedAt == null) return OnboardingGate.phone;
  if (me.profile?.profileCompletedAt == null) return OnboardingGate.profile;
  return OnboardingGate.none;
```

`lib/router/auth_redirect.dart`:

```dart
const _onboardingRoutes = {'/onboarding/username', '/onboarding/phone', '/onboarding/profile'};
```
and add, between the username and profile branches:

```dart
  if (gate.onboardingGate == OnboardingGate.phone) {
    if (location == '/onboarding/phone') return null;
    return '/onboarding/phone';
  }
```

Also update the existing username branch so the phone and profile screens remain unreachable while a username is needed (it already redirects everything except `/onboarding/username`). Run the two test files again: PASS.

- [ ] **Step 4: Write the failing form tests**

```dart
// test/features/account/settings/phone_verify_form_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/core/api/api_client.dart';
import 'package:sentinelx_mobile/core/l10n/gen/app_localizations.dart';
import 'package:sentinelx_mobile/core/providers.dart';
import 'package:sentinelx_mobile/features/account/settings/account_repository.dart';
import 'package:sentinelx_mobile/features/account/settings/phone_verify_form.dart';

import '../../../fakes/fake_account_repository.dart';

Future<AppLocalizations> _pump(WidgetTester tester, FakeAccountRepository repo, {VoidCallback? onVerified}) async {
  tester.view.physicalSize = const Size(375, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    retry: (_, _) => null,
    overrides: [
      accountRepositoryProvider.overrideWithValue(repo),
      viewerIdProvider.overrideWith((ref) async => 'u1'),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: PhoneVerifyForm(onVerified: onVerified ?? () {})),
    ),
  ));
  await tester.pumpAndSettle();
  return AppLocalizations.of(tester.element(find.byType(PhoneVerifyForm)));
}

Future<void> _sendCode(WidgetTester tester, {String phone = '08012345678'}) async {
  await tester.enterText(find.byKey(const Key('phone-number')), phone);
  await tester.tap(find.byKey(const Key('phone-send')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('sending a code reveals the code field and a resend countdown', (tester) async {
    final repo = FakeAccountRepository();
    final l10n = await _pump(tester, repo);
    expect(find.byKey(const Key('phone-code')), findsNothing);
    await _sendCode(tester);
    expect(repo.lastPhone, '08012345678');
    expect(find.byKey(const Key('phone-code')), findsOneWidget);
    expect(find.byKey(const Key('phone-resend')), findsOneWidget);
    expect(tester.widget<TextButton>(find.byKey(const Key('phone-resend'))).onPressed, isNull); // counting down
    expect(find.textContaining(l10n.mobileSettingsPhoneResendIn('60').split('60').first), findsOneWidget);
  });

  testWidgets('the countdown ends and Resend becomes available', (tester) async {
    final repo = FakeAccountRepository();
    await _pump(tester, repo);
    await _sendCode(tester);
    await tester.pump(const Duration(seconds: 61));
    expect(tester.widget<TextButton>(find.byKey(const Key('phone-resend'))).onPressed, isNotNull);
  });

  testWidgets('a server cooldown starts the countdown from retryAfterSeconds and keeps the number step', (tester) async {
    final repo = FakeAccountRepository()
      ..phoneCodeError = const ApiException(status: 429, code: 'phone_cooldown', message: 'x', fields: {'retryAfterSeconds': '40'});
    final l10n = await _pump(tester, repo);
    await _sendCode(tester);
    expect(find.text(l10n.mobileSettingsPhoneErrorCooldown), findsOneWidget);
    expect(find.byKey(const Key('phone-code')), findsNothing);
    expect(tester.widget<FilledButton>(find.byKey(const Key('phone-send'))).onPressed, isNull); // waits out the 40 s
    await tester.pump(const Duration(seconds: 41));
    expect(tester.widget<FilledButton>(find.byKey(const Key('phone-send'))).onPressed, isNotNull);
  });

  testWidgets('phone_unavailable shows the fixed message with no retry loop', (tester) async {
    final repo = FakeAccountRepository()..phoneCodeError = const ApiException(status: 503, code: 'phone_unavailable', message: 'x');
    final l10n = await _pump(tester, repo);
    await _sendCode(tester);
    expect(find.text(l10n.mobileSettingsPhoneUnavailable), findsOneWidget);
    expect(find.byKey(const Key('phone-send')), findsNothing);
  });

  testWidgets('an invalid number shows the invalid-number message', (tester) async {
    final repo = FakeAccountRepository()..phoneCodeError = const ApiException(status: 400, code: 'phone_invalid', message: 'x');
    final l10n = await _pump(tester, repo);
    await _sendCode(tester, phone: 'abc');
    expect(find.text(l10n.mobileSettingsPhoneErrorInvalid), findsOneWidget);
  });

  testWidgets('a wrong code shows the message and stays; the right code verifies and calls back', (tester) async {
    final repo = FakeAccountRepository();
    var verified = 0;
    final l10n = await _pump(tester, repo, onVerified: () => verified++);
    await _sendCode(tester);

    repo.phoneConfirmError = const ApiException(status: 400, code: 'phone_code_wrong', message: 'x');
    await tester.enterText(find.byKey(const Key('phone-code')), '000000');
    await tester.tap(find.byKey(const Key('phone-confirm')));
    await tester.pumpAndSettle();
    expect(find.text(l10n.mobileSettingsPhoneErrorCodeWrong), findsOneWidget);
    expect(verified, 0);

    repo.phoneConfirmError = null;
    await tester.enterText(find.byKey(const Key('phone-code')), '123456');
    await tester.tap(find.byKey(const Key('phone-confirm')));
    await tester.pumpAndSettle();
    expect(repo.lastCode, '123456');
    expect(verified, 1);
  });

  testWidgets('a malformed code never reaches the server', (tester) async {
    final repo = FakeAccountRepository();
    await _pump(tester, repo);
    await _sendCode(tester);
    await tester.enterText(find.byKey(const Key('phone-code')), '12');
    await tester.tap(find.byKey(const Key('phone-confirm')));
    await tester.pumpAndSettle();
    expect(repo.calls.where((c) => c == 'confirmPhoneCode'), isEmpty);
  });
}
```

- [ ] **Step 5: Run and confirm failure**

Run: `flutter test test/features/account/settings/phone_verify_form_test.dart`
Expected: FAIL (form missing).

- [ ] **Step 6: Implement the form**

```dart
// lib/features/account/settings/phone_verify_form.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/l10n/gen/app_localizations.dart';
import '../../../core/providers.dart';
import 'account_error_copy.dart';
import 'account_repository.dart';

/// The WhatsApp verification flow, shared by Settings -> Phone and the `/onboarding/phone` gate: number,
/// then a 6-digit code with a resend countdown, then [onVerified]. The server owns every limit (cooldown,
/// daily cap, attempts); the countdown here is a courtesy that a 429's `retryAfterSeconds` always overrides.
class PhoneVerifyForm extends ConsumerStatefulWidget {
  const PhoneVerifyForm({super.key, required this.onVerified});

  final VoidCallback onVerified;

  @override
  ConsumerState<PhoneVerifyForm> createState() => _PhoneVerifyFormState();
}

class _PhoneVerifyFormState extends ConsumerState<PhoneVerifyForm> {
  final _phone = TextEditingController();
  final _code = TextEditingController();
  Timer? _tick;
  bool _codeSent = false;
  bool _busy = false;
  bool _unavailable = false;
  int _secondsLeft = 0;
  String? _error;

  @override
  void dispose() {
    _tick?.cancel();
    _phone.dispose();
    _code.dispose();
    super.dispose();
  }

  void _startCountdown(int seconds) {
    _tick?.cancel();
    setState(() => _secondsLeft = seconds);
    if (seconds <= 0) return;
    _tick = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() => _secondsLeft = (_secondsLeft - 1).clamp(0, 3600));
      if (_secondsLeft == 0) t.cancel();
    });
  }

  String _copy(Object e) => phoneErrorCopy(AppLocalizations.of(context), e is ApiException ? e.code : 'unknown');

  Future<void> _send() async {
    final number = _phone.text.trim();
    if (number.isEmpty || _busy || _secondsLeft > 0) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final ticket = await ref.read(accountRepositoryProvider).requestPhoneCode(number);
      if (!mounted) return;
      // Clamped to 0..60: a skewed device clock must neither lock the button for hours nor open it early
      // (the server's cooldown is the real gate and answers 429 with retryAfterSeconds if we are early).
      final remaining = ticket.resendAt.difference(DateTime.now().toUtc()).inSeconds.clamp(0, 60);
      setState(() {
        _busy = false;
        _codeSent = true;
      });
      _startCountdown(remaining);
    } catch (e) {
      if (!mounted) return;
      final code = e is ApiException ? e.code : '';
      setState(() {
        _busy = false;
        if (code == 'phone_unavailable') {
          _unavailable = true;
        } else {
          _error = _copy(e);
        }
      });
      if (e is ApiException && e.code == 'phone_cooldown') {
        _startCountdown(int.tryParse(e.fields['retryAfterSeconds'] ?? '') ?? 60);
      }
    }
  }

  Future<void> _confirm() async {
    final code = _code.text.trim();
    if (_busy) return;
    if (!RegExp(r'^[0-9]{6}$').hasMatch(code)) {
      setState(() => _error = AppLocalizations.of(context).mobileSettingsPhoneErrorCodeInvalid);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(accountRepositoryProvider).confirmPhoneCode(code);
      if (!mounted) return;
      ref.invalidate(myAccountProvider);
      ref.invalidate(meProvider); // the onboarding gate reads phoneVerifiedAt from /me
      widget.onVerified();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = _copy(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (_unavailable) {
      return Text(l10n.mobileSettingsPhoneUnavailable, key: const Key('phone-unavailable'));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          key: const Key('phone-number'),
          controller: _phone,
          enabled: !_codeSent,
          keyboardType: TextInputType.phone,
          autofillHints: const [AutofillHints.telephoneNumber],
          decoration: InputDecoration(labelText: l10n.mobileSettingsPhoneNumberLabel),
        ),
        const SizedBox(height: 12),
        if (!_codeSent)
          FilledButton(
            key: const Key('phone-send'),
            onPressed: (_busy || _secondsLeft > 0) ? null : _send,
            child: Text(_secondsLeft > 0 ? l10n.mobileSettingsPhoneResendIn('$_secondsLeft') : l10n.mobileSettingsPhoneSendCode),
          )
        else ...[
          TextField(
            key: const Key('phone-code'),
            controller: _code,
            keyboardType: TextInputType.number,
            maxLength: 6,
            autofillHints: const [AutofillHints.oneTimeCode],
            decoration: InputDecoration(labelText: l10n.mobileSettingsPhoneCodeLabel, counterText: ''),
            onSubmitted: (_) => _confirm(),
          ),
          const SizedBox(height: 8),
          FilledButton(key: const Key('phone-confirm'), onPressed: _busy ? null : _confirm, child: Text(l10n.mobileSettingsPhoneConfirm)),
          TextButton(
            key: const Key('phone-resend'),
            onPressed: (_busy || _secondsLeft > 0) ? null : _resendFromCodeStep,
            child: Text(_secondsLeft > 0 ? l10n.mobileSettingsPhoneResendIn('$_secondsLeft') : l10n.mobileSettingsPhoneResend),
          ),
        ],
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(_error!, key: const Key('phone-error'), style: const TextStyle(color: Colors.redAccent)),
        ],
      ],
    );
  }

  Future<void> _resendFromCodeStep() async {
    // Same call as the first send, with the number the user already typed (the field is read-only now).
    setState(() => _codeSent = false);
    await _send();
    if (mounted && _error != null) setState(() => _codeSent = true);
  }
}
```

- [ ] **Step 7: Run and confirm the form tests pass**

Run: `flutter test test/features/account/settings/phone_verify_form_test.dart`
Expected: PASS. In the cooldown test the **Send** button is the active control (the screen stays on the number step), which is why it asserts on `phone-send`. If `_resendFromCodeStep`'s brief flip back to the number step causes a flicker in the real UI, that is acceptable (the field keeps its text); do not add more state for it.

- [ ] **Step 8: Write the failing screen tests, then implement the screens and routes**

```dart
// test/features/account/settings/phone_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sentinelx_mobile/core/api/account_models.dart';
import 'package:sentinelx_mobile/core/l10n/gen/app_localizations.dart';
import 'package:sentinelx_mobile/core/providers.dart';
import 'package:sentinelx_mobile/features/account/settings/account_repository.dart';
import 'package:sentinelx_mobile/features/account/settings/phone_screen.dart';
import 'package:sentinelx_mobile/features/onboarding/onboarding_phone_screen.dart';

import '../../../fakes/fake_account_repository.dart';

Future<void> _pump(WidgetTester tester, Widget home, FakeAccountRepository repo) async {
  tester.view.physicalSize = const Size(375, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final router = GoRouter(routes: [
    GoRoute(path: '/', builder: (_, _) => home),
    GoRoute(path: '/home', builder: (_, _) => const Scaffold(body: Text('HOME'))),
  ]);
  await tester.pumpWidget(ProviderScope(
    retry: (_, _) => null,
    overrides: [
      accountRepositoryProvider.overrideWithValue(repo),
      viewerIdProvider.overrideWith((ref) async => 'u1'),
    ],
    child: MaterialApp.router(
      routerConfig: router,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Settings -> Phone shows the masked number once verified, never the form', (tester) async {
    final repo = FakeAccountRepository()
      ..accountResult = testAccount(phone: AccountPhone(masked: '••••••678', verifiedAt: DateTime.utc(2026, 10, 1)));
    await _pump(tester, const PhoneScreen(), repo);
    final l10n = AppLocalizations.of(tester.element(find.byType(PhoneScreen)));
    expect(find.text(l10n.mobileSettingsPhoneVerified('••••••678')), findsOneWidget);
    expect(find.byKey(const Key('phone-number')), findsNothing);
  });

  testWidgets('Settings -> Phone shows the form when not verified', (tester) async {
    await _pump(tester, const PhoneScreen(), FakeAccountRepository());
    expect(find.byKey(const Key('phone-number')), findsOneWidget);
  });

  testWidgets('the onboarding gate screen has the form, no back button and no skip', (tester) async {
    await _pump(tester, const OnboardingPhoneScreen(), FakeAccountRepository());
    expect(find.byKey(const Key('phone-number')), findsOneWidget);
    expect(find.byType(BackButton), findsNothing);
    expect(find.byKey(const Key('onboarding-phone-skip')), findsNothing);
  });
}
```

```dart
// lib/features/account/settings/phone_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/l10n/gen/app_localizations.dart';
import 'account_error_copy.dart';
import 'account_repository.dart';
import 'phone_verify_form.dart';

/// Settings -> Phone verification (`/account/phone`).
class PhoneScreen extends ConsumerWidget {
  const PhoneScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final account = ref.watch(myAccountProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.mobileSettingsPhoneTitle)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: account.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(genericAccountErrorCopy(l10n, e is ApiException ? e.code : 'unknown')),
              TextButton(onPressed: () => ref.invalidate(myAccountProvider), child: Text(l10n.accountRetry)),
            ]),
          ),
          data: (a) {
            if (a == null) return Center(child: Text(l10n.ntfSignedOut));
            final phone = a.phone;
            if (phone != null) return Text(l10n.mobileSettingsPhoneVerified(phone.masked), key: const Key('phone-verified'));
            return SingleChildScrollView(child: PhoneVerifyForm(onVerified: () => ref.invalidate(myAccountProvider)));
          },
        ),
      ),
    );
  }
}
```

```dart
// lib/features/onboarding/onboarding_phone_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/gen/app_localizations.dart';
import '../account/settings/phone_verify_form.dart';

/// The gate version of phone verification (`/onboarding/phone`), shown when `enforcePhoneVerification` is on
/// and the player's phone is not verified. Same form as Settings; no back button and no skip, because the
/// router redirects every other route here until it succeeds (the redirect then sends a verified user home).
class OnboardingPhoneScreen extends StatelessWidget {
  const OnboardingPhoneScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: AppBar(automaticallyImplyLeading: false, title: Text(l10n.authPhoneStepTitle)),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l10n.authPhoneStepSubtitle),
              const SizedBox(height: 16),
              // meProvider is refreshed by the form; the router's gate listener then redirects to '/'.
              PhoneVerifyForm(onVerified: () => context.go('/')),
            ],
          ),
        ),
      ),
    );
  }
}
```

Routes in `lib/router/app_router.dart` (imports `../features/account/settings/phone_screen.dart` and `../features/onboarding/onboarding_phone_screen.dart`): next to the other onboarding routes,

```dart
      GoRoute(
        path: '/onboarding/phone',
        builder: (context, state) => const OnboardingPhoneScreen(),
      ),
```
and inside `/account` beside `security`:
```dart
                  GoRoute(
                    path: 'phone',
                    builder: (context, state) => const PhoneScreen(),
                  ),
```

- [ ] **Step 9: Run and confirm pass**

Run: `flutter test test/features/account/settings test/core/onboarding_gate_test.dart test/router && flutter analyze`
Expected: PASS, clean.

- [ ] **Step 10: Commit**

```bash
git add lib/core/auth lib/router lib/features/account/settings lib/features/onboarding test
git commit -m "feat(account): phone verification screen, onboarding gate and redirect

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

### Task 9: Account deletion (screen and app-wide banner)

**Files:**
- Create: `lib/features/account/settings/delete_account_screen.dart`, `lib/features/account/settings/deletion_banner_host.dart`
- Modify: `lib/app.dart`, `lib/router/app_router.dart`
- Test: `test/features/account/settings/delete_account_screen_test.dart`, `test/features/account/settings/deletion_banner_host_test.dart`

**Interfaces:**
- Consumes: `myAccountProvider`, `accountRepositoryProvider`, `meProvider`, `authRepositoryProvider.signOut`, `DeletionBlocker.listFrom`, `dateLocale`.
- Produces: `DeleteAccountScreen`, `DeletionBannerHost({required Widget child})`, route `/account/delete`.

- [ ] **Step 1: Write the failing screen tests**

```dart
// test/features/account/settings/delete_account_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sentinelx_mobile/core/api/account_models.dart';
import 'package:sentinelx_mobile/core/api/api_client.dart';
import 'package:sentinelx_mobile/core/api/models.dart';
import 'package:sentinelx_mobile/core/auth/auth_providers.dart';
import 'package:sentinelx_mobile/core/auth/auth_repository.dart';
import 'package:sentinelx_mobile/core/l10n/gen/app_localizations.dart';
import 'package:sentinelx_mobile/core/providers.dart';
import 'package:sentinelx_mobile/features/account/settings/account_repository.dart';
import 'package:sentinelx_mobile/features/account/settings/delete_account_screen.dart';

import '../../../fakes/fake_account_repository.dart';

class _FakeAuth implements AuthRepository {
  int signOuts = 0;
  Object? signOutError;
  @override
  Future<void> signOut() async {
    signOuts++;
    if (signOutError != null) throw signOutError!;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

MeResponse _me({String? deletionRequestedAt}) => MeResponse(
      id: 'u1', email: 'a@b.com', roles: const [], isStaff: false, isAdmin: false,
      profile: MeProfile(
        username: 'Rex', displayName: 'Rex', avatarUrl: null, whatsappNumber: null, country: null, locale: 'en',
        membershipTier: null, kycVerified: false, deletionRequestedAt: deletionRequestedAt,
      ),
    );

Future<AppLocalizations> _pump(WidgetTester tester, FakeAccountRepository repo, _FakeAuth auth, {MeResponse? me}) async {
  tester.view.physicalSize = const Size(375, 1200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final router = GoRouter(routes: [
    GoRoute(path: '/', builder: (_, _) => const DeleteAccountScreen()),
    GoRoute(path: '/login', builder: (_, _) => const Scaffold(body: Text('LOGIN PAGE'))),
  ]);
  await tester.pumpWidget(ProviderScope(
    retry: (_, _) => null,
    overrides: [
      accountRepositoryProvider.overrideWithValue(repo),
      authRepositoryProvider.overrideWithValue(auth),
      viewerIdProvider.overrideWith((ref) async => 'u1'),
      meProvider.overrideWith((ref) async => me ?? _me()),
    ],
    child: MaterialApp.router(
      routerConfig: router,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    ),
  ));
  await tester.pumpAndSettle();
  return AppLocalizations.of(tester.element(find.byType(DeleteAccountScreen)));
}

void main() {
  testWidgets('not pending: scheduling needs the literal DELETE', (tester) async {
    final repo = FakeAccountRepository();
    await _pump(tester, repo, _FakeAuth());
    await tester.ensureVisible(find.byKey(const Key('delete-schedule')));
    await tester.enterText(find.byKey(const Key('delete-confirm-field')), 'delete');
    await tester.tap(find.byKey(const Key('delete-schedule')));
    await tester.pumpAndSettle();
    expect(repo.calls.where((c) => c == 'requestDeletion'), isEmpty);

    await tester.enterText(find.byKey(const Key('delete-confirm-field')), 'DELETE');
    repo.accountResult = testAccount(
      deletion: DeletionState(requestedAt: DateTime.utc(2026, 10, 7), dueAt: DateTime.utc(2026, 10, 22), daysRemaining: 15),
    );
    await tester.tap(find.byKey(const Key('delete-schedule')));
    await tester.pumpAndSettle();
    expect(repo.calls, contains('requestDeletion'));
    expect(find.byKey(const Key('delete-pending')), findsOneWidget); // refreshed into the pending state
  });

  testWidgets('blockers are listed with their copy and nothing is scheduled', (tester) async {
    final repo = FakeAccountRepository()
      ..deletionError = const ApiException(
        status: 409,
        code: 'deletion_blocked',
        message: 'x',
        details: {
          'blockers': [
            {'code': 'wallet_balance', 'amount': 5000},
            {'code': 'pending_withdrawal', 'count': 2},
            {'code': 'brand_new_blocker', 'count': 1},
          ],
        },
      );
    final l10n = await _pump(tester, repo, _FakeAuth());
    await tester.ensureVisible(find.byKey(const Key('delete-schedule')));
    await tester.enterText(find.byKey(const Key('delete-confirm-field')), 'DELETE');
    await tester.tap(find.byKey(const Key('delete-schedule')));
    await tester.pumpAndSettle();
    expect(find.text(l10n.accountDeletionBlockedTitle), findsOneWidget);
    expect(find.text(l10n.accountDeletionBlockerWalletBalance('₦5,000')), findsOneWidget);
    expect(find.text(l10n.accountDeletionBlockerWithdrawal('2')), findsOneWidget);
    expect(find.byKey(const Key('blocker-unknown')), findsOneWidget); // an unknown code still gets a line
  });

  testWidgets('pending: shows the countdown and Cancel deletion cancels', (tester) async {
    final repo = FakeAccountRepository()
      ..accountResult = testAccount(
        deletion: DeletionState(requestedAt: DateTime.utc(2026, 10, 5), dueAt: DateTime.utc(2026, 10, 20), daysRemaining: 13),
      );
    await _pump(tester, repo, _FakeAuth(), me: _me(deletionRequestedAt: '2026-10-05T00:00:00.000Z'));
    expect(find.byKey(const Key('delete-pending')), findsOneWidget);
    repo.accountResult = testAccount();
    await tester.tap(find.byKey(const Key('delete-cancel')));
    await tester.pumpAndSettle();
    expect(repo.calls, contains('cancelDeletion'));
    expect(find.byKey(const Key('delete-schedule')), findsOneWidget);
  });

  testWidgets('delete now: wrong username is refused client-side, the right one deletes, signs out and goes to login', (tester) async {
    final repo = FakeAccountRepository();
    final auth = _FakeAuth();
    await _pump(tester, repo, auth);
    await tester.ensureVisible(find.byKey(const Key('delete-now-field')));
    await tester.enterText(find.byKey(const Key('delete-now-field')), 'someone');
    await tester.tap(find.byKey(const Key('delete-now')));
    await tester.pumpAndSettle();
    expect(repo.calls.where((c) => c == 'deleteNow'), isEmpty);

    await tester.enterText(find.byKey(const Key('delete-now-field')), '  rex ');
    await tester.tap(find.byKey(const Key('delete-now')));
    await tester.pumpAndSettle();
    expect(repo.lastUsername, 'rex');
    expect(auth.signOuts, 1);
    expect(find.text('LOGIN PAGE'), findsOneWidget);
  });

  testWidgets('delete now still ends on login when signOut itself fails (the auth user is already gone)', (tester) async {
    final repo = FakeAccountRepository();
    final auth = _FakeAuth()..signOutError = StateError('401');
    await _pump(tester, repo, auth);
    await tester.ensureVisible(find.byKey(const Key('delete-now-field')));
    await tester.enterText(find.byKey(const Key('delete-now-field')), 'Rex');
    await tester.tap(find.byKey(const Key('delete-now')));
    await tester.pumpAndSettle();
    expect(find.text('LOGIN PAGE'), findsOneWidget);
  });

  testWidgets('delete now blocked: stays signed in and lists the blockers', (tester) async {
    final repo = FakeAccountRepository()
      ..deleteNowError = const ApiException(status: 409, code: 'deletion_blocked', message: 'x', details: {
        'blockers': [{'code': 'active_listing', 'count': 1}],
      });
    final auth = _FakeAuth();
    final l10n = await _pump(tester, repo, auth);
    await tester.ensureVisible(find.byKey(const Key('delete-now-field')));
    await tester.enterText(find.byKey(const Key('delete-now-field')), 'Rex');
    await tester.tap(find.byKey(const Key('delete-now')));
    await tester.pumpAndSettle();
    expect(auth.signOuts, 0);
    expect(find.text(l10n.accountDeletionBlockerListing('1')), findsOneWidget);
    expect(find.text('LOGIN PAGE'), findsNothing);
  });
}
```

- [ ] **Step 2: Run and confirm failure**

Run: `flutter test test/features/account/settings/delete_account_screen_test.dart`
Expected: FAIL (screen missing).

- [ ] **Step 3: Implement the screen**

```dart
// lib/features/account/settings/delete_account_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/api/account_models.dart';
import '../../../core/api/api_client.dart';
import '../../../core/auth/auth_providers.dart';
import '../../../core/l10n/gen/app_localizations.dart';
import '../../../core/providers.dart';
import '../../../core/utils/date_locale.dart';
import 'account_error_copy.dart';
import 'account_repository.dart';

String _formatAmount(num amount) => '₦${NumberFormat.decimalPattern('en').format(amount)}';

/// One readable line per blocker; an unknown code from a newer server still gets a generic line so the user
/// is never told "blocked" with nothing listed.
Widget _blockerLine(AppLocalizations l10n, DeletionBlocker b) {
  final count = '${b.count ?? 0}';
  final text = switch (b.code) {
    'wallet_balance' => l10n.accountDeletionBlockerWalletBalance(_formatAmount(b.amount ?? 0)),
    'pending_withdrawal' => l10n.accountDeletionBlockerWithdrawal(count),
    'open_escrow_order' => l10n.accountDeletionBlockerEscrow(count),
    'active_listing' => l10n.accountDeletionBlockerListing(count),
    'active_tournament' => l10n.accountDeletionBlockerTournament,
    'unfinished_match' => l10n.accountDeletionBlockerMatch(count),
    'unfinished_friendly' => l10n.accountDeletionBlockerFriendly(count),
    _ => l10n.mobileSettingsDeleteFailed,
  };
  final known = const {
    'wallet_balance', 'pending_withdrawal', 'open_escrow_order', 'active_listing', 'active_tournament', 'unfinished_match',
    'unfinished_friendly',
  }.contains(b.code);
  return Padding(
    key: known ? null : const Key('blocker-unknown'),
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Text(text),
  );
}

/// Settings -> Delete account (`/account/delete`): schedule (type DELETE, 15-day grace), cancel while
/// pending, or delete now (type the exact username, irreversible).
class DeleteAccountScreen extends ConsumerStatefulWidget {
  const DeleteAccountScreen({super.key});

  @override
  ConsumerState<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends ConsumerState<DeleteAccountScreen> {
  final _confirm = TextEditingController();
  final _usernameConfirm = TextEditingController();
  bool _busy = false;
  String? _error;
  List<DeletionBlocker> _blockers = const [];

  @override
  void dispose() {
    _confirm.dispose();
    _usernameConfirm.dispose();
    super.dispose();
  }

  void _fail(Object e) {
    final l10n = AppLocalizations.of(context);
    if (e is ApiException && e.code == 'deletion_blocked') {
      setState(() {
        _busy = false;
        _error = null;
        _blockers = DeletionBlocker.listFrom(e.details);
      });
      return;
    }
    setState(() {
      _busy = false;
      _blockers = const [];
      _error = e is ApiException && e.code == 'network' ? l10n.mobileSettingsNetworkError : l10n.mobileSettingsDeleteFailed;
    });
  }

  Future<void> _schedule() async {
    if (_busy || _confirm.text != 'DELETE') return;
    setState(() {
      _busy = true;
      _error = null;
      _blockers = const [];
    });
    try {
      await ref.read(accountRepositoryProvider).requestDeletion();
      ref.invalidate(myAccountProvider);
      ref.invalidate(meProvider); // the app-wide banner reads deletionRequestedAt from /me
      if (mounted) setState(() => _busy = false);
    } catch (e) {
      if (mounted) _fail(e);
    }
  }

  Future<void> _cancel() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(accountRepositoryProvider).cancelDeletion();
      ref.invalidate(myAccountProvider);
      ref.invalidate(meProvider);
      if (mounted) setState(() => _busy = false);
    } catch (e) {
      if (mounted) _fail(e);
    }
  }

  Future<void> _deleteNow(String username) async {
    final typed = _usernameConfirm.text.trim();
    if (_busy || typed.toLowerCase() != username.toLowerCase()) return;
    setState(() {
      _busy = true;
      _error = null;
      _blockers = const [];
    });
    try {
      await ref.read(accountRepositoryProvider).deleteNow(typed);
    } catch (e) {
      if (mounted) _fail(e);
      return;
    }
    // The server has deleted the auth user, so signing out may itself be refused. Whatever happens, this
    // account is gone: clear the local session if we can and always land on the login screen.
    try {
      await ref.read(authRepositoryProvider).signOut();
    } catch (_) {}
    if (mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final account = ref.watch(myAccountProvider);
    final username = ref.watch(meProvider).asData?.value?.profile?.username ?? '';
    return Scaffold(
      appBar: AppBar(title: Text(l10n.accountDeletionTitle)),
      body: account.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(genericAccountErrorCopy(l10n, e is ApiException ? e.code : 'unknown')),
            TextButton(onPressed: () => ref.invalidate(myAccountProvider), child: Text(l10n.accountRetry)),
          ]),
        ),
        data: (a) {
          if (a == null) return Center(child: Text(l10n.ntfSignedOut));
          final deletion = a.deletion;
          final locale = dateLocale(l10n.localeName);
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (deletion != null) ...[
                Text(l10n.accountDeletionPendingHeading, key: const Key('delete-pending'), style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Text(l10n.accountDeletionPendingBody(DateFormat.yMMMd(locale).format(deletion.dueAt.toLocal()), '${deletion.daysRemaining}')),
                const SizedBox(height: 4),
                Text(l10n.accountDeletionCanCancel),
                const SizedBox(height: 12),
                OutlinedButton(
                  key: const Key('delete-cancel'),
                  onPressed: _busy ? null : _cancel,
                  child: Text(_busy ? l10n.accountDeletionBannerCancelling : l10n.accountDeletionBannerCancel),
                ),
              ] else ...[
                Text(l10n.accountDeletionHistoryKept),
                const SizedBox(height: 4),
                Text(l10n.accountDeletionUsernameRetired(username)),
                const SizedBox(height: 4),
                Text(l10n.accountDeletionEmailReusable),
                const SizedBox(height: 16),
                TextField(
                  key: const Key('delete-confirm-field'),
                  controller: _confirm,
                  decoration: InputDecoration(labelText: l10n.accountDeletionTypeDelete),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 8),
                FilledButton(
                  key: const Key('delete-schedule'),
                  onPressed: (_busy || _confirm.text != 'DELETE') ? null : _schedule,
                  child: Text(_busy ? l10n.accountDeletionConfirmButtonPending : l10n.accountDeletionConfirmButton),
                ),
              ],
              if (_blockers.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(l10n.accountDeletionBlockedTitle, style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 4),
                for (final b in _blockers) _blockerLine(l10n, b),
              ],
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, key: const Key('delete-error'), style: const TextStyle(color: Colors.redAccent)),
              ],
              const Divider(height: 40),
              Text(l10n.accountDeletionDeleteNowTitle, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(l10n.accountDeletionDeleteNowWarning),
              const SizedBox(height: 12),
              TextField(
                key: const Key('delete-now-field'),
                controller: _usernameConfirm,
                decoration: InputDecoration(labelText: l10n.accountDeletionDeleteNowPrompt(username)),
              ),
              const SizedBox(height: 8),
              FilledButton(
                key: const Key('delete-now'),
                style: FilledButton.styleFrom(backgroundColor: Colors.red.shade800),
                onPressed: _busy ? null : () => _deleteNow(username),
                child: Text(_busy ? l10n.accountDeletionDeleteNowButtonPending : l10n.accountDeletionDeleteNowButton),
              ),
            ],
          );
        },
      ),
    );
  }
}
```

(For the "Delete now" flow with deletion pending, the web blocks it with `restricted` copy only for restricted actions elsewhere; deleting now is allowed during grace, as on the web.)

- [ ] **Step 4: Run and confirm the screen tests pass**

Run: `flutter test test/features/account/settings/delete_account_screen_test.dart`
Expected: PASS.

- [ ] **Step 5: Write the failing banner tests**

```dart
// test/features/account/settings/deletion_banner_host_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/core/api/account_models.dart';
import 'package:sentinelx_mobile/core/api/models.dart';
import 'package:sentinelx_mobile/core/l10n/gen/app_localizations.dart';
import 'package:sentinelx_mobile/core/providers.dart';
import 'package:sentinelx_mobile/features/account/settings/account_repository.dart';
import 'package:sentinelx_mobile/features/account/settings/deletion_banner_host.dart';

import '../../../fakes/fake_account_repository.dart';

MeResponse _me(String? requested) => MeResponse(
      id: 'u1', email: 'a@b.com', roles: const [], isStaff: false, isAdmin: false,
      profile: MeProfile(
        username: 'ada', displayName: 'Ada', avatarUrl: null, whatsappNumber: null, country: null, locale: 'en',
        membershipTier: null, kycVerified: false, deletionRequestedAt: requested,
      ),
    );

class _Probe extends StatefulWidget {
  const _Probe();
  static int initCount = 0;
  @override
  State<_Probe> createState() => _ProbeState();
}

class _ProbeState extends State<_Probe> {
  @override
  void initState() {
    super.initState();
    _Probe.initCount++;
  }

  @override
  Widget build(BuildContext context) => const Text('APP');
}

Future<ProviderContainer> _pump(WidgetTester tester, FakeAccountRepository repo, String? requested) async {
  _Probe.initCount = 0;
  final container = ProviderContainer(
    retry: (_, _) => null,
    overrides: [
      accountRepositoryProvider.overrideWithValue(repo),
      viewerIdProvider.overrideWith((ref) async => 'u1'),
      meProvider.overrideWith((ref) async => _me(requested)),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => DeletionBannerHost(child: child!),
      home: const _Probe(),
    ),
  ));
  await tester.pumpAndSettle();
  return container;
}

void main() {
  testWidgets('no banner when no deletion is pending', (tester) async {
    await _pump(tester, FakeAccountRepository(), null);
    expect(find.byKey(const Key('deletion-banner')), findsNothing);
    expect(find.text('APP'), findsOneWidget);
  });

  testWidgets('a pending deletion shows the countdown and Cancel deletion refreshes both providers', (tester) async {
    final repo = FakeAccountRepository()
      ..accountResult = testAccount(
        deletion: DeletionState(requestedAt: DateTime.utc(2026, 10, 5), dueAt: DateTime.utc(2026, 10, 20), daysRemaining: 13),
      );
    await _pump(tester, repo, '2026-10-05T00:00:00.000Z');
    expect(find.byKey(const Key('deletion-banner')), findsOneWidget);
    repo.accountResult = testAccount();
    await tester.tap(find.byKey(const Key('deletion-banner-cancel')));
    await tester.pumpAndSettle();
    expect(repo.calls, contains('cancelDeletion'));
  });

  testWidgets('the app content is never rebuilt as the banner appears or disappears (navigation state survives)', (tester) async {
    final repo = FakeAccountRepository();
    final container = await _pump(tester, repo, null);
    expect(_Probe.initCount, 1);
    container.updateOverrides([
      accountRepositoryProvider.overrideWithValue(repo),
      viewerIdProvider.overrideWith((ref) async => 'u1'),
      meProvider.overrideWith((ref) async => _me('2026-10-05T00:00:00.000Z')),
    ]);
    container.invalidate(meProvider);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('deletion-banner')), findsOneWidget);
    expect(_Probe.initCount, 1, reason: 'the child must keep its State');
  });
}
```

If `ProviderContainer.updateOverrides` is not available in the installed Riverpod, replace the third test's mechanism with a `StateProvider`-style switch: override `meProvider` with `(ref) async => ref.watch(_pendingFlag) ? _me('2026-10-05T00:00:00.000Z') : _me(null)` and flip `_pendingFlag` through the container. The assertion (`initCount == 1`) is the point.

- [ ] **Step 6: Run and confirm failure**

Run: `flutter test test/features/account/settings/deletion_banner_host_test.dart`
Expected: FAIL (host missing).

- [ ] **Step 7: Implement the banner host**

```dart
// lib/features/account/settings/deletion_banner_host.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/l10n/gen/app_localizations.dart';
import '../../../core/providers.dart';
import '../../../core/theme/sx_colors.dart';
import '../../../core/utils/date_locale.dart';
import 'account_repository.dart';

/// A persistent "your account is scheduled for deletion" banner above the whole app, with Cancel. Mounted in
/// `MaterialApp.builder`.
///
/// The child sits at the same position in the tree whether or not the banner is showing (a Column with the
/// banner slot first and the child in an Expanded, always). Swapping between `child` and `Column(child)`
/// would give the Navigator a new parent and reset the whole navigation stack every time the banner
/// toggled.
class DeletionBannerHost extends ConsumerWidget {
  const DeletionBannerHost({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pending = ref.watch(meProvider.select((m) => m.asData?.value?.profile?.deletionRequestedAt != null));
    return Column(
      children: [
        if (pending) const _Banner() else const SizedBox.shrink(),
        Expanded(
          child: MediaQuery.removePadding(context: context, removeTop: pending, child: child),
        ),
      ],
    );
  }
}

class _Banner extends ConsumerStatefulWidget {
  const _Banner();

  @override
  ConsumerState<_Banner> createState() => _BannerState();
}

class _BannerState extends ConsumerState<_Banner> {
  bool _cancelling = false;

  Future<void> _cancel() async {
    setState(() => _cancelling = true);
    try {
      await ref.read(accountRepositoryProvider).cancelDeletion();
      ref.invalidate(myAccountProvider);
      ref.invalidate(meProvider);
    } catch (_) {
      if (mounted) setState(() => _cancelling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final deletion = ref.watch(myAccountProvider).asData?.value?.deletion;
    final text = deletion == null
        ? l10n.accountDeletionPendingHeading
        : l10n.accountDeletionBannerText(DateFormat.yMMMd(dateLocale(l10n.localeName)).format(deletion.dueAt.toLocal()), '${deletion.daysRemaining}');
    return Material(
      key: const Key('deletion-banner'),
      color: SxColors.surface,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.amber),
              const SizedBox(width: 8),
              Expanded(child: Text(text, style: Theme.of(context).textTheme.bodySmall)),
              TextButton(
                key: const Key('deletion-banner-cancel'),
                onPressed: _cancelling ? null : _cancel,
                child: Text(_cancelling ? l10n.accountDeletionBannerCancelling : l10n.accountDeletionBannerCancel),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

Wire it in `lib/app.dart`'s `builder` and add the route:

```dart
      builder: (context, child) => AppGate(
        child: PushBannerHost(
          child: DeletionBannerHost(child: child ?? const SizedBox.shrink()),
        ),
      ),
```
(import `features/account/settings/deletion_banner_host.dart`), and in `lib/router/app_router.dart` beside `phone`:

```dart
                  GoRoute(
                    path: 'delete',
                    builder: (context, state) => const DeleteAccountScreen(),
                  ),
```
(import `../features/account/settings/delete_account_screen.dart`). `SxColors.surface` is already used by `PushBannerHost`; confirm the import path `../../../core/theme/sx_colors.dart` resolves (the push banner imports `'../../theme/sx_colors.dart'` from `lib/core/notifications/push/`).

- [ ] **Step 8: Run the full suite**

Run: `flutter analyze && flutter test`
Expected: clean and all green (record the new total in `TESTING-NOTES.md` in Task 10). If an existing test pumps the full `SentinelXApp` and breaks because `DeletionBannerHost` now watches `meProvider`, override `meProvider` in that test (the same way the `AppGate` tests do).

- [ ] **Step 9: Commit**

```bash
git add lib/app.dart lib/router/app_router.dart lib/features/account/settings test/features/account/settings
git commit -m "feat(account): account deletion screen and app-wide pending-deletion banner

Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>"
```

---

### Task 10: Docs, staging pass, and merge (owner-gated)

**Files:**
- Modify: `CLAUDE.md` (route map, Phase 6e notes), `TESTING-NOTES.md`
- Memory: add a project memory after merge (see Step 6)

- [ ] **Step 1: Update `CLAUDE.md`.** In the Phase 1 route table add rows:

```
| `/account/language` | Settings -> Language (en / fr / pcm) |
| `/account/security` | Settings -> Security (change email, password reset link) |
| `/account/sign-in-methods` | Settings -> Sign-in methods (link / unlink Google) |
| `/account/phone` | Settings -> Phone verification |
| `/account/delete` | Settings -> Delete account (schedule, cancel, delete now) |
| `/onboarding/phone` | Phone gate (only reachable while `enforcePhoneVerification` is on and the phone is unverified) |
```

and add a "Settings and account (Phase 6e)" paragraph after the Phase 5c one covering: every account write goes through `AccountRepository` over `/api/mobile/v1/me/*` (no `supabase.auth.updateUser`/`unlinkIdentity`); the only direct Supabase auth call is `linkIdentity` (`google_linker.dart`) returning through `ng.com.sentinelxesports.app://link-callback` (Android intent filter; the URL must be allowlisted in Supabase and Manual Linking enabled); `pcm` ships with web-derived copy only, mobile-authored strings fall back to English (open item: a Pidgin pass), framework widgets fall back through `appLocalizationsDelegates` and every `DateFormat` locale goes through `dateLocale()`; the pending-deletion banner is a `Column` host that must not change shape; `/onboarding/phone` ships but **the owner flips `enforce_phone_verification`**, and the gate now depends on `/me.profile.phoneVerifiedAt`. Update the tripwire bullet to say the screen now exists in this build, so the flag may be flipped once a released version contains it.

- [ ] **Step 2: Full verification.** Run `flutter analyze` and `flutter test`; both must be clean. Record the test count and result in `TESTING-NOTES.md` under a new "Phase 6e" heading.

- [ ] **Step 3: Staging pass (owner-gated).** Needs the web plan deployed to **staging** and the app built against staging (not a Vercel preview, which hits production). With a `zzqa_` account, record each result in `TESTING-NOTES.md`:
  1. Language: switch to Pidgin; open Community and a match (dates render), open a text field, restart the app (language persists), switch back. Sign in on a second device: the server language applies.
  2. Security: change email with a wrong password (inline error), with the right one (check the staging inbox, open the link, confirm `pendingEmail` clears); password reset link arrives.
  3. Sign-in methods: link Google through the browser (success refreshes the row; cancel leaves no error); unlink with the right password; with one method only, Unlink is hidden with the explanation.
  4. Phone: if staging has `META_WHATSAPP_*`, request, receive, confirm; otherwise confirm the screen shows the "unavailable" message and the form does not retry-loop. Never on production without the owner's own number and say-so.
  5. Delete: schedule (banner appears app-wide, survives navigation), cancel (banner gone), schedule again, **delete now** with the exact username (lands on login; the account is tombstoned). Use a throwaway `zzqa_` account and remove it with `anonymise_account` afterwards if delete-now was not used.
  6. Gate: only by unit tests until the owner flips the flag; do **not** flip it for the test.

- [ ] **Step 4: Owner actions to confirm before merging:** Supabase **Manual Linking** is enabled and `ng.com.sentinelxesports.app://link-callback` is in the Auth redirect allowlist (staging and production); the web plan is merged and the `account_rate_limit_events` migration is applied to production by the owner.

- [ ] **Step 5: Merge and push.** `git checkout master && git merge --no-ff phase6e/settings-account && git push origin master`.

- [ ] **Step 6: Save a project memory** (`project_mobile_phase6e_settings.md` plus a one-line `MEMORY.md` pointer) with: merge SHAs for both repos, the test counts, what the staging pass did and did not cover, the open items below, and "Phase 6 next: 6d Referrals".

## Open items this plan leaves for the owner

- A Pidgin translation pass for mobile-authored strings (`ntf*`, `cmp*`, `dm*`, `chat*`, `quest*`, …); until then they show English under `pcm`.
- iOS: the same `link-callback` URL scheme and the iOS usage strings (Phase 10).
- Flipping `enforce_phone_verification` once a released app contains `/onboarding/phone` and WhatsApp (`META_WHATSAPP_*`) is live in production.

## Self-review against the spec

- **§3.2 / §3.6 screens:** hub + language (Task 5), security (6), sign-in methods (7), phone + gate (8), deletion + banner (9), profile and notifications re-linked unchanged (existing).
- **§3.3 corrections on mobile:** locale through `PUT /me/locale` (Tasks 1, 4), unlink asks for the password (7), `phone_unavailable` has its own state (8).
- **§3.6 behaviours:** banner (9), delete-now sign-out (9), `localeProvider` seeded from `/me` and cached (4), `pcm` with `en` framework fallback (3), Google link browser round-trip with quiet cancel (7), password sheets with inline errors (6, 7), ARB-only copy via the generator (2), phone countdown from the server with 429 override (8), tripwire respected (8, 10).
- **Not in the spec but required by what the code showed:** date-format crash for `pcm` (Task 3), gate depended on a field `/me` did not carry (Task 8 with web Task 7b), generator placeholder metadata (Task 2).
- **Type consistency:** `AccountRepository` method names (`account`, `requestDeletion`, `cancelDeletion`, `deleteNow`, `requestPhoneCode`, `confirmPhoneCode`, `changeEmail`, `unlinkGoogle`, `setLocale`) are identical in Tasks 4-9 and in `FakeAccountRepository`; `ApiClient` names (`getMyAccount`, `postAccountDeletion`, `deleteAccountDeletion`, `postAccountDeletionExecute`, `postPhoneCode`, `postPhoneConfirm`, `postMyEmail`, `deleteGoogleIdentity`, `putMyLocale`) match the operation ids in the web plan.
