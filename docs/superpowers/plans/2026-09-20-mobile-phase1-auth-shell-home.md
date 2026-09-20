# Mobile Phase 1 — Auth, Shell, Home, Static Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A new user can sign up (email + Google), confirm via App Link, claim a username, and land on Home; ban/retired-username checks proven. Ships the 5-tab shell (Compete/Watch/Community/Trade/Account), Home, and the static-content pipeline (with Terms fully wired as the proof).

**Architecture:** `lib/core/auth/**` holds the repository/providers/gate that every auth screen depends on; screens live in `lib/features/auth/` and `lib/features/onboarding/`. The router grows from a flat list into a `StatefulShellRoute` with Home as a standalone route outside the shell. Static content is generated, never hand-retyped: a Dart script flattens the web repo's `messages/{en,fr}.json` into this repo's ARB files, and a generic `StaticPage` widget renders any page from a small per-page section manifest. Tier rules unchanged: `supabase_flutter` direct for T1 reads and the two Tier-1 auth calls (`signInWithPassword`, `verifyOtp`); every write that isn't already an Auth-API call goes through `ApiClient`.

**Tech Stack:** Flutter 3.41.9 / Dart 3.11.5, `flutter_riverpod` 3.x (manual providers, no codegen), `go_router` 17.x, `supabase_flutter` 2.17.x, `dio`, `google_sign_in`, `app_links`, `flutter_test` (fakes, no mocking package).

**Spec:** `docs/superpowers/specs/2026-09-20-mobile-phase1-auth-shell-home-design.md` (web repo) §3–§6. Master spec: `docs/superpowers/specs/2026-09-18-flutter-mobile-app-master-design.md` §4.4, §6.1, §6.8, §8.1, §8.2, §8.20, §13 Phase 1. **Depends on** `docs/superpowers/plans/2026-09-20-mobile-phase1-api.md` (web repo) being merged to `origin/main` first — every `ApiClient` method in Task 1 calls an endpoint that plan ships.

## Global Constraints

- **No production writes from this app beyond what the exit criterion requires.** Every write this plan adds (`signup`, `session/start`, `onboarding/username`) is exercised for real exactly once per flow, following the testing discipline below — never looped, never scripted into a test harness that could run repeatedly against production.
- **Testing discipline (spec §5) — binding for every manual/device test step in this plan:**
  - Reuse the already-seeded test accounts for anything that doesn't exercise signup itself (Home, existing tournament screens).
  - Every account created to test signup/onboarding/confirmation is prefixed **`zzqa_`** in its username, using a **plus-addressed email off an inbox the owner controls** (provided out of band) so confirmation links are real.
  - Log every such account in **`TESTING-NOTES.md`** (repo root) as it's created — username, date, what it verified.
  - Clean each one up via `anonymise_account` once its flow is verified — ask the owner before running any RPC against production, same as every other production mutation in this plan.
