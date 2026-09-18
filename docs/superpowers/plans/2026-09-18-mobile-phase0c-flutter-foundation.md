# Mobile Phase 0C — Flutter Foundation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn the read-only tournament slice into the app foundation every later phase builds on: flavor config, Riverpod, dark Sentinel X theme, a typed API client for `/api/mobile/v1`, session/role providers, a remote-config kill-switch gate, crash reporting into `client_error_logs`, an i18n scaffold, a web-link resolver, and Android App Links — proven by an authenticated round trip (`GET /me`) from a device.

**Architecture:** `lib/core/**` holds cross-cutting infrastructure (config, api, auth, gate, theme, l10n, routing, errors) exposed as manual Riverpod providers (no codegen). The existing `lib/data`, `lib/models`, `lib/features/tournaments` slice stays where it is, migrated to read its repository from a provider; it is replaced wholesale by the API-backed feature in Phase 2, so it is **not** reshuffled now. Tier rules from the master spec apply: raw reads via `supabase_flutter`, computed reads and **all writes** via `ApiClient`.

**Tech Stack:** Flutter 3.41.9 / Dart 3.11.5, `flutter_riverpod`, `go_router` (present), `supabase_flutter` (present), `dio`, `package_info_plus`, `url_launcher`, `flutter_localizations` + `intl`, `flutter_test` (fakes, no mocking package).

**Spec:** `docs/superpowers/specs/2026-09-18-flutter-mobile-app-master-design.md` §4, §6.1, §6.2 (registration endpoints only), §6.10, §6.11, §13 Phase 0. **Depends on web plans** `2026-09-18-mobile-phase0b-api-foundation.md` (Tasks 3, 9, 10 below need its endpoints and `openapi/mobile-v1.json`) in the web repo `C:\Users\gorok\Videos\sentinelx`.

## Global Constraints

- Flutter **3.41.9** stable, Dart **3.11.5** (`environment.sdk: ^3.11.5`). Add packages with `flutter pub add` (resolves current compatible versions) — do not hand-pin.
- **No production writes from the app in Phase 0.** The only write is `POST /errors` (crash log). Dev and prod flavors both point at the production Supabase project (`itxubrkbropttfdackmi`) because no staging database exists (owner decision, Phase 0); therefore no feature in this plan may write anything else.
- Supabase publishable key and project URL are public by design and stay as `String.fromEnvironment` defaults so `flutter run` needs no flags; **no secret ever enters the app**.
- The RLS-scoped Supabase client is for **reads only**; every mutation goes through `ApiClient` (master spec §3).
- Riverpod: manual providers only (`Provider`, `FutureProvider`, `StreamProvider`); read async values with `.asData?.value` (works across Riverpod 2/3); disable automatic provider retry (`retry: (_, __) => null`) in the app container and in every test scope so error states surface immediately.
- App Links: package `ng.com.sentinelxesports.app`, host `sentinelxesports.com.ng`. In Phase 0 the manifest claims **only** the exact path `/tournaments` (the slice's list screen). `/auth/confirm` is added in Phase 1, tournament slug pages in Phase 2 (the slice's routes are id-based, so claiming slug URLs now would open a broken screen).
- Store-listing name is **Sentinel X**. Times shown to users are WAT (`Africa/Lagos`) — no time formatting is introduced in Phase 0.
- Every commit: verify `git branch --show-current` and `git diff --cached --stat` first. This repo has no remote; do not add CI workflows (there is nothing to run them) — `flutter analyze && flutter test` is the gate.
- **Deferred from the master spec (with reason):** Dart codegen from OpenAPI (4 endpoints: hand-written client + a contract test is smaller; revisit at Phase 2 when endpoints number in the dozens), `riverpod_generator`, bundled brand fonts (Barlow Condensed/Inter — asset licensing/download is a Phase 9 polish item; Phase 0 theme uses tokens with the default font), the `pcm` locale (Flutter's Material delegates do not support `pcm`; needs a fallback delegate, done with the first real translated screens in Phase 1), Sentry (crashes go to `client_error_logs` first), feature-first file moves of the existing slice.

## File Structure

| File | Responsibility |
|---|---|
| `lib/core/config/app_config.dart` | `AppConfig` from `--dart-define` (flavor, Supabase, API base, debug tools) |
| `lib/core/utils/version.dart` | `compareVersions()` (port of the web helper, same vectors) |
| `lib/core/config/remote_config.dart` | `RemoteConfig` model, `evaluateGate()` |
| `lib/core/api/api_client.dart` | `ApiClient`, `ApiException` |
| `lib/core/api/models.dart` | `MeResponse`, `MeProfile` |
| `lib/core/providers.dart` | App-wide providers (config, supabase, session, api, remote config, me, role, version, reporter) |
| `lib/core/errors/error_reporter.dart` | Capped, deduped, never-throwing crash reporter |
| `lib/core/theme/sx_colors.dart`, `theme.dart` | Web design tokens and `ThemeData` |
| `lib/core/l10n/*.arb`, `l10n.yaml`, `lib/core/l10n/gen/*` | i18n scaffold (en, fr) |
| `lib/core/gate/app_gate.dart` | Maintenance / update-required overlay |
| `lib/core/routing/web_links.dart` | `resolveWebLink()` |
| `lib/features/debug/debug_sign_in_screen.dart` | Dev-only sign-in + `/me` round trip |
| `lib/main.dart`, `lib/app.dart`, `lib/router/app_router.dart` | Bootstrap, root widget, routes |
| `api/openapi.json` | Pinned copy of the web contract |
| `test/**` | Fakes, helpers and tests per task |

---

### Task 1: Dependencies, Riverpod smoke test, `AppConfig`

**Files:**
- Modify: `pubspec.yaml` (via `flutter pub add`)
- Create: `lib/core/config/app_config.dart`, `config/dev.json`, `test/core/riverpod_smoke_test.dart`, `test/core/app_config_test.dart`
- Do **not** delete `lib/core/env.dart` yet (removed in Task 7).

**Interfaces:**
- Produces: `class AppConfig { final String flavor; final String supabaseUrl; final String supabasePublishableKey; final String apiBaseUrl; final bool debugTools; bool get isDev; const AppConfig({...}); const factory AppConfig.fromEnvironment(); }`

- [ ] **Step 1: Add dependencies**

Run (PowerShell, repo root):
```powershell
flutter pub add flutter_riverpod dio package_info_plus url_launcher intl
flutter pub add flutter_localizations --sdk=flutter
flutter pub get
```
Expected: exits 0; `pubspec.lock` contains `flutter_riverpod`, `dio`, `package_info_plus`, `url_launcher`.

- [ ] **Step 2: Write the Riverpod smoke test (proves the installed major version's API before we depend on it)**

`test/core/riverpod_smoke_test.dart`
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final _failing = FutureProvider.autoDispose<int>((ref) async => throw Exception('boom'));

void main() {
  testWidgets('a failing FutureProvider surfaces its error at once when retry is disabled', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        retry: (_, __) => null,
        child: MaterialApp(
          home: Consumer(
            builder: (context, ref, _) => ref.watch(_failing).when(
                  data: (v) => Text('$v'),
                  loading: () => const Text('loading'),
                  error: (e, _) => const Text('error'),
                ),
          ),
        ),
      ),
    );
    expect(find.text('loading'), findsOneWidget);
    await tester.pump();
    expect(find.text('error'), findsOneWidget);
  });
}
```
Run: `flutter test test/core/riverpod_smoke_test.dart` → Expected: PASS. **If it does not compile because `ProviderScope` has no `retry:` parameter, the installed Riverpod is 2.x: remove the `retry:` argument here and in every later `ProviderScope`/`ProviderContainer` in this plan (2.x has no automatic retry) and note it in the commit message.**

- [ ] **Step 3: Write the failing config test**

`test/core/app_config_test.dart`
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/core/config/app_config.dart';

void main() {
  test('defaults to the prod flavor pointing at production with debug tools off', () {
    const config = AppConfig.fromEnvironment();
    expect(config.flavor, 'prod');
    expect(config.isDev, isFalse);
    expect(config.supabaseUrl, 'https://itxubrkbropttfdackmi.supabase.co');
    expect(config.apiBaseUrl, 'https://sentinelxesports.com.ng');
    expect(config.debugTools, isFalse);
  });

  test('isDev reflects the flavor', () {
    const dev = AppConfig(
      flavor: 'dev',
      supabaseUrl: 'u',
      supabasePublishableKey: 'k',
      apiBaseUrl: 'http://10.0.2.2:3000',
      debugTools: true,
    );
    expect(dev.isDev, isTrue);
    expect(dev.debugTools, isTrue);
  });
}
```
Run: `flutter test test/core/app_config_test.dart` → Expected: FAIL (file missing).

- [ ] **Step 4: Implement**

`lib/core/config/app_config.dart`
```dart
class AppConfig {
  const AppConfig({
    required this.flavor,
    required this.supabaseUrl,
    required this.supabasePublishableKey,
    required this.apiBaseUrl,
    required this.debugTools,
  });

  /// Build-time config. Override with `--dart-define` or `--dart-define-from-file=config/dev.json`.
  /// Defaults are the production public values so a bare `flutter run` works; the publishable
  /// key is public by design (same value ships in the web bundle).
  const factory AppConfig.fromEnvironment() = _EnvAppConfig;

  final String flavor;
  final String supabaseUrl;
  final String supabasePublishableKey;
  final String apiBaseUrl;
  final bool debugTools;

  bool get isDev => flavor == 'dev';
}

class _EnvAppConfig extends AppConfig {
  const _EnvAppConfig()
      : super(
          flavor: String.fromEnvironment('FLAVOR', defaultValue: 'prod'),
          supabaseUrl: String.fromEnvironment(
            'SUPABASE_URL',
            defaultValue: 'https://itxubrkbropttfdackmi.supabase.co',
          ),
          supabasePublishableKey: String.fromEnvironment(
            'SUPABASE_PUBLISHABLE_KEY',
            defaultValue: 'sb_publishable_bsIF_bY19uFCno5BjS4sMQ_PiEbY6zs',
          ),
          apiBaseUrl: String.fromEnvironment('API_BASE_URL', defaultValue: 'https://sentinelxesports.com.ng'),
          debugTools: bool.fromEnvironment('DEBUG_TOOLS'),
        );
}
```
`config/dev.json`
```json
{ "FLAVOR": "dev", "DEBUG_TOOLS": true }
```
(Point `API_BASE_URL` at a local Next.js dev server with `--dart-define=API_BASE_URL=http://10.0.2.2:3000` from an Android emulator.)

- [ ] **Step 5: Run** `flutter test test/core` → Expected: 3 passed. `flutter analyze` → No issues.

- [ ] **Step 6: Commit**
```powershell
git add pubspec.yaml pubspec.lock lib/core config test/core
git diff --cached --stat
git commit -m "chore: add riverpod/dio/package_info/url_launcher/intl; AppConfig from --dart-define"
```

---

### Task 2: Version comparison, `RemoteConfig`, gate evaluation

**Files:**
- Create: `lib/core/utils/version.dart`, `lib/core/config/remote_config.dart`
- Test: `test/core/version_test.dart`, `test/core/remote_config_test.dart`

**Interfaces:**
- Produces: `int compareVersions(String a, String b)` (-1/0/1, same semantics and vectors as `lib/mobile-api/version.ts` in the web repo); `class RemoteConfig` with `factory RemoteConfig.fromJson(Map<String, dynamic>)`, fields `minSupportedAppVersion, latestAppVersion, maintenanceMessage (String?), siteUrl, coinsPerNaira (int), nairaPerCoin (double), coinsPerEntry (int), coinsHalfEntry (int), enforcePhoneVerification (bool), whatsappCommunityUrl (String?), features (Map<String,bool>)` and `bool feature(String key)` (unknown key → `true`); `enum GateKind { open, maintenance, updateRequired }`; `class GateState { final GateKind kind; final String? message; final String? minVersion; }`; `GateState evaluateGate(RemoteConfig? config, String installedVersion)`.

- [ ] **Step 1: Write the failing tests**

`test/core/version_test.dart`
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/core/utils/version.dart';

void main() {
  test('orders dotted numeric versions', () {
    expect(compareVersions('1.0.0', '1.0.1'), -1);
    expect(compareVersions('1.2.0', '1.1.9'), 1);
    expect(compareVersions('2.0.0', '2.0.0'), 0);
  });
  test('compares numerically, not lexically', () => expect(compareVersions('1.10.0', '1.9.0'), 1));
  test('ignores the +build suffix', () => expect(compareVersions('1.0.0+45', '1.0.0'), 0));
  test('treats missing segments as zero', () {
    expect(compareVersions('1.0', '1.0.0'), 0);
    expect(compareVersions('1', '1.0.1'), -1);
  });
  test('treats an unparseable version as 0.0.0', () => expect(compareVersions('garbage', '0.0.1'), -1));
}
```

`test/core/remote_config_test.dart`
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/core/config/remote_config.dart';

Map<String, dynamic> _json({String min = '0.0.0', Map<String, dynamic>? maintenance}) => {
      'minSupportedAppVersion': min,
      'latestAppVersion': '1.4.0',
      'maintenance': maintenance,
      'siteUrl': 'https://sentinelxesports.com.ng',
      'coins': {'coinsPerNaira': 2, 'nairaPerCoin': 0.5, 'coinsPerEntry': 1000, 'coinsHalfEntry': 500},
      'enforcePhoneVerification': false,
      'whatsappCommunityUrl': null,
      'features': {'wagering': false, 'store': true},
    };

void main() {
  group('RemoteConfig.fromJson', () {
    test('parses the /config payload', () {
      final c = RemoteConfig.fromJson(_json(min: '1.2.0', maintenance: {'message': 'Back at 3pm'}));
      expect(c.minSupportedAppVersion, '1.2.0');
      expect(c.maintenanceMessage, 'Back at 3pm');
      expect(c.coinsPerEntry, 1000);
      expect(c.nairaPerCoin, 0.5);
      expect(c.whatsappCommunityUrl, isNull);
    });
    test('feature() reads flags and treats unknown keys as enabled', () {
      final c = RemoteConfig.fromJson(_json());
      expect(c.feature('wagering'), isFalse);
      expect(c.feature('store'), isTrue);
      expect(c.feature('something_new'), isTrue);
    });
  });

  group('evaluateGate', () {
    test('opens when the config could not be fetched — never lock users out on a network blip', () {
      expect(evaluateGate(null, '1.0.0').kind, GateKind.open);
    });
    test('opens when the installed version meets the minimum', () {
      expect(evaluateGate(RemoteConfig.fromJson(_json(min: '1.0.0')), '1.0.0+7').kind, GateKind.open);
    });
    test('requires an update below the minimum and names it', () {
      final g = evaluateGate(RemoteConfig.fromJson(_json(min: '1.2.0')), '1.1.9');
      expect(g.kind, GateKind.updateRequired);
      expect(g.minVersion, '1.2.0');
    });
    test('maintenance wins over everything and carries the message', () {
      final g = evaluateGate(RemoteConfig.fromJson(_json(min: '9.0.0', maintenance: {'message': 'Down'})), '1.0.0');
      expect(g.kind, GateKind.maintenance);
      expect(g.message, 'Down');
    });
  });
}
```
Run: `flutter test test/core/version_test.dart test/core/remote_config_test.dart` → Expected: FAIL (files missing).

- [ ] **Step 2: Implement**

`lib/core/utils/version.dart`
```dart
List<int> _parts(String v) => v.split('+').first.split('.').map((s) => int.tryParse(s) ?? 0).toList();

/// Numeric dotted-version comparison, ignoring a `+build` suffix. Mirrors lib/mobile-api/version.ts
/// in the web repo; keep the test vectors identical.
int compareVersions(String a, String b) {
  final pa = _parts(a);
  final pb = _parts(b);
  final n = pa.length > pb.length ? pa.length : pb.length;
  for (var i = 0; i < n; i++) {
    final x = i < pa.length ? pa[i] : 0;
    final y = i < pb.length ? pb[i] : 0;
    if (x < y) return -1;
    if (x > y) return 1;
  }
  return 0;
}
```

`lib/core/config/remote_config.dart`
```dart
import '../utils/version.dart';

class RemoteConfig {
  const RemoteConfig({
    required this.minSupportedAppVersion,
    required this.latestAppVersion,
    required this.maintenanceMessage,
    required this.siteUrl,
    required this.coinsPerNaira,
    required this.nairaPerCoin,
    required this.coinsPerEntry,
    required this.coinsHalfEntry,
    required this.enforcePhoneVerification,
    required this.whatsappCommunityUrl,
    required this.features,
  });

  factory RemoteConfig.fromJson(Map<String, dynamic> j) {
    final coins = j['coins'] as Map<String, dynamic>;
    final maintenance = j['maintenance'] as Map<String, dynamic>?;
    final features = (j['features'] as Map<String, dynamic>).map((k, v) => MapEntry(k, v as bool));
    return RemoteConfig(
      minSupportedAppVersion: j['minSupportedAppVersion'] as String,
      latestAppVersion: j['latestAppVersion'] as String,
      maintenanceMessage: maintenance?['message'] as String?,
      siteUrl: j['siteUrl'] as String,
      coinsPerNaira: (coins['coinsPerNaira'] as num).toInt(),
      nairaPerCoin: (coins['nairaPerCoin'] as num).toDouble(),
      coinsPerEntry: (coins['coinsPerEntry'] as num).toInt(),
      coinsHalfEntry: (coins['coinsHalfEntry'] as num).toInt(),
      enforcePhoneVerification: j['enforcePhoneVerification'] as bool,
      whatsappCommunityUrl: j['whatsappCommunityUrl'] as String?,
      features: features,
    );
  }

  final String minSupportedAppVersion;
  final String latestAppVersion;
  final String? maintenanceMessage;
  final String siteUrl;
  final int coinsPerNaira;
  final double nairaPerCoin;
  final int coinsPerEntry;
  final int coinsHalfEntry;
  final bool enforcePhoneVerification;
  final String? whatsappCommunityUrl;
  final Map<String, bool> features;

  /// A flag the server does not know about is not gated.
  bool feature(String key) => features[key] ?? true;
}

enum GateKind { open, maintenance, updateRequired }

class GateState {
  const GateState(this.kind, {this.message, this.minVersion});
  final GateKind kind;
  final String? message;
  final String? minVersion;
}

GateState evaluateGate(RemoteConfig? config, String installedVersion) {
  if (config == null) return const GateState(GateKind.open);
  if (config.maintenanceMessage != null) {
    return GateState(GateKind.maintenance, message: config.maintenanceMessage);
  }
  if (compareVersions(installedVersion, config.minSupportedAppVersion) < 0) {
    return GateState(GateKind.updateRequired, minVersion: config.minSupportedAppVersion);
  }
  return const GateState(GateKind.open);
}
```

- [ ] **Step 3: Run** `flutter test test/core` → Expected: all pass. `flutter analyze` → clean.

- [ ] **Step 4: Commit**
```powershell
git add lib/core test/core && git diff --cached --stat
git commit -m "feat(core): version comparison, RemoteConfig model and gate evaluation"
```

---

### Task 3: `ApiClient`, models, and the contract test

**Files:**
- Create: `lib/core/api/api_client.dart`, `lib/core/api/models.dart`, `api/openapi.json` (copied), `test/core/api_client_test.dart`, `test/core/api_contract_test.dart`