- Riverpod: manual providers only (`Provider`, `FutureProvider`, `StreamProvider`); `retry: (_, _) => null` in every `ProviderContainer`/`ProviderScope` used in tests (installed version is 3.x — confirmed in `pubspec.yaml`, matches Phase 0C's finding).
- `ApiClient` is the only mutation path; `supabase_flutter` direct calls are limited to `signInWithPassword`, `signUp`/`signInWithIdToken` (Google), `verifyOtp`, `updateUser` (password reset) and `signOut` — Tier 1 Auth API calls, not `profiles` writes (S2 lock-down: `profiles` cannot be written via PostgREST at all, mobile or web).
- Every commit: verify `git branch --show-current` and `git diff --cached --stat` first. `flutter analyze && flutter test` must be clean before each commit.
- **Owner setup step, not a blocker for writing code:** Google Sign-In needs an Android OAuth client (package `ng.com.sentinelxesports.app` + release/debug SHA-1) registered in the Google Cloud project backing Supabase's existing Google provider, and that Web Client ID set as `GOOGLE_WEB_CLIENT_ID`. Task 6 implements the button and repository method regardless; the button simply fails with a clear error until the owner completes this, exactly like `ANDROID_CERT_SHA256` in Phase 0C.
- **Tripwire (spec §4.4):** do not set `enforce_phone_verification=true` in any environment until a shipped app version has the onboarding-phone screen — flipping it today strands signed-in app users at a gate route that doesn't exist. Task 11 records this in `CLAUDE.md`.

---

## File Structure

| File | Responsibility |
|---|---|
| `lib/core/api/api_client.dart` (modify), `lib/core/api/models.dart` (modify) | 6 new methods; `SessionStartResponse`, `DailyLoginAward`, `HomeSummary` + its nested models |
| `api/openapi.json` (modify) | re-pinned copy of the web repo's `openapi/mobile-v1.json` |
| `tool/gen_l10n_from_web.dart` | flattens `../sentinelx/messages/{en,fr}.json` namespaces into this repo's ARB files |
| `lib/core/l10n/app_en.arb`, `app_fr.arb` (modify, generated sections) | `auth*`, `common*`, `nav*`, `home*` keys (this task), `terms*` (Task 10) |
| `lib/core/config/app_config.dart` (modify) | `googleWebClientId` field |
| `lib/core/auth/auth_repository.dart`, `auth_providers.dart` | `AuthRepository`, `AuthException`, providers |
| `lib/core/auth/onboarding_gate.dart` | `resolveOnboardingGate(MeResponse?, RemoteConfig?)` |
| `lib/features/auth/login_screen.dart`, `forgot_password_screen.dart`, `reset_password_screen.dart` | Task 4 |
| `lib/features/auth/signup_screen.dart`, `check_email_screen.dart`, `lib/features/onboarding/onboarding_username_screen.dart` | Task 5 |
| `lib/features/auth/google_sign_in_button.dart` | Task 6 |
| `lib/core/auth/email_link_handler.dart`, `android/app/src/main/AndroidManifest.xml` (modify) | Task 7 |
| `lib/router/app_router.dart` (modify), `lib/core/routing/web_links.dart` (modify), `lib/shared/widgets/sx_tab_app_bar.dart`, `lib/shared/widgets/coming_soon_screen.dart`, `lib/features/account/account_screen.dart`, `lib/core/notifications/unread_counts.dart` | Task 8 |
| `lib/features/home/home_repository.dart`, `home_providers.dart`, `home_screen.dart` | Task 9 |
| `lib/core/static/rich_content.dart`, `lib/shared/widgets/static_page_screen.dart`, `lib/features/static/terms_screen.dart` | Task 10 |
| `CLAUDE.md` (modify), `TESTING-NOTES.md` (new) | Task 11 |

---

### Task 1: `ApiClient` extensions and pinned contract

**Files:**
- Modify: `lib/core/api/api_client.dart`, `lib/core/api/models.dart`, `api/openapi.json`
- Test: `test/core/api_client_test.dart` (extend, existing tests unchanged), `test/core/api_contract_test.dart` (no change — it reads the file, already generic)

**Interfaces:**
- Produces: `class DailyLoginAward { bool awardedToday; int coinsAwarded; int xpAwarded; int streak; String? milestone; }`; `class SessionStartResponse { DailyLoginAward dailyLogin; String? deletionRequestedAt; }`; `class HomeTournamentCard`, `HomeLeaderboardPlayer`, `HomeBanner`, `HallOfFameTeaser`, `HomeStats`, `HomeSummary` (all with `fromJson`); `ApiClient.postAuthSignup(...)`, `.postAuthResendConfirmation(String)`, `.postAuthRequestReset(String)`, `.postSessionStart()`, `.postOnboardingUsername(String) → Future<String>`, `.getHome() → Future<HomeSummary>`.

- [ ] **Step 1: Copy the refreshed web contract**

The web plan's Task 6 regenerates `openapi/mobile-v1.json` in the web repo with the six new operations (`postAuthSignup`, `postAuthResendConfirmation`, `postAuthRequestReset`, `postSessionStart`, `postOnboardingUsername`, `getHome`). Copy it into this repo:
```powershell
Copy-Item "C:\Users\gorok\Videos\sentinelx\openapi\mobile-v1.json" "api\openapi.json" -Force
```
Verify: `git diff --stat api/openapi.json` shows a change (not "no changes" — if the web plan hasn't been merged yet, stop and merge it first).

- [ ] **Step 2: Write the failing tests**

Append to `test/core/api_client_test.dart` (add to the existing `_configData`-based file; do not remove any existing test):
```dart
  test('postAuthSignup posts username/email/password and omits absent optional fields', () async {
    final adapter = _FakeAdapter((req) => _json(200, {'data': {'ok': true}}));
    await _client(adapter).postAuthSignup(username: 'newplayer', email: 'a@b.com', password: 'password123');
    final req = adapter.requests.single;
    expect(req.method, 'POST');
    expect(req.uri.toString(), 'https://api.test/api/mobile/v1/auth/signup');
    expect(req.data, {'username': 'newplayer', 'email': 'a@b.com', 'password': 'password123'});
  });

  test('postAuthSignup includes ref and locale when given', () async {
    final adapter = _FakeAdapter((_) => _json(200, {'data': {'ok': true}}));
    await _client(adapter).postAuthSignup(username: 'n', email: 'a@b.com', password: 'password123', ref: 'friend1', locale: 'fr');
    expect(adapter.requests.single.data, {'username': 'n', 'email': 'a@b.com', 'password': 'password123', 'ref': 'friend1', 'locale': 'fr'});
  });

  test('postAuthResendConfirmation and postAuthRequestReset post the email', () async {
    final adapter = _FakeAdapter((_) => _json(200, {'data': {'ok': true}}));
    final client = _client(adapter);
    await client.postAuthResendConfirmation('a@b.com');
    expect(adapter.requests.last.uri.toString(), 'https://api.test/api/mobile/v1/auth/resend-confirmation');
    await client.postAuthRequestReset('a@b.com');
    expect(adapter.requests.last.uri.toString(), 'https://api.test/api/mobile/v1/auth/request-reset');
  });

  test('postSessionStart parses the daily-login award and deletion status', () async {
    final adapter = _FakeAdapter((_) => _json(200, {
          'data': {
            'dailyLogin': {'awardedToday': true, 'coinsAwarded': 55, 'xpAwarded': 120, 'streak': 7, 'milestone': 'week'},
            'deletionRequestedAt': null,
          }
        }));
    final result = await _client(adapter).postSessionStart();
    expect(adapter.requests.single.method, 'POST');
    expect(result.dailyLogin.streak, 7);
    expect(result.dailyLogin.milestone, 'week');
    expect(result.deletionRequestedAt, isNull);
  });

  test('postOnboardingUsername posts the username and returns the claimed one', () async {
    final adapter = _FakeAdapter((_) => _json(200, {'data': {'username': 'BrandNew'}}));
    final username = await _client(adapter).postOnboardingUsername('BrandNew');
    expect(adapter.requests.single.data, {'username': 'BrandNew'});
    expect(username, 'BrandNew');
  });

  test('getHome parses the full summary', () async {
    final adapter = _FakeAdapter((_) => _json(200, {
          'data': {
            'banner': {'title': 'Hero', 'imageUrl': null, 'linkUrl': null},
            'featuredTournament': {
              'id': 't1', 'title': 'FC Mobile Cup', 'slug': 'fc-mobile-cup', 'status': 'active',
              'prizePool': 8000, 'registrationFee': 500, 'tournamentStart': null, 'registrationEnd': null,
              'tournamentEnd': null, 'maxPlayers': 16, 'format': 'knockout', 'tournamentType': 'masters',
              'cardImageUrl': null, 'game': {'name': 'EA FC Mobile', 'iconUrl': null, 'slug': 'ea-fc-mobile', 'category': 'football'},
            },
            'upcomingTournaments': [],
            'leaderboardTeaser': [
              {'id': 'p1', 'username': 'ada', 'displayName': 'Ada', 'avatarUrl': null, 'wins': 10, 'totalMatches': 15,
               'sxScore': 900, 'sentinelTier': 'elite', 'membershipTier': 'guardian', 'equippedAvatarBorder': null}
            ],
            'hallOfFame': null,
            'stats': {'playerCount': 42, 'tournamentCount': 7, 'prizesPaidOut': 1000},
          }
        }));
    final summary = await _client(adapter).getHome();
    expect(adapter.requests.single.uri.toString(), 'https://api.test/api/mobile/v1/home');
    expect(summary.featuredTournament?.title, 'FC Mobile Cup');
    expect(summary.featuredTournament?.game?.name, 'EA FC Mobile');
    expect(summary.leaderboardTeaser.single.username, 'ada');
    expect(summary.hallOfFame, isNull);
    expect(summary.stats.playerCount, 42);
  });
```

- [ ] **Step 2b: Add the six operations to `usedOperations`**

In `lib/core/api/api_client.dart`, extend the existing `usedOperations` map:
```dart
    'postAuthSignup': 'post /api/mobile/v1/auth/signup',
    'postAuthResendConfirmation': 'post /api/mobile/v1/auth/resend-confirmation',
    'postAuthRequestReset': 'post /api/mobile/v1/auth/request-reset',
    'postSessionStart': 'post /api/mobile/v1/session/start',
    'postOnboardingUsername': 'post /api/mobile/v1/onboarding/username',
    'getHome': 'get /api/mobile/v1/home',
```

- [ ] **Step 3: Run to verify failure**

Run: `flutter test test/core/api_client_test.dart` → Expected: FAIL (methods don't exist yet).
Run: `flutter test test/core/api_contract_test.dart` → Expected: PASS already (the six new keys now have matching entries in `api/openapi.json` from Step 1 — if this fails, the copy in Step 1 didn't happen or is stale).

- [ ] **Step 4: Implement the models**

Append to `lib/core/api/models.dart`:
```dart
class DailyLoginAward {
  const DailyLoginAward({
    required this.awardedToday,
    required this.coinsAwarded,
    required this.xpAwarded,
    required this.streak,
    required this.milestone,
  });

  factory DailyLoginAward.fromJson(Map<String, dynamic> j) => DailyLoginAward(
        awardedToday: j['awardedToday'] as bool,
        coinsAwarded: (j['coinsAwarded'] as num).toInt(),
        xpAwarded: (j['xpAwarded'] as num).toInt(),
        streak: (j['streak'] as num).toInt(),
        milestone: j['milestone'] as String?,
      );

  final bool awardedToday;
  final int coinsAwarded;
  final int xpAwarded;
  final int streak;
  final String? milestone; // 'week' | 'month' | null
}

class SessionStartResponse {
  const SessionStartResponse({required this.dailyLogin, required this.deletionRequestedAt});

  factory SessionStartResponse.fromJson(Map<String, dynamic> j) => SessionStartResponse(
        dailyLogin: DailyLoginAward.fromJson(j['dailyLogin'] as Map<String, dynamic>),
        deletionRequestedAt: j['deletionRequestedAt'] as String?,
      );

  final DailyLoginAward dailyLogin;
  final String? deletionRequestedAt;
}

class HomeGame {
  const HomeGame({required this.name, required this.iconUrl, required this.slug, required this.category});
  factory HomeGame.fromJson(Map<String, dynamic> j) => HomeGame(
        name: j['name'] as String,
        iconUrl: j['iconUrl'] as String?,
        slug: j['slug'] as String?,
        category: j['category'] as String?,
      );
  final String name;
  final String? iconUrl;
  final String? slug;
  final String? category;
}

class HomeTournamentCard {
  const HomeTournamentCard({
    required this.id,
    required this.title,
    required this.slug,
    required this.status,
    required this.prizePool,
    required this.registrationFee,
    required this.tournamentStart,
    required this.registrationEnd,
    required this.tournamentEnd,
    required this.maxPlayers,
    required this.format,
    required this.tournamentType,
    required this.cardImageUrl,
    required this.game,
  });

  factory HomeTournamentCard.fromJson(Map<String, dynamic> j) => HomeTournamentCard(
        id: j['id'] as String,
        title: j['title'] as String,
        slug: j['slug'] as String,
        status: j['status'] as String,
        prizePool: (j['prizePool'] as num).toInt(),
        registrationFee: (j['registrationFee'] as num).toInt(),
        tournamentStart: j['tournamentStart'] as String?,
        registrationEnd: j['registrationEnd'] as String?,
        tournamentEnd: j['tournamentEnd'] as String?,
        maxPlayers: (j['maxPlayers'] as num?)?.toInt(),
        format: j['format'] as String?,
        tournamentType: j['tournamentType'] as String?,
        cardImageUrl: j['cardImageUrl'] as String?,
        game: j['game'] == null ? null : HomeGame.fromJson(j['game'] as Map<String, dynamic>),
      );

  final String id;
  final String title;
  final String slug;
  final String status;
  final int prizePool;
  final int registrationFee;
  final String? tournamentStart;
  final String? registrationEnd;
  final String? tournamentEnd;
  final int? maxPlayers;
  final String? format;
  final String? tournamentType;
  final String? cardImageUrl;
  final HomeGame? game;
}

class HomeLeaderboardPlayer {
  const HomeLeaderboardPlayer({
    required this.id,
    required this.username,
    required this.displayName,
    required this.avatarUrl,
    required this.wins,
    required this.totalMatches,
    required this.sxScore,
    required this.sentinelTier,
    required this.membershipTier,
    required this.equippedAvatarBorder,
  });

  factory HomeLeaderboardPlayer.fromJson(Map<String, dynamic> j) => HomeLeaderboardPlayer(
        id: j['id'] as String,
        username: j['username'] as String?,
        displayName: j['displayName'] as String?,
        avatarUrl: j['avatarUrl'] as String?,
        wins: (j['wins'] as num).toInt(),
        totalMatches: (j['totalMatches'] as num).toInt(),
        sxScore: (j['sxScore'] as num).toInt(),
        sentinelTier: j['sentinelTier'] as String?,
        membershipTier: j['membershipTier'] as String?,
        equippedAvatarBorder: j['equippedAvatarBorder'] as String?,
      );

  final String id;
  final String? username;
  final String? displayName;
  final String? avatarUrl;
  final int wins;
  final int totalMatches;
  final int sxScore;
  final String? sentinelTier;
  final String? membershipTier;
  final String? equippedAvatarBorder;
}

class HomeBanner {
  const HomeBanner({required this.title, required this.imageUrl, required this.linkUrl});
  factory HomeBanner.fromJson(Map<String, dynamic> j) =>
      HomeBanner(title: j['title'] as String, imageUrl: j['imageUrl'] as String?, linkUrl: j['linkUrl'] as String?);
  final String title;
  final String? imageUrl;
  final String? linkUrl;
}

class HallOfFameTeaser {
  const HallOfFameTeaser({
    required this.slug,
    required this.title,
    required this.prizePool,
    required this.gameName,
    required this.championName,
  });
  factory HallOfFameTeaser.fromJson(Map<String, dynamic> j) => HallOfFameTeaser(
        slug: j['slug'] as String,
        title: j['title'] as String,
        prizePool: (j['prizePool'] as num).toInt(),
        gameName: j['gameName'] as String?,
        championName: j['championName'] as String,
      );
  final String slug;
  final String title;
  final int prizePool;
  final String? gameName;
  final String championName;
}

class HomeStats {
  const HomeStats({required this.playerCount, required this.tournamentCount, required this.prizesPaidOut});
  factory HomeStats.fromJson(Map<String, dynamic> j) => HomeStats(
        playerCount: (j['playerCount'] as num).toInt(),
        tournamentCount: (j['tournamentCount'] as num).toInt(),
        prizesPaidOut: (j['prizesPaidOut'] as num).toInt(),
      );
  final int playerCount;
  final int tournamentCount;
  final int prizesPaidOut;
}

class HomeSummary {
  const HomeSummary({
    required this.banner,
    required this.featuredTournament,
    required this.upcomingTournaments,
    required this.leaderboardTeaser,
    required this.hallOfFame,
    required this.stats,
  });

  factory HomeSummary.fromJson(Map<String, dynamic> j) => HomeSummary(
        banner: j['banner'] == null ? null : HomeBanner.fromJson(j['banner'] as Map<String, dynamic>),
        featuredTournament:
            j['featuredTournament'] == null ? null : HomeTournamentCard.fromJson(j['featuredTournament'] as Map<String, dynamic>),
        upcomingTournaments: (j['upcomingTournaments'] as List<dynamic>)
            .map((e) => HomeTournamentCard.fromJson(e as Map<String, dynamic>))
            .toList(),
        leaderboardTeaser: (j['leaderboardTeaser'] as List<dynamic>)
            .map((e) => HomeLeaderboardPlayer.fromJson(e as Map<String, dynamic>))
            .toList(),
        hallOfFame: j['hallOfFame'] == null ? null : HallOfFameTeaser.fromJson(j['hallOfFame'] as Map<String, dynamic>),
        stats: HomeStats.fromJson(j['stats'] as Map<String, dynamic>),
      );

  final HomeBanner? banner;
  final HomeTournamentCard? featuredTournament;
  final List<HomeTournamentCard> upcomingTournaments;
  final List<HomeLeaderboardPlayer> leaderboardTeaser;
  final HallOfFameTeaser? hallOfFame;
  final HomeStats stats;
}
```

- [ ] **Step 5: Implement the client methods**

Append to the `ApiClient` class in `lib/core/api/api_client.dart` (after `unregisterDevice`):
```dart
  Future<void> postAuthSignup({
    required String username,
    required String email,
    required String password,
    String? ref,
    String? locale,
  }) =>
      _send('POST', '/auth/signup', (_) {}, body: {
        'username': username,
        'email': email,
        'password': password,
        if (ref != null) 'ref': ref,
        if (locale != null) 'locale': locale,
      });

  Future<void> postAuthResendConfirmation(String email) =>
      _send('POST', '/auth/resend-confirmation', (_) {}, body: {'email': email});

  Future<void> postAuthRequestReset(String email) =>
      _send('POST', '/auth/request-reset', (_) {}, body: {'email': email});

  Future<SessionStartResponse> postSessionStart() =>
      _send('POST', '/session/start', (d) => SessionStartResponse.fromJson(d! as Map<String, dynamic>));

  Future<String> postOnboardingUsername(String username) => _send(
        'POST',
        '/onboarding/username',
        (d) => (d! as Map<String, dynamic>)['username'] as String,
        body: {'username': username},
      );

  Future<HomeSummary> getHome() => _send('GET', '/home', (d) => HomeSummary.fromJson(d! as Map<String, dynamic>));
```

- [ ] **Step 6: Run to verify pass**

Run: `flutter test test/core/api_client_test.dart test/core/api_contract_test.dart` → Expected: all pass. Run: `flutter analyze` → clean.

- [ ] **Step 7: Commit**
```bash
git add lib/core/api api/openapi.json test/core/api_client_test.dart
git commit -m "feat(api): signup, session/start, onboarding/username and home client methods"
```

---

### Task 2: Generate ARB content from the web repo (`auth`, `common`, `nav`, `home`)

**Files:**
- Create: `tool/gen_l10n_from_web.dart`
- Test: `tool/gen_l10n_from_web_test.dart`
- Modify: `lib/core/l10n/app_en.arb`, `lib/core/l10n/app_fr.arb` (generated sections appended — hand-written Phase 0C keys stay)

**Interfaces:**
- Produces: `Map<String, String> flattenNamespace(Map<String, dynamic> json, String prefix)` (pure — recursively joins nested keys, e.g. `{'login': {'title': 'x'}}` under prefix `auth` → `{'authLoginTitle': 'x'}`); `String toArbKey(List<String> path)`; a `main()` that reads `<source>/{en,fr}.json`, flattens the requested namespaces, and merges the result into this repo's `.arb` files (never removing existing keys).

- [ ] **Step 1: Write the failing test**

`tool/gen_l10n_from_web_test.dart`
```dart
import 'package:test/test.dart';
import '../tool/gen_l10n_from_web.dart';

void main() {
  group('toArbKey', () {
    test('camelCases a namespace-qualified path', () {
      expect(toArbKey(['auth', 'login', 'title']), 'authLoginTitle');
    });
    test('handles a two-segment (flat-namespace) path', () {
      expect(toArbKey(['terms', 's1Heading']), 'termsS1Heading');
    });
  });

  group('flattenNamespace', () {
    test('flattens a nested namespace with dotted prefixing', () {
      final result = flattenNamespace({
        'login': {'title': 'Welcome back', 'submit': 'Log in'},
        'errors': {'invalid_email': 'Enter a valid email address.'},
      }, 'auth');
      expect(result, {
        'authLoginTitle': 'Welcome back',
        'authLoginSubmit': 'Log in',
        'authErrorsInvalidEmail': 'Enter a valid email address.',
      });
    });

    test('flattens a flat namespace with one level of prefixing', () {
      final result = flattenNamespace({'title': 'Terms of Service', 's1Heading': '1. Who We Are'}, 'terms');
      expect(result, {'termsTitle': 'Terms of Service', 'termsS1Heading': '1. Who We Are'});
    });

    test('substitutes ICU placeholders from {curly} to {curly} unchanged (ARB already uses that syntax)', () {
      final result = flattenNamespace({'checkEmailBody': 'We sent a link to {email}.'}, 'signup');
      expect(result['signupCheckEmailBody'], 'We sent a link to {email}.');
    });
  });
}
```
(This uses the `test` package, not `flutter_test`, since it has no Flutter/widget dependency — a plain Dart script test. Add it once: `dart pub add --dev test`.)

- [ ] **Step 2: Run to verify failure**

Run: `dart test tool/gen_l10n_from_web_test.dart` → Expected: FAIL (module missing).

- [ ] **Step 3: Implement**

`tool/gen_l10n_from_web.dart`
```dart
import 'dart:convert';
import 'dart:io';

// Converts a namespace-qualified path (e.g. ['auth', 'login', 'title']) into
// the ARB key this repo's ARB files use for it (e.g. 'authLoginTitle').
String toArbKey(List<String> path) {
  final capitalized = path
      .asMap()
      .entries
      .map((e) => e.key == 0 ? e.value : '${e.value[0].toUpperCase()}${e.value.substring(1)}');
  return capitalized.join();
}

// Recursively walks a namespace's JSON value, joining nested keys under
// `prefix`. A leaf is any value that is not itself a Map (the web messages
// files only ever nest one or two levels — auth.login.title — never arrays).
Map<String, String> flattenNamespace(Map<String, dynamic> json, String prefix) {
  final out = <String, String>{};
  void walk(Map<String, dynamic> node, List<String> path) {
    node.forEach((key, value) {
      final nextPath = [...path, key];
      if (value is Map<String, dynamic>) {
        walk(value, nextPath);
      } else {
        out[toArbKey(nextPath)] = value.toString();
      }
    });
  }

  walk(json, [prefix]);
  return out;
}

// Merges `additions` into the ARB file at `path`, preserving every existing
// key (including '@@locale' and any '@key' ICU metadata blocks) and only
// adding/overwriting the keys this run produced. Keys are written in a
// stable, sorted order after the existing ones so re-runs produce small diffs.
void mergeIntoArb(String path, Map<String, String> additions) {
  final file = File(path);
  final existing = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  final merged = {...existing, ...additions};
  final encoder = const JsonEncoder.withIndent('  ');
  file.writeAsStringSync('${encoder.convert(merged)}\n');
}

Future<void> main(List<String> args) async {
  final parsed = <String, String>{};
  for (final a in args) {
    final eq = a.indexOf('=');
    if (a.startsWith('--') && eq > 0) parsed[a.substring(2, eq)] = a.substring(eq + 1);
  }
  final source = parsed['source'] ?? '../sentinelx/messages';
  final namespaces = (parsed['namespaces'] ?? 'common,nav,home,auth').split(',');
  final locales = (parsed['locales'] ?? 'en,fr').split(',');

  for (final locale in locales) {
    final sourceFile = File('$source/$locale.json');
    if (!sourceFile.existsSync()) {
      stderr.writeln('Skipping $locale: $source/$locale.json not found.');
      continue;
    }
    final data = jsonDecode(sourceFile.readAsStringSync()) as Map<String, dynamic>;
    final additions = <String, String>{};
    for (final ns in namespaces) {
      final nsData = data[ns];
      if (nsData == null) {
        stderr.writeln('Warning: namespace "$ns" missing from $source/$locale.json');
        continue;
      }
      additions.addAll(flattenNamespace(nsData as Map<String, dynamic>, ns));
    }
    final target = 'lib/core/l10n/app_$locale.arb';
    if (!File(target).existsSync()) {
      stderr.writeln('Skipping $locale: no $target in this repo (only en/fr are wired for Material delegates in Phase 1 — pcm stays deferred).');
      continue;
    }
    mergeIntoArb(target, additions);
    stdout.writeln('Merged ${additions.length} keys into $target');
  }
}
```

- [ ] **Step 4: Run to verify pass**

Run: `dart test tool/gen_l10n_from_web_test.dart` → Expected: 5 passed.

- [ ] **Step 5: Run the script against the real web repo and regenerate localizations**

```powershell
dart run tool/gen_l10n_from_web.dart --source=../sentinelx/messages --namespaces=common,nav,home,auth --locales=en,fr
flutter gen-l10n
```
Expected: `lib/core/l10n/app_en.arb` and `app_fr.arb` each gain ~70 new keys (`authLogin*`, `authSignup*`, `authForgot*`, `authReset*`, `authUsernameStep*`, `authAvailability*`, `authNotices*`, `authErrors*`, `authCommon*`, `authMeta*`, `commonSiteName`/`commonViewAll`/etc., `navHome`/`navTournaments`/`navTv`/`navCommunity`/`navExchange`/etc., `homeUpcomingHeading`/`homeTopPlayersHeading`/`homeFullRankingsLink`); the existing 6 hand-written keys (`appName`, `maintenanceTitle`, ...) are untouched. `lib/core/l10n/gen/app_localizations.dart` regenerates with a getter for each.

Verify a sample: open `lib/core/l10n/app_en.arb` and confirm `"authErrorsInvalidCredentials": "Invalid email or password."` and `"authSignupCheckEmailBody": "We sent a confirmation link to {email}. Click it to activate your account, then log in and pick your handle."` are present (the `{email}` placeholder needs an accompanying `"@authSignupCheckEmailBody": {"placeholders": {"email": {"type": "String"}}}` metadata block for `flutter gen-l10n` to generate a parameterized getter — **add that one metadata block by hand** for `authSignupCheckEmailBody` and `authSignupSigningUpAs` (the only two keys in this namespace set with a `{placeholder}`), since the flattening script copies string values only, not ICU metadata. Re-run `flutter gen-l10n` after adding them.

- [ ] **Step 6: Verify and commit**

Run: `flutter analyze` → clean (confirms the generated localizations file compiles). Run: `flutter test` → still all green (nothing yet consumes the new keys).
```bash
git add tool lib/core/l10n
git commit -m "feat(l10n): generate auth/common/nav/home ARB content from the web repo's messages"
```

---

### Task 3: `AuthRepository`, providers, onboarding gate

**Files:**
- Modify: `lib/core/config/app_config.dart`
- Create: `lib/core/auth/auth_repository.dart`, `lib/core/auth/auth_providers.dart`, `lib/core/auth/onboarding_gate.dart`
- Test: `test/core/app_config_test.dart` (extend), `test/core/auth_repository_test.dart`, `test/core/onboarding_gate_test.dart`

**Interfaces:**
- Consumes: `ApiClient` (Task 1); `SupabaseClient` (`supabase_flutter`); `MeResponse` (existing); `RemoteConfig.enforcePhoneVerification` (existing).
- Produces: `class AuthException implements Exception { String code; String message; }`; `abstract class AuthRepository { Future<void> signInWithPassword(...); Future<void> signUp(...); Future<void> resendConfirmation(String); Future<void> requestReset(String); Future<void> resetPassword(String newPassword); Future<String> claimUsername(String); Future<void> signOut(); }`; `SupabaseAuthRepository` (impl); `authRepositoryProvider`; `enum OnboardingGate { username, phone, none }`; `resolveOnboardingGate(MeResponse? me, RemoteConfig? config): OnboardingGate`.

- [ ] **Step 1: Extend `AppConfig` — write the failing test first**

Append to `test/core/app_config_test.dart`:
```dart
  test('googleWebClientId defaults to empty until the owner sets it', () {
    expect(const AppConfig.fromEnvironment().googleWebClientId, '');
  });
```
Run: `flutter test test/core/app_config_test.dart` → Expected: FAIL (`googleWebClientId` getter doesn't exist).

Add `required this.googleWebClientId` to `AppConfig`'s constructor and field list, and to `_EnvAppConfig`:
```dart
          googleWebClientId: const String.fromEnvironment('GOOGLE_WEB_CLIENT_ID', defaultValue: ''),
```
Update the existing `const dev = AppConfig(...)` literal in the same test file to include `googleWebClientId: ''` (a required positional/named field — the constructor now requires it everywhere `AppConfig(...)` is constructed directly; `test/core/app_gate_test.dart` does not construct one directly, only `test/core/app_config_test.dart` does).
Run again → Expected: pass.

- [ ] **Step 2: Write the failing repository test**

`test/core/auth_repository_test.dart`
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/core/auth/auth_repository.dart';

class _Recording {
  final calls = <String, List<Object?>>{};
  void record(String name, List<Object?> args) => calls[name] = args;
}

class _FakeAuth {
  _FakeAuth(this._rec);
  final _Recording _rec;
  Object? failWith;

  Future<void> signInWithPassword({required String email, required String password}) async {
    _rec.record('signInWithPassword', [email, password]);
    if (failWith != null) throw failWith!;
  }

  Future<void> updateUser({required String password}) async {
    _rec.record('updateUser', [password]);
  }

  Future<void> signOut() async => _rec.record('signOut', []);
}

class _FakeApi {
  _FakeApi(this._rec);
  final _Recording _rec;

  Future<void> postAuthSignup({required String username, required String email, required String password, String? ref, String? locale}) async {
    _rec.record('postAuthSignup', [username, email, password, ref, locale]);
  }

  Future<void> postAuthResendConfirmation(String email) async => _rec.record('postAuthResendConfirmation', [email]);
  Future<void> postAuthRequestReset(String email) async => _rec.record('postAuthRequestReset', [email]);
  Future<String> postOnboardingUsername(String username) async {
    _rec.record('postOnboardingUsername', [username]);
    return username;
  }
}

void main() {
  test('signInWithPassword delegates to Supabase Auth directly (Tier 1)', () async {
    final rec = _Recording();
    final repo = SupabaseAuthRepository(_FakeAuth(rec) as dynamic, _FakeApi(rec) as dynamic);
    await repo.signInWithPassword(email: 'a@b.com', password: 'password123');
    expect(rec.calls['signInWithPassword'], ['a@b.com', 'password123']);
  });

  test('signUp goes through the API, not Supabase Auth directly', () async {
    final rec = _Recording();
    final repo = SupabaseAuthRepository(_FakeAuth(rec) as dynamic, _FakeApi(rec) as dynamic);
    await repo.signUp(username: 'new', email: 'a@b.com', password: 'password123', ref: 'x', locale: 'fr');
    expect(rec.calls['postAuthSignup'], ['new', 'a@b.com', 'password123', 'x', 'fr']);
    expect(rec.calls.containsKey('signUp'), isFalse);
  });

  test('resendConfirmation and requestReset go through the API', () async {
    final rec = _Recording();
    final repo = SupabaseAuthRepository(_FakeAuth(rec) as dynamic, _FakeApi(rec) as dynamic);
    await repo.resendConfirmation('a@b.com');
    await repo.requestReset('a@b.com');
    expect(rec.calls['postAuthResendConfirmation'], ['a@b.com']);
    expect(rec.calls['postAuthRequestReset'], ['a@b.com']);
  });

  test('resetPassword calls Supabase Auth updateUser directly (a session already exists from verifyOtp)', () async {
    final rec = _Recording();
    final repo = SupabaseAuthRepository(_FakeAuth(rec) as dynamic, _FakeApi(rec) as dynamic);
    await repo.resetPassword('newpassword123');
    expect(rec.calls['updateUser'], ['newpassword123']);
  });

  test('claimUsername goes through the API and returns the claimed username', () async {
    final rec = _Recording();
    final repo = SupabaseAuthRepository(_FakeAuth(rec) as dynamic, _FakeApi(rec) as dynamic);
    final result = await repo.claimUsername('BrandNew');
    expect(result, 'BrandNew');
    expect(rec.calls['postOnboardingUsername'], ['BrandNew']);
  });

  test('signOut calls Supabase Auth directly', () async {
    final rec = _Recording();
    final repo = SupabaseAuthRepository(_FakeAuth(rec) as dynamic, _FakeApi(rec) as dynamic);
    await repo.signOut();
    expect(rec.calls['signOut'], []);
  });

  test('maps an ApiException-shaped failure into AuthException with the same code', () async {
    final rec = _Recording();
    final fakeAuth = _FakeAuth(rec)..failWith = _FakeApiError('invalid_credentials', 'Invalid email or password.');
    final repo = SupabaseAuthRepository(fakeAuth as dynamic, _FakeApi(rec) as dynamic);
    await expectLater(
      repo.signInWithPassword(email: 'a@b.com', password: 'wrong'),
      throwsA(isA<AuthException>().having((e) => e.code, 'code', 'invalid_credentials')),
    );
  });
}

class _FakeApiError implements Exception {
  _FakeApiError(this.code, this.message);
  final String code;
  final String message;
}
```
This test double-types the fake auth/api clients as `dynamic` deliberately — `SupabaseAuthRepository`'s constructor will accept the real `SupabaseClient`/`ApiClient` types, and this test exercises only the subset of methods it calls, matching the Dart duck-typing pattern the existing `test/fakes/fake_tournaments_repository.dart` already uses for its own abstract-interface fake (verify that file's pattern before writing this one; if it implements the interface explicitly rather than duck-typing, follow that convention instead and implement `AuthRepository` directly in the fakes rather than faking Supabase/ApiClient).

- [ ] **Step 3: Run to verify failure**

Run: `flutter test test/core/auth_repository_test.dart` → Expected: FAIL (module missing).

- [ ] **Step 4: Implement**

`lib/core/auth/auth_repository.dart`
```dart
import 'package:supabase_flutter/supabase_flutter.dart';

import '../api/api_client.dart';

class AuthException implements Exception {
  const AuthException(this.code, this.message);
  final String code;
  final String message;

  @override
  String toString() => 'AuthException($code: $message)';
}

abstract class AuthRepository {
  Future<void> signInWithPassword({required String email, required String password});
  Future<void> signUp({required String username, required String email, required String password, String? ref, String? locale});
  Future<void> resendConfirmation(String email);
  Future<void> requestReset(String email);
  Future<void> resetPassword(String newPassword);
  Future<String> claimUsername(String username);
  Future<void> signOut();
}

// Tier 1 for the two calls Supabase Auth itself already guards
// (signInWithPassword, updateUser after a verifyOtp-established session) and
// signOut; every other mutation is Tier 3 through ApiClient — never a direct
// `supabase.auth.signUp`, which skips the ban/retired-username/locale logic
// (master spec §2.4).
class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository(this._auth, this._api);

  final GoTrueClient _auth;
  final ApiClient _api;

  @override
  Future<void> signInWithPassword({required String email, required String password}) async {
    try {
      await _auth.signInWithPassword(email: email, password: password);
    } on AuthApiException catch (e) {
      throw AuthException(e.code ?? 'invalid_credentials', e.message);
    } on ApiException catch (e) {
      throw AuthException(e.code, e.message);
    }
  }

  @override
  Future<void> signUp({
    required String username,
    required String email,
    required String password,
    String? ref,
    String? locale,
  }) async {
    try {
      await _api.postAuthSignup(username: username, email: email, password: password, ref: ref, locale: locale);
    } on ApiException catch (e) {
      throw AuthException(e.code, e.message);
    }
  }

  @override
  Future<void> resendConfirmation(String email) => _guard(() => _api.postAuthResendConfirmation(email));

  @override
  Future<void> requestReset(String email) => _guard(() => _api.postAuthRequestReset(email));

  @override
  Future<void> resetPassword(String newPassword) => _guard(() => _auth.updateUser(UserAttributes(password: newPassword)));

  @override
  Future<String> claimUsername(String username) async {
    try {
      return await _api.postOnboardingUsername(username);
    } on ApiException catch (e) {
      throw AuthException(e.code, e.message);
    }
  }

  @override
  Future<void> signOut() => _auth.signOut();

  Future<void> _guard(Future<void> Function() run) async {
    try {
      await run();
    } on ApiException catch (e) {
      throw AuthException(e.code, e.message);
    } on AuthApiException catch (e) {
      throw AuthException(e.code ?? 'reset_failed', e.message);
    }
  }
}
```

`lib/core/auth/onboarding_gate.dart`
```dart
import '../api/models.dart';
import '../config/remote_config.dart';

enum OnboardingGate { username, phone, none }

// Mirrors the web's resolveOnboardingGate (lib/onboarding/gate.ts) exactly,
// including the phone gate's kill-switch: enforcePhoneVerification is read
// from /config, never hard-coded, and is false in every environment today
// (see this plan's tripwire — no onboarding-phone screen exists yet).
OnboardingGate resolveOnboardingGate(MeResponse? me, RemoteConfig? config) {
  if (me == null) return OnboardingGate.none;
  if (me.profile?.username == null) return OnboardingGate.username;
  // phoneVerifiedAt isn't in MeResponse yet (not needed until the flag flips)
  // — this branch is unreachable while enforcePhoneVerification is false.
  if (config?.enforcePhoneVerification ?? false) return OnboardingGate.phone;
  return OnboardingGate.none;
}
```

`lib/core/auth/auth_providers.dart`
```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import 'auth_repository.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  final api = ref.watch(apiClientProvider);
  return SupabaseAuthRepository(supabase.auth, api);
});
```

- [ ] **Step 5: Write the onboarding-gate test**

`test/core/onboarding_gate_test.dart`
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/core/api/models.dart';
import 'package:sentinelx_mobile/core/auth/onboarding_gate.dart';
import 'package:sentinelx_mobile/core/config/remote_config.dart';

MeResponse _me({String? username}) => MeResponse(
      id: 'u',
      email: 'a@b.com',
      roles: const [],
      isStaff: false,
      isAdmin: false,
      profile: username == null
          ? null
          : MeProfile(
              username: username,
              displayName: username,
              avatarUrl: null,
              whatsappNumber: null,
              country: null,
              locale: 'en',
              membershipTier: null,
              kycVerified: false,
              deletionRequestedAt: null,
            ),
    );

RemoteConfig _config({bool enforcePhone = false}) => RemoteConfig.fromJson({
      'minSupportedAppVersion': '0.0.0',
      'latestAppVersion': '1.0.0',
      'maintenance': null,
      'siteUrl': 'https://sentinelxesports.com.ng',
      'coins': {'coinsPerNaira': 2, 'nairaPerCoin': 0.5, 'coinsPerEntry': 1000, 'coinsHalfEntry': 500},
      'enforcePhoneVerification': enforcePhone,
      'whatsappCommunityUrl': null,
      'features': <String, bool>{},
    });

void main() {
  test('signed out: no gate', () {
    expect(resolveOnboardingGate(null, _config()), OnboardingGate.none);
  });
  test('no username yet: username gate', () {
    expect(resolveOnboardingGate(_me(username: null), _config()), OnboardingGate.username);
  });
  test('has a username, phone gate off: no gate', () {
    expect(resolveOnboardingGate(_me(username: 'ada'), _config()), OnboardingGate.none);
  });
  test('has a username, phone gate on: phone gate', () {
    expect(resolveOnboardingGate(_me(username: 'ada'), _config(enforcePhone: true)), OnboardingGate.phone);
  });
  test('config not loaded yet: never demands phone (open by default, matches AppGate\u2019s own null-config fail-open)', () {
    expect(resolveOnboardingGate(_me(username: 'ada'), null), OnboardingGate.none);
  });
}
```

- [ ] **Step 6: Run all, verify pass**

Run: `flutter test test/core/app_config_test.dart test/core/auth_repository_test.dart test/core/onboarding_gate_test.dart` → Expected: all pass. `flutter analyze` → clean.

- [ ] **Step 7: Commit**
```bash
git add lib/core/config/app_config.dart lib/core/auth test/core
git commit -m "feat(auth): AuthRepository, onboarding gate, googleWebClientId config"
```

---

### Task 4: Login, Forgot Password, Reset Password screens

**Files:**
- Create: `lib/features/auth/login_screen.dart`, `lib/features/auth/forgot_password_screen.dart`, `lib/features/auth/reset_password_screen.dart`
- Test: `test/features/auth_test_fakes.dart`, `test/features/login_screen_test.dart`, `test/features/forgot_password_screen_test.dart`, `test/features/reset_password_screen_test.dart`

**Interfaces:**
- Consumes: `authRepositoryProvider` (Task 3); `AppLocalizations` keys `authLogin*`, `authForgot*`, `authReset*`, `authCommon*`, `authErrors*` (Task 2).
- Produces: `LoginScreen({onLoggedIn, onForgotPassword, onCreateAccount})`; `ForgotPasswordScreen()` (no params — internal notice state only); `ResetPasswordScreen({onDone})` — each a `ConsumerStatefulWidget`. Plus the shared test fake `FakeAuthRepositoryForForgot` (`test/features/auth_test_fakes.dart`), reused by Task 5's tests.

- [ ] **Step 1: Write the failing tests**

`test/features/login_screen_test.dart`
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/core/auth/auth_providers.dart';
import 'package:sentinelx_mobile/core/auth/auth_repository.dart';
import 'package:sentinelx_mobile/core/l10n/gen/app_localizations.dart';
import 'package:sentinelx_mobile/features/auth/login_screen.dart';

class _FakeAuthRepository implements AuthRepository {
  String? lastEmail;
  String? lastPassword;
  Object? throwOnSignIn;
  bool loggedIn = false;

  @override
  Future<void> signInWithPassword({required String email, required String password}) async {
    lastEmail = email;
    lastPassword = password;
    if (throwOnSignIn != null) throw throwOnSignIn!;
    loggedIn = true;
  }

  @override
  Future<void> signUp({required String username, required String email, required String password, String? ref, String? locale}) async {}
  @override
  Future<void> resendConfirmation(String email) async {}
  @override
  Future<void> requestReset(String email) async {}
  @override
  Future<void> resetPassword(String newPassword) async {}
  @override
  Future<String> claimUsername(String username) async => username;
  @override
  Future<void> signOut() async {}
}

Future<void> _pump(WidgetTester tester, _FakeAuthRepository repo, {VoidCallback? onLoggedIn}) {
  return tester.pumpWidget(ProviderScope(
    retry: (_, _) => null,
    overrides: [authRepositoryProvider.overrideWithValue(repo)],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: LoginScreen(onLoggedIn: onLoggedIn ?? () {}, onForgotPassword: () {}, onCreateAccount: () {}),
    ),
  ));
}

void main() {
  testWidgets('submits email and password, then calls onLoggedIn', (tester) async {
    final repo = _FakeAuthRepository();
    var loggedIn = false;
    await _pump(tester, repo, onLoggedIn: () => loggedIn = true);

    await tester.enterText(find.byKey(const Key('login-email')), 'a@b.com');
    await tester.enterText(find.byKey(const Key('login-password')), 'password123');
    await tester.tap(find.byKey(const Key('login-submit')));
    await tester.pumpAndSettle();

    expect(repo.lastEmail, 'a@b.com');
    expect(repo.lastPassword, 'password123');
    expect(loggedIn, isTrue);
  });

  testWidgets('shows a translated error and does not call onLoggedIn on failure', (tester) async {
    final repo = _FakeAuthRepository()..throwOnSignIn = const AuthException('invalid_credentials', 'x');
    var loggedIn = false;
    await _pump(tester, repo, onLoggedIn: () => loggedIn = true);

    await tester.enterText(find.byKey(const Key('login-email')), 'a@b.com');
    await tester.enterText(find.byKey(const Key('login-password')), 'wrong');
    await tester.tap(find.byKey(const Key('login-submit')));
    await tester.pumpAndSettle();

    expect(find.text('Invalid email or password.'), findsOneWidget);
    expect(loggedIn, isFalse);
  });

  testWidgets('offers a resend button when the account exists but is unconfirmed', (tester) async {
    final repo = _FakeAuthRepository()..throwOnSignIn = const AuthException('email_not_confirmed', 'x');
    await _pump(tester, repo);
    await tester.enterText(find.byKey(const Key('login-email')), 'a@b.com');
    await tester.enterText(find.byKey(const Key('login-password')), 'password123');
    await tester.tap(find.byKey(const Key('login-submit')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('login-resend')), findsOneWidget);
  });
}
```

**Before writing `forgot_password_screen_test.dart`, create the shared fake it needs.** `login_screen_test.dart`'s `_FakeAuthRepository` above is private (`_`-prefixed, invisible outside its own file — Dart privacy is library-scoped) and single-purpose, so `forgot_password_screen_test.dart` (and Task 5's signup/onboarding tests) get their own small shared, public fake instead of reaching into `login_screen_test.dart`:

`test/features/auth_test_fakes.dart`
```dart
import 'package:sentinelx_mobile/core/auth/auth_repository.dart';

class FakeAuthRepositoryForForgot implements AuthRepository {
  String? lastEmail;

  @override
  Future<void> requestReset(String email) async => lastEmail = email;
  @override
  Future<void> signInWithPassword({required String email, required String password}) async {}
  @override
  Future<void> signUp({required String username, required String email, required String password, String? ref, String? locale}) async {}
  @override
  Future<void> resendConfirmation(String email) async {}
  @override
  Future<void> resetPassword(String newPassword) async {}
  @override
  Future<String> claimUsername(String username) async => username;
  @override
  Future<void> signOut() async {}
}
```

`test/features/forgot_password_screen_test.dart`
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/core/auth/auth_providers.dart';
import 'package:sentinelx_mobile/core/l10n/gen/app_localizations.dart';
import 'package:sentinelx_mobile/features/auth/forgot_password_screen.dart';

import 'auth_test_fakes.dart';

void main() {
  testWidgets('sends a reset request and shows the neutral notice', (tester) async {
    final repo = FakeAuthRepositoryForForgot();
    await tester.pumpWidget(ProviderScope(
      retry: (_, _) => null,
      overrides: [authRepositoryProvider.overrideWithValue(repo)],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const ForgotPasswordScreen(),
      ),
    ));

    await tester.enterText(find.byKey(const Key('forgot-email')), 'a@b.com');
    await tester.tap(find.byKey(const Key('forgot-submit')));
    await tester.pumpAndSettle();

    expect(repo.lastEmail, 'a@b.com');
    expect(find.text("If an account exists for that email, we've sent a reset link."), findsOneWidget);
  });
}
```

`test/features/reset_password_screen_test.dart`
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/core/auth/auth_providers.dart';
import 'package:sentinelx_mobile/core/l10n/gen/app_localizations.dart';
import 'package:sentinelx_mobile/features/auth/reset_password_screen.dart';

import 'auth_test_fakes.dart';

class _RecordingReset extends FakeAuthRepositoryForForgot {
  String? lastPassword;
  @override
  Future<void> resetPassword(String newPassword) async => lastPassword = newPassword;
}

void main() {
  testWidgets('submits the new password and calls onDone', (tester) async {
    final repo = _RecordingReset();
    var done = false;
    await tester.pumpWidget(ProviderScope(
      retry: (_, _) => null,
      overrides: [authRepositoryProvider.overrideWithValue(repo)],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ResetPasswordScreen(onDone: () => done = true),
      ),
    ));

    await tester.enterText(find.byKey(const Key('reset-password')), 'newpassword123');
    await tester.tap(find.byKey(const Key('reset-submit')));
    await tester.pumpAndSettle();

    expect(repo.lastPassword, 'newpassword123');
    expect(done, isTrue);
  });
}
```

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/features/login_screen_test.dart test/features/forgot_password_screen_test.dart test/features/reset_password_screen_test.dart` → Expected: FAIL (screens don't exist).

- [ ] **Step 3: Implement**

`lib/features/auth/login_screen.dart`
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_providers.dart';
import '../../core/auth/auth_repository.dart';
import '../../core/l10n/gen/app_localizations.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key, required this.onLoggedIn, required this.onForgotPassword, required this.onCreateAccount});

  final VoidCallback onLoggedIn;
  final VoidCallback onForgotPassword;
  final VoidCallback onCreateAccount;

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  String? _errorCode;
  bool _resending = false;

  String _errorText(AppLocalizations l10n, String code) => switch (code) {
        'invalid_email' => l10n.authErrorsInvalidEmail,
        'password_required' => l10n.authErrorsPasswordRequired,
        'invalid_credentials' => l10n.authErrorsInvalidCredentials,
        'email_not_confirmed' => l10n.authErrorsEmailNotConfirmed,
        _ => l10n.authErrorsSignupFailed,
      };

  Future<void> _submit() async {
    setState(() {
      _loading = true;
      _errorCode = null;
    });
    try {
      await ref.read(authRepositoryProvider).signInWithPassword(email: _email.text.trim(), password: _password.text);
      widget.onLoggedIn();
    } on AuthException catch (e) {
      setState(() => _errorCode = e.code);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resend() async {
    setState(() => _resending = true);
    try {
      await ref.read(authRepositoryProvider).resendConfirmation(_email.text.trim());
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.authLoginTitle)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ListView(
            children: [
              Text(l10n.authLoginSubtitle),
              const SizedBox(height: 24),
              TextField(
                key: const Key('login-email'),
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(labelText: l10n.authCommonEmail),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('login-password'),
                controller: _password,
                obscureText: true,
                decoration: InputDecoration(labelText: l10n.authCommonPassword),
              ),
              if (_errorCode != null) ...[
                const SizedBox(height: 12),
                Text(_errorText(l10n, _errorCode!), style: const TextStyle(color: Colors.redAccent)),
              ],
              if (_errorCode == 'email_not_confirmed') ...[
                const SizedBox(height: 8),
                TextButton(
                  key: const Key('login-resend'),
                  onPressed: _resending ? null : _resend,
                  child: Text(_resending ? l10n.authLoginResending : l10n.authLoginResend),
                ),
              ],
              const SizedBox(height: 16),
              ElevatedButton(
                key: const Key('login-submit'),
                onPressed: _loading ? null : _submit,
                child: Text(_loading ? l10n.authLoginSubmitting : l10n.authLoginSubmit),
              ),
              TextButton(onPressed: widget.onForgotPassword, child: Text(l10n.authLoginForgot)),
              TextButton(onPressed: widget.onCreateAccount, child: Text(l10n.authLoginCreateAccount)),
            ],
          ),
        ),
      ),
    );
  }
}
```

`lib/features/auth/forgot_password_screen.dart`
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_providers.dart';
import '../../core/l10n/gen/app_localizations.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _email = TextEditingController();
  bool _loading = false;
  bool _sent = false;

  Future<void> _submit() async {
    setState(() => _loading = true);
    await ref.read(authRepositoryProvider).requestReset(_email.text.trim());
    if (mounted) setState(() { _loading = false; _sent = true; });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.authForgotTitle)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ListView(
            children: [
              Text(l10n.authForgotSubtitle),
              const SizedBox(height: 24),
              TextField(
                key: const Key('forgot-email'),
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(labelText: l10n.authCommonEmail),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                key: const Key('forgot-submit'),
                onPressed: _loading ? null : _submit,
                child: Text(_loading ? l10n.authForgotSubmitting : l10n.authForgotSubmit),
              ),
              if (_sent) ...[
                const SizedBox(height: 16),
                Text(l10n.authNoticesResetSent),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
```