**Interfaces:**
- Consumes: `RemoteConfig` (Task 2). Web endpoints: `getConfig` GET `/config`, `getMe` GET `/me`, `postClientError` POST `/errors`, `postDevice` POST `/devices`, `deleteDevice` DELETE `/devices` (all under `/api/mobile/v1`).
- Produces:
```dart
class ApiException implements Exception { final int status; final String code; final String message; final Map<String,String> fields; bool get isUpdateRequired; bool get isUnauthorized; }
typedef AccessTokenSupplier = Future<String?> Function();
class ApiClient {
  ApiClient({required Dio dio});
  factory ApiClient.create({required String baseUrl, required String appVersion, required String platform, required AccessTokenSupplier accessToken, HttpClientAdapter? adapter});
  Future<RemoteConfig> getConfig();
  Future<MeResponse> getMe();
  Future<void> postClientError({required String message, String? stack, String? route, required String platform, required String appVersion, String? locale});
  Future<void> registerDevice({required String token, required String platform, required String appVersion});
  Future<void> unregisterDevice(String token);
  static const Map<String, String> usedOperations;   // operationId -> 'method /path'
}
class MeResponse { id, email, roles, isStaff, isAdmin, MeProfile? profile }
class MeProfile { username, displayName, avatarUrl, whatsappNumber, country, locale, membershipTier, kycVerified, deletionRequestedAt }
```

- [ ] **Step 1: Pin the contract** (requires web plan 0B Tasks 4–7 done)

```powershell
New-Item -ItemType Directory -Force api | Out-Null
Copy-Item C:\Users\gorok\Videos\sentinelx\openapi\mobile-v1.json api\openapi.json
```
Expected: `api/openapi.json` exists and contains the operation ids `getConfig, getMe, postClientError, postDevice, deleteDevice`.

- [ ] **Step 2: Write the failing tests**

`test/core/api_client_test.dart`
```dart
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
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
    ResponseBody.fromString(jsonEncode(body), status, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    });

ApiClient _client(_FakeAdapter adapter, {String? token = 'tok'}) => ApiClient.create(
      baseUrl: 'https://api.test',
      appVersion: '1.2.3',
      platform: 'android',
      accessToken: () async => token,
      adapter: adapter,
    );

const _configData = {
  'minSupportedAppVersion': '1.0.0',
  'latestAppVersion': '1.4.0',
  'maintenance': null,
  'siteUrl': 'https://sentinelxesports.com.ng',
  'coins': {'coinsPerNaira': 2, 'nairaPerCoin': 0.5, 'coinsPerEntry': 1000, 'coinsHalfEntry': 500},
  'enforcePhoneVerification': false,
  'whatsappCommunityUrl': null,
  'features': {'wagering': true},
};

void main() {
  test('getConfig unwraps the data envelope and parses RemoteConfig', () async {
    final adapter = _FakeAdapter((_) => _json(200, {'data': _configData}));
    final config = await _client(adapter).getConfig();
    expect(config.latestAppVersion, '1.4.0');
    expect(adapter.requests.single.uri.toString(), 'https://api.test/api/mobile/v1/config');
    expect(adapter.requests.single.method, 'GET');
  });

  test('sends the bearer token and app identity headers', () async {
    final adapter = _FakeAdapter((_) => _json(200, {'data': _configData}));
    await _client(adapter).getConfig();
    final h = adapter.requests.single.headers;
    expect(h['Authorization'], 'Bearer tok');
    expect(h['X-App-Version'], '1.2.3');
    expect(h['X-Platform'], 'android');
  });

  test('omits Authorization when signed out', () async {
    final adapter = _FakeAdapter((_) => _json(200, {'data': _configData}));
    await _client(adapter, token: null).getConfig();
    expect(adapter.requests.single.headers.containsKey('Authorization'), isFalse);
  });

  test('maps the error envelope to ApiException including field codes', () async {
    final adapter = _FakeAdapter((_) => _json(400, {
          'error': {
            'code': 'validation_failed',
            'message': 'Some fields are invalid.',
            'fields': {'token': 'too_small'},
          },
        }));
    await expectLater(
      _client(adapter).registerDevice(token: 'x', platform: 'android', appVersion: '1.0.0'),
      throwsA(isA<ApiException>()
          .having((e) => e.status, 'status', 400)
          .having((e) => e.code, 'code', 'validation_failed')
          .having((e) => e.fields, 'fields', {'token': 'too_small'})),
    );
  });

  test('flags 426 as update-required and 401 as unauthorized', () async {
    final a426 = _FakeAdapter((_) => _json(426, {'error': {'code': 'app_update_required', 'message': 'Update'}}));
    await expectLater(_client(a426).getMe(), throwsA(isA<ApiException>().having((e) => e.isUpdateRequired, 'upd', true)));
    final a401 = _FakeAdapter((_) => _json(401, {'error': {'code': 'unauthorized', 'message': 'Sign in'}}));
    await expectLater(_client(a401).getMe(), throwsA(isA<ApiException>().having((e) => e.isUnauthorized, 'unauth', true)));
  });

  test('a transport failure becomes ApiException(status 0, network)', () async {
    final adapter = _FakeAdapter((o) => throw DioException(requestOptions: o, type: DioExceptionType.connectionError));
    await expectLater(
      _client(adapter).getConfig(),
      throwsA(isA<ApiException>().having((e) => e.status, 'status', 0).having((e) => e.code, 'code', 'network')),
    );
  });

  test('getMe parses roles and the profile', () async {
    final adapter = _FakeAdapter((_) => _json(200, {
          'data': {
            'id': 'u1',
            'email': 'a@b.c',
            'roles': ['moderator'],
            'isStaff': true,
            'isAdmin': false,
            'profile': {
              'username': 'ada', 'displayName': 'Ada', 'avatarUrl': null, 'whatsappNumber': null, 'country': 'NG',
              'locale': 'en', 'membershipTier': 'guardian', 'kycVerified': false, 'deletionRequestedAt': null,
            },
          },
        }));
    final me = await _client(adapter).getMe();
    expect(me.isStaff, isTrue);
    expect(me.isAdmin, isFalse);
    expect(me.roles, ['moderator']);
    expect(me.profile?.username, 'ada');
  });

  test('postClientError sends the documented body', () async {
    final adapter = _FakeAdapter((_) => _json(200, {'data': {'ok': true}}));
    await _client(adapter).postClientError(
      message: 'boom', stack: 's', route: '/tournaments', platform: 'android', appVersion: '1.2.3', locale: 'en',
    );
    final req = adapter.requests.single;
    expect(req.method, 'POST');
    expect(req.uri.path, '/api/mobile/v1/errors');
    expect(req.data, {'message': 'boom', 'stack': 's', 'route': '/tournaments', 'platform': 'android', 'appVersion': '1.2.3', 'locale': 'en'});
  });

  test('unregisterDevice is a DELETE with the token in the body', () async {
    final adapter = _FakeAdapter((_) => _json(200, {'data': {'ok': true}}));
    await _client(adapter).unregisterDevice('t' * 30);
    final req = adapter.requests.single;
    expect(req.method, 'DELETE');
    expect(req.uri.path, '/api/mobile/v1/devices');
    expect(req.data, {'token': 't' * 30});
  });
}
```

`test/core/api_contract_test.dart`
```dart
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/core/api/api_client.dart';

void main() {
  test('every operation the client uses exists in the pinned web contract (api/openapi.json)', () {
    final doc = jsonDecode(File('api/openapi.json').readAsStringSync()) as Map<String, dynamic>;
    final paths = doc['paths'] as Map<String, dynamic>;

    final published = <String, String>{}; // operationId -> 'method /path'
    paths.forEach((path, methods) {
      (methods as Map<String, dynamic>).forEach((method, op) {
        published[(op as Map<String, dynamic>)['operationId'] as String] = '$method $path';
      });
    });

    for (final entry in ApiClient.usedOperations.entries) {
      expect(published[entry.key], entry.value, reason: '${entry.key} drifted from the web contract — re-copy openapi/mobile-v1.json and fix ApiClient');
    }
  });
}
```
Run: `flutter test test/core/api_client_test.dart test/core/api_contract_test.dart` → Expected: FAIL (files missing).

- [ ] **Step 3: Implement**

`lib/core/api/models.dart`
```dart
class MeProfile {
  const MeProfile({
    required this.username,
    required this.displayName,
    required this.avatarUrl,
    required this.whatsappNumber,
    required this.country,
    required this.locale,
    required this.membershipTier,
    required this.kycVerified,
    required this.deletionRequestedAt,
  });

  factory MeProfile.fromJson(Map<String, dynamic> j) => MeProfile(
        username: j['username'] as String?,
        displayName: j['displayName'] as String?,
        avatarUrl: j['avatarUrl'] as String?,
        whatsappNumber: j['whatsappNumber'] as String?,
        country: j['country'] as String?,
        locale: j['locale'] as String?,
        membershipTier: j['membershipTier'] as String?,
        kycVerified: j['kycVerified'] as bool,
        deletionRequestedAt: j['deletionRequestedAt'] as String?,
      );

  final String? username;
  final String? displayName;
  final String? avatarUrl;
  final String? whatsappNumber;
  final String? country;
  final String? locale;
  final String? membershipTier;
  final bool kycVerified;
  final String? deletionRequestedAt;
}

class MeResponse {
  const MeResponse({
    required this.id,
    required this.email,
    required this.roles,
    required this.isStaff,
    required this.isAdmin,
    required this.profile,
  });

  factory MeResponse.fromJson(Map<String, dynamic> j) => MeResponse(
        id: j['id'] as String,
        email: j['email'] as String?,
        roles: (j['roles'] as List<dynamic>).cast<String>(),
        isStaff: j['isStaff'] as bool,
        isAdmin: j['isAdmin'] as bool,
        profile: j['profile'] == null ? null : MeProfile.fromJson(j['profile'] as Map<String, dynamic>),
      );

  final String id;
  final String? email;
  final List<String> roles;
  final bool isStaff;
  final bool isAdmin;
  final MeProfile? profile;
}
```