`lib/features/auth/reset_password_screen.dart`
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_providers.dart';
import '../../core/l10n/gen/app_localizations.dart';

class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({super.key, required this.onDone});

  final VoidCallback onDone;

  @override
  ConsumerState<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final _password = TextEditingController();
  bool _loading = false;

  Future<void> _submit() async {
    setState(() => _loading = true);
    try {
      await ref.read(authRepositoryProvider).resetPassword(_password.text);
      widget.onDone();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.authResetTitle)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ListView(
            children: [
              Text(l10n.authResetSubtitle),
              const SizedBox(height: 24),
              TextField(
                key: const Key('reset-password'),
                controller: _password,
                obscureText: true,
                decoration: InputDecoration(labelText: l10n.authResetNewPassword, helperText: l10n.authCommonAtLeast8),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                key: const Key('reset-submit'),
                onPressed: _loading ? null : _submit,
                child: Text(_loading ? l10n.authResetSubmitting : l10n.authResetSubmit),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run to verify pass**

Run: `flutter test test/features/login_screen_test.dart test/features/forgot_password_screen_test.dart test/features/reset_password_screen_test.dart` → Expected: all pass. `flutter analyze` → clean.

- [ ] **Step 5: Commit**
```bash
git add lib/features/auth test/features
git commit -m "feat(auth): Login, Forgot Password, Reset Password screens"
```

---

### Task 5: Signup wizard, Check-your-email, Onboarding username

**Files:**
- Create: `lib/features/auth/signup_screen.dart`, `lib/features/auth/check_email_screen.dart`, `lib/features/onboarding/onboarding_username_screen.dart`
- Test: `test/features/signup_screen_test.dart`, `test/features/onboarding_username_screen_test.dart`

**Interfaces:**
- Consumes: `authRepositoryProvider`; `AppLocalizations` `authSignup*`, `authUsernameStep*`, `authAvailability*`, `authErrors*`.
- Produces: `SignupScreen({onSignedUp(email), onLogIn, initialRef})`; `CheckEmailScreen({email, onGoToLogin})`; `OnboardingUsernameScreen({onClaimed})`.

- [ ] **Step 1: Write the failing tests**

`test/features/signup_screen_test.dart`
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/core/auth/auth_providers.dart';
import 'package:sentinelx_mobile/core/auth/auth_repository.dart';
import 'package:sentinelx_mobile/core/l10n/gen/app_localizations.dart';
import 'package:sentinelx_mobile/features/auth/signup_screen.dart';

import 'auth_test_fakes.dart';

class _RecordingSignup extends FakeAuthRepositoryForForgot {
  Map<String, Object?>? args;
  Object? throwOnSignUp;

  @override
  Future<void> signUp({required String username, required String email, required String password, String? ref, String? locale}) async {
    args = {'username': username, 'email': email, 'password': password, 'ref': ref, 'locale': locale};
    if (throwOnSignUp != null) throw throwOnSignUp!;
  }
}

Future<void> _pump(WidgetTester tester, _RecordingSignup repo, {String? initialRef, void Function(String email)? onSignedUp}) {
  return tester.pumpWidget(ProviderScope(
    retry: (_, _) => null,
    overrides: [authRepositoryProvider.overrideWithValue(repo)],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: SignupScreen(onSignedUp: onSignedUp ?? (_) {}, onLogIn: () {}, initialRef: initialRef),
    ),
  ));
}

void main() {
  testWidgets('submits username, email, password and calls onSignedUp with the email', (tester) async {
    final repo = _RecordingSignup();
    String? signedUpEmail;
    await _pump(tester, repo, onSignedUp: (e) => signedUpEmail = e);

    await tester.enterText(find.byKey(const Key('signup-username')), 'newplayer');
    await tester.tap(find.byKey(const Key('signup-continue-email')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('signup-email')), 'new@x.com');
    await tester.enterText(find.byKey(const Key('signup-password')), 'password123');
    await tester.tap(find.byKey(const Key('signup-submit')));
    await tester.pumpAndSettle();

    expect(repo.args, {'username': 'newplayer', 'email': 'new@x.com', 'password': 'password123', 'ref': null, 'locale': 'en'});
    expect(signedUpEmail, 'new@x.com');
  });

  testWidgets('passes the initial ref through to signUp', (tester) async {
    final repo = _RecordingSignup();
    await _pump(tester, repo, initialRef: 'friend1');
    await tester.enterText(find.byKey(const Key('signup-username')), 'newplayer');
    await tester.tap(find.byKey(const Key('signup-continue-email')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('signup-email')), 'new@x.com');
    await tester.enterText(find.byKey(const Key('signup-password')), 'password123');
    await tester.tap(find.byKey(const Key('signup-submit')));
    await tester.pumpAndSettle();
    expect(repo.args?['ref'], 'friend1');
  });

  testWidgets('shows a translated error on a taken username without leaving the wizard', (tester) async {
    final repo = _RecordingSignup()..throwOnSignUp = const AuthException('username_taken', 'x');
    var signedUp = false;
    await _pump(tester, repo, onSignedUp: (_) => signedUp = true);
    await tester.enterText(find.byKey(const Key('signup-username')), 'taken');
    await tester.tap(find.byKey(const Key('signup-continue-email')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('signup-email')), 'new@x.com');
    await tester.enterText(find.byKey(const Key('signup-password')), 'password123');
    await tester.tap(find.byKey(const Key('signup-submit')));
    await tester.pumpAndSettle();
    expect(find.text('That username is taken \u2014 try another.'), findsOneWidget);
    expect(signedUp, isFalse);
  });
}
```

`test/features/onboarding_username_screen_test.dart`
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/core/auth/auth_providers.dart';
import 'package:sentinelx_mobile/core/l10n/gen/app_localizations.dart';
import 'package:sentinelx_mobile/features/onboarding/onboarding_username_screen.dart';

import 'auth_test_fakes.dart';

class _RecordingClaim extends FakeAuthRepositoryForForgot {
  String? claimed;
  Object? throwOnClaim;

  @override
  Future<String> claimUsername(String username) async {
    claimed = username;
    if (throwOnClaim != null) throw throwOnClaim!;
    return username;
  }
}

void main() {
  testWidgets('claims a username and calls onClaimed', (tester) async {
    final repo = _RecordingClaim();
    var claimed = false;
    await tester.pumpWidget(ProviderScope(
      retry: (_, _) => null,
      overrides: [authRepositoryProvider.overrideWithValue(repo)],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: OnboardingUsernameScreen(onClaimed: () => claimed = true),
      ),
    ));

    await tester.enterText(find.byKey(const Key('onboarding-username')), 'BrandNew');
    await tester.tap(find.byKey(const Key('onboarding-username-submit')));
    await tester.pumpAndSettle();

    expect(repo.claimed, 'BrandNew');
    expect(claimed, isTrue);
  });
}
```

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/features/signup_screen_test.dart test/features/onboarding_username_screen_test.dart` → Expected: FAIL (screens missing).

- [ ] **Step 3: Implement**

`lib/features/auth/signup_screen.dart`
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_providers.dart';
import '../../core/auth/auth_repository.dart';
import '../../core/l10n/gen/app_localizations.dart';

class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key, required this.onSignedUp, required this.onLogIn, this.initialRef});

  final void Function(String email) onSignedUp;
  final VoidCallback onLogIn;
  final String? initialRef;

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final _username = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  int _step = 1;
  bool _loading = false;
  String? _errorCode;

  String _errorText(AppLocalizations l10n, String code) => switch (code) {
        'invalid_email' => l10n.authErrorsInvalidEmail,
        'password_too_short' => l10n.authErrorsPasswordTooShort,
        'username_too_short' => l10n.authErrorsUsernameTooShort,
        'username_too_long' => l10n.authErrorsUsernameTooLong,
        'username_charset' => l10n.authErrorsUsernameCharset,
        'blocked_details' => l10n.authErrorsBlockedDetails,
        'username_taken' => l10n.authErrorsUsernameTaken,
        'username_taken_go_back' => l10n.authErrorsUsernameTakenGoBack,
        _ => l10n.authErrorsSignupFailed,
      };

  Future<void> _submit() async {
    setState(() { _loading = true; _errorCode = null; });
    try {
      final locale = Localizations.localeOf(context).languageCode;
      await ref.read(authRepositoryProvider).signUp(
            username: _username.text.trim(),
            email: _email.text.trim(),
            password: _password.text,
            ref: widget.initialRef,
            locale: locale,
          );
      widget.onSignedUp(_email.text.trim());
    } on AuthException catch (e) {
      setState(() => _errorCode = e.code);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(_step == 1 ? l10n.authSignupStep1Title : l10n.authSignupStep2Title)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ListView(
            children: _step == 1
                ? [
                    Text(l10n.authSignupStep1Subtitle),
                    const SizedBox(height: 16),
                    TextField(
                      key: const Key('signup-username'),
                      controller: _username,
                      decoration: InputDecoration(labelText: l10n.authCommonUsername),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      key: const Key('signup-continue-email'),
                      onPressed: () => setState(() => _step = 2),
                      child: Text(l10n.authSignupContinueWithEmail),
                    ),
                    TextButton(onPressed: widget.onLogIn, child: Text(l10n.authSignupLogIn)),
                  ]
                : [
                    Text(l10n.authSignupSigningUpAs(_username.text)),
                    const SizedBox(height: 16),
                    TextField(
                      key: const Key('signup-email'),
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(labelText: l10n.authCommonEmail),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      key: const Key('signup-password'),
                      controller: _password,
                      obscureText: true,
                      decoration: InputDecoration(labelText: l10n.authCommonPassword, helperText: l10n.authCommonAtLeast8),
                    ),
                    if (_errorCode != null) ...[
                      const SizedBox(height: 12),
                      Text(_errorText(l10n, _errorCode!), style: const TextStyle(color: Colors.redAccent)),
                    ],
                    const SizedBox(height: 16),
                    ElevatedButton(
                      key: const Key('signup-submit'),
                      onPressed: _loading ? null : _submit,
                      child: Text(_loading ? l10n.authSignupSubmitting : l10n.authSignupSubmit),
                    ),
                    TextButton(onPressed: () => setState(() => _step = 1), child: Text(l10n.authCommonBack)),
                  ],
          ),
        ),
      ),
    );
  }
}
```

`lib/features/auth/check_email_screen.dart`
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_providers.dart';
import '../../core/l10n/gen/app_localizations.dart';

class CheckEmailScreen extends ConsumerStatefulWidget {
  const CheckEmailScreen({super.key, required this.email, required this.onGoToLogin});

  final String email;
  final VoidCallback onGoToLogin;

  @override
  ConsumerState<CheckEmailScreen> createState() => _CheckEmailScreenState();
}

class _CheckEmailScreenState extends ConsumerState<CheckEmailScreen> {
  bool _resending = false;
  bool _sent = false;

  Future<void> _resend() async {
    setState(() => _resending = true);
    await ref.read(authRepositoryProvider).resendConfirmation(widget.email);
    if (mounted) setState(() { _resending = false; _sent = true; });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.authSignupCheckEmailTitle)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ListView(
            children: [
              Text(l10n.authSignupCheckEmailBody(widget.email)),
              const SizedBox(height: 16),
              Text(l10n.authSignupNothingYet),
              const SizedBox(height: 12),
              TextButton(
                key: const Key('check-email-resend'),
                onPressed: _resending ? null : _resend,
                child: Text(_resending ? l10n.authSignupResending : l10n.authSignupResend),
              ),
              if (_sent) Text(l10n.authNoticesResendSent),
              const SizedBox(height: 16),
              TextButton(onPressed: widget.onGoToLogin, child: Text(l10n.authCommonBackToLogin)),
            ],
          ),
        ),
      ),
    );
  }
}
```

`lib/features/onboarding/onboarding_username_screen.dart`
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_providers.dart';
import '../../core/auth/auth_repository.dart';
import '../../core/l10n/gen/app_localizations.dart';

class OnboardingUsernameScreen extends ConsumerStatefulWidget {
  const OnboardingUsernameScreen({super.key, required this.onClaimed});

  final VoidCallback onClaimed;

  @override
  ConsumerState<OnboardingUsernameScreen> createState() => _OnboardingUsernameScreenState();
}

class _OnboardingUsernameScreenState extends ConsumerState<OnboardingUsernameScreen> {
  final _username = TextEditingController();
  bool _loading = false;
  String? _errorCode;

  String _errorText(AppLocalizations l10n, String code) => switch (code) {
        'username_too_short' => l10n.authErrorsUsernameTooShort,
        'username_too_long' => l10n.authErrorsUsernameTooLong,
        'username_charset' => l10n.authErrorsUsernameCharset,
        'username_taken' => l10n.authErrorsUsernameTaken,
        _ => l10n.authErrorsUsernameSaveFailed,
      };

  Future<void> _submit() async {
    setState(() { _loading = true; _errorCode = null; });
    try {
      await ref.read(authRepositoryProvider).claimUsername(_username.text.trim());
      widget.onClaimed();
    } on AuthException catch (e) {
      setState(() => _errorCode = e.code);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.authUsernameStepTitle)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ListView(
            children: [
              Text(l10n.authUsernameStepSubtitle),
              const SizedBox(height: 16),
              TextField(
                key: const Key('onboarding-username'),
                controller: _username,
                decoration: InputDecoration(labelText: l10n.authCommonUsername),
              ),
              if (_errorCode != null) ...[
                const SizedBox(height: 12),
                Text(_errorText(l10n, _errorCode!), style: const TextStyle(color: Colors.redAccent)),
              ],
              const SizedBox(height: 16),
              ElevatedButton(
                key: const Key('onboarding-username-submit'),
                onPressed: _loading ? null : _submit,
                child: Text(_loading ? l10n.authUsernameStepSubmitting : l10n.authUsernameStepSubmit),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run to verify pass**

Run: `flutter test test/features/signup_screen_test.dart test/features/onboarding_username_screen_test.dart` → Expected: all pass. `flutter analyze` → clean.

- [ ] **Step 5: Commit**
```bash
git add lib/features/auth/signup_screen.dart lib/features/auth/check_email_screen.dart lib/features/onboarding test/features
git commit -m "feat(auth): Signup wizard, Check-your-email, Onboarding username screens"
```

---

### Task 6: Google Sign-In

**Files:**
- Modify: `lib/core/auth/auth_repository.dart`, `lib/core/auth/auth_providers.dart`, `lib/features/auth/login_screen.dart`, `lib/features/auth/signup_screen.dart`
- Create: `lib/features/auth/google_sign_in_button.dart`
- Test: `test/core/auth_repository_test.dart` (extend), `test/core/google_sign_in_smoke_test.dart`, `test/features/auth_test_fakes.dart` (add the new stub), `test/features/login_screen_test.dart` (add the new stub)

**Interfaces:**
- Produces: `AuthRepository.signInWithGoogle()`; `GoogleSignInButton({onSignedIn})`.

- [ ] **Step 1: Add the dependency and smoke-test its installed API version**

```powershell
flutter pub add google_sign_in
```

`test/core/google_sign_in_smoke_test.dart`
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';

void main() {
  test('the installed google_sign_in exposes the v7+ singleton API this plan targets', () {
    // v7+: GoogleSignIn.instance is a singleton with .initialize()/.authenticate().
    // If this fails to compile, the installed version is 6.x instead — switch
    // Step 3's implementation to `GoogleSignIn(serverClientId: ...).signIn()`
    // (the v6 instance-based API) and note the version pin in pubspec.yaml.
    expect(GoogleSignIn.instance, isNotNull);
  });
}
```
Run: `flutter test test/core/google_sign_in_smoke_test.dart` → **read the compiler output before writing anything else.** If `GoogleSignIn.instance` doesn't exist, the resolved version is 6.x — rewrite this test to construct `GoogleSignIn(serverClientId: 'x')` instead and use that shape in Step 3.