`lib/core/api/api_client.dart`
```dart
import 'package:dio/dio.dart';

import '../config/remote_config.dart';
import 'models.dart';

class ApiException implements Exception {
  const ApiException({required this.status, required this.code, required this.message, this.fields = const {}});

  final int status;
  final String code;
  final String message;
  final Map<String, String> fields;

  bool get isUpdateRequired => status == 426;
  bool get isUnauthorized => status == 401;

  @override
  String toString() => 'ApiException($status $code: $message)';
}

typedef AccessTokenSupplier = Future<String?> Function();

class ApiClient {
  ApiClient({required Dio dio}) : _dio = dio;

  /// Operations this client calls, keyed by OpenAPI operationId — checked against api/openapi.json
  /// by test/core/api_contract_test.dart so web/mobile drift fails CI instead of a user's phone.
  static const Map<String, String> usedOperations = {
    'getConfig': 'get /api/mobile/v1/config',
    'getMe': 'get /api/mobile/v1/me',
    'postClientError': 'post /api/mobile/v1/errors',
    'postDevice': 'post /api/mobile/v1/devices',
    'deleteDevice': 'delete /api/mobile/v1/devices',
  };

  static const _base = '/api/mobile/v1';
  final Dio _dio;

  factory ApiClient.create({
    required String baseUrl,
    required String appVersion,
    required String platform,
    required AccessTokenSupplier accessToken,
    HttpClientAdapter? adapter,
  }) {
    final dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      validateStatus: (_) => true, // every status is decoded by _send
      headers: {'X-App-Version': appVersion, 'X-Platform': platform},
    ));
    if (adapter != null) dio.httpClientAdapter = adapter;
    dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) async {
      final token = await accessToken();
      if (token != null) options.headers['Authorization'] = 'Bearer $token';
      handler.next(options);
    }));
    return ApiClient(dio: dio);
  }

  Future<T> _send<T>(String method, String path, T Function(Object? data) parse, {Object? body}) async {
    final Response<dynamic> res;
    try {
      res = await _dio.request<dynamic>(
        '$_base$path',
        data: body,
        options: Options(method: method, responseType: ResponseType.json),
      );
    } on DioException catch (e) {
      throw ApiException(status: 0, code: 'network', message: e.message ?? 'Network error');
    }

    final status = res.statusCode ?? 0;
    final json = res.data;
    if (status >= 200 && status < 300 && json is Map<String, dynamic> && json.containsKey('data')) {
      return parse(json['data']);
    }
    if (json is Map<String, dynamic> && json['error'] is Map<String, dynamic>) {
      final err = json['error'] as Map<String, dynamic>;
      final fields = (err['fields'] as Map<String, dynamic>?)?.map((k, v) => MapEntry(k, v.toString())) ?? const <String, String>{};
      throw ApiException(
        status: status,
        code: err['code'] as String? ?? 'unknown',
        message: err['message'] as String? ?? 'Request failed',
        fields: fields,
      );
    }
    throw ApiException(status: status, code: 'bad_response', message: 'Unexpected response ($status).');
  }

  Future<RemoteConfig> getConfig() =>
      _send('GET', '/config', (d) => RemoteConfig.fromJson(d! as Map<String, dynamic>));

  Future<MeResponse> getMe() => _send('GET', '/me', (d) => MeResponse.fromJson(d! as Map<String, dynamic>));

  Future<void> postClientError({
    required String message,
    String? stack,
    String? route,
    required String platform,
    required String appVersion,
    String? locale,
  }) =>
      _send('POST', '/errors', (_) {}, body: {
        'message': message,
        if (stack != null) 'stack': stack,
        if (route != null) 'route': route,
        'platform': platform,
        'appVersion': appVersion,
        if (locale != null) 'locale': locale,
      });

  Future<void> registerDevice({required String token, required String platform, required String appVersion}) =>
      _send('POST', '/devices', (_) {}, body: {'token': token, 'platform': platform, 'appVersion': appVersion});

  Future<void> unregisterDevice(String token) => _send('DELETE', '/devices', (_) {}, body: {'token': token});
}
```

- [ ] **Step 4: Run** `flutter test test/core` → Expected: all pass (9 client tests + 1 contract test). `flutter analyze` → clean.

- [ ] **Step 5: Commit**
```powershell
git add lib/core api test/core && git diff --cached --stat
git commit -m "feat(core): typed ApiClient for /api/mobile/v1 with pinned OpenAPI contract test"
```

---

### Task 4: Core providers (session, api, remote config, role) and the crash reporter

**Files:**
- Create: `lib/core/providers.dart`, `lib/core/errors/error_reporter.dart`
- Test: `test/core/error_reporter_test.dart`, `test/core/role_provider_test.dart`

**Interfaces:**
- Consumes: `AppConfig`, `ApiClient`, `RemoteConfig`, `MeResponse`.
- Produces (all in `lib/core/providers.dart`): `appConfigProvider: Provider<AppConfig>`; `installedVersionProvider: Provider<String>` (throws unless overridden); `supabaseClientProvider: Provider<SupabaseClient>`; `sessionProvider: StreamProvider<Session?>`; `apiClientProvider: Provider<ApiClient>`; `remoteConfigProvider: FutureProvider<RemoteConfig?>` (null on any failure); `meProvider: FutureProvider<MeResponse?>` (null when signed out); `enum AppRole { player, moderator, admin }`; `roleProvider: Provider<AppRole?>` (null when signed out); `errorReporterProvider: Provider<ErrorReporter>`.
- Produces (`error_reporter.dart`): `typedef ErrorSender = Future<void> Function(String message, String? stack, String? route); class ErrorReporter { ErrorReporter(ErrorSender send, {int maxReports = 20}); Future<void> report(Object error, StackTrace? stack, {String? route}); }` — never throws; sends at most `maxReports` per app run; skips a report whose message equals the previous one.

- [ ] **Step 1: Write the failing tests**

`test/core/error_reporter_test.dart`
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/core/errors/error_reporter.dart';

void main() {
  test('sends message, stack and route', () async {
    final sent = <List<String?>>[];
    final r = ErrorReporter((m, s, route) async => sent.add([m, s, route]));
    await r.report(StateError('boom'), StackTrace.fromString('trace'), route: '/x');
    expect(sent.single[0], contains('boom'));
    expect(sent.single[1], 'trace');
    expect(sent.single[2], '/x');
  });

  test('never throws even when the sender fails', () async {
    final r = ErrorReporter((m, s, route) async => throw Exception('network down'));
    await r.report(Exception('a'), null);
  });

  test('skips an immediately repeated identical message', () async {
    var n = 0;
    final r = ErrorReporter((m, s, route) async => n++);
    await r.report(Exception('same'), null);
    await r.report(Exception('same'), null);
    await r.report(Exception('different'), null);
    expect(n, 2);
  });

  test('caps reports per run', () async {
    var n = 0;
    final r = ErrorReporter((m, s, route) async => n++, maxReports: 3);
    for (var i = 0; i < 10; i++) {
      await r.report(Exception('e$i'), null);
    }
    expect(n, 3);
  });
}
```

`test/core/role_provider_test.dart`
```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/core/api/models.dart';
import 'package:sentinelx_mobile/core/providers.dart';

MeResponse _me({bool staff = false, bool admin = false}) =>
    MeResponse(id: 'u', email: null, roles: const [], isStaff: staff, isAdmin: admin, profile: null);

Future<AppRole?> _roleFor(MeResponse? me) async {
  final container = ProviderContainer(
    retry: (_, __) => null,
    overrides: [meProvider.overrideWith((ref) async => me)],
  );
  addTearDown(container.dispose);
  await container.read(meProvider.future);
  return container.read(roleProvider);
}

void main() {
  test('signed out has no role', () async => expect(await _roleFor(null), isNull));
  test('a plain user is a player', () async => expect(await _roleFor(_me()), AppRole.player));
  test('staff who is not admin is a moderator', () async => expect(await _roleFor(_me(staff: true)), AppRole.moderator));
  test('an admin is an admin', () async => expect(await _roleFor(_me(staff: true, admin: true)), AppRole.admin));
}
```
Run: `flutter test test/core/error_reporter_test.dart test/core/role_provider_test.dart` → Expected: FAIL.

- [ ] **Step 2: Implement**

`lib/core/errors/error_reporter.dart`
```dart
typedef ErrorSender = Future<void> Function(String message, String? stack, String? route);

/// Reports uncaught errors to the backend. Must never throw or loop: it runs inside error handlers.
class ErrorReporter {
  ErrorReporter(this._send, {this.maxReports = 20});

  final ErrorSender _send;
  final int maxReports;
  int _sent = 0;
  String? _last;

  Future<void> report(Object error, StackTrace? stack, {String? route}) async {
    try {
      final message = error.toString();
      if (_sent >= maxReports || message == _last) return;
      _last = message;
      _sent++;
      await _send(message, stack?.toString(), route);
    } catch (_) {
      // Swallow — a logging failure must never replace one problem with another.
    }
  }
}
```

`lib/core/providers.dart`
```dart
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'api/api_client.dart';
import 'api/models.dart';
import 'config/app_config.dart';
import 'config/remote_config.dart';
import 'errors/error_reporter.dart';

final appConfigProvider = Provider<AppConfig>((ref) => const AppConfig.fromEnvironment());

/// Overridden in main() with PackageInfo.version, and in tests.
final installedVersionProvider =
    Provider<String>((ref) => throw UnimplementedError('Override installedVersionProvider'));

final supabaseClientProvider = Provider<SupabaseClient>((ref) => Supabase.instance.client);

final sessionProvider = StreamProvider<Session?>((ref) async* {
  final auth = ref.watch(supabaseClientProvider).auth;
  yield auth.currentSession;
  yield* auth.onAuthStateChange.map((state) => state.session);
});