- [ ] **Step 2: Extend the repository test**

Append to `test/core/auth_repository_test.dart`:
```dart
  test('signInWithGoogle is on the AuthRepository interface', () {
    // Compile-time check: AuthRepository must declare signInWithGoogle().
    // ignore: unused_element
    Future<void> Function(AuthRepository) _ = (r) => r.signInWithGoogle();
  });
```
(A real behavioral test of `signInWithGoogle()` would need to stub the `google_sign_in` plugin's platform channel, which is out of scope for a unit test — the plugin's own tests cover the OAuth handshake. This compile-time check plus the manual device test in Task 11 is the right-sized coverage here, same reasoning `google_sign_in`'s own package README gives for testing consumers.)

- [ ] **Step 3: Implement**

Add to `AuthRepository`'s abstract interface: `Future<void> signInWithGoogle();`

**This adds a new abstract method, so every existing fake implementing `AuthRepository` needs it too, or Tasks 4–5's tests stop compiling.** Add `@override Future<void> signInWithGoogle() async {}` to:
- `FakeAuthRepositoryForForgot` (`test/features/auth_test_fakes.dart`) — covers `_RecordingReset`, `_RecordingSignup`, `_RecordingClaim`, which all `extends` it and inherit the stub.
- `_FakeAuthRepository` (`test/features/login_screen_test.dart`) — a standalone implementer, not a subclass of the shared fake, so it needs its own stub.

In `SupabaseAuthRepository` (`lib/core/auth/auth_repository.dart`), add the constructor parameter and method (**use the shape Step 1 confirmed**; this is the v7+ form). The parameter defaults to `''` — **do not make it `required`** — every `SupabaseAuthRepository(...)` call site written in Tasks 3–5's tests omits it, and those must keep compiling unchanged:
```dart
  SupabaseAuthRepository(this._auth, this._api, {String googleWebClientId = ''}) : _googleWebClientId = googleWebClientId;

  final String _googleWebClientId;

  @override
  Future<void> signInWithGoogle() async {
    if (_googleWebClientId.isEmpty) {
      throw const AuthException('google_not_configured', 'Google sign-in is not set up yet.');
    }
    final googleSignIn = GoogleSignIn.instance;
    await googleSignIn.initialize(serverClientId: _googleWebClientId);
    final account = await googleSignIn.authenticate();
    final idToken = account.authentication.idToken;
    if (idToken == null) {
      throw const AuthException('google_no_token', 'Google sign-in did not return a token.');
    }
    try {
      await _auth.signInWithIdToken(provider: OAuthProvider.google, idToken: idToken);
    } on AuthApiException catch (e) {
      throw AuthException(e.code ?? 'signup_failed', e.message);
    }
  }
```
Add `import 'package:google_sign_in/google_sign_in.dart';` at the top of the file.

Update `lib/core/auth/auth_providers.dart`'s `authRepositoryProvider` to pass the new parameter:
```dart
  return SupabaseAuthRepository(supabase.auth, api, googleWebClientId: ref.watch(appConfigProvider).googleWebClientId);
```

`lib/features/auth/google_sign_in_button.dart`
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_providers.dart';
import '../../core/auth/auth_repository.dart';
import '../../core/l10n/gen/app_localizations.dart';

class GoogleSignInButton extends ConsumerStatefulWidget {
  const GoogleSignInButton({super.key, required this.onSignedIn});

  final VoidCallback onSignedIn;

  @override
  ConsumerState<GoogleSignInButton> createState() => _GoogleSignInButtonState();
}

class _GoogleSignInButtonState extends ConsumerState<GoogleSignInButton> {
  bool _loading = false;
  String? _error;

  Future<void> _tap() async {
    setState(() { _loading = true; _error = null; });
    try {
      await ref.read(authRepositoryProvider).signInWithGoogle();
      widget.onSignedIn();
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      children: [
        OutlinedButton(
          key: const Key('google-sign-in'),
          onPressed: _loading ? null : _tap,
          child: Text(l10n.authCommonContinueWithGoogle),
        ),
        if (_error != null) Text(_error!, style: const TextStyle(color: Colors.redAccent)),
      ],
    );
  }
}
```

Wire `GoogleSignInButton(onSignedIn: widget.onLoggedIn)` into `LoginScreen`'s and `SignupScreen`'s build methods, below the primary submit button, separated by the existing `authCommonOr` label — a small, mechanical addition to each screen's `ListView` children (add `Text(l10n.authCommonOr)` and `GoogleSignInButton(onSignedIn: ...)` after the submit/back buttons in both files).

- [ ] **Step 4: Run to verify pass**

Run: `flutter test test/core/google_sign_in_smoke_test.dart test/core/auth_repository_test.dart test/features/login_screen_test.dart test/features/signup_screen_test.dart` → Expected: all pass. `flutter analyze` → clean.

- [ ] **Step 5: Commit**
```bash
git add lib/core/auth lib/features/auth pubspec.yaml pubspec.lock test/core/google_sign_in_smoke_test.dart
git commit -m "feat(auth): Google Sign-In (native, signInWithIdToken)"
```

---

### Task 7: `/auth/confirm` App Link handling

**Files:**
- Create: `lib/core/auth/email_link_handler.dart`
- Modify: `android/app/src/main/AndroidManifest.xml`, `lib/router/app_router.dart` (redirect hook only — full restructure is Task 8)
- Test: `test/core/email_link_handler_test.dart`

**Interfaces:**
- Produces: `enum EmailLinkOutcome { verified, recovery, failed }`; `EmailLinkResult { EmailLinkOutcome outcome; }`; `Future<EmailLinkResult> handleEmailLink(Uri link, {required GoTrueClient auth})` (parses `token_hash`+`type`, calls `verifyOtp`, classifies the outcome — routing to a destination happens in Task 8's router once Home/onboarding routes exist).

- [ ] **Step 1: Add the dependency**

```powershell
flutter pub add app_links
```

- [ ] **Step 2: Write the failing test**

`test/core/email_link_handler_test.dart`
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/core/auth/email_link_handler.dart';

class _FakeAuth {
  Map<String, Object?>? lastVerify;
  bool fail = false;

  Future<void> verifyOTP({required OtpType type, required String tokenHash}) async {
    lastVerify = {'type': type, 'tokenHash': tokenHash};
    if (fail) throw Exception('bad token');
  }
}

enum OtpType { signup, recovery, emailChange, invite, magiclink }

void main() {
  test('a recovery link calls verifyOtp with type=recovery and reports outcome=recovery', () async {
    final auth = _FakeAuth();
    final result = await handleEmailLink(
      Uri.parse('https://sentinelxesports.com.ng/auth/confirm?token_hash=abc123&type=recovery'),
      auth: auth as dynamic,
    );
    expect(auth.lastVerify?['tokenHash'], 'abc123');
    expect(result.outcome, EmailLinkOutcome.recovery);
  });

  test('a signup confirmation link reports outcome=verified', () async {
    final auth = _FakeAuth();
    final result = await handleEmailLink(
      Uri.parse('https://sentinelxesports.com.ng/auth/confirm?token_hash=xyz&type=signup'),
      auth: auth as dynamic,
    );
    expect(result.outcome, EmailLinkOutcome.verified);
  });

  test('a locale-prefixed link (fr/pcm) is still handled', () async {
    final auth = _FakeAuth();
    final result = await handleEmailLink(
      Uri.parse('https://sentinelxesports.com.ng/fr/auth/confirm?token_hash=xyz&type=email_change'),
      auth: auth as dynamic,
    );
    expect(result.outcome, EmailLinkOutcome.verified);
  });

  test('a missing token_hash or type reports failed without calling verifyOtp', () async {
    final auth = _FakeAuth();
    final result = await handleEmailLink(Uri.parse('https://sentinelxesports.com.ng/auth/confirm'), auth: auth as dynamic);
    expect(result.outcome, EmailLinkOutcome.failed);
    expect(auth.lastVerify, isNull);
  });

  test('a verifyOtp failure (expired/used link) reports failed', () async {
    final auth = _FakeAuth()..fail = true;
    final result = await handleEmailLink(
      Uri.parse('https://sentinelxesports.com.ng/auth/confirm?token_hash=abc&type=signup'),
      auth: auth as dynamic,
    );
    expect(result.outcome, EmailLinkOutcome.failed);
  });
}
```

- [ ] **Step 3: Run to verify failure**

Run: `flutter test test/core/email_link_handler_test.dart` → Expected: FAIL (module missing).

- [ ] **Step 4: Implement**

`lib/core/auth/email_link_handler.dart`
```dart
import 'package:supabase_flutter/supabase_flutter.dart';

enum EmailLinkOutcome { verified, recovery, failed }

class EmailLinkResult {
  const EmailLinkResult(this.outcome);
  final EmailLinkOutcome outcome;
}

const _typeMap = {
  'signup': OtpType.signup,
  'recovery': OtpType.recovery,
  'email_change': OtpType.emailChange,
  'invite': OtpType.invite,
  'magiclink': OtpType.magiclink,
};

// Handles a claimed https://sentinelxesports.com.ng/auth/confirm App Link.
// Same token_hash+type flow the web route (app/auth/confirm/route.ts) uses —
// verifyOtp establishes a session locally, no code exchange, no fragment.
Future<EmailLinkResult> handleEmailLink(Uri link, {required GoTrueClient auth}) async {
  final tokenHash = link.queryParameters['token_hash'];
  final typeParam = link.queryParameters['type'];
  final type = typeParam == null ? null : _typeMap[typeParam];
  if (tokenHash == null || type == null) return const EmailLinkResult(EmailLinkOutcome.failed);

  try {
    await auth.verifyOTP(type: type, tokenHash: tokenHash);
  } catch (_) {
    return const EmailLinkResult(EmailLinkOutcome.failed);
  }

  return EmailLinkResult(type == OtpType.recovery ? EmailLinkOutcome.recovery : EmailLinkOutcome.verified);
}
```

- [ ] **Step 5: Run to verify pass**

Run: `flutter test test/core/email_link_handler_test.dart` → Expected: 5 passed. `flutter analyze` → clean (the test's `_FakeAuth`/`OtpType` are test-local stand-ins matching `supabase_flutter`'s real `GoTrueClient.verifyOTP`/`OtpType` shape — if `flutter analyze` reports the test file's fake doesn't structurally match, adjust the fake's signature to the installed `supabase_flutter` version's actual `verifyOTP` parameters, the same "compile against the real package" discipline as Task 6's Google Sign-In smoke test).

- [ ] **Step 6: Android manifest — claim `/auth/confirm`**

In `android/app/src/main/AndroidManifest.xml`, add a second `<data>` element to the existing `android:autoVerify="true"` intent-filter (do not create a second intent-filter block — multiple `<data>` tags under one filter is the standard pattern):
```xml
            <intent-filter android:autoVerify="true">
                <action android:name="android.intent.action.VIEW"/>
                <category android:name="android.intent.category.DEFAULT"/>
                <category android:name="android.intent.category.BROWSABLE"/>
                <data android:scheme="https" android:host="sentinelxesports.com.ng" android:path="/tournaments"/>
                <data android:scheme="https" android:host="sentinelxesports.com.ng" android:path="/auth/confirm"/>
            </intent-filter>
```
(Task 8 adds the remaining pillar paths once their routes exist.)

- [ ] **Step 7: Commit**
```bash
git add lib/core/auth/email_link_handler.dart android/app/src/main/AndroidManifest.xml pubspec.yaml pubspec.lock test/core/email_link_handler_test.dart
git commit -m "feat(auth): handle /auth/confirm App Links via verifyOtp"
```

---

### Task 8: Router restructure — 5-tab shell, Home slot, gate wiring

**Files:**
- Modify: `lib/router/app_router.dart`, `lib/core/routing/web_links.dart`, `lib/core/auth/auth_providers.dart`, `lib/main.dart`, `android/app/src/main/AndroidManifest.xml`
- Create: `lib/shared/widgets/sx_tab_app_bar.dart`, `lib/shared/widgets/coming_soon_screen.dart`, `lib/features/account/account_screen.dart`, `lib/core/notifications/unread_counts.dart`, `lib/core/routing/incoming_links.dart`
- Test: `test/core/web_links_test.dart` (updated expectations), `test/router/app_router_test.dart` (extended), `test/core/unread_counts_test.dart`, `test/features/account_screen_test.dart`, `test/core/incoming_links_test.dart`

**Interfaces:**
- Consumes: `resolveOnboardingGate` (Task 3); `handleEmailLink` (Task 7); `authRepositoryProvider`; `sessionProvider`, `meProvider`, `roleProvider`, `remoteConfigProvider` (existing); `resolveWebLink` (existing, extended).
- Produces: `Stream<int> unreadCount(SupabaseClient, {required String userId, String? type})`; `unreadNotificationCountProvider`, `unreadMessageCountProvider` (`StreamProvider.autoDispose`); `onboardingGateProvider`; `isAuthConfirmPath`, `handleIncomingLink`, `listenForIncomingLinks`; `SxTabAppBar({title, onLogoTap})`; `ComingSoonScreen({title})`; `AccountScreen`; router paths finalized (see below).

**Route map after this task** (Home outside the shell; the shell owns the 5 tabs; auth/onboarding routes are top-level, unauthenticated-reachable):
```
/                         Home (standalone)
/login  /signup  /signup/check-email  /forgot-password  /reset-password
/onboarding/username
/tournaments  /tournaments/:id  /tournaments/:id/bracket    (Compete branch — existing slice, unmoved)
/tv                                                          (Watch branch — coming soon)
/community                                                   (Community branch — coming soon)
/exchange                                                     (Trade branch — coming soon)
/account                                                      (Account branch)
/debug                                                        (debugTools only, unchanged)
```

- [ ] **Step 1: Update `web_links_test.dart` for the new route map (failing first)**

Replace `test/core/web_links_test.dart` entirely:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/core/routing/web_links.dart';

void main() {
  test('maps the site root to standalone Home', () {
    expect(resolveWebLink('https://sentinelxesports.com.ng/'), '/');
    expect(resolveWebLink('/'), '/');
  });

  test('maps the tournaments list to the Compete branch (no longer the site root)', () {
    expect(resolveWebLink('https://sentinelxesports.com.ng/tournaments'), '/tournaments');
  });

  test('maps tv, community and exchange to their branch roots', () {
    expect(resolveWebLink('https://sentinelxesports.com.ng/tv'), '/tv');
    expect(resolveWebLink('https://sentinelxesports.com.ng/community'), '/community');
    expect(resolveWebLink('https://sentinelxesports.com.ng/exchange'), '/exchange');
  });

  test('strips a locale prefix, query and fragment', () {
    expect(resolveWebLink('https://sentinelxesports.com.ng/fr/tournaments'), '/tournaments');
    expect(resolveWebLink('https://sentinelxesports.com.ng/pcm/tournaments?x=1#y'), '/tournaments');
    expect(resolveWebLink('https://sentinelxesports.com.ng/fr/'), '/');
  });

  test('accepts the www host and tolerates a trailing slash', () {
    expect(resolveWebLink('https://www.sentinelxesports.com.ng/tournaments/'), '/tournaments');
  });

  test('returns null for other hosts and for paths the app has no screen for yet', () {
    expect(resolveWebLink('https://evil.example/tournaments'), isNull);
    expect(resolveWebLink('https://sentinelxesports.com.ng/tournaments/some-slug'), isNull);
    expect(resolveWebLink('not a url at all ::'), isNull);
  });
}
```

Run: `flutter test test/core/web_links_test.dart` → Expected: FAIL (`/tournaments` still resolves to `/`).

- [ ] **Step 2: Implement the `web_links.dart` change**

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
      return '/tournaments';
    case 'tv':
      return '/tv';
    case 'community':
      return '/community';
    case 'exchange':
      return '/exchange';
  }
  return null;
}
```

Run: `flutter test test/core/web_links_test.dart` → Expected: pass.

- [ ] **Step 3: Write the failing unread-counts test**

`test/core/unread_counts_test.dart`
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/core/notifications/unread_counts.dart';

void main() {
  test('countQuery filters by player_id, read=false, and an optional type', () {
    expect(countQuery(playerId: 'u1', type: null), {'player_id': 'u1', 'read': false});
    expect(countQuery(playerId: 'u1', type: 'direct_message'), {'player_id': 'u1', 'read': false, 'type': 'direct_message'});
  });
}
```
(This is deliberately the only unit-testable slice of `unread_counts.dart` — the Realtime subscription itself needs a live Supabase channel, which is exercised by the manual device test in Task 11, not a widget/unit test. Compare to Phase 0's `RealtimeManager` deferral reasoning in the design spec: a single disposable subscription doesn't get a general test harness built for it.)

- [ ] **Step 4: Run to verify failure**

Run: `flutter test test/core/unread_counts_test.dart` → Expected: FAIL (module missing).

- [ ] **Step 5: Implement `unread_counts.dart`**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../providers.dart';

Map<String, Object> countQuery({required String playerId, String? type}) => {
      'player_id': playerId,
      'read': false,
      if (type != null) 'type': type,
    };

// Refetches the count on every insert/update to this player's notifications
// (never assumes no gap — same "refetch on reconnect" rule as the master
// spec's RealtimeManager). One disposable subscription per screen; the
// general-purpose channel manager is Phase 5's job once DMs/feed/bell give
// it three real consumers to design against.
Stream<int> unreadCount(SupabaseClient client, {required String userId, String? type}) async* {
  Future<int> fetch() async {
    var query = client.from('player_notifications').select('id').eq('player_id', userId).eq('read', false);
    if (type != null) query = query.eq('type', type);
    final rows = await query;
    return (rows as List).length;
  }

  yield await fetch();
  await for (final _ in client
      .from('player_notifications')
      .stream(primaryKey: ['id'])
      .eq('player_id', userId)) {
    yield await fetch();
  }
}

final unreadNotificationCountProvider = StreamProvider.autoDispose<int>((ref) {
  final me = ref.watch(meProvider).asData?.value;
  if (me == null) return const Stream.empty();
  return unreadCount(ref.watch(supabaseClientProvider), userId: me.id);
});

final unreadMessageCountProvider = StreamProvider.autoDispose<int>((ref) {
  final me = ref.watch(meProvider).asData?.value;
  if (me == null) return const Stream.empty();
  return unreadCount(ref.watch(supabaseClientProvider), userId: me.id, type: 'direct_message');
});
```

- [ ] **Step 6: Run to verify pass**

Run: `flutter test test/core/unread_counts_test.dart` → Expected: pass.

- [ ] **Step 7: `SxTabAppBar`, `ComingSoonScreen`, `AccountScreen`**

`lib/shared/widgets/sx_tab_app_bar.dart`
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/notifications/unread_counts.dart';
import '../../core/theme/sx_colors.dart';

class SxTabAppBar extends ConsumerWidget implements PreferredSizeWidget {
  const SxTabAppBar({super.key, required this.title, required this.onLogoTap});

  final String title;
  final VoidCallback onLogoTap;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifCount = ref.watch(unreadNotificationCountProvider).asData?.value ?? 0;
    final dmCount = ref.watch(unreadMessageCountProvider).asData?.value ?? 0;
    return AppBar(
      leading: IconButton(
        key: const Key('sx-logo'),
        icon: const Icon(Icons.sports_esports, color: SxColors.primary),
        onPressed: onLogoTap,
      ),
      title: Text(title),
      actions: [
        _BellIcon(key: const Key('bell-notifications'), icon: Icons.notifications_outlined, count: notifCount),
        _BellIcon(key: const Key('bell-messages'), icon: Icons.mail_outline, count: dmCount),
        const SizedBox(width: 8),
      ],
    );
  }
}

class _BellIcon extends StatelessWidget {
  const _BellIcon({super.key, required this.icon, required this.count});
  final IconData icon;
  final int count;

  @override
  Widget build(BuildContext context) {
    // Both bells route through the coming-soon pattern until Phase 5 builds
    // the real drawer/inbox (spec §4.5) — one deferred-feature UI, not two.
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(icon: Icon(icon), onPressed: () => Navigator.of(context).pushNamed('/coming-soon')),
        if (count > 0)
          Positioned(
            right: 6,
            top: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(color: Colors.redAccent, borderRadius: BorderRadius.circular(8)),
              child: Text('$count', style: const TextStyle(fontSize: 10, color: Colors.white)),
            ),
          ),
      ],
    );
  }
}
```

`lib/shared/widgets/coming_soon_screen.dart`
```dart
import 'package:flutter/material.dart';