String get _platform => defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android';

final apiClientProvider = Provider<ApiClient>((ref) {
  final config = ref.watch(appConfigProvider);
  final supabase = ref.watch(supabaseClientProvider);
  return ApiClient.create(
    baseUrl: config.apiBaseUrl,
    appVersion: ref.watch(installedVersionProvider),
    platform: _platform,
    accessToken: () async => supabase.auth.currentSession?.accessToken,
  );
});

/// Null on any failure: a config fetch problem must never lock users out (see evaluateGate).
final remoteConfigProvider = FutureProvider<RemoteConfig?>((ref) async {
  try {
    return await ref.watch(apiClientProvider).getConfig();
  } catch (_) {
    return null;
  }
});

/// The signed-in user with roles; null when signed out.
final meProvider = FutureProvider<MeResponse?>((ref) async {
  final session = ref.watch(sessionProvider).asData?.value;
  if (session == null) return null;
  return ref.watch(apiClientProvider).getMe();
});

enum AppRole { player, moderator, admin }

/// Drives the role-aware Admin entry point. Display only — every admin API call re-checks server-side.
final roleProvider = Provider<AppRole?>((ref) {
  final me = ref.watch(meProvider).asData?.value;
  if (me == null) return null;
  if (me.isAdmin) return AppRole.admin;
  if (me.isStaff) return AppRole.moderator;
  return AppRole.player;
});

final errorReporterProvider = Provider<ErrorReporter>((ref) {
  final version = ref.watch(installedVersionProvider);
  return ErrorReporter((message, stack, route) => ref.read(apiClientProvider).postClientError(
        message: message,
        stack: stack,
        route: route,
        platform: _platform,
        appVersion: version,
      ));
});
```

- [ ] **Step 3: Run** `flutter test test/core` → Expected: all pass. `flutter analyze` → clean.

- [ ] **Step 4: Commit**
```powershell
git add lib/core test/core && git diff --cached --stat
git commit -m "feat(core): session/api/config/role providers and a capped, never-throwing error reporter"
```

---

### Task 5: Migrate the tournament slice to Riverpod

**Files:**
- Create: `lib/features/tournaments/tournaments_providers.dart`, `test/support/pump_app.dart`
- Modify (rewrite): `lib/features/tournaments/tournament_list_screen.dart`, `tournament_detail_screen.dart`, `bracket_screen.dart`, `lib/router/app_router.dart`
- Modify: `test/features/tournament_list_screen_test.dart`, `tournament_detail_screen_test.dart`, `bracket_screen_test.dart`, `test/router/app_router_test.dart`, `test/widget_test.dart`

**Interfaces:**
- Consumes: `supabaseClientProvider` (Task 4); existing `TournamentsRepository`, `SupabaseTournamentsRepository`, `Tournament`, `BracketMatch`, `roundSortIndex`, `roundDisplayName`.
- Produces: `tournamentsRepositoryProvider: Provider<TournamentsRepository>`; `tournamentsProvider: FutureProvider.autoDispose<List<Tournament>>`; `tournamentProvider: FutureProvider.autoDispose.family<Tournament, String>` (key = id); `bracketProvider: FutureProvider.autoDispose.family<List<BracketMatch>, String>` (key = tournament id). Screens: `TournamentListScreen({required onTournamentTap})`, `TournamentDetailScreen({required tournamentId, required onViewBracket})`, `BracketScreen({required tournamentId})`. Router: `GoRouter buildAppRouter({bool debugTools = false})`, `routerProvider: Provider<GoRouter>`. Test helpers: `pumpWithRepo(WidgetTester, TournamentsRepository, Widget home)`, `pumpRouterWithRepo(WidgetTester, TournamentsRepository)`.

- [ ] **Step 1: Test helper first (used by every migrated test)**

`test/support/pump_app.dart`
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/data/tournaments_repository.dart';
import 'package:sentinelx_mobile/features/tournaments/tournaments_providers.dart';
import 'package:sentinelx_mobile/router/app_router.dart';

Future<void> pumpWithRepo(WidgetTester tester, TournamentsRepository repository, Widget home) {
  return tester.pumpWidget(ProviderScope(
    retry: (_, __) => null,
    overrides: [tournamentsRepositoryProvider.overrideWithValue(repository)],
    child: MaterialApp(home: home),
  ));
}

Future<void> pumpRouterWithRepo(WidgetTester tester, TournamentsRepository repository) {
  return tester.pumpWidget(ProviderScope(
    retry: (_, __) => null,
    overrides: [tournamentsRepositoryProvider.overrideWithValue(repository)],
    child: MaterialApp.router(routerConfig: buildAppRouter()),
  ));
}
```

- [ ] **Step 2: Migrate the tests mechanically (they fail to compile until the screens change — that is the red state)**

In each of the four test files add `import '../support/pump_app.dart';` (`import 'support/pump_app.dart';` in `test/widget_test.dart`), and rewrite every screen construction:
```dart
// list screen — before
await tester.pumpWidget(MaterialApp(
  home: TournamentListScreen(repository: repository, onTournamentTap: (_) {}),
));
// after
await pumpWithRepo(tester, repository, TournamentListScreen(onTournamentTap: (_) {}));

// detail screen — before
await tester.pumpWidget(MaterialApp(
  home: TournamentDetailScreen(repository: repository, tournamentId: 't1', onViewBracket: () {}),
));
// after
await pumpWithRepo(tester, repository, TournamentDetailScreen(tournamentId: 't1', onViewBracket: () {}));

// bracket screen — before
await tester.pumpWidget(MaterialApp(home: BracketScreen(repository: repository, tournamentId: 't1')));
// after
await pumpWithRepo(tester, repository, BracketScreen(tournamentId: 't1'));

// router tests (app_router_test.dart, widget_test.dart) — before
await tester.pumpWidget(MaterialApp.router(routerConfig: buildAppRouter(repository: repository)));
// after
await pumpRouterWithRepo(tester, repository);
```
Apply to **every** occurrence (the tests in these files that construct the screen inside larger `MaterialApp(...)` wrappers with extra parameters — e.g. `bracket_screen_test.dart:139` inside a sized box — keep the wrapper by passing it as the `home:` argument: `pumpWithRepo(tester, repository, <the existing wrapper widget containing BracketScreen(tournamentId: 't1')>)`). Keep every assertion unchanged.

Run: `flutter test` → Expected: FAIL (compile errors: `tournaments_providers.dart` missing, screens still take `repository`).

- [ ] **Step 3: Providers**

`lib/features/tournaments/tournaments_providers.dart`
```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../data/supabase_tournaments_repository.dart';
import '../../data/tournaments_repository.dart';
import '../../models/bracket_match.dart';
import '../../models/tournament.dart';

final tournamentsRepositoryProvider = Provider<TournamentsRepository>(
  (ref) => SupabaseTournamentsRepository(ref.watch(supabaseClientProvider)),
);

final tournamentsProvider = FutureProvider.autoDispose<List<Tournament>>(
  (ref) => ref.watch(tournamentsRepositoryProvider).fetchTournaments(),
);

final tournamentProvider = FutureProvider.autoDispose.family<Tournament, String>(
  (ref, id) => ref.watch(tournamentsRepositoryProvider).fetchTournament(id),
);

final bracketProvider = FutureProvider.autoDispose.family<List<BracketMatch>, String>(
  (ref, id) => ref.watch(tournamentsRepositoryProvider).fetchBracket(id),
);
```

- [ ] **Step 4: Screens**

`lib/features/tournaments/tournament_list_screen.dart`
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/tournament.dart';
import 'tournaments_providers.dart';

class TournamentListScreen extends ConsumerWidget {
  const TournamentListScreen({super.key, required this.onTournamentTap});

  final void Function(Tournament tournament) onTournamentTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tournaments = ref.watch(tournamentsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Tournaments')),
      body: tournaments.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Failed to load tournaments: $error')),
        data: (items) {
          if (items.isEmpty) {
            return const Center(child: Text('No tournaments yet.'));
          }
          return ListView.builder(
            itemCount: items.length,
            itemBuilder: (context, index) {
              final tournament = items[index];
              return ListTile(
                key: Key('tournament-tile-${tournament.id}'),
                title: Text(tournament.title),
                subtitle: Text('${tournament.gameName} • ${tournament.status}'),
                onTap: () => onTournamentTap(tournament),
              );
            },
          );
        },
      ),
    );
  }
}
```

`lib/features/tournaments/tournament_detail_screen.dart`
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'tournaments_providers.dart';

class TournamentDetailScreen extends ConsumerWidget {
  const TournamentDetailScreen({
    super.key,
    required this.tournamentId,
    required this.onViewBracket,
  });

  final String tournamentId;
  final VoidCallback onViewBracket;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(tournamentProvider(tournamentId));
    return Scaffold(
      appBar: AppBar(title: const Text('Tournament')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Failed to load tournament: $error')),
        data: (tournament) => SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(tournament.title, style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text('${tournament.gameName} • ${tournament.status}'),
              const SizedBox(height: 16),
              Text('Prize pool: ${tournament.prizePool}'),
              if (tournament.prizeSecond != null) Text('2nd place: ${tournament.prizeSecond}'),
              if (tournament.prizeThird != null) Text('3rd place: ${tournament.prizeThird}'),
              const SizedBox(height: 8),
              Text('Registration fee: ${tournament.registrationFee}'),
              if (tournament.maxPlayers != null) Text('Max players: ${tournament.maxPlayers}'),
              if (tournament.description != null) ...[
                const SizedBox(height: 16),
                Text(tournament.description!),
              ],
              const SizedBox(height: 24),
              ElevatedButton(
                key: const Key('view-bracket-button'),
                onPressed: onViewBracket,
                child: const Text('View Bracket'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

`lib/features/tournaments/bracket_screen.dart` — replace **only** the top of the file through the end of `_BracketScreenState` (everything before `class _RoundColumn`), leaving `_RoundColumn` and `_MatchCard` byte-for-byte unchanged:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/bracket_match.dart';
import 'tournaments_providers.dart';

class BracketScreen extends ConsumerWidget {
  const BracketScreen({super.key, required this.tournamentId});

  final String tournamentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(bracketProvider(tournamentId));
    return Scaffold(
      appBar: AppBar(title: const Text('Bracket')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Failed to load bracket: $error')),
        data: (matches) {
          if (matches.isEmpty) {
            return const Center(child: Text('No matches yet.'));
          }

          final matchesByRound = <String, List<BracketMatch>>{};
          for (final match in matches) {
            matchesByRound.putIfAbsent(match.round, () => []).add(match);
          }
          final rounds = matchesByRound.keys.toList()
            ..sort((a, b) => roundSortIndex(a).compareTo(roundSortIndex(b)));

          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final round in rounds)
                  Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: _RoundColumn(
                      round: round,
                      matches: matchesByRound[round]!,
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
```

- [ ] **Step 5: Router**

`lib/router/app_router.dart`
```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/debug/debug_sign_in_screen.dart';
import '../features/tournaments/bracket_screen.dart';
import '../features/tournaments/tournament_detail_screen.dart';
import '../features/tournaments/tournament_list_screen.dart';
import '../core/providers.dart';

GoRouter buildAppRouter({bool debugTools = false}) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => TournamentListScreen(
          onTournamentTap: (tournament) => context.push('/tournaments/${tournament.id}'),
        ),
      ),
      GoRoute(
        path: '/tournaments/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return TournamentDetailScreen(
            tournamentId: id,
            onViewBracket: () => context.push('/tournaments/$id/bracket'),
          );
        },
      ),
      GoRoute(
        path: '/tournaments/:id/bracket',
        builder: (context, state) => BracketScreen(tournamentId: state.pathParameters['id']!),
      ),
      if (debugTools)
        GoRoute(path: '/debug', builder: (context, state) => const DebugSignInScreen()),
    ],
  );
}

final routerProvider = Provider<GoRouter>((ref) {
  final router = buildAppRouter(debugTools: ref.watch(appConfigProvider).debugTools);
  ref.onDispose(router.dispose);
  return router;
});
```
This imports `features/debug/debug_sign_in_screen.dart`, created in Task 9 — **create a minimal stub now so this task compiles**:

`lib/features/debug/debug_sign_in_screen.dart`
```dart
import 'package:flutter/material.dart';

/// Replaced with the real dev-only sign-in + /me round trip in Task 9.
class DebugSignInScreen extends StatelessWidget {
  const DebugSignInScreen({super.key});

  @override
  Widget build(BuildContext context) => const Scaffold(body: Center(child: Text('debug')));
}
```

- [ ] **Step 6: Add a router test for the debug route gate**

Append to `test/router/app_router_test.dart` (inside `main()`):
```dart
  test('the /debug route exists only when debug tools are enabled', () {
    bool hasDebug(bool tools) => buildAppRouter(debugTools: tools)
        .configuration
        .routes
        .whereType<GoRoute>()
        .any((r) => r.path == '/debug');
    expect(hasDebug(false), isFalse);
    expect(hasDebug(true), isTrue);
  });
```
with `import 'package:go_router/go_router.dart';` at the top of the file.

- [ ] **Step 7: Run everything** `flutter test` → Expected: all pre-existing behaviours pass (list/detail/bracket/router/widget tests) plus the new tests. `flutter analyze` → clean.

- [ ] **Step 8: Commit**
```powershell
git add lib test && git diff --cached --stat
git commit -m "refactor: read tournaments through Riverpod providers; provider-owned router; debug route gate"
```

---

### Task 6: Theme and i18n scaffold

**Files:**
- Create: `lib/core/theme/sx_colors.dart`, `lib/core/theme/theme.dart`, `l10n.yaml`, `lib/core/l10n/app_en.arb`, `lib/core/l10n/app_fr.arb`, generated `lib/core/l10n/gen/*`
- Modify: `pubspec.yaml` (`flutter: generate: true`)
- Test: `test/core/theme_test.dart`, `test/core/l10n_test.dart`

**Interfaces:**
- Produces: `SxColors` (`background 0xFF0B0B0F, surface 0xFF13131F, border 0xFF1E1E30, primary 0xFF7C3AED, primaryLight 0xFF9333EA, accentText 0xFFA78BFA, success 0xFF10B981, warning 0xFFF59E0B, textSecondary 0xFF9CA3AF`) — the web `tailwind.config.ts` `sx.*` palette; `ThemeData buildTheme()`; localizations class `AppLocalizations` with getters `appName`, `maintenanceTitle`, `updateRequiredTitle`, `updateAction`, method `updateRequiredBody(String minVersion)`.

- [ ] **Step 1: Write the failing tests**

`test/core/theme_test.dart`
```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/core/theme/sx_colors.dart';
import 'package:sentinelx_mobile/core/theme/theme.dart';

void main() {
  test('uses the web palette: near-black ground, violet primary', () {
    final theme = buildTheme();
    expect(theme.brightness, Brightness.dark);
    expect(theme.scaffoldBackgroundColor, SxColors.background);
    expect(theme.colorScheme.primary, SxColors.primary);
    expect(SxColors.background, const Color(0xFF0B0B0F));
    expect(SxColors.primary, const Color(0xFF7C3AED));
    expect(SxColors.accentText, const Color(0xFFA78BFA));
  });
}
```

`test/core/l10n_test.dart`
```dart
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

Set<String> _keys(String path) => (jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>)
    .keys
    .where((k) => !k.startsWith('@'))
    .toSet();

void main() {
  test('every locale defines exactly the keys of the English template', () {
    final en = _keys('lib/core/l10n/app_en.arb');
    expect(_keys('lib/core/l10n/app_fr.arb'), en);
  });
}
```
Run: `flutter test test/core/theme_test.dart test/core/l10n_test.dart` → Expected: FAIL.

- [ ] **Step 2: Theme**

`lib/core/theme/sx_colors.dart`
```dart
import 'dart:ui';

/// The `sx.*` palette from the web repo's tailwind.config.ts. Change it there first, then here.
class SxColors {
  const SxColors._();

  static const background = Color(0xFF0B0B0F);
  static const surface = Color(0xFF13131F);
  static const border = Color(0xFF1E1E30);
  static const primary = Color(0xFF7C3AED);
  static const primaryLight = Color(0xFF9333EA);
  static const accentText = Color(0xFFA78BFA);
  static const success = Color(0xFF10B981);
  static const warning = Color(0xFFF59E0B);
  static const textSecondary = Color(0xFF9CA3AF);
}
```

`lib/core/theme/theme.dart`
```dart
import 'package:flutter/material.dart';

import 'sx_colors.dart';

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: SxColors.primary,
    brightness: Brightness.dark,
  ).copyWith(
    primary: SxColors.primary,
    secondary: SxColors.accentText,
    surface: SxColors.surface,
    outline: SxColors.border,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme,
    scaffoldBackgroundColor: SxColors.background,
    appBarTheme: const AppBarTheme(
      backgroundColor: SxColors.background,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
    ),
    cardTheme: CardThemeData(
      color: SxColors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: SxColors.border),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: SxColors.primary,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(48), // 48dp touch target
      ),
    ),
  );
}
```

- [ ] **Step 3: i18n scaffold**

`pubspec.yaml` — under `flutter:` add `generate: true` (keep `uses-material-design: true`).

`l10n.yaml`
```yaml
arb-dir: lib/core/l10n
template-arb-file: app_en.arb
output-localization-file: app_localizations.dart
output-dir: lib/core/l10n/gen
synthetic-package: false
nullable-getter: false
```

`lib/core/l10n/app_en.arb`
```json
{
  "@@locale": "en",
  "appName": "Sentinel X",
  "maintenanceTitle": "We'll be right back",
  "updateRequiredTitle": "Update required",
  "updateRequiredBody": "Please update Sentinel X to version {minVersion} or newer to continue.",
  "@updateRequiredBody": { "placeholders": { "minVersion": { "type": "String" } } },
  "updateAction": "Update now"
}
```

`lib/core/l10n/app_fr.arb`
```json
{
  "@@locale": "fr",
  "appName": "Sentinel X",
  "maintenanceTitle": "Nous revenons tout de suite",
  "updateRequiredTitle": "Mise à jour requise",
  "updateRequiredBody": "Veuillez mettre à jour Sentinel X vers la version {minVersion} ou plus récente pour continuer.",
  "@updateRequiredBody": { "placeholders": { "minVersion": { "type": "String" } } },
  "updateAction": "Mettre à jour"
}
```
Generate: `flutter gen-l10n` → creates `lib/core/l10n/gen/app_localizations.dart`, `app_localizations_en.dart`, `app_localizations_fr.dart` (commit them).

- [ ] **Step 4: Run** `flutter test test/core` → Expected: pass. `flutter analyze` → clean.

- [ ] **Step 5: Commit**
```powershell
git add pubspec.yaml l10n.yaml lib/core test/core && git diff --cached --stat
git commit -m "feat(core): web-palette dark theme and en/fr l10n scaffold (pcm deferred to Phase 1)"
```

---

### Task 7: `AppGate`, root app, and bootstrap

**Files:**
- Create: `lib/core/gate/app_gate.dart`, `lib/app.dart`, `test/core/app_gate_test.dart`
- Modify: `lib/main.dart`
- Delete: `lib/core/env.dart`

**Interfaces:**
- Consumes: `evaluateGate`, `GateState`, `remoteConfigProvider`, `installedVersionProvider`, `AppLocalizations`, `SxColors`, `errorReporterProvider`, `routerProvider`, `buildTheme`.
- Produces: `class AppGate extends ConsumerWidget { const AppGate({super.key, required Widget child}); }` — shows `child` when open, `MaintenanceScreen`/`UpdateRequiredScreen` otherwise; `class SentinelXApp extends ConsumerWidget`.