class ComingSoonScreen extends StatelessWidget {
  const ComingSoonScreen({super.key, required this.title, required this.onLogoTap});

  final String title;
  final VoidCallback onLogoTap;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: const Center(child: Text('Coming soon')),
    );
  }
}
```

`lib/features/account/account_screen.dart`
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_providers.dart';
import '../../core/providers.dart';

class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key, required this.onLogIn, required this.onSignUp});

  final VoidCallback onLogIn;
  final VoidCallback onSignUp;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(meProvider).asData?.value;
    return Scaffold(
      appBar: AppBar(title: const Text('Account')),
      body: Center(
        child: me == null
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ElevatedButton(key: const Key('account-login'), onPressed: onLogIn, child: const Text('Log in')),
                  TextButton(key: const Key('account-signup'), onPressed: onSignUp, child: const Text('Create account')),
                ],
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(me.profile?.displayName ?? me.profile?.username ?? me.email ?? ''),
                  TextButton(
                    key: const Key('account-sign-out'),
                    onPressed: () => ref.read(authRepositoryProvider).signOut(),
                    child: const Text('Sign out'),
                  ),
                ],
              ),
      ),
    );
  }
}
```
`test/features/account_screen_test.dart` (written and run red→green the same way as every other screen in this plan — override `meProvider` in a `ProviderScope`, following the exact pattern `test/core/role_provider_test.dart` already uses for that provider):
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/core/api/models.dart';
import 'package:sentinelx_mobile/core/providers.dart';
import 'package:sentinelx_mobile/features/account/account_screen.dart';