- [ ] **Step 1: Write the failing widget test**

`test/core/app_gate_test.dart`
```dart
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/core/config/remote_config.dart';
import 'package:sentinelx_mobile/core/gate/app_gate.dart';
import 'package:sentinelx_mobile/core/l10n/gen/app_localizations.dart';
import 'package:sentinelx_mobile/core/providers.dart';

RemoteConfig _config({String min = '0.0.0', String? maintenance}) => RemoteConfig.fromJson({
      'minSupportedAppVersion': min,
      'latestAppVersion': '9.9.9',
      'maintenance': maintenance == null ? null : {'message': maintenance},
      'siteUrl': 'https://sentinelxesports.com.ng',
      'coins': {'coinsPerNaira': 2, 'nairaPerCoin': 0.5, 'coinsPerEntry': 1000, 'coinsHalfEntry': 500},
      'enforcePhoneVerification': false,
      'whatsappCommunityUrl': null,
      'features': <String, bool>{},
    });

Future<void> _pump(WidgetTester tester, {required RemoteConfig? config, String installed = '1.0.0'}) {
  return tester.pumpWidget(ProviderScope(
    retry: (_, __) => null,
    overrides: [
      installedVersionProvider.overrideWithValue(installed),
      remoteConfigProvider.overrideWith((ref) async => config),
    ],
    child: MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: const AppGate(child: Text('APP')),
    ),
  ));
}

void main() {
  testWidgets('shows the app while the config is still loading', (tester) async {
    await _pump(tester, config: _config());
    expect(find.text('APP'), findsOneWidget);
  });

  testWidgets('shows the app when the version is supported', (tester) async {
    await _pump(tester, config: _config(min: '1.0.0'));
    await tester.pumpAndSettle();
    expect(find.text('APP'), findsOneWidget);
  });

  testWidgets('blocks with the update screen below the minimum version', (tester) async {
    await _pump(tester, config: _config(min: '2.0.0'), installed: '1.9.9');
    await tester.pumpAndSettle();
    expect(find.text('APP'), findsNothing);
    expect(find.text('Update required'), findsOneWidget);
    expect(find.textContaining('2.0.0'), findsOneWidget);
  });

  testWidgets('blocks with the maintenance screen and shows the server message', (tester) async {
    await _pump(tester, config: _config(maintenance: 'Back at 3pm'));
    await tester.pumpAndSettle();
    expect(find.text('APP'), findsNothing);
    expect(find.text("We'll be right back"), findsOneWidget);
    expect(find.text('Back at 3pm'), findsOneWidget);
  });

  testWidgets('a failed config fetch never locks the user out', (tester) async {
    await _pump(tester, config: null);
    await tester.pumpAndSettle();
    expect(find.text('APP'), findsOneWidget);
  });
}
```
Run: `flutter test test/core/app_gate_test.dart` → Expected: FAIL (`app_gate.dart` missing).

- [ ] **Step 2: Implement the gate**

`lib/core/gate/app_gate.dart`
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/remote_config.dart';
import '../l10n/gen/app_localizations.dart';
import '../providers.dart';
import '../theme/sx_colors.dart';

const _playStoreUrl = 'https://play.google.com/store/apps/details?id=ng.com.sentinelxesports.app';

class AppGate extends ConsumerWidget {
  const AppGate({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(remoteConfigProvider).asData?.value; // null while loading or on failure -> open
    final gate = evaluateGate(config, ref.watch(installedVersionProvider));
    switch (gate.kind) {
      case GateKind.open:
        return child;
      case GateKind.maintenance:
        return _Blocker(title: AppLocalizations.of(context).maintenanceTitle, body: gate.message ?? '');
      case GateKind.updateRequired:
        final l10n = AppLocalizations.of(context);
        return _Blocker(
          title: l10n.updateRequiredTitle,
          body: l10n.updateRequiredBody(gate.minVersion ?? ''),
          actionLabel: l10n.updateAction,
          onAction: () => launchUrl(Uri.parse(_playStoreUrl), mode: LaunchMode.externalApplication),
        );
    }
  }
}

class _Blocker extends StatelessWidget {
  const _Blocker({required this.title, required this.body, this.actionLabel, this.onAction});

  final String title;
  final String body;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SxColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: Theme.of(context).textTheme.headlineSmall, textAlign: TextAlign.center),
                const SizedBox(height: 12),
                Text(body, textAlign: TextAlign.center, style: const TextStyle(color: SxColors.textSecondary)),
                if (actionLabel != null) ...[
                  const SizedBox(height: 24),
                  ElevatedButton(onPressed: onAction, child: Text(actionLabel!)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 3: Root app and bootstrap**

`lib/app.dart`
```dart
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/gate/app_gate.dart';
import 'core/l10n/gen/app_localizations.dart';
import 'core/theme/theme.dart';
import 'router/app_router.dart';

class SentinelXApp extends ConsumerWidget {
  const SentinelXApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'Sentinel X',
      theme: buildTheme(),
      routerConfig: ref.watch(routerProvider),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => AppGate(child: child ?? const SizedBox.shrink()),
    );
  }
}
```

`lib/main.dart`
```dart
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/config/app_config.dart';
import 'core/providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  const config = AppConfig.fromEnvironment();
  final info = await PackageInfo.fromPlatform();
  await Supabase.initialize(url: config.supabaseUrl, publishableKey: config.supabasePublishableKey);

  final container = ProviderContainer(
    retry: (_, __) => null,
    overrides: [installedVersionProvider.overrideWithValue(info.version)],
  );
  final reporter = container.read(errorReporterProvider);

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    reporter.report(details.exception, details.stack);
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    reporter.report(error, stack);
    return true;
  };

  runApp(UncontrolledProviderScope(container: container, child: const SentinelXApp()));
}
```
(`foundation.dart` import is used by `FlutterError`/`kDebugMode`; remove it if `flutter analyze` reports it unused.)

Delete `lib/core/env.dart`: `git rm lib/core/env.dart`. Confirm no references: `Select-String -Path lib -Pattern "SupabaseEnv" -Recurse` → no matches.

- [ ] **Step 4: Run** `flutter test` → Expected: all pass (gate: 5 new). `flutter analyze` → clean.

- [ ] **Step 5: Commit**
```powershell
git add -A lib test && git diff --cached --stat
git commit -m "feat(core): remote-config AppGate, root app widget, crash-reporting bootstrap; drop env.dart"
```

---

### Task 8: Web-link resolver

**Files:**
- Create: `lib/core/routing/web_links.dart`
- Test: `test/core/web_links_test.dart`

**Interfaces:** Produces `String? resolveWebLink(String input)` — maps a web URL or path (optional locale prefix `en|fr|pcm`, optional query/fragment) on `sentinelxesports.com.ng` / `www.` to an in-app location, or `null` when the app has no screen for it. Phase 0 table: `/` and `/tournaments` → `/`. (Entries are added per phase: `/auth/confirm` in Phase 1, `/tournaments/:slug…` in Phase 2 when routes accept slugs.)

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/core/routing/web_links.dart';

void main() {
  test('maps the tournaments list and site root to the in-app list screen', () {
    expect(resolveWebLink('https://sentinelxesports.com.ng/tournaments'), '/');
    expect(resolveWebLink('https://sentinelxesports.com.ng/'), '/');
    expect(resolveWebLink('/tournaments'), '/');
  });

  test('strips a locale prefix, query and fragment', () {
    expect(resolveWebLink('https://sentinelxesports.com.ng/fr/tournaments'), '/');
    expect(resolveWebLink('https://sentinelxesports.com.ng/pcm/tournaments?x=1#y'), '/');
  });

  test('accepts the www host and tolerates a trailing slash', () {
    expect(resolveWebLink('https://www.sentinelxesports.com.ng/tournaments/'), '/');
  });

  test('returns null for other hosts and for paths the app has no screen for yet', () {
    expect(resolveWebLink('https://evil.example/tournaments'), isNull);
    expect(resolveWebLink('https://sentinelxesports.com.ng/exchange'), isNull);
    expect(resolveWebLink('https://sentinelxesports.com.ng/tournaments/some-slug'), isNull);
    expect(resolveWebLink('not a url at all ::'), isNull);
  });
}
```
Run → Expected: FAIL.

- [ ] **Step 2: Implement**

`lib/core/routing/web_links.dart`
```dart
const _hosts = {'sentinelxesports.com.ng', 'www.sentinelxesports.com.ng'};
const _locales = {'en', 'fr', 'pcm'};

/// Web `link` values (push payloads, bell items, App Links) are web route paths. This is the single
/// place that turns one into an in-app go_router location. Extend the switch as each phase adds screens.
String? resolveWebLink(String input) {
  final uri = Uri.tryParse(input.trim());
  if (uri == null) return null;
  if (uri.hasAuthority && !_hosts.contains(uri.host)) return null;

  final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
  if (segments.isNotEmpty && _locales.contains(segments.first)) segments.removeAt(0);

  if (segments.isEmpty) return '/';
  switch (segments.join('/')) {
    case 'tournaments':
      return '/';
  }
  return null;
}
```

- [ ] **Step 3: Run** `flutter test test/core/web_links_test.dart` → Expected: 4 passed. `flutter analyze` → clean.

- [ ] **Step 4: Commit**
```powershell
git add lib/core test/core && git diff --cached --stat
git commit -m "feat(core): resolveWebLink maps web paths/URLs to in-app locations"
```

---

### Task 9: Android identity, App Links, and the debug round-trip screen

**Files:**
- Modify: `android/app/build.gradle*` (namespace, applicationId), `android/app/src/main/AndroidManifest.xml`, `MainActivity` package + directory
- Modify (replace stub): `lib/features/debug/debug_sign_in_screen.dart`

**Interfaces:** Consumes `supabaseClientProvider`, `apiClientProvider`, `ApiException`, `MeResponse`.

- [ ] **Step 1: Rename the Android package to `ng.com.sentinelxesports.app`** (nothing has shipped, so this is free now and painful later)

```powershell
Get-ChildItem -Recurse android\app\src\main\kotlin | Select-Object FullName
```
Expected: one `MainActivity.kt` under `...\com\example\sentinelx_mobile\`. Then:
```powershell
New-Item -ItemType Directory -Force android\app\src\main\kotlin\ng\com\sentinelxesports\app | Out-Null
git mv android\app\src\main\kotlin\com\example\sentinelx_mobile\MainActivity.kt android\app\src\main\kotlin\ng\com\sentinelxesports\app\MainActivity.kt
```
Edit the first line of that file to `package ng.com.sentinelxesports.app`. In `android/app/build.gradle(.kts)` set `namespace = "ng.com.sentinelxesports.app"` and `applicationId = "ng.com.sentinelxesports.app"`. Remove the now-empty `com/example` directories.

- [ ] **Step 2: Manifest** — in `android/app/src/main/AndroidManifest.xml`:
  1. Add before `<application>`: `<uses-permission android:name="android.permission.INTERNET"/>` (release builds have no network without it; only debug/profile manifests add it implicitly).
  2. Set `android:label="Sentinel X"`.
  3. Inside the `<activity>` after the existing MAIN/LAUNCHER filter add the verified App Link (exact path only, per Global Constraints):
```xml
            <intent-filter android:autoVerify="true">
                <action android:name="android.intent.action.VIEW"/>
                <category android:name="android.intent.category.DEFAULT"/>
                <category android:name="android.intent.category.BROWSABLE"/>
                <data android:scheme="https" android:host="sentinelxesports.com.ng" android:path="/tournaments"/>
            </intent-filter>
```

- [ ] **Step 3: Build check** — `flutter build apk --debug` → Expected: `Built build\app\outputs\flutter-apk\app-debug.apk`. If Gradle complains about the old package, `flutter clean` then rebuild.

- [ ] **Step 4: Replace the debug stub with the real round-trip screen**

`lib/features/debug/debug_sign_in_screen.dart`
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/providers.dart';

/// Dev-only (route exists only when DEBUG_TOOLS is true). Proves the Phase 0 exit criterion:
/// sign in with Supabase, call the bearer-authenticated GET /me, see the roles that will drive
/// the role-aware Admin section. Replaced by the real login flow in Phase 1.
class DebugSignInScreen extends ConsumerStatefulWidget {
  const DebugSignInScreen({super.key});

  @override
  ConsumerState<DebugSignInScreen> createState() => _DebugSignInScreenState();
}

class _DebugSignInScreenState extends ConsumerState<DebugSignInScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  String _output = 'Not signed in.';
  bool _busy = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _run() async {
    setState(() => _busy = true);
    try {
      await ref.read(supabaseClientProvider).auth.signInWithPassword(
            email: _email.text.trim(),
            password: _password.text,
          );
      final me = await ref.read(apiClientProvider).getMe();
      _output = 'OK ${me.id}\nroles: ${me.roles}\nisStaff: ${me.isStaff}  isAdmin: ${me.isAdmin}\n'
          'username: ${me.profile?.username}';
    } on ApiException catch (e) {
      _output = 'API error: $e';
    } catch (e) {
      _output = 'Error: $e';
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Debug sign-in')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(controller: _email, decoration: const InputDecoration(labelText: 'Email')),
          TextField(controller: _password, obscureText: true, decoration: const InputDecoration(labelText: 'Password')),
          const SizedBox(height: 16),
          ElevatedButton(
            key: const Key('debug-sign-in'),
            onPressed: _busy ? null : _run,
            child: Text(_busy ? 'Working…' : 'Sign in and call /me'),
          ),
          const SizedBox(height: 16),
          SelectableText(_output),
        ],
      ),
    );
  }
}
```

- [ ] **Step 5: Verify** `flutter analyze` → clean; `flutter test` → all pass.

- [ ] **Step 6: Commit**
```powershell
git add -A android lib && git diff --cached --stat
git commit -m "feat(android): ng.com.sentinelxesports.app id, INTERNET permission, /tournaments App Link; dev-only /me round trip"
```

---

### Task 10: Device round trip, App Links verification, and docs — **manual; needs the web plans shipped and an Android device or emulator**

**Files:** Modify `README.md`, `CLAUDE.md`.

- [ ] **Step 1: Get the debug signing fingerprint**
```powershell
keytool -list -v -keystore "$env:USERPROFILE\.android\debug.keystore" -alias androiddebugkey -storepass android -keypass android | Select-String "SHA256"
```
Expected: one `SHA256: AA:BB:…` line. **Ask the owner** to set `ANDROID_CERT_SHA256` to that value in the Vercel production environment (and later append the Play upload/app-signing fingerprints in Phase 9), then confirm `https://sentinelxesports.com.ng/.well-known/assetlinks.json` returns a statement containing it.

- [ ] **Step 2: Run on a device/emulator with dev flags**
```powershell
flutter devices
flutter run --dart-define-from-file=config/dev.json --route=/debug
```
The app opens directly on the dev-only sign-in screen (the `/debug` route exists because `config/dev.json` sets `DEBUG_TOOLS`). Sign in with a **dedicated tagged test account** (not a real player) and press **Sign in and call /me**.
Expected: output `OK <uuid>` with `roles`, `isStaff`, `isAdmin` matching that account's `user_roles`. A staff test account must show `isStaff: true` — this is the role-aware admin gate working end to end.

- [ ] **Step 3: Verify the kill switch (read-only)** — with the app running signed-out, confirm the tournament list loads (T1 read) and that `GET /api/mobile/v1/config` is fetched (`flutter logs` or the Vercel request log). To exercise the gate, set `MOBILE_MIN_APP_VERSION=9.0.0` on a Vercel **preview** deployment only (never production) and point the app at it with `--dart-define=API_BASE_URL=<preview url>`; expected: the "Update required" screen. Remove the override afterwards.

- [ ] **Step 4: Verify App Links** (after Step 1's env var is live)
```powershell
adb shell pm verify-app-links --re-verify ng.com.sentinelxesports.app
adb shell pm get-app-links ng.com.sentinelxesports.app
adb shell am start -a android.intent.action.VIEW -d "https://sentinelxesports.com.ng/tournaments"
```
Expected: `sentinelxesports.com.ng: verified`, and the third command opens the app on the tournament list without a chooser. If verification shows `none`/`legacy_failure`, the fingerprint in Vercel does not match the installed debug key — recheck Step 1.

- [ ] **Step 5: Verify crash reporting** — temporarily throw from a dev-only button or run `flutter run` with a deliberately failing route, confirm a row appears in `client_error_logs` with `user_agent = 'sentinelx-mobile/<version> (android)'` (staff can read it; or `select` via the Supabase MCP). Remove the temporary throw.

- [ ] **Step 6: Update `README.md`** with: what the app is, `flutter pub get`, run/test/analyze commands, `flutter run --dart-define-from-file=config/dev.json`, the contract-sync procedure (copy `openapi/mobile-v1.json` from the web repo to `api/openapi.json`, run `flutter test`), and a link to the master spec.

- [ ] **Step 7: Update `CLAUDE.md`** — replace "No state-management package…" leftovers with: providers live in `lib/core/providers.dart`; screens read through providers; new infrastructure goes under `lib/core/`; the existing tournaments slice is temporary until Phase 2; add the commands `flutter analyze`, `flutter test`, `flutter gen-l10n`.

- [ ] **Step 8: Final gate and commit**

Run: `flutter analyze` → No issues. `flutter test` → all pass.
```powershell
git add README.md CLAUDE.md && git diff --cached --stat
git commit -m "docs: README and CLAUDE.md for the Phase 0 foundation"
```

---

## Self-Review

**Spec coverage (§13 Phase 0, mobile side).** Flavors/config → Task 1. Riverpod migration of the existing slice → Task 5. Theme tokens → Task 6. i18n scaffold → Task 6 (en/fr; `pcm` deferred with reason). API client pipeline → Task 3 (hand-written + contract test; codegen deferred with reason). Router with guards + link resolver → Tasks 5 and 8 (role/session guards need auth screens — `sessionProvider`/`roleProvider` are in place; redirect rules land with Phase 1's login). `/config` kill-switch → Tasks 2, 4, 7. Sentry → replaced by `client_error_logs` reporting (Tasks 4, 7). CI → local gate (no remote). App Links → Task 9–10. "Authenticated round trip from a device" → Task 9–10. Web-side items (S1–S3, bearer helper, `/config`, `/errors`, `/devices`, `assetlinks.json`) live in plans 0A and 0B.

**Placeholder scan.** No TBD/TODO; every code step is literal. Task 5 Step 2 is a mechanical rewrite rule with four worked before/after examples plus the exact edge case (the wrapped bracket test), verified by running the suite.

**Type consistency.** `RemoteConfig`/`GateState`/`evaluateGate` (Task 2) are used unchanged in Tasks 4 and 7. `ApiClient` method names and `usedOperations` keys (Task 3) match the web plan's `operationId`s (`getConfig, getMe, postClientError, postDevice, deleteDevice`). Provider names (Task 4) are used identically in Tasks 5, 7, 9. `installedVersionProvider` is overridden in `main()` and in the gate test. `routerProvider`/`buildAppRouter({debugTools})` are consistent between Task 5 and the router test.

**Known limits.** No automatic 401 refresh-and-retry in `ApiClient` (supabase_flutter refreshes tokens itself; a retry layer arrives with the first authenticated write, Phase 1). The debug sign-in screen has no widget test because it talks to the concrete Supabase client; its correctness is the manual Task 10 round trip. Tournament screens still use unformatted prize/fee numbers — money formatting arrives with the Phase 2 rebuild.