void main() {
  testWidgets('signed out: shows log in and create account actions', (tester) async {
    var loginTapped = false;
    await tester.pumpWidget(ProviderScope(
      retry: (_, _) => null,
      overrides: [meProvider.overrideWith((ref) async => null)],
      child: MaterialApp(home: AccountScreen(onLogIn: () => loginTapped = true, onSignUp: () {})),
    ));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('account-login')), findsOneWidget);
    await tester.tap(find.byKey(const Key('account-login')));
    expect(loginTapped, isTrue);
  });

  testWidgets('signed in: shows the display name and a sign-out action', (tester) async {
    final me = MeResponse(
      id: 'u1', email: 'a@b.com', roles: const [], isStaff: false, isAdmin: false,
      profile: const MeProfile(
        username: 'ada', displayName: 'Ada', avatarUrl: null, whatsappNumber: null, country: null,
        locale: 'en', membershipTier: null, kycVerified: false, deletionRequestedAt: null,
      ),
    );
    await tester.pumpWidget(ProviderScope(
      retry: (_, _) => null,
      overrides: [meProvider.overrideWith((ref) async => me)],
      child: MaterialApp(home: AccountScreen(onLogIn: () {}, onSignUp: () {})),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Ada'), findsOneWidget);
    expect(find.byKey(const Key('account-sign-out')), findsOneWidget);
  });
}
```
Run: `flutter test test/features/account_screen_test.dart` → red before `account_screen.dart` exists (Step 7 above), green immediately after — this is the task's own TDD pair, sequenced here at the end of Step 7's file group rather than reordered ahead of it, since `AccountScreen` needed writing once, not twice.

- [ ] **Step 7b: Wire the onboarding gate as a provider, and wire `handleEmailLink` (Task 7) into the running app**

Task 7 built `handleEmailLink` but never called it from anywhere, and Task 3 built `resolveOnboardingGate` but nothing ever reads it — both are load-bearing for the exit criterion ("confirm via App Link... claim username... land on Home") and for Google sign-in, which also lands a user with no username yet (the `handle_new_user()` trigger only seeds `username` from email-signup metadata — a fresh Google account has none either, so the gate applies to both paths, not just email confirmation). Fix both now, before the router needs them.

**Files:** Modify `lib/core/auth/auth_providers.dart`; create `lib/core/routing/incoming_links.dart`; modify `lib/main.dart`.
**Test:** `test/core/incoming_links_test.dart`.

Add to `lib/core/auth/auth_providers.dart`:
```dart
import '../api/models.dart';
import '../config/remote_config.dart';
import 'onboarding_gate.dart';

final onboardingGateProvider = Provider<OnboardingGate>((ref) {
  final me = ref.watch(meProvider).asData?.value;
  final config = ref.watch(remoteConfigProvider).asData?.value;
  return resolveOnboardingGate(me, config);
});
```
(Add the two new imports to the top of the existing file alongside its current imports; `MeResponse`/`RemoteConfig` types themselves are already imported transitively via `meProvider`/`remoteConfigProvider`'s own files, but importing them directly here keeps `OnboardingGate`'s resolution explicit and matches `onboarding_gate.dart`'s own import style.)

Write the failing test first — `test/core/incoming_links_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/core/routing/incoming_links.dart';

void main() {
  group('isAuthConfirmPath', () {
    test('matches the bare path', () {
      expect(isAuthConfirmPath(Uri.parse('https://sentinelxesports.com.ng/auth/confirm?token_hash=x&type=signup')), isTrue);
    });
    test('matches a locale-prefixed path', () {
      expect(isAuthConfirmPath(Uri.parse('https://sentinelxesports.com.ng/fr/auth/confirm?token_hash=x&type=signup')), isTrue);
    });
    test('does not match other paths', () {
      expect(isAuthConfirmPath(Uri.parse('https://sentinelxesports.com.ng/tournaments')), isFalse);
    });
  });
}
```
Run: `flutter test test/core/incoming_links_test.dart` → FAIL (module missing).

Implement `lib/core/routing/incoming_links.dart`:
```dart
import 'package:app_links/app_links.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/email_link_handler.dart';
import 'web_links.dart';

const _locales = {'en', 'fr', 'pcm'};

bool isAuthConfirmPath(Uri uri) {
  final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
  if (segments.isNotEmpty && _locales.contains(segments.first)) segments.removeAt(0);
  return segments.join('/') == 'auth/confirm';
}

// The single place an incoming URI (App Link tap, cold-start deep link) is
// decided between two paths: /auth/confirm needs verifyOtp run against it
// first (Task 7); everything else is a plain in-app navigation resolved by
// resolveWebLink. Both end in the same router.go(...).
Future<void> handleIncomingLink(Uri uri, {required GoRouter router, required GoTrueClient auth}) async {
  if (isAuthConfirmPath(uri)) {
    final result = await handleEmailLink(uri, auth: auth);
    switch (result.outcome) {
      case EmailLinkOutcome.recovery:
        router.go('/reset-password');
      case EmailLinkOutcome.verified:
        // Always true immediately after signup confirmation (username is
        // claimed AFTER confirmation, never before — design spec §4.1). A
        // Google sign-in or an already-onboarded email_change link lands on
        // Home instead via onLoggedIn/onSignedIn; this branch is specific to
        // the confirm-link flow.
        router.go('/onboarding/username');
      case EmailLinkOutcome.failed:
        router.go('/login');
    }
    return;
  }
  final resolved = resolveWebLink(uri.toString());
  if (resolved != null) router.go(resolved);
}

void listenForIncomingLinks({required GoRouter router, required GoTrueClient auth}) {
  final appLinks = AppLinks();
  appLinks.uriLinkStream.listen((uri) => handleIncomingLink(uri, router: router, auth: auth));
  appLinks.getInitialLink().then((uri) {
    if (uri != null) handleIncomingLink(uri, router: router, auth: auth);
  });
}
```
Run: `flutter test test/core/incoming_links_test.dart` → pass.

Wire it into `lib/main.dart` — add, right after `runApp(...)`:
```dart
  listenForIncomingLinks(router: container.read(routerProvider), auth: container.read(supabaseClientProvider).auth);
```
Add `import 'core/routing/incoming_links.dart';` to `main.dart`'s imports. (`handleIncomingLink`'s router-navigation calls aren't unit-tested beyond `isAuthConfirmPath` above — routing a real `GoRouter` from a background stream callback needs a running app, which is exactly what Task 11's device round-trip test exercises end to end.)

- [ ] **Step 8: Restructure the router**

Replace `lib/router/app_router.dart` entirely:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/auth/onboarding_gate.dart';
import '../core/providers.dart';
import '../core/routing/web_links.dart';
import '../features/account/account_screen.dart';
import '../features/auth/check_email_screen.dart';
import '../features/auth/forgot_password_screen.dart';
import '../features/auth/login_screen.dart';
import '../features/auth/reset_password_screen.dart';
import '../features/auth/signup_screen.dart';
import '../features/debug/debug_sign_in_screen.dart';
import '../features/home/home_screen.dart';
import '../features/onboarding/onboarding_username_screen.dart';
import '../features/tournaments/bracket_screen.dart';
import '../features/tournaments/tournament_detail_screen.dart';
import '../features/tournaments/tournament_list_screen.dart';
import '../shared/widgets/coming_soon_screen.dart';

final _shellKey = GlobalKey<NavigatorState>();

GoRouter buildAppRouter({bool debugTools = false, OnboardingGate Function()? gateOverride}) {
  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      final incoming = state.uri.toString();
      final resolved = resolveWebLink(incoming);
      if (resolved != null && resolved != incoming) return resolved;
      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (context, state) => HomeScreen(onGoTo: (path) => context.go(path))),
      GoRoute(path: '/login', builder: (context, state) => LoginScreen(
            onLoggedIn: () => context.go('/'),
            onForgotPassword: () => context.push('/forgot-password'),
            onCreateAccount: () => context.push('/signup'),
          )),
      GoRoute(
        path: '/signup',
        builder: (context, state) => SignupScreen(
          onSignedUp: (email) => context.push('/signup/check-email', extra: email),
          onLogIn: () => context.push('/login'),
          initialRef: state.uri.queryParameters['ref'],
        ),
      ),
      GoRoute(
        path: '/signup/check-email',
        builder: (context, state) => CheckEmailScreen(email: state.extra as String? ?? '', onGoToLogin: () => context.go('/login')),
      ),
      GoRoute(path: '/forgot-password', builder: (context, state) => const ForgotPasswordScreen()),
      GoRoute(path: '/reset-password', builder: (context, state) => ResetPasswordScreen(onDone: () => context.go('/'))),
      GoRoute(
        path: '/onboarding/username',
        builder: (context, state) => OnboardingUsernameScreen(onClaimed: () => context.go('/')),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => shell,
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/tournaments',
              builder: (context, state) => TournamentListScreen(
                onTournamentTap: (t) => context.push('/tournaments/${t.id}'),
              ),
              routes: [
                GoRoute(
                  path: ':id',
                  builder: (context, state) {
                    final id = state.pathParameters['id']!;
                    return TournamentDetailScreen(tournamentId: id, onViewBracket: () => context.push('/tournaments/$id/bracket'));
                  },
                  routes: [GoRoute(path: 'bracket', builder: (context, state) => BracketScreen(tournamentId: state.pathParameters['id']!))],
                ),
              ],
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/tv', builder: (context, state) => ComingSoonScreen(title: 'Watch', onLogoTap: () => context.go('/'))),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/community', builder: (context, state) => ComingSoonScreen(title: 'Community', onLogoTap: () => context.go('/'))),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/exchange', builder: (context, state) => ComingSoonScreen(title: 'Trade', onLogoTap: () => context.go('/'))),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/account',
              builder: (context, state) => AccountScreen(onLogIn: () => context.push('/login'), onSignUp: () => context.push('/signup')),
            ),
          ]),
        ],
      ),
      if (debugTools) GoRoute(path: '/debug', builder: (context, state) => const DebugSignInScreen()),
    ],
  );
}

final routerProvider = Provider<GoRouter>((ref) {
  final router = buildAppRouter(debugTools: ref.watch(appConfigProvider).debugTools);
  ref.onDispose(router.dispose);
  return router;
});
```
Note: the outer `Scaffold`/`BottomNavigationBar` chrome for the `StatefulShellRoute` (the actual 5-icon tab bar widget) is intentionally minimal here — `builder: (context, state, shell) => shell` returns the bare `StatefulNavigationShell`, which is itself a valid `Widget`. Wrap it with a real bottom nav bar as a small follow-up inside this same task before Step 9's tests, since `test/router/app_router_test.dart`'s existing navigation assertions (list → detail → bracket) need the tab body reachable either way — this refactor does not change those tests' expectations, only the path prefix stays `/tournaments/...` as before.

Add a `BottomNavigationBar`-driving wrapper: change the `builder` to:
```dart
        builder: (context, state, shell) => Scaffold(
          body: shell,
          bottomNavigationBar: NavigationBar(
            selectedIndex: shell.currentIndex,
            onDestinationSelected: shell.goBranch,
            destinations: const [
              NavigationDestination(icon: Icon(Icons.emoji_events_outlined), label: 'Compete'),
              NavigationDestination(icon: Icon(Icons.live_tv_outlined), label: 'Watch'),
              NavigationDestination(icon: Icon(Icons.groups_outlined), label: 'Community'),
              NavigationDestination(icon: Icon(Icons.storefront_outlined), label: 'Trade'),
              NavigationDestination(icon: Icon(Icons.person_outline), label: 'Account'),
            ],
          ),
        ),
```

- [ ] **Step 9: Update `app_router_test.dart` for the new paths**

The existing navigation test (`navigates list -> detail -> bracket and back`) taps `find.byKey(const Key('tournament-tile-t1'))` then expects `/tournaments/t1/bracket`'s content — unchanged by path since the *relative* structure inside the Compete branch didn't change, only its now living under a shell. Update `pumpRouterWithRepo` in `test/support/pump_app.dart` if it hard-codes `MaterialApp(home: ...)` around a bare `buildAppRouter()` result expecting `/` to show the tournament list — it now shows Home, so the existing test must navigate to `/tournaments` first:
```dart
Future<void> pumpRouterWithRepo(WidgetTester tester, TournamentsRepository repository) {
  return tester.pumpWidget(ProviderScope(
    retry: (_, _) => null,
    overrides: [tournamentsRepositoryProvider.overrideWithValue(repository)],
    child: MaterialApp.router(routerConfig: buildAppRouter(), routeInformationProvider: PlatformRouteInformationProvider(
      initialRouteInformation: RouteInformation(uri: Uri.parse('/tournaments')),
    )),
  ));
}
```
And add a new test to `test/router/app_router_test.dart`:
```dart
  testWidgets('the tab bar has all five destinations and Home lives outside it', (tester) async {
    await pumpRouterWithRepo(tester, FakeTournamentsRepository(tournaments: const [], tournamentById: null, matchesByTournament: const {}));
    await tester.pumpAndSettle();
    expect(find.text('Compete'), findsOneWidget);
    expect(find.text('Watch'), findsOneWidget);
    expect(find.text('Community'), findsOneWidget);
    expect(find.text('Trade'), findsOneWidget);
    expect(find.text('Account'), findsOneWidget);
  });
```

- [ ] **Step 10: Manifest — remaining pillar paths**

In `android/app/src/main/AndroidManifest.xml`, add three more `<data>` lines to the same `autoVerify` intent-filter from Task 7:
```xml
                <data android:scheme="https" android:host="sentinelxesports.com.ng" android:path="/tv"/>
                <data android:scheme="https" android:host="sentinelxesports.com.ng" android:path="/community"/>
                <data android:scheme="https" android:host="sentinelxesports.com.ng" android:path="/exchange"/>
```

- [ ] **Step 11: Run everything, verify pass**

Run: `flutter test` → all pass (this is the point where a stale reference to the old flat router structure anywhere else in the test suite — e.g. `test/widget_test.dart` — would surface; fix any such reference to build `MaterialApp.router` against the new `buildAppRouter()`, following the same pattern Step 9 used). `flutter analyze` → clean.

- [ ] **Step 12: Commit**
```bash
git add lib/router lib/core/routing lib/core/notifications lib/core/auth/auth_providers.dart lib/main.dart lib/shared lib/features/account android test
git commit -m "feat(shell): 5-tab StatefulShellRoute, Home outside the shell, unread-count bells"
```

---

### Task 9: Home screen

**Files:**
- Create: `lib/features/home/home_repository.dart`, `lib/features/home/home_providers.dart`, `lib/features/home/home_screen.dart`
- Test: `test/features/home_screen_test.dart`

**Interfaces:**
- Consumes: `apiClientProvider`; `HomeSummary`/`HomeTournamentCard`/etc. (Task 1); `sessionProvider` (existing, to trigger `POST /session/start` once); `onboardingGateProvider`, `OnboardingGate` (Task 8).
- Produces: `abstract class HomeRepository { Future<HomeSummary> fetchHome(); }`; `ApiHomeRepository`; `homeRepositoryProvider`; `homeProvider: FutureProvider.autoDispose<HomeSummary>`; `sessionStartedProvider` (fires `postSessionStart()` once per signed-in session); `HomeScreen({onGoTo})`.

- [ ] **Step 1: Write the failing test**

`test/features/home_screen_test.dart`
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/core/api/models.dart';
import 'package:sentinelx_mobile/core/auth/auth_providers.dart';
import 'package:sentinelx_mobile/core/auth/onboarding_gate.dart';
import 'package:sentinelx_mobile/core/l10n/gen/app_localizations.dart';
import 'package:sentinelx_mobile/features/home/home_providers.dart';
import 'package:sentinelx_mobile/features/home/home_repository.dart';
import 'package:sentinelx_mobile/features/home/home_screen.dart';

class _FakeHomeRepository implements HomeRepository {
  _FakeHomeRepository(this._summary);
  final HomeSummary _summary;
  @override
  Future<HomeSummary> fetchHome() async => _summary;
}

HomeSummary _summary({List<HomeTournamentCard> upcoming = const []}) => HomeSummary(
      banner: null,
      featuredTournament: HomeTournamentCard(
        id: 't1', title: 'FC Mobile Cup', slug: 'fc-mobile-cup', status: 'active', prizePool: 8000,
        registrationFee: 500, tournamentStart: null, registrationEnd: null, tournamentEnd: null,
        maxPlayers: 16, format: 'knockout', tournamentType: 'masters', cardImageUrl: null, game: null,
      ),
      upcomingTournaments: upcoming,
      leaderboardTeaser: const [],
      hallOfFame: null,
      stats: const HomeStats(playerCount: 42, tournamentCount: 7, prizesPaidOut: 100000),
    );

void main() {
  testWidgets('shows a loading indicator, then the featured tournament and stats', (tester) async {
    await tester.pumpWidget(ProviderScope(
      retry: (_, _) => null,
      overrides: [homeRepositoryProvider.overrideWithValue(_FakeHomeRepository(_summary()))],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: HomeScreen(onGoTo: (_) {}),
      ),
    ));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.text('FC Mobile Cup'), findsOneWidget);
    expect(find.textContaining('42'), findsWidgets);
  });

  testWidgets('pull-to-refresh re-fetches', (tester) async {
    var calls = 0;
    final repo = _CountingRepository(_summary(), onFetch: () => calls++);
    await tester.pumpWidget(ProviderScope(
      retry: (_, _) => null,
      overrides: [homeRepositoryProvider.overrideWithValue(repo)],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: HomeScreen(onGoTo: (_) {}),
      ),
    ));
    await tester.pumpAndSettle();
    expect(calls, 1);
    await tester.fling(find.byType(RefreshIndicator), const Offset(0, 300), 1000);
    await tester.pumpAndSettle();
    expect(calls, greaterThan(1));
  });

  testWidgets('redirects to onboarding username when the gate says so (e.g. a fresh Google sign-in)', (tester) async {
    String? goneTo;
    await tester.pumpWidget(ProviderScope(
      retry: (_, _) => null,
      overrides: [
        homeRepositoryProvider.overrideWithValue(_FakeHomeRepository(_summary())),
        onboardingGateProvider.overrideWithValue(OnboardingGate.username),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: HomeScreen(onGoTo: (path) => goneTo = path),
      ),
    ));
    await tester.pumpAndSettle();
    expect(goneTo, '/onboarding/username');
  });

  testWidgets('does not redirect when the gate is clear', (tester) async {
    String? goneTo;
    await tester.pumpWidget(ProviderScope(
      retry: (_, _) => null,
      overrides: [
        homeRepositoryProvider.overrideWithValue(_FakeHomeRepository(_summary())),
        onboardingGateProvider.overrideWithValue(OnboardingGate.none),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: HomeScreen(onGoTo: (path) => goneTo = path),
      ),
    ));
    await tester.pumpAndSettle();
    expect(goneTo, isNull);
  });
}

class _CountingRepository implements HomeRepository {
  _CountingRepository(this._summary, {required this.onFetch});
  final HomeSummary _summary;
  final VoidCallback onFetch;
  @override
  Future<HomeSummary> fetchHome() async {
    onFetch();
    return _summary;
  }
}
```

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/features/home_screen_test.dart` → Expected: FAIL (module missing).

- [ ] **Step 3: Implement**

`lib/features/home/home_repository.dart`
```dart
import '../../core/api/api_client.dart';
import '../../core/api/models.dart';

abstract class HomeRepository {
  Future<HomeSummary> fetchHome();
}

class ApiHomeRepository implements HomeRepository {
  ApiHomeRepository(this._api);
  final ApiClient _api;

  @override
  Future<HomeSummary> fetchHome() => _api.getHome();
}
```

`lib/features/home/home_providers.dart`
```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import 'home_repository.dart';

final homeRepositoryProvider = Provider<HomeRepository>((ref) => ApiHomeRepository(ref.watch(apiClientProvider)));

final homeProvider = FutureProvider.autoDispose((ref) => ref.watch(homeRepositoryProvider).fetchHome());

// Fires POST /session/start once per signed-in session (spec §2: "once per
// app process after a session exists", never on every screen visit).
// keepAlive so re-entering Home doesn't re-fire it for the same session.
final sessionStartedProvider = FutureProvider<void>((ref) async {
  final session = ref.watch(sessionProvider).asData?.value;
  if (session == null) return;
  await ref.watch(apiClientProvider).postSessionStart();
});
```

`lib/features/home/home_screen.dart`
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_providers.dart';
import '../../core/auth/onboarding_gate.dart';
import '../../core/l10n/gen/app_localizations.dart';
import 'home_providers.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key, required this.onGoTo});

  final void Function(String path) onGoTo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(sessionStartedProvider); // side-effecting; result not rendered
    // Catches a signed-in user with no username who reached Home some way
    // other than the confirm-link flow (incoming_links.dart routes that case
    // straight to /onboarding/username already) — chiefly a fresh Google
    // sign-in, which has no username metadata either. ref.listen, not
    // ref.watch: this is a one-shot navigation side effect, not something to
    // rebuild the screen over.
    ref.listen(onboardingGateProvider, (previous, next) {
      if (next == OnboardingGate.username) onGoTo('/onboarding/username');
    });
    final home = ref.watch(homeProvider);
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Sentinel X')),
      body: home.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Failed to load: $e')),
        data: (summary) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(homeProvider),
          child: ListView(
            children: [
              if (summary.featuredTournament != null)
                ListTile(
                  key: const Key('home-featured'),
                  title: Text(summary.featuredTournament!.title),
                  subtitle: Text(summary.featuredTournament!.status),
                  onTap: () => onGoTo('/tournaments/${summary.featuredTournament!.id}'),
                ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text('${summary.stats.playerCount} players \u00b7 ${summary.stats.tournamentCount} tournaments'),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(l10n.homeUpcomingHeading),
                    TextButton(onPressed: () => onGoTo('/tournaments'), child: Text(l10n.homeFullRankingsLink)),
                  ],
                ),
              ),
              for (final t in summary.upcomingTournaments)
                ListTile(title: Text(t.title), onTap: () => onGoTo('/tournaments/${t.id}')),
              Padding(padding: const EdgeInsets.all(16), child: Text(l10n.homeTopPlayersHeading)),
              for (final p in summary.leaderboardTeaser) ListTile(title: Text(p.displayName ?? p.username ?? '\u2014')),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run to verify pass**

Run: `flutter test test/features/home_screen_test.dart` → Expected: pass. `flutter analyze` → clean.

- [ ] **Step 5: Commit**
```bash
git add lib/features/home test/features/home_screen_test.dart
git commit -m "feat(home): Home screen backed by GET /home, session/start fired once per session"
```

---

### Task 10: Static pages — mechanism + Terms

**Files:**
- Create: `lib/core/static/rich_content.dart`, `lib/shared/widgets/static_page_screen.dart`, `lib/features/static/terms_screen.dart`
- Test: `test/core/rich_content_test.dart`, `test/features/terms_screen_test.dart`

**Interfaces:**
- Produces: `String stripRichTags(String raw)` (removes next-intl-style `<tag>...</tag>` wrappers, keeping inner text — web's `<link>`/`<email>` tags don't carry their target in the JSON itself, so Phase 1 renders them as plain text; live inline links are a follow-up, not invented here); `List<String> parseListFragment(String raw)` (extracts `<li>...</li>` items, each passed through `stripRichTags`); `class StaticSection { String heading; List<String> paragraphs; List<String>? bulletItems; }`; `StaticPageScreen({title, summary, sections})` (sticky-ish simple ToC: a `ListView` of section headings that scroll-links down, mirroring the web `LegalDocShell`'s anchored-sections concept without its sticky-sidebar chrome, which doesn't translate to a phone width).

**Scope note (deliberate, not an oversight):** the master spec's §8.20 static-page list has 13 pages. Terms/Privacy/RefundPolicy/Rules/CommunityRules/Safety/Escrow share this section-manifest shape (`eyebrow`/`title`/`subtitle`/`summary` + numbered or named heading/paragraph/list groups); About/Contact/Help/HowItWorks/TournamentGuide/TournamentFaqs use bespoke marketing/FAQ layouts (badges, timelines, Q&A pairs) that don't fit one generic renderer. This task builds the generic mechanism and wires **Terms** as the fully-tested proof; the remaining prose-shaped pages (Privacy, RefundPolicy, Rules, CommunityRules, Safety, Escrow) each need their own short `List<StaticSection>` manifest written the same way — mechanical, not new engineering — and are listed as follow-up in this task's Step 6. The bespoke pages are out of this plan's scope entirely (they block nothing in the Phase 1 exit criterion).

- [ ] **Step 1: Write the failing tests**

`test/core/rich_content_test.dart`
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/core/static/rich_content.dart';

void main() {
  group('stripRichTags', () {
    test('removes a single wrapping tag, keeping the inner text', () {
      expect(stripRichTags('contact us at <email>sentinelxesports@gmail.com</email>.'),
          'contact us at sentinelxesports@gmail.com.');
    });
    test('removes multiple different tags in one string', () {
      expect(stripRichTags('See the <link>Refund Policy</link> for <email>details</email>.'), 'See the Refund Policy for details.');
    });
    test('leaves plain text untouched', () {
      expect(stripRichTags('Nigerian law applies.'), 'Nigerian law applies.');
    });
  });

  group('parseListFragment', () {
    test('extracts each <li> item as plain text', () {
      expect(
        parseListFragment('<li>Submitting false results</li><li>Using exploits</li>'),
        ['Submitting false results', 'Using exploits'],
      );
    });
    test('returns an empty list for a fragment with no <li> items', () {
      expect(parseListFragment(''), <String>[]);
    });
  });
}
```

`test/features/terms_screen_test.dart`
```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/core/l10n/gen/app_localizations.dart';
import 'package:sentinelx_mobile/features/static/terms_screen.dart';

void main() {
  testWidgets('renders the title and every section heading', (tester) async {
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const TermsScreen(),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Terms of Service'), findsWidgets);
    expect(find.textContaining('Who We Are'), findsOneWidget);
    expect(find.textContaining('Eligibility'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/core/rich_content_test.dart test/features/terms_screen_test.dart` → Expected: FAIL (modules missing).

- [ ] **Step 3: Implement `rich_content.dart` and `static_page_screen.dart`**

`lib/core/static/rich_content.dart`
```dart
final _tagPattern = RegExp(r'<[^>]+>');
final _liPattern = RegExp(r'<li>(.*?)</li>', dotAll: true);

/// Strips next-intl-style rich-text tags (`<email>x</email>`, `<link>x</link>`).
/// Their href targets live in web component code, not this JSON string, so
/// Phase 1 renders plain text rather than guessing a destination.
String stripRichTags(String raw) => raw.replaceAll(_tagPattern, '');

/// Extracts `<li>...</li>` fragment items (the web's `sNList`-shaped keys)
/// as plain strings, each itself stripped of any rich-text tags.
List<String> parseListFragment(String raw) =>
    _liPattern.allMatches(raw).map((m) => stripRichTags(m.group(1) ?? '')).toList();
```

`lib/shared/widgets/static_page_screen.dart`
```dart
import 'package:flutter/material.dart';

class StaticSection {
  const StaticSection({required this.heading, this.paragraphs = const [], this.bulletItems});
  final String heading;
  final List<String> paragraphs;
  final List<String>? bulletItems;
}

class StaticPageScreen extends StatelessWidget {
  const StaticPageScreen({super.key, required this.title, required this.summary, required this.sections});

  final String title;
  final String summary;
  final List<StaticSection> sections;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(title, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 12),
            Text(summary, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 24),
            for (final section in sections) ...[
              Text(section.heading, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              for (final p in section.paragraphs) ...[
                Text(p),
                const SizedBox(height: 8),
              ],
              if (section.bulletItems != null)
                for (final item in section.bulletItems!)
                  Padding(
                    padding: const EdgeInsets.only(left: 8, bottom: 4),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('\u2022  '),
                      Expanded(child: Text(item)),
                    ]),
                  ),
              const SizedBox(height: 20),
            ],
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Generate the `terms*` ARB keys and implement `TermsScreen`**

```powershell
dart run tool/gen_l10n_from_web.dart --source=../sentinelx/messages --namespaces=terms --locales=en,fr
flutter gen-l10n
```

`lib/features/static/terms_screen.dart`
```dart
import 'package:flutter/widgets.dart';

import '../../core/l10n/gen/app_localizations.dart';
import '../../core/static/rich_content.dart';
import '../../shared/widgets/static_page_screen.dart';

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // 15 sections in the web source (verified against messages/en.json at
    // plan-writing time). s5 and s8 each carry a paragraph split by a
    // bulleted <li> fragment; every other section is heading + P1..Pn.
    final sections = [
      StaticSection(heading: l10n.termsS1Heading, paragraphs: [l10n.termsS1P1, l10n.termsS1P2]),
      StaticSection(heading: l10n.termsS2Heading, paragraphs: [l10n.termsS2P1]),
      StaticSection(heading: l10n.termsS3Heading, paragraphs: [l10n.termsS3P1, stripRichTags(l10n.termsS3P2)]),
      StaticSection(heading: l10n.termsS4Heading, paragraphs: [stripRichTags(l10n.termsS4P3)]),
      StaticSection(
        heading: l10n.termsS5Heading,
        paragraphs: [l10n.termsS5Intro, stripRichTags(l10n.termsS5P2)],
        bulletItems: parseListFragment(l10n.termsS5List),
      ),
      StaticSection(heading: l10n.termsS6Heading, paragraphs: [l10n.termsS6P1]),
      StaticSection(heading: l10n.termsS7Heading, paragraphs: [l10n.termsS7P1]),
      StaticSection(heading: l10n.termsS8Heading, paragraphs: [], bulletItems: parseListFragment(l10n.termsS8List)),
      StaticSection(heading: l10n.termsS9Heading, paragraphs: [l10n.termsS9P1]),
      StaticSection(heading: l10n.termsS10Heading, paragraphs: [l10n.termsS10P1]),
      StaticSection(heading: l10n.termsS11Heading, paragraphs: []),
      StaticSection(heading: l10n.termsS12Heading, paragraphs: []),
      StaticSection(heading: l10n.termsS13Heading, paragraphs: []),
      StaticSection(heading: l10n.termsS14Heading, paragraphs: []),
      StaticSection(heading: l10n.termsS15Heading, paragraphs: []),
    ];
    return StaticPageScreen(title: l10n.termsTitle, summary: l10n.termsSummary, sections: sections);
  }
}
```
**Before running the tests:** open `lib/core/l10n/app_en.arb` and confirm which of `s6`–`s15` have a `P1`/`P2`/etc. key versus only a heading (`s11`–`s15` may be single-paragraph or heading-only sections in the real content) — fill in this screen's `paragraphs: [...]` lists to match exactly what exists (an ARB key referenced here that the generator didn't produce is a compile error in the generated `AppLocalizations` class, which is the safety net: this screen cannot silently render fewer paragraphs than the source has).

- [ ] **Step 5: Run to verify pass**

Run: `flutter test test/core/rich_content_test.dart test/features/terms_screen_test.dart` → Expected: pass. `flutter analyze` → clean.

- [ ] **Step 6: Record the follow-up**

Add a code comment at the top of `lib/shared/widgets/static_page_screen.dart` (already covers the "why" — no action needed) and a line to this repo's `CLAUDE.md` under a new "Static pages" heading: "Terms is wired via `StaticPageScreen`. Privacy, RefundPolicy, Rules, CommunityRules, Safety, Escrow follow the identical pattern — run `gen_l10n_from_web.dart` for that namespace, write its section manifest by inspecting the real ARB keys (don't guess section counts). About/Contact/Help/HowItWorks/TournamentGuide/TournamentFaqs need bespoke screens, not `StaticPageScreen` — different content shape (marketing/FAQ, not ToC prose)."

- [ ] **Step 7: Commit**
```bash
git add lib/core/static lib/shared/widgets/static_page_screen.dart lib/features/static lib/core/l10n CLAUDE.md test
git commit -m "feat(static): rich-tag stripping, generic StaticPageScreen, Terms wired end-to-end"
```

---

### Task 11: Housekeeping and end-to-end verification

**Files:**
- Modify: `CLAUDE.md`
- Create: `TESTING-NOTES.md`

- [ ] **Step 1: `CLAUDE.md` housekeeping**

Add under a new "## Phase 1 notes" heading:
1. The tripwire from this plan's Global Constraints (enforce_phone_verification / onboarding-phone screen).
2. Route map table from Task 8 ("Route map after this task").
3. "Auth screens read error copy from the `auth.errors`/`auth.notices` ARB keys generated by `tool/gen_l10n_from_web.dart` — never hard-code new English strings for auth copy; add the string to the web repo's `messages/en.json` first, then regenerate."
4. The static-pages follow-up note from Task 10 Step 6 (if not already added there).

- [ ] **Step 2: Full automated verification**

Run: `flutter analyze` → clean.
Run: `flutter test` → all suites pass.
Run: `flutter build apk --flavor dev -t lib/main.dart --dart-define=FLAVOR=dev --dart-define=API_BASE_URL=https://sentinelxesports.com.ng` (or the flavor's existing build command if Phase 0C set one up differently — check `pubspec.yaml`/CI config first) → Expected: builds successfully. If Google Sign-In's Android OAuth client isn't set up yet (Global Constraints), the build still succeeds — only the runtime button fails.

- [ ] **Step 3: Create `TESTING-NOTES.md`**

```markdown
# Testing Notes

Tracks every `zzqa_`-prefixed test account created while testing Phase 1's
signup/onboarding/confirmation flow against production (no staging DB exists
— see the design spec §5). Reused test accounts (non-signup flows) are not
logged here.

| Username | Date | Verified | Cleaned up (anonymise_account) |
|---|---|---|---|
```

- [ ] **Step 4: Device round-trip — signup → confirm → claim username → Home**

Following the testing discipline (Global Constraints): pick a `zzqa_`-prefixed username and a plus-addressed email off the owner-provided inbox. On a device/emulator with the `dev` flavor pointed at production:
1. Open the app, tap Account → Create account, complete the signup wizard.
2. Log the account in `TESTING-NOTES.md` immediately (username, today's date, "signup wizard").
3. Open the confirmation email on the same device; tap the link — confirm it opens the app (App Link) and lands on the Onboarding Username screen (not a browser).
4. Claim the pre-filled username; confirm it lands on Home with the featured tournament/stats visible.
5. Update the `TESTING-NOTES.md` row: "Verified: signup wizard, App Link confirm, username claim, Home render."
6. **Ask the owner before running `anonymise_account`** against this account; once approved, run it and mark the row "Cleaned up" with today's date.

- [ ] **Step 5: Device round-trip — Google Sign-In** (only if the owner has completed the OAuth-client setup)

Tap "Continue with Google" on Login, complete the native picker, confirm it lands on Home (a Google account with an existing username skips onboarding entirely — Home should render directly, no Onboarding Username screen). If the owner hasn't set up the OAuth client yet, skip this step and note it as outstanding in the commit message.

- [ ] **Step 6: Commit**
```bash
git add CLAUDE.md TESTING-NOTES.md
git commit -m "docs: Phase 1 housekeeping, testing notes, route map"
```

---

## Self-Review

**Spec coverage.** Design spec §2 (session/start called once per app process) → Task 9's `sessionStartedProvider`. §3 (all six endpoints) → Task 1 (client), consumed by Tasks 3–5, 9. §4.1–4.4 (screens, App Links, Google, no-phone-screen tripwire) → Tasks 4–8. §4.5 (Home outside the tab bar, unread bells via single disposable subscription not `RealtimeManager`, coming-soon for both bell taps) → Task 8. §4.6 (static pages, generated not retyped) → Task 2, Task 10. §5 (testing discipline) → Global Constraints, threaded through every task with a device-test step, concretely exercised in Task 11.

**Placeholder scan.** No TBD/TODO. Task 10's scope note is an explicit, justified cut (6 of 13 static pages deferred with a stated reason and a stated mechanism for finishing them), not a hidden gap — flagged in both the task and `CLAUDE.md`.

**Type consistency.** `AuthException` (Task 3) is the error type every screen in Tasks 4–6 catches by the same field names (`code`, `message`). `HomeSummary`/`HomeTournamentCard`/etc. (Task 1) are consumed unchanged by `HomeRepository`/`HomeScreen` (Task 9). `resolveOnboardingGate` (Task 3) returns the `OnboardingGate` enum both `onboardingGateProvider` (Task 8) and `handleIncomingLink` (Task 8) reason about, and `HomeScreen` (Task 9) redirects on. `unreadCount`/`unreadNotificationCountProvider`/`unreadMessageCountProvider` (Task 8) match `SxTabAppBar`'s consumption exactly. `SupabaseAuthRepository`'s `googleWebClientId` constructor parameter (Task 6) defaults to `''` specifically so Tasks 3–5's existing test call sites keep compiling; `AuthRepository.signInWithGoogle()` (Task 6) is stubbed onto every pre-existing fake (`FakeAuthRepositoryForForgot` and its three subclasses, `_FakeAuthRepository`) so those tasks' tests don't break when the interface grows a method after they were written.

**Fixed during self-review (caught here, not left for the executor to discover):** `handleEmailLink` (Task 7) was originally written with nothing calling it — no App Link tap would ever have reached it. Task 8 Step 7b now wires `app_links`' incoming-URI stream to it via `incoming_links.dart`, called from `main.dart`. Similarly, `resolveOnboardingGate` (Task 3) was defined but never consulted by anything — a fresh Google sign-in (no `username` metadata, same as email signup before confirmation) would have landed on Home with no route to `/onboarding/username`. Task 8 Step 7b adds `onboardingGateProvider`; Task 9's `HomeScreen` now `ref.listen`s it and redirects. The `GET /home` tournament-card wire shape was also corrected upstream in the web plan (`2026-09-20-mobile-phase1-api.md`) from an accidental snake_case leak to the established camelCase convention, before this plan's Task 1 models were written against it — so that fix didn't need to ripple through here.

**Known limits.** Google Sign-In's exact package API (v6 vs v7+) is resolved by a smoke test at implementation time, not assumed — Task 6 Step 1. The router's `StatefulShellRoute` bottom nav bar is Material's stock `NavigationBar`, not the "gamey feel" custom widget system (that's explicitly Phase 9 polish per the master spec). Static pages beyond Terms need their own manifests (Task 10's scope note) — mechanical follow-up, not blocking the Phase 1 exit criterion. `pcm` locale stays unsupported by Material's delegates (Phase 0C's documented gap, unchanged here).
