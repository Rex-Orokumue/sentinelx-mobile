# Mobile Phase 3a (Flutter) — Rankings / Seasons / Hall of Fame Screens Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship Rankings, Seasons and Hall of Fame screens in the Flutter app, backed by the five Phase 3a web endpoints, showing the same numbers as the web pages.

**Architecture:** Hand-written `ApiClient` methods + plain-Dart models with `fromJson`, one `Repository` per feature behind a Riverpod `Provider`, screens are `ConsumerWidget`s reading `FutureProvider`s. New feature folders only; shared files are touched by *appended lines* only (parallel Phase 2b work is editing the same repo).

**Tech Stack:** Flutter (stable), Dart ^3.11, `flutter_riverpod` ^3.3 (manual providers, no codegen), `go_router`, `dio`, `flutter_test`.

**Spec:** `docs/superpowers/specs/2026-09-23-mobile-phase3a-rankings-seasons-hof-design.md` **in the web repo** (`C:\Users\gorok\Videos\sentinelx`). Read it and `CLAUDE.md` in *this* repo first. The web-side plan is `docs/superpowers/plans/2026-09-23-mobile-phase3a-web-api.md` (same web repo) — the endpoints this plan calls are built there (PR 2). Wire shapes are defined by `lib/mobile-api/endpoints/progress-schemas.ts` in the web repo; Task 1's models must match it field-for-field.

## Global Constraints

- **All reads go through `ApiClient`** (`/api/mobile/v1/*`); never read Supabase/PostgREST directly for these screens. Screens never construct a repository or `ApiClient` — they read providers.
- **Every new `ApiClient` method must be listed in `ApiClient.usedOperations`** (operationId → `'method /api/mobile/v1/path'`); `test/core/api_contract_test.dart` checks each against `api/openapi.json`. `api/openapi.json` is a **copy** of the web repo's `openapi/mobile-v1.json` — copy it, never hand-edit it.
- **Copy is never hard-coded in widgets.** Web has no i18n namespace for these three pages (verified: `messages/en.json` only has the nav labels `rankings`/`seasons`/`hallOfFame`), so add the new keys **directly to `lib/core/l10n/app_en.arb`** (the template) and run `flutter gen-l10n`; never edit `lib/core/l10n/gen/*` by hand. Do not add them to `app_fr.arb` (gen-l10n falls back to the template).
- **Do not touch the temporary tournaments slice** (`lib/data`, `lib/models`, `lib/features/tournaments`) — Phase 2a/2b are replacing it. Routes for this phase are added *inside the Compete branch* of the router, but no tournaments file is edited.
- **New models live in `lib/core/api/progress_models.dart`**, not `models.dart`. Edits to `api_client.dart` and `app_router.dart` are **appended lines / new routes only**.
- **Mobile-first at 375px**; no horizontal overflow. Use `SxColors` (`lib/core/theme/sx_colors.dart`); no new colors.
- **Tombstones:** `PlayerCard.isDeleted == true` renders as a neutral "Deleted player" row (ARB key `commonDeletedPlayer`), never a blank/crash.
- **Before every commit:** `flutter analyze` (no issues) and `flutter test` (all pass). Regenerate l10n after ARB edits and commit the generated output.
- **Testing against production is forbidden**; use the staging deployment / a local fake. No writes exist in this phase.
- Use American spelling in new prose/code.

## Coordination (shared-file hotspots)

Phase 2b is being built concurrently in this same repo by another agent. Work in your own worktree (`git worktree add ../sentinelx_mobile-p3a -b phase3a/screens origin/master` — default branch is `master`). Hotspots: `lib/core/api/api_client.dart` (append methods and `usedOperations` lines at the end of their blocks), `api/openapi.json` (re-copy, never merge text), `lib/router/app_router.dart` (add routes only), ARB + generated l10n (regenerate after rebase), `lib/features/home/home_screen.dart` (Task 8 adds three list tiles only). Rebase onto `origin/master` before the final run of the checks.

---

## File Structure

| File | Responsibility |
|---|---|
| `lib/core/api/progress_models.dart` (create) | `PlayerCard`, `RankingRow`, `RankingsPage`, `RankingsScope`, `GameChip`, `Highlights`, `SeasonSummary`, `SeasonDetail`, `SeasonGame`, `HallOfFame*` — `fromJson` only |
| `lib/core/api/api_client.dart` (modify, append) | `getRankings`, `getRankingsMe`, `getSeasons`, `getSeasonDetail`, `getHallOfFame` + `usedOperations` entries |
| `lib/features/rankings/{rankings_repository,rankings_providers,rankings_screen}.dart` (create) | Rankings feature |
| `lib/features/seasons/{seasons_repository,seasons_providers,seasons_list_screen,season_detail_screen}.dart` (create) | Seasons feature |
| `lib/features/hall_of_fame/{hall_of_fame_repository,hall_of_fame_providers,hall_of_fame_screen}.dart` (create) | Hall of fame feature |
| `lib/shared/widgets/player_avatar.dart` (create) | Avatar + optional frame + tombstone handling shared by all three |
| `lib/core/l10n/app_en.arb` (modify) | New keys |
| `lib/router/app_router.dart` (modify) | Add `/rankings`, `/seasons`, `/seasons/:slug`, `/hall-of-fame` inside the Compete branch |
| `lib/core/routing/web_links.dart` (modify) | Map the same web paths |
| `lib/features/home/home_screen.dart` (modify) | Three entry tiles |
| `test/…` beside each (create) | Model, client, provider, widget, routing tests |
| `docs/agent-handoffs/…` | (written separately) |

---

### Task 1: Worktree, contract refresh, models

**Files:**
- Create: `lib/core/api/progress_models.dart`, `test/core/progress_models_test.dart`
- Modify: `api/openapi.json` (re-copy)

**Interfaces:**
- Produces (all in `progress_models.dart`; every class has `factory X.fromJson(Map<String, dynamic> j)`):

```dart
class PlayerCard { String id; String? username; String? displayName; String? avatarUrl; String? frameUrl;
  String? country; int sxScore; String? sentinelTier; String membershipTier; bool kycVerified; bool isDeleted;
  String get label; }                                   // displayName ?? username ?? '' (empty for tombstones)
class Trend { String direction; int delta; }             // direction: up|down|flat|new
class RankingRow { int rank; PlayerCard player; int wins; int losses; int totalMatches; double winRate;
  int goalsScored; int goalsConceded; int goalDiff; int totalTitles; Trend trend; int streak; }
class GameChip { String id; String slug; String name; String category; }
class RankingsScope { String? game; String? region; String metric; }   // metric: score|wins
class PageInfo { int page; int totalPages; int total; int perPage; }
class RankingsStats { int playersRanked; int gamesIncluded; int totalMatches; num prizesAwarded; }
class Highlights { PlayerCard? topScore; PlayerCard? topTitles; PlayerCard? topWinRate; PlayerCard? topStreak; int topStreakValue; }
class RankingsPage { RankingsScope scope; List<RankingRow> rows; PageInfo page; List<GameChip> games;
  List<String> regions; RankingsStats stats; Highlights highlights; }
class RankingsMe { RankingRow? row; }
class SeasonSummary { String id; String slug; String name; String startDate; String endDate; }
class SeasonTournament { String id; String title; String slug; String tournamentType; String status;
  String? tournamentStart; bool invitationOnly; }
class SeasonLeaderboardRow { String playerId; String? username; String? displayName; String? avatarUrl;
  int sxScore; int points; bool isProvisional; }
class SeasonTierLabels { String communityClub; String masters; String qualificationNote; bool showChampionsCupSpotlight; }
class SeasonGame { String gameId; String gameName; String gameSlug; List<SeasonTournament> tournaments;
  List<SeasonLeaderboardRow> leaderboard; SeasonTierLabels tierLabels; }
class SeasonDetail { SeasonSummary season; List<SeasonGame> games; }
class Placing { String id; String name; }
class HofChampion { String tournamentId; String slug; String title; String tournamentType; String gameId;
  String gameName; String? date; num? prizePool; Placing champion; Placing? runnerUp;
  String? championAvatarUrl; String? seasonName; }
class AwardOption { String? gameId; String gameLabel; PlayerCard? winner; num metricValue; }
class CategoryAward { String category; String label; String metricLabel; List<AwardOption> options; }
class HofAwards { PlayerCard? mvp; List<AwardOption> goldenBoot; List<CategoryAward> categories; }
class HofChampions { List<HofChampion> championsCup; List<HofChampion> masters; List<HofChampion> communityClub; List<HofChampion> open; }
class BronzeFinish { String tournamentId; String slug; String title; String? gameName; String? date; Placing player; }
class HallOfFame { List<GameChip> games; String? selectedGame; HofAwards awards; HofChampions champions; List<BronzeFinish> bronze; }
```
Numbers arrive as JSON `num`; parse ints with `(j['x'] as num).toInt()` like `models.dart` does. `Placing` must match the web schema exactly — before writing it, open `lib/mobile-api/endpoints/progress-schemas.ts` in the web repo and copy the final field set (Task 9 of the web plan may have added fields).

- [ ] **Step 1: Worktree and baseline**

```bash
cd C:\Users\gorok\sentinelx_mobile
git fetch origin
git worktree add ..\sentinelx_mobile-p3a -b phase3a/screens origin/master
cd ..\sentinelx_mobile-p3a
flutter pub get
flutter analyze && flutter test
```
Expected: clean and green. If not, stop and report; do not build on a red base.

- [ ] **Step 2: Get the contract**

The endpoints exist in the web repo's `openapi/mobile-v1.json` only after web PR 2 merges (or on its branch `phase3a/api`). Copy the current file:

```bash
copy C:\Users\gorok\Videos\sentinelx\openapi\mobile-v1.json api\openapi.json
```
(If the web PR is not merged yet, copy from the web worktree on branch `phase3a/api` instead. Confirm with `findstr /c:"getRankings" api\openapi.json` — it must be present.)

- [ ] **Step 3: Write the failing model tests**

```dart
// test/core/progress_models_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/core/api/progress_models.dart';

const _card = {
  'id': 'p1', 'username': 'ada', 'displayName': 'Ada', 'avatarUrl': null, 'frameUrl': null, 'country': 'NG',
  'sxScore': 980, 'sentinelTier': 'trusted', 'membershipTier': 'bronze', 'kycVerified': true, 'isDeleted': false,
};

Map<String, dynamic> _row(int rank) => {
      'rank': rank, 'player': _card, 'wins': 5, 'losses': 2, 'totalMatches': 7, 'winRate': 0.7142857,
      'goalsScored': 20, 'goalsConceded': 8, 'goalDiff': 12, 'totalTitles': 1,
      'trend': {'direction': 'up', 'delta': 2}, 'streak': 3,
    };

void main() {
  test('RankingsPage parses rows, scope, chips, stats and highlights', () {
    final page = RankingsPage.fromJson({
      'scope': {'game': null, 'region': null, 'metric': 'score'},
      'rows': [_row(1), _row(2)],
      'page': {'page': 1, 'totalPages': 3, 'total': 25, 'perPage': 10},
      'games': [{'id': 'g1', 'slug': 'dls', 'name': 'Dream League Soccer', 'category': 'football'}],
      'regions': ['GH', 'NG'],
      'stats': {'playersRanked': 25, 'gamesIncluded': 1, 'totalMatches': 100, 'prizesAwarded': 50000},
      'highlights': {'topScore': _card, 'topTitles': null, 'topWinRate': null, 'topStreak': null, 'topStreakValue': 4},
    });
    expect(page.rows.map((r) => r.rank), [1, 2]);
    expect(page.rows.first.trend.direction, 'up');
    expect(page.page.totalPages, 3);
    expect(page.scope.metric, 'score');
    expect(page.highlights.topScore?.label, 'Ada');
    expect(page.highlights.topTitles, isNull);
  });

  test('PlayerCard tombstone has an empty label', () {
    final c = PlayerCard.fromJson({..._card, 'username': null, 'displayName': null, 'isDeleted': true});
    expect(c.isDeleted, isTrue);
    expect(c.label, '');
  });

  test('RankingsMe accepts a null row', () {
    expect(RankingsMe.fromJson({'row': null}).row, isNull);
    expect(RankingsMe.fromJson({'row': _row(4)}).row?.rank, 4);
  });

  test('SeasonDetail parses per-game sections with provisional rows', () {
    final d = SeasonDetail.fromJson({
      'season': {'id': 's1', 'slug': 'season-1', 'name': 'Season 1', 'startDate': '2026-08-01', 'endDate': '2026-10-31'},
      'games': [
        {
          'gameId': 'g1', 'gameName': 'Dream League Soccer', 'gameSlug': 'dls',
          'tournaments': [
            {'id': 't1', 'title': 'Masters Sept', 'slug': 'masters-sept', 'tournamentType': 'masters', 'status': 'completed', 'tournamentStart': null, 'invitationOnly': true},
          ],
          'leaderboard': [
            {'playerId': 'p1', 'username': 'ada', 'displayName': 'Ada', 'avatarUrl': null, 'sxScore': 1200, 'points': 40, 'isProvisional': true},
          ],
          'tierLabels': {'communityClub': 'Community Clubs', 'masters': 'Masters', 'qualificationNote': 'Top 16 earn an invitation.', 'showChampionsCupSpotlight': true},
        },
      ],
    });
    expect(d.games.single.leaderboard.single.isProvisional, isTrue);
    expect(d.games.single.tournaments.single.invitationOnly, isTrue);
    expect(d.games.single.tierLabels.masters, 'Masters');
  });

  test('HallOfFame parses awards, grouped champions and bronze finishes', () {
    final champ = {
      'tournamentId': 't1', 'slug': 'masters-sept', 'title': 'Masters Sept', 'tournamentType': 'masters', 'gameId': 'g1',
      'gameName': 'Dream League Soccer', 'date': '2026-09-20', 'prizePool': 10000,
      'champion': {'id': 'p1', 'name': 'Ada'}, 'runnerUp': null, 'championAvatarUrl': null, 'seasonName': 'Season 1',
    };
    final h = HallOfFame.fromJson({
      'games': [], 'selectedGame': null,
      'awards': {
        'mvp': _card,
        'goldenBoot': [{'gameId': null, 'gameLabel': 'All Goals', 'winner': _card, 'metricValue': 40}],
        'categories': [],
      },
      'champions': {'championsCup': [], 'masters': [champ], 'communityClub': [], 'open': []},
      'bronze': [{'tournamentId': 't1', 'slug': 'masters-sept', 'title': 'Masters Sept', 'gameName': null, 'date': null, 'player': {'id': 'p3', 'name': 'Chidi'}}],
    });
    expect(h.awards.mvp?.label, 'Ada');
    expect(h.champions.masters.single.champion.name, 'Ada');
    expect(h.champions.masters.single.runnerUp, isNull);
    expect(h.bronze.single.player.name, 'Chidi');
  });
}
```

- [ ] **Step 4: Run to fail**

Run: `flutter test test/core/progress_models_test.dart`
Expected: FAIL — `progress_models.dart` does not exist.

- [ ] **Step 5: Implement `progress_models.dart`**

Write the classes listed in **Interfaces**, each in the style of `lib/core/api/models.dart` (const constructor with `required` named params, `factory fromJson`, `final` fields). Worked pattern to copy for every class:

```dart
class PlayerCard {
  const PlayerCard({
    required this.id, required this.username, required this.displayName, required this.avatarUrl,
    required this.frameUrl, required this.country, required this.sxScore, required this.sentinelTier,
    required this.membershipTier, required this.kycVerified, required this.isDeleted,
  });

  factory PlayerCard.fromJson(Map<String, dynamic> j) => PlayerCard(
        id: j['id'] as String,
        username: j['username'] as String?,
        displayName: j['displayName'] as String?,
        avatarUrl: j['avatarUrl'] as String?,
        frameUrl: j['frameUrl'] as String?,
        country: j['country'] as String?,
        sxScore: (j['sxScore'] as num).toInt(),
        sentinelTier: j['sentinelTier'] as String?,
        membershipTier: j['membershipTier'] as String,
        kycVerified: j['kycVerified'] as bool,
        isDeleted: j['isDeleted'] as bool,
      );

  final String id;
  final String? username;
  final String? displayName;
  final String? avatarUrl;
  final String? frameUrl;
  final String? country;
  final int sxScore;
  final String? sentinelTier;
  final String membershipTier;
  final bool kycVerified;
  final bool isDeleted;

  String get label => displayName ?? username ?? '';
}
```
Lists parse as `(j['rows'] as List<dynamic>).map((e) => RankingRow.fromJson(e as Map<String, dynamic>)).toList()`; nullable objects as `j['x'] == null ? null : X.fromJson(j['x'] as Map<String, dynamic>)`. `winRate` is `(j['winRate'] as num).toDouble()`. `prizesAwarded`/`prizePool`/`metricValue` stay `num`.

- [ ] **Step 6: Run to green, analyze, commit**

```bash
flutter test test/core/progress_models_test.dart
flutter analyze
git add api/openapi.json lib/core/api/progress_models.dart test/core/progress_models_test.dart
git commit -m "feat(api): progress models for rankings/seasons/hall of fame

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

### Task 2: `ApiClient` methods + contract entries

**Files:**
- Modify: `lib/core/api/api_client.dart` (append methods; append `usedOperations` entries)
- Test: `test/core/api_client_progress_test.dart` (create)

**Interfaces:**
- Consumes: models from Task 1.
- Produces:

```dart
Future<RankingsPage> getRankings({String? game, String? region, int page = 1});
Future<RankingsMe> getRankingsMe({String? game, String? region});
Future<List<SeasonSummary>> getSeasons();
Future<SeasonDetail> getSeasonDetail(String slug);
Future<HallOfFame> getHallOfFame({String? game});
```

- [ ] **Step 1: Failing test** (reuse the `_FakeAdapter`/`_json`/`_client` pattern from `test/core/api_client_test.dart` — copy those three helpers into the new file, do not import from the other test)

```dart
// test/core/api_client_progress_test.dart
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
    ResponseBody.fromString(jsonEncode(body), status, headers: {Headers.contentTypeHeader: [Headers.jsonContentType]});

ApiClient _client(_FakeAdapter a, {String? token = 'tok'}) => ApiClient.create(
      baseUrl: 'https://api.test', appVersion: '1.2.3', platform: 'android', accessToken: () async => token, adapter: a);

const _emptyPage = {
  'scope': {'game': 'dls', 'region': null, 'metric': 'wins'}, 'rows': [],
  'page': {'page': 2, 'totalPages': 2, 'total': 11, 'perPage': 10}, 'games': [], 'regions': [],
  'stats': {'playersRanked': 11, 'gamesIncluded': 1, 'totalMatches': 5, 'prizesAwarded': 0},
  'highlights': {'topScore': null, 'topTitles': null, 'topWinRate': null, 'topStreak': null, 'topStreakValue': 0},
};

void main() {
  test('getRankings sends only the set query params', () async {
    final adapter = _FakeAdapter((_) => _json(200, {'data': _emptyPage}));
    final page = await _client(adapter).getRankings(game: 'dls', page: 2);
    expect(page.scope.metric, 'wins');
    final uri = adapter.requests.single.uri;
    expect(uri.path, '/api/mobile/v1/rankings');
    expect(uri.queryParameters, {'game': 'dls', 'page': '2'});
  });

  test('getRankingsMe hits /rankings/me with the bearer token', () async {
    final adapter = _FakeAdapter((_) => _json(200, {'data': {'row': null}}));
    final me = await _client(adapter).getRankingsMe(region: 'NG');
    expect(me.row, isNull);
    expect(adapter.requests.single.uri.path, '/api/mobile/v1/rankings/me');
    expect(adapter.requests.single.headers['Authorization'], 'Bearer tok');
  });

  test('getSeasons and getSeasonDetail use the documented paths', () async {
    final adapter = _FakeAdapter((o) => o.uri.path.endsWith('/seasons')
        ? _json(200, {'data': {'seasons': [{'id': 's1', 'slug': 'season-1', 'name': 'Season 1', 'startDate': '2026-08-01', 'endDate': '2026-10-31'}]}})
        : _json(404, {'error': {'code': 'not_found', 'message': 'Not found.'}}));
    final api = _client(adapter);
    expect((await api.getSeasons()).single.slug, 'season-1');
    await expectLater(api.getSeasonDetail('nope'), throwsA(isA<ApiException>().having((e) => e.status, 'status', 404)));
    expect(adapter.requests.last.uri.path, '/api/mobile/v1/seasons/nope');
  });

  test('getHallOfFame passes the optional game filter', () async {
    final adapter = _FakeAdapter((_) => _json(200, {'data': {
      'games': [], 'selectedGame': 'dls',
      'awards': {'mvp': null, 'goldenBoot': [], 'categories': []},
      'champions': {'championsCup': [], 'masters': [], 'communityClub': [], 'open': []}, 'bronze': [],
    }}));
    final h = await _client(adapter).getHallOfFame(game: 'dls');
    expect(h.selectedGame, 'dls');
    expect(adapter.requests.single.uri.queryParameters, {'game': 'dls'});
  });
}
```

- [ ] **Step 2:** `flutter test test/core/api_client_progress_test.dart` → FAIL (methods missing).

- [ ] **Step 3: Implement (append to the class, after the last existing method)**

```dart
  String _withQuery(String path, Map<String, Object?> query) {
    final q = <String, String>{
      for (final e in query.entries)
        if (e.value != null) e.key: e.value.toString(),
    };
    return q.isEmpty ? path : Uri(path: path, queryParameters: q).toString();
  }

  Future<RankingsPage> getRankings({String? game, String? region, int page = 1}) => _send(
        'GET',
        _withQuery('/rankings', {'game': game, 'region': region, 'page': page > 1 ? page : null}),
        (d) => RankingsPage.fromJson(d! as Map<String, dynamic>),
      );

  Future<RankingsMe> getRankingsMe({String? game, String? region}) => _send(
        'GET',
        _withQuery('/rankings/me', {'game': game, 'region': region}),
        (d) => RankingsMe.fromJson(d! as Map<String, dynamic>),
      );

  Future<List<SeasonSummary>> getSeasons() => _send(
        'GET',
        '/seasons',
        (d) => ((d! as Map<String, dynamic>)['seasons'] as List<dynamic>)
            .map((e) => SeasonSummary.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  Future<SeasonDetail> getSeasonDetail(String slug) =>
      _send('GET', '/seasons/${Uri.encodeComponent(slug)}', (d) => SeasonDetail.fromJson(d! as Map<String, dynamic>));

  Future<HallOfFame> getHallOfFame({String? game}) => _send(
        'GET',
        _withQuery('/hall-of-fame', {'game': game}),
        (d) => HallOfFame.fromJson(d! as Map<String, dynamic>),
      );
```
Add `import 'progress_models.dart';` next to the existing `import 'models.dart';`. Append to `usedOperations`, after the last entry:

```dart
    'getRankings': 'get /api/mobile/v1/rankings',
    'getRankingsMe': 'get /api/mobile/v1/rankings/me',
    'getSeasons': 'get /api/mobile/v1/seasons',
    'getSeasonDetail': 'get /api/mobile/v1/seasons/{slug}',
    'getHallOfFame': 'get /api/mobile/v1/hall-of-fame',
```

- [ ] **Step 4:** `flutter test test/core` → PASS, including `api_contract_test.dart` (proves the copy of `openapi.json` from Task 1 contains all five operations with these exact method/path strings).
- [ ] **Step 5:** `flutter analyze`, commit `feat(api): rankings/seasons/hall-of-fame client methods` (with the Co-Authored-By trailer).

---

### Task 3: Shared avatar widget + copy keys

**Files:**
- Create: `lib/shared/widgets/player_avatar.dart`, `test/shared/player_avatar_test.dart`
- Modify: `lib/core/l10n/app_en.arb` (+ regenerate)

**Interfaces:**
- Produces: `PlayerAvatar({Key? key, String? avatarUrl, String? frameUrl, bool isDeleted = false, double size = 40})`.
- Produces ARB keys (all consumed by Tasks 4–7):

| Key | English |
|---|---|
| `commonDeletedPlayer` | `Deleted player` |
| `rankingsTitle` | `Leaderboards` |
| `rankingsRankByScore` | `Ranked by SX Score` |
| `rankingsRankByWins` | `Ranked by wins` |
| `rankingsAllGames` | `All games` |
| `rankingsAllRegions` | `All regions` |
| `rankingsWinsCount` (`{wins}`) | `{wins} wins` |
| `rankingsMatchesCount` (`{matches}`) | `{matches} matches` |
| `rankingsStreakValue` (`{n}`) | `{n}-win streak` |
| `rankingsYourRank` | `Your rank` |
| `rankingsPageOf` (`{page}`,`{total}`) | `Page {page} of {total}` |
| `rankingsPrev` / `rankingsNext` | `Previous` / `Next` |
| `rankingsEmpty` | `No ranked players yet.` |
| `rankingsErrorRetry` | `Couldn't load. Tap to retry.` |
| `rankingsPlayersRanked` (`{n}`) | `{n} players ranked` |
| `rankingsTrendNew` | `New` |
| `seasonsTitle` | `Seasons` |
| `seasonsEmpty` | `No seasons yet.` |
| `seasonsProvisional` | `Provisional` |
| `seasonsProvisionalNote` | `Points can still change while tournaments are in progress.` |
| `seasonsPoints` (`{n}`) | `{n} pts` |
| `seasonsTournaments` | `Tournaments` |
| `seasonsInviteOnly` | `Invite only` |
| `seasonsYou` | `You` |
| `hallOfFameTitle` | `Hall of Fame` |
| `hallOfFameMvp` | `All-Time MVP` |
| `hallOfFameGoldenBoot` | `Golden Boot` |
| `hallOfFameChampionsCup` | `Champions Cup` |
| `hallOfFameMasters` | `Masters` |
| `hallOfFameCommunityClub` | `Community Club` |
| `hallOfFameOpen` | `Open tournaments` |
| `hallOfFameBronze` | `Bronze finishes` |
| `hallOfFameRunnerUp` (`{name}`) | `Runner-up: {name}` |
| `hallOfFameEmpty` | `Nothing here yet.` |

Placeholder keys need the `@key` metadata block, exactly like `updateRequiredBody` in `app_en.arb`:

```json
  "rankingsWinsCount": "{wins} wins",
  "@rankingsWinsCount": { "placeholders": { "wins": { "type": "int" } } },
```
(`rankingsMatchesCount` → `matches: int`; `rankingsStreakValue` → `n: int`; `rankingsPageOf` → `page: int`, `total: int`; `rankingsPlayersRanked` → `n: int`; `seasonsPoints` → `n: int`; `hallOfFameRunnerUp` → `name: String`.)

- [ ] **Step 1: Failing widget test**

```dart
// test/shared/player_avatar_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/shared/widgets/player_avatar.dart';

void main() {
  testWidgets('deleted accounts show a neutral placeholder, never a network image', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: PlayerAvatar(avatarUrl: 'https://x/a.png', isDeleted: true))));
    expect(find.byKey(const Key('avatar-placeholder')), findsOneWidget);
    expect(find.byType(Image), findsNothing);
  });

  testWidgets('missing avatar url falls back to the placeholder', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: PlayerAvatar(avatarUrl: null))));
    expect(find.byKey(const Key('avatar-placeholder')), findsOneWidget);
  });
}
```

- [ ] **Step 2:** `flutter test test/shared/player_avatar_test.dart` → FAIL.
- [ ] **Step 3: Implement**

```dart
// lib/shared/widgets/player_avatar.dart
import 'package:flutter/material.dart';

import '../../core/theme/sx_colors.dart';

/// Circular avatar with an optional equipped frame overlay. Deleted accounts and missing images
/// render the same neutral placeholder — never a blank box or a broken-image icon.
class PlayerAvatar extends StatelessWidget {
  const PlayerAvatar({super.key, required this.avatarUrl, this.frameUrl, this.isDeleted = false, this.size = 40});

  final String? avatarUrl;
  final String? frameUrl;
  final bool isDeleted;
  final double size;

  @override
  Widget build(BuildContext context) {
    final showImage = !isDeleted && avatarUrl != null && avatarUrl!.isNotEmpty;
    final placeholder = Container(
      key: const Key('avatar-placeholder'),
      width: size,
      height: size,
      decoration: const BoxDecoration(color: SxColors.surface, shape: BoxShape.circle),
      child: Icon(Icons.person, size: size * 0.55, color: SxColors.textSecondary),
    );
    return SizedBox(
      width: size,
      height: size,
      child: Stack(alignment: Alignment.center, children: [
        ClipOval(
          child: showImage
              ? Image.network(avatarUrl!, width: size, height: size, fit: BoxFit.cover, errorBuilder: (_, _, _) => placeholder)
              : placeholder,
        ),
        if (!isDeleted && frameUrl != null)
          IgnorePointer(child: Image.network(frameUrl!, width: size * 1.25, height: size * 1.25, errorBuilder: (_, _, _) => const SizedBox.shrink())),
      ]),
    );
  }
}
```
Web `frameUrl` values are site-relative paths (e.g. `/frames/gold.webp`); resolve them against `appConfigProvider`'s site URL only if they start with `/` — do that resolution in the *screens* via a tiny helper `resolveAsset(String? path, String siteUrl)` placed at the bottom of this file and covered by a one-line test (`'/x.webp'` + `'https://s.test'` → `'https://s.test/x.webp'`; absolute URLs pass through; null stays null). Screens pass `resolveAsset(card.frameUrl, siteUrl)`.

- [ ] **Step 4:** Add the ARB keys from the table (English only), then `flutter gen-l10n`. Run `flutter test` (the existing `test/core/l10n_test.dart` must still pass) and `flutter analyze`.
- [ ] **Step 5:** Commit `feat(shared): PlayerAvatar + rankings/seasons/hall-of-fame copy` (include regenerated `lib/core/l10n/gen/*`).

---

### Task 4: Rankings feature

**Files:**
- Create: `lib/features/rankings/rankings_repository.dart`, `lib/features/rankings/rankings_providers.dart`, `lib/features/rankings/rankings_screen.dart`
- Test: `test/features/rankings_screen_test.dart`

**Interfaces:**
- Consumes: `apiClientProvider`, `meProvider` (`lib/core/providers.dart`), `ApiClient.getRankings/getRankingsMe`, `PlayerAvatar`, ARB keys.
- Produces:

```dart
abstract class RankingsRepository {
  Future<RankingsPage> fetch(RankingsQuery q);
  Future<RankingsMe> fetchMe(RankingsQuery q);
}
class RankingsQuery { const RankingsQuery({this.game, this.region, this.page = 1}); final String? game; final String? region; final int page;
  RankingsQuery copyWith({Object? game = _keep, Object? region = _keep, int? page}); }   // == / hashCode by value
final rankingsRepositoryProvider = Provider<RankingsRepository>(...);
final rankingsQueryProvider = NotifierProvider.autoDispose<RankingsQueryNotifier, RankingsQuery>(RankingsQueryNotifier.new);
final rankingsProvider = FutureProvider.autoDispose<RankingsPage>((ref) => ref.watch(rankingsRepositoryProvider).fetch(ref.watch(rankingsQueryProvider)));
final rankingsMeProvider = FutureProvider.autoDispose<RankingsMe?>(...);   // null (no request) when signed out
class RankingsScreen extends ConsumerWidget { const RankingsScreen({super.key, required this.onGoTo}); final void Function(String path) onGoTo; }
```

Behavior: changing `game` or `region` resets `page` to 1; `page` changes keep filters. `rankingsMeProvider` returns `null` **without calling the API** when `meProvider` has no user (signed out).

- [ ] **Step 1: Failing tests**

```dart
// test/features/rankings_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/core/api/models.dart';
import 'package:sentinelx_mobile/core/api/progress_models.dart';
import 'package:sentinelx_mobile/core/l10n/gen/app_localizations.dart';
import 'package:sentinelx_mobile/core/providers.dart';
import 'package:sentinelx_mobile/features/rankings/rankings_providers.dart';
import 'package:sentinelx_mobile/features/rankings/rankings_repository.dart';
import 'package:sentinelx_mobile/features/rankings/rankings_screen.dart';

PlayerCard _card(String id, String? name, {bool deleted = false}) => PlayerCard(
      id: id, username: name, displayName: name, avatarUrl: null, frameUrl: null, country: 'NG', sxScore: 900,
      sentinelTier: 'trusted', membershipTier: 'bronze', kycVerified: false, isDeleted: deleted);

RankingRow _row(int rank, PlayerCard p, {String trend = 'flat'}) => RankingRow(
      rank: rank, player: p, wins: 10 - rank, losses: rank, totalMatches: 10, winRate: 0.5, goalsScored: 10, goalsConceded: 5,
      goalDiff: 5, totalTitles: 0, trend: Trend(direction: trend, delta: 1), streak: 2);

RankingsPage _page(List<RankingRow> rows, {int page = 1, int totalPages = 1, String? game, String metric = 'score'}) => RankingsPage(
      scope: RankingsScope(game: game, region: null, metric: metric), rows: rows,
      page: PageInfo(page: page, totalPages: totalPages, total: rows.length, perPage: 10),
      games: const [GameChip(id: 'g1', slug: 'dls', name: 'DLS', category: 'football')], regions: const ['NG'],
      stats: const RankingsStats(playersRanked: 2, gamesIncluded: 1, totalMatches: 5, prizesAwarded: 0),
      highlights: const Highlights(topScore: null, topTitles: null, topWinRate: null, topStreak: null, topStreakValue: 0));

class _FakeRepo implements RankingsRepository {
  _FakeRepo(this.page, {this.me});
  final RankingsPage page;
  final RankingRow? me;
  final queries = <RankingsQuery>[];
  int meCalls = 0;
  @override
  Future<RankingsPage> fetch(RankingsQuery q) async { queries.add(q); return page; }
  @override
  Future<RankingsMe> fetchMe(RankingsQuery q) async { meCalls++; return RankingsMe(row: me); }
}

Widget _app(_FakeRepo repo, {bool signedIn = false}) => ProviderScope(
      retry: (_, _) => null,
      overrides: [
        rankingsRepositoryProvider.overrideWithValue(repo),
        meProvider.overrideWith((ref) async => signedIn
            ? const MeResponse(id: 'p9', email: null, roles: [], isStaff: false, isAdmin: false, profile: null)
            : null),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: RankingsScreen(onGoTo: (_) {}),
      ),
    );

void main() {
  testWidgets('renders ranked rows with rank, name and the score/wins metric', (tester) async {
    final repo = _FakeRepo(_page([_row(1, _card('p1', 'Ada')), _row(2, _card('p2', 'Bola'))]));
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();
    expect(find.text('Ada'), findsOneWidget);
    expect(find.text('Bola'), findsOneWidget);
    expect(find.byKey(const Key('rank-row-1')), findsOneWidget);
    expect(find.text('Ranked by SX Score'), findsOneWidget);
  });

  testWidgets('a deleted account renders as "Deleted player", never blank', (tester) async {
    final repo = _FakeRepo(_page([_row(1, _card('p1', null, deleted: true))]));
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();
    expect(find.text('Deleted player'), findsOneWidget);
  });

  testWidgets('tapping a game chip refetches with that game and resets to page 1', (tester) async {
    final repo = _FakeRepo(_page([_row(1, _card('p1', 'Ada'))], page: 2, totalPages: 3));
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('chip-game-dls')));
    await tester.pumpAndSettle();
    expect(repo.queries.last.game, 'dls');
    expect(repo.queries.last.page, 1);
  });

  testWidgets('Next requests page+1 and keeps the active filters', (tester) async {
    final repo = _FakeRepo(_page([_row(1, _card('p1', 'Ada'))], page: 1, totalPages: 3));
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('page-next')));
    await tester.pumpAndSettle();
    expect(repo.queries.last.page, 2);
  });

  testWidgets('signed out: never calls /rankings/me and shows no "your rank" card', (tester) async {
    final repo = _FakeRepo(_page([_row(1, _card('p1', 'Ada'))]));
    await tester.pumpWidget(_app(repo, signedIn: false));
    await tester.pumpAndSettle();
    expect(repo.meCalls, 0);
    expect(find.byKey(const Key('your-rank-card')), findsNothing);
  });

  testWidgets('signed in and ranked off-page: shows the pinned "your rank" card', (tester) async {
    final repo = _FakeRepo(_page([_row(1, _card('p1', 'Ada'))]), me: _row(42, _card('p9', 'Me')));
    await tester.pumpWidget(_app(repo, signedIn: true));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('your-rank-card')), findsOneWidget);
    expect(find.text('42'), findsWidgets);
  });

  testWidgets('empty board shows the empty state', (tester) async {
    await tester.pumpWidget(_app(_FakeRepo(_page(const []))));
    await tester.pumpAndSettle();
    expect(find.text('No ranked players yet.'), findsOneWidget);
  });
}
```

(`MeResponse`'s constructor takes `profile: MeProfile?` — passing `null` is valid per `models.dart`. If `meProvider.overrideWith` has a different signature in Riverpod 3.3, mirror how `test/features/home_screen_test.dart` / `account_screen_test.dart` override it.)

- [ ] **Step 2:** `flutter test test/features/rankings_screen_test.dart` → FAIL (files missing).

- [ ] **Step 3: Repository + providers**

```dart
// lib/features/rankings/rankings_repository.dart
import '../../core/api/api_client.dart';
import '../../core/api/progress_models.dart';

const _keep = Object();

class RankingsQuery {
  const RankingsQuery({this.game, this.region, this.page = 1});
  final String? game;
  final String? region;
  final int page;

  RankingsQuery copyWith({Object? game = _keep, Object? region = _keep, int? page}) => RankingsQuery(
        game: identical(game, _keep) ? this.game : game as String?,
        region: identical(region, _keep) ? this.region : region as String?,
        page: page ?? this.page,
      );

  @override
  bool operator ==(Object other) => other is RankingsQuery && other.game == game && other.region == region && other.page == page;
  @override
  int get hashCode => Object.hash(game, region, page);
}

abstract class RankingsRepository {
  Future<RankingsPage> fetch(RankingsQuery q);
  Future<RankingsMe> fetchMe(RankingsQuery q);
}

class ApiRankingsRepository implements RankingsRepository {
  ApiRankingsRepository(this._api);
  final ApiClient _api;
  @override
  Future<RankingsPage> fetch(RankingsQuery q) => _api.getRankings(game: q.game, region: q.region, page: q.page);
  @override
  Future<RankingsMe> fetchMe(RankingsQuery q) => _api.getRankingsMe(game: q.game, region: q.region);
}
```

```dart
// lib/features/rankings/rankings_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/progress_models.dart';
import '../../core/providers.dart';
import 'rankings_repository.dart';

final rankingsRepositoryProvider = Provider<RankingsRepository>((ref) => ApiRankingsRepository(ref.watch(apiClientProvider)));

class RankingsQueryNotifier extends Notifier<RankingsQuery> {
  @override
  RankingsQuery build() => const RankingsQuery();

  /// Changing a filter always returns to page 1 so the user never lands on an out-of-range page.
  void setGame(String? game) => state = RankingsQuery(game: game, region: state.region);
  void setRegion(String? region) => state = RankingsQuery(game: state.game, region: region);
  void setPage(int page) => state = state.copyWith(page: page);
}

final rankingsQueryProvider = NotifierProvider.autoDispose<RankingsQueryNotifier, RankingsQuery>(RankingsQueryNotifier.new);

final rankingsProvider = FutureProvider.autoDispose<RankingsPage>(
  (ref) => ref.watch(rankingsRepositoryProvider).fetch(ref.watch(rankingsQueryProvider)),
);

/// The signed-in viewer's own row in the current scope. Signed out -> null WITHOUT calling the API.
final rankingsMeProvider = FutureProvider.autoDispose<RankingRow?>((ref) async {
  final me = await ref.watch(meProvider.future);
  if (me == null) return null;
  final q = ref.watch(rankingsQueryProvider);
  return (await ref.watch(rankingsRepositoryProvider).fetchMe(q)).row;
});
```

- [ ] **Step 4: Screen**

Build `RankingsScreen` (`ConsumerWidget`) with this structure — every string from `AppLocalizations`, every tappable given the `Key` the tests use:
- `Scaffold` + `AppBar(title: l10n.rankingsTitle)`; `RefreshIndicator` that `ref.invalidate(rankingsProvider)` and `ref.invalidate(rankingsMeProvider)`.
- **Filter bar** (horizontally scrollable `SingleChildScrollView`): a `ChoiceChip` "All games" (`Key('chip-game-all')`) + one per `page.games` (`Key('chip-game-${g.slug}')`); below it region chips (`Key('chip-region-all')`, `Key('chip-region-$r')`). Selected state comes from `page.scope`. Taps call `ref.read(rankingsQueryProvider.notifier).setGame/…`.
- **Scope line:** `page.scope.metric == 'wins' ? l10n.rankingsRankByWins : l10n.rankingsRankByScore`, plus `l10n.rankingsPlayersRanked(page.stats.playersRanked)`.
- **Your-rank card** (`Key('your-rank-card')`) — shown only when `rankingsMeProvider` yields a non-null row **and** that row's `rank` is not among the visible rows; same row layout, title `l10n.rankingsYourRank`.
- **Rows** (`ListView.builder`, `Key('rank-row-${row.rank}')`): oversized rank number (top-3 tinted with `SxColors.warning`/`textSecondary`/`accentText`), `PlayerAvatar`, name (`isDeleted ? l10n.commonDeletedPlayer : player.label`), subtitle `l10n.rankingsWinsCount(wins)` · `l10n.rankingsMatchesCount(totalMatches)`, the metric value on the right (`metric == 'wins' ? wins : sxScore`), a trend arrow (`up` green ▲ delta, `down` red ▼ delta, `flat` –, `new` `l10n.rankingsTrendNew`), and a `🔥`/`l10n.rankingsStreakValue(n)` chip when `streak >= 3`.
- **Pager:** `Prev`/`Next` `TextButton`s (`Key('page-prev')`, `Key('page-next')`), disabled at the ends, and `l10n.rankingsPageOf(page, totalPages)`. They call `setPage`.
- `loading` → centered `CircularProgressIndicator`; `error` → tappable message `l10n.rankingsErrorRetry` that invalidates the provider; empty rows → `l10n.rankingsEmpty`.
- The screen also exposes `onGoTo` for two footer links (`/seasons`, `/hall-of-fame`) using the existing nav ARB keys `navSeasons` and `navHallOfFame`-equivalent — use `l10n.seasonsTitle` and `l10n.hallOfFameTitle`.

Keep each private widget (`_FilterBar`, `_RankRow`, `_TrendBadge`, `_Pager`) in the same file until it exceeds ~150 lines.

- [ ] **Step 5:** `flutter test test/features/rankings_screen_test.dart` → PASS. `flutter analyze` clean.
- [ ] **Step 6:** Commit `feat(rankings): leaderboard screen with filters, pager, your-rank card`.

---

### Task 5: Seasons feature

**Files:**
- Create: `lib/features/seasons/seasons_repository.dart`, `seasons_providers.dart`, `seasons_list_screen.dart`, `season_detail_screen.dart`
- Test: `test/features/seasons_screens_test.dart`

**Interfaces:**
- Produces:

```dart
abstract class SeasonsRepository { Future<List<SeasonSummary>> list(); Future<SeasonDetail> detail(String slug); }
final seasonsRepositoryProvider = Provider<SeasonsRepository>(...);
final seasonsProvider = FutureProvider.autoDispose<List<SeasonSummary>>(...);
final seasonDetailProvider = FutureProvider.autoDispose.family<SeasonDetail, String>((ref, slug) => ...);
class SeasonsListScreen extends ConsumerWidget { const SeasonsListScreen({super.key, required this.onSeasonTap}); final void Function(SeasonSummary) onSeasonTap; }
class SeasonDetailScreen extends ConsumerWidget { const SeasonDetailScreen({super.key, required this.slug}); final String slug; }
```

Behavior: the detail screen shows one tab per `SeasonGame` (server order — DLS first is decided by the server); each tab shows the game's leaderboard (rank = index+1 in returned order, name, `l10n.seasonsPoints(points)`, a `seasonsProvisional` badge when `isProvisional`, and the note `seasonsProvisionalNote` once under the table if any row is provisional), the tournaments list (`seasonsTournaments`, an `seasonsInviteOnly` chip when `invitationOnly`), and `tierLabels.qualificationNote`. **The viewer's own row is highlighted** (`Key('season-row-me')`, label `l10n.seasonsYou`) by comparing `playerId` to `meProvider`'s `id` — **no extra API call**.

- [ ] **Step 1: Failing tests**

```dart
// test/features/seasons_screens_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/core/api/models.dart';
import 'package:sentinelx_mobile/core/api/progress_models.dart';
import 'package:sentinelx_mobile/core/l10n/gen/app_localizations.dart';
import 'package:sentinelx_mobile/core/providers.dart';
import 'package:sentinelx_mobile/features/seasons/season_detail_screen.dart';
import 'package:sentinelx_mobile/features/seasons/seasons_list_screen.dart';
import 'package:sentinelx_mobile/features/seasons/seasons_providers.dart';
import 'package:sentinelx_mobile/features/seasons/seasons_repository.dart';

const _season = SeasonSummary(id: 's1', slug: 'season-1', name: 'Season 1', startDate: '2026-08-01', endDate: '2026-10-31');

SeasonDetail _detail({bool provisional = true}) => SeasonDetail(season: _season, games: [
      SeasonGame(
        gameId: 'g1', gameName: 'Dream League Soccer', gameSlug: 'dls',
        tournaments: const [SeasonTournament(id: 't1', title: 'Masters Sept', slug: 'masters-sept', tournamentType: 'masters', status: 'completed', tournamentStart: null, invitationOnly: true)],
        leaderboard: [
          SeasonLeaderboardRow(playerId: 'p1', username: 'ada', displayName: 'Ada', avatarUrl: null, sxScore: 1200, points: 40, isProvisional: provisional),
          const SeasonLeaderboardRow(playerId: 'p9', username: 'me', displayName: 'Me', avatarUrl: null, sxScore: 900, points: 10, isProvisional: false),
        ],
        tierLabels: const SeasonTierLabels(communityClub: 'Community Clubs', masters: 'Masters', qualificationNote: 'Top 16 earn an invitation.', showChampionsCupSpotlight: true),
      ),
      SeasonGame(
        gameId: 'g2', gameName: 'EA FC Mobile', gameSlug: 'ea-fc-mobile', tournaments: const [], leaderboard: const [],
        tierLabels: const SeasonTierLabels(communityClub: 'Circuit Cups', masters: 'Elite Cups', qualificationNote: 'Top 16 monthly points earn an invitation.', showChampionsCupSpotlight: false),
      ),
    ]);

class _Repo implements SeasonsRepository {
  _Repo(this.detailData);
  final SeasonDetail detailData;
  @override
  Future<List<SeasonSummary>> list() async => [_season];
  @override
  Future<SeasonDetail> detail(String slug) async => detailData;
}

Widget _app(Widget home, _Repo repo, {String? meId}) => ProviderScope(
      retry: (_, _) => null,
      overrides: [
        seasonsRepositoryProvider.overrideWithValue(repo),
        meProvider.overrideWith((ref) async => meId == null
            ? null
            : MeResponse(id: meId, email: null, roles: const [], isStaff: false, isAdmin: false, profile: null)),
      ],
      child: MaterialApp(localizationsDelegates: AppLocalizations.localizationsDelegates, supportedLocales: AppLocalizations.supportedLocales, home: home),
    );

void main() {
  testWidgets('list shows seasons and reports taps', (tester) async {
    SeasonSummary? tapped;
    await tester.pumpWidget(_app(SeasonsListScreen(onSeasonTap: (s) => tapped = s), _Repo(_detail())));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Season 1'));
    expect(tapped?.slug, 'season-1');
  });

  testWidgets('detail: game tabs, provisional badge + note, invite-only chip, qualification note', (tester) async {
    await tester.pumpWidget(_app(const SeasonDetailScreen(slug: 'season-1'), _Repo(_detail())));
    await tester.pumpAndSettle();
    expect(find.text('Dream League Soccer'), findsWidgets);
    expect(find.text('EA FC Mobile'), findsWidgets);
    expect(find.text('Provisional'), findsOneWidget);
    expect(find.text('Points can still change while tournaments are in progress.'), findsOneWidget);
    expect(find.text('Invite only'), findsOneWidget);
    expect(find.text('Top 16 earn an invitation.'), findsOneWidget);
  });

  testWidgets('detail: the viewer\'s own row is highlighted by comparing playerId to /me', (tester) async {
    await tester.pumpWidget(_app(const SeasonDetailScreen(slug: 'season-1'), _Repo(_detail()), meId: 'p9'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('season-row-me')), findsOneWidget);
    expect(find.text('You'), findsOneWidget);
  });

  testWidgets('detail: no provisional rows means no provisional note', (tester) async {
    await tester.pumpWidget(_app(const SeasonDetailScreen(slug: 'season-1'), _Repo(_detail(provisional: false))));
    await tester.pumpAndSettle();
    expect(find.text('Points can still change while tournaments are in progress.'), findsNothing);
  });

  testWidgets('switching to a game with no data shows the empty state, not a crash', (tester) async {
    await tester.pumpWidget(_app(const SeasonDetailScreen(slug: 'season-1'), _Repo(_detail())));
    await tester.pumpAndSettle();
    await tester.tap(find.text('EA FC Mobile').first);
    await tester.pumpAndSettle();
    expect(find.text('Nothing here yet.'), findsWidgets);
  });
}
```

- [ ] **Step 2:** run → FAIL.
- [ ] **Step 3: Implement** repository (`ApiSeasonsRepository` over `getSeasons`/`getSeasonDetail`), providers (mirroring Task 4's `Provider`/`FutureProvider.autoDispose`, plus `.family` for detail), `SeasonsListScreen` (`ListView` of `ListTile`s: name, `startDate – endDate`, `onTap → onSeasonTap`; empty → `seasonsEmpty`), and `SeasonDetailScreen` using `DefaultTabController` with `TabBar(isScrollable: true)` — one `Tab(text: game.gameName)` per game — and a `TabBarView` of `_GameSection` widgets. Highlight logic:

```dart
final myId = ref.watch(meProvider).asData?.value?.id;
// in the row builder:
final isMe = myId != null && row.playerId == myId;
// Container(key: isMe ? const Key('season-row-me') : null, ... trailing: isMe ? Chip(label: Text(l10n.seasonsYou)) : null)
```
Row name: `row.displayName ?? row.username ?? l10n.commonDeletedPlayer`. A game with an empty leaderboard **and** no tournaments shows `l10n.hallOfFameEmpty` ("Nothing here yet.") — reuse that key, do not add another.

- [ ] **Step 4:** `flutter test test/features/seasons_screens_test.dart` → PASS; `flutter analyze`.
- [ ] **Step 5:** Commit `feat(seasons): season list + per-game standings screens`.

---

### Task 6: Hall of Fame feature

**Files:**
- Create: `lib/features/hall_of_fame/hall_of_fame_repository.dart`, `hall_of_fame_providers.dart`, `hall_of_fame_screen.dart`
- Test: `test/features/hall_of_fame_screen_test.dart`

**Interfaces:**
- Produces:

```dart
abstract class HallOfFameRepository { Future<HallOfFame> fetch({String? game}); }
final hallOfFameRepositoryProvider = Provider<HallOfFameRepository>(...);
final hallOfFameGameProvider = NotifierProvider.autoDispose<HallOfFameGameNotifier, String?>(...);   // selected game slug, null = all
final hallOfFameProvider = FutureProvider.autoDispose<HallOfFame>((ref) => ref.watch(hallOfFameRepositoryProvider).fetch(game: ref.watch(hallOfFameGameProvider)));
class HallOfFameScreen extends ConsumerWidget { const HallOfFameScreen({super.key}); }
```

Behavior (web parity, `app/[locale]/(public)/hall-of-fame/page.tsx`): game filter chips (`Key('hof-chip-all')`, `Key('hof-chip-${slug}')`); **All-time awards** (MVP card, Golden Boot, then per-category awards; each award with multiple `options` shows small chips to switch between "All …" and per-game winners, defaulting to option 0); **Champions** sections in this order — `hallOfFameChampionsCup`, `hallOfFameMasters`, `hallOfFameCommunityClub`, `hallOfFameOpen`; **Bronze finishes** (`hallOfFameBronze`). **Under a game filter, empty sections are hidden; with no filter they show `hallOfFameEmpty`** (web's `showEmptySections = !selectedGame`).

- [ ] **Step 1: Failing tests**

```dart
// test/features/hall_of_fame_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/core/api/progress_models.dart';
import 'package:sentinelx_mobile/core/l10n/gen/app_localizations.dart';
import 'package:sentinelx_mobile/features/hall_of_fame/hall_of_fame_providers.dart';
import 'package:sentinelx_mobile/features/hall_of_fame/hall_of_fame_repository.dart';
import 'package:sentinelx_mobile/features/hall_of_fame/hall_of_fame_screen.dart';

PlayerCard _card(String id, String name) => PlayerCard(
      id: id, username: name, displayName: name, avatarUrl: null, frameUrl: null, country: 'NG', sxScore: 1500,
      sentinelTier: 'elite', membershipTier: 'gold', kycVerified: true, isDeleted: false);

HofChampion _champ(String type, String champion) => HofChampion(
      tournamentId: 't-$type', slug: 's-$type', title: 'Title $type', tournamentType: type, gameId: 'g1', gameName: 'DLS',
      date: '2026-09-20', prizePool: 10000, champion: Placing(id: 'c-$type', name: champion),
      runnerUp: const Placing(id: 'r1', name: 'Runner'), championAvatarUrl: null, seasonName: 'Season 1');

HallOfFame _hof({bool masters = true, String? selected}) => HallOfFame(
      games: const [GameChip(id: 'g1', slug: 'dls', name: 'DLS', category: 'football')],
      selectedGame: selected,
      awards: HofAwards(
        mvp: _card('p1', 'Ada'),
        goldenBoot: [
          AwardOption(gameId: null, gameLabel: 'All Goals', winner: _card('p2', 'Bola'), metricValue: 40),
          AwardOption(gameId: 'g1', gameLabel: 'DLS', winner: _card('p3', 'Chidi'), metricValue: 25),
        ],
        categories: const [],
      ),
      champions: HofChampions(championsCup: const [], masters: masters ? [_champ('masters', 'Dayo')] : const [], communityClub: const [], open: const []),
      bronze: const [BronzeFinish(tournamentId: 't1', slug: 's', title: 'Masters Sept', gameName: 'DLS', date: null, player: Placing(id: 'p5', name: 'Efe'))],
    );

class _Repo implements HallOfFameRepository {
  _Repo(this.data);
  final HallOfFame data;
  final games = <String?>[];
  @override
  Future<HallOfFame> fetch({String? game}) async { games.add(game); return data; }
}

Widget _app(_Repo repo) => ProviderScope(
      retry: (_, _) => null,
      overrides: [hallOfFameRepositoryProvider.overrideWithValue(repo)],
      child: MaterialApp(localizationsDelegates: AppLocalizations.localizationsDelegates, supportedLocales: AppLocalizations.supportedLocales, home: const HallOfFameScreen()),
    );

void main() {
  testWidgets('shows MVP, golden boot default option, champions, runner-up and bronze', (tester) async {
    await tester.pumpWidget(_app(_Repo(_hof())));
    await tester.pumpAndSettle();
    expect(find.text('All-Time MVP'), findsOneWidget);
    expect(find.text('Ada'), findsOneWidget);
    expect(find.text('Bola'), findsOneWidget);          // golden boot option 0
    expect(find.text('Dayo'), findsOneWidget);          // masters champion
    expect(find.text('Runner-up: Runner'), findsOneWidget);
    expect(find.text('Efe'), findsOneWidget);           // bronze
  });

  testWidgets('switching the golden boot option shows that option\'s winner', (tester) async {
    await tester.pumpWidget(_app(_Repo(_hof())));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('award-option-Golden Boot-DLS')));
    await tester.pumpAndSettle();
    expect(find.text('Chidi'), findsOneWidget);
  });

  testWidgets('no filter: empty champion sections show the aspirational empty state', (tester) async {
    await tester.pumpWidget(_app(_Repo(_hof(masters: false))));
    await tester.pumpAndSettle();
    expect(find.text('Nothing here yet.'), findsWidgets);
  });

  testWidgets('under a game filter, empty sections are hidden', (tester) async {
    final repo = _Repo(_hof(masters: false, selected: 'dls'));
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('hof-chip-dls')));
    await tester.pumpAndSettle();
    expect(repo.games.last, 'dls');
    expect(find.text('Masters'), findsNothing);
  });
}
```

- [ ] **Step 2:** run → FAIL.
- [ ] **Step 3: Implement** repository/providers (same pattern as Tasks 4–5; `HallOfFameGameNotifier` with `setGame(String?)`) and `HallOfFameScreen`: a `ListView` with the filter chips, an `_AwardCard` (title from ARB, winner name, `PlayerAvatar`, metric value; when `options.length > 1`, a row of `ChoiceChip`s keyed `Key('award-option-$title-${option.gameLabel}')`, local selection state in a small `StatefulWidget` so it survives rebuilds without polluting providers), `_ChampionSection` (heading, list of `_ChampionTile` showing `title`, `champion.name`, `l10n.hallOfFameRunnerUp(name)` when present, `seasonName`, prize), and `_BronzeSection`. `showEmptySections = data.selectedGame == null` decides whether an empty section shows `l10n.hallOfFameEmpty` or is omitted (**heading included**).
- [ ] **Step 4:** run → PASS; `flutter analyze`.
- [ ] **Step 5:** Commit `feat(hall-of-fame): awards, champions and bronze finishes screen`.

---

### Task 7: Routing and web-link resolution

**Files:**
- Modify: `lib/router/app_router.dart`, `lib/core/routing/web_links.dart`
- Test: `test/core/web_links_test.dart` (append cases), `test/features/progress_routes_test.dart` (create)

- [ ] **Step 1: Failing tests**

Append to `test/core/web_links_test.dart` (inside its existing `main()`, following that file's style):

```dart
  test('maps rankings, seasons and hall-of-fame web paths (with and without a locale)', () {
    expect(resolveWebLink('https://sentinelxesports.com.ng/rankings'), '/rankings');
    expect(resolveWebLink('https://sentinelxesports.com.ng/en/rankings'), '/rankings');
    expect(resolveWebLink('https://sentinelxesports.com.ng/hall-of-fame'), '/hall-of-fame');
    expect(resolveWebLink('https://sentinelxesports.com.ng/seasons/season-1'), '/seasons/season-1');
    expect(resolveWebLink('https://sentinelxesports.com.ng/fr/seasons/season-1'), '/seasons/season-1');
    expect(resolveWebLink('https://evil.example/rankings'), isNull);
  });
```

```dart
// test/features/progress_routes_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/core/l10n/gen/app_localizations.dart';
import 'package:sentinelx_mobile/router/app_router.dart';
import 'package:sentinelx_mobile/features/rankings/rankings_screen.dart';
import 'package:sentinelx_mobile/features/seasons/season_detail_screen.dart';
import 'package:sentinelx_mobile/features/hall_of_fame/hall_of_fame_screen.dart';

Future<void> _pump(WidgetTester tester, String location) => tester.pumpWidget(ProviderScope(
      retry: (_, _) => null,
      child: MaterialApp.router(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: buildAppRouter(initialLocation: location),
      ),
    ));

void main() {
  // The screens will hit real providers here (no network in tests -> they land in their error state), which is fine:
  // this test only proves each location resolves to the right screen inside the app router.
  testWidgets('/rankings resolves to RankingsScreen', (tester) async {
    await _pump(tester, '/rankings');
    await tester.pump();
    expect(find.byType(RankingsScreen), findsOneWidget);
  });
  testWidgets('/seasons/season-1 resolves to SeasonDetailScreen with the slug', (tester) async {
    await _pump(tester, '/seasons/season-1');
    await tester.pump();
    expect(tester.widget<SeasonDetailScreen>(find.byType(SeasonDetailScreen)).slug, 'season-1');
  });
  testWidgets('/hall-of-fame resolves to HallOfFameScreen', (tester) async {
    await _pump(tester, '/hall-of-fame');
    await tester.pump();
    expect(find.byType(HallOfFameScreen), findsOneWidget);
  });
}
```
(If pumping the real router without overrides throws on Supabase/`Supabase.instance` access in this repo's test setup, copy the override set that `test/support/pump_app.dart`/`test/features/account_screen_test.dart` uses to stub `apiClientProvider` and `meProvider`, and override the three repository providers with never-completing fakes.)

- [ ] **Step 2:** run → FAIL.
- [ ] **Step 3: Implement**

`web_links.dart` — inside `resolveWebLink`, before the `switch`, add (do not reorder existing cases):

```dart
  if (segments.length == 2 && segments.first == 'seasons') return '/seasons/${segments[1]}';
```
and add to the switch:
```dart
    case 'rankings':
      return '/rankings';
    case 'seasons':
      return '/seasons';
    case 'hall-of-fame':
      return '/hall-of-fame';
```

`app_router.dart` — add imports for the three feature screens, then inside the **first** `StatefulShellBranch` (Compete), after the existing `/tournaments` `GoRoute`, add sibling routes (this keeps the bottom bar visible with Compete selected and edits no tournaments code):

```dart
            GoRoute(path: '/rankings', builder: (context, state) => RankingsScreen(onGoTo: (path) => context.push(path))),
            GoRoute(
              path: '/seasons',
              builder: (context, state) => SeasonsListScreen(onSeasonTap: (s) => context.push('/seasons/${s.slug}')),
              routes: [GoRoute(path: ':slug', builder: (context, state) => SeasonDetailScreen(slug: state.pathParameters['slug']!))],
            ),
            GoRoute(path: '/hall-of-fame', builder: (context, state) => const HallOfFameScreen()),
```

- [ ] **Step 4:** `flutter test test/core/web_links_test.dart test/features/progress_routes_test.dart` → PASS; then the whole `flutter test`.
- [ ] **Step 5:** Commit `feat(router): rankings, seasons and hall-of-fame routes + web link mapping`.

---

### Task 8: Entry points from Home

**Files:**
- Modify: `lib/features/home/home_screen.dart`
- Test: `test/features/home_screen_test.dart` (append)

**Why Home and not the Compete screen:** the Compete tab currently *is* the temporary tournaments slice, which Phase 2a/2b are replacing; editing it now would collide with them. Adding a Compete-tab entry row is a follow-up for after the API-backed tournaments list lands (note it in the handoff).

- [ ] **Step 1: Failing test** — append to `test/features/home_screen_test.dart`, following that file's existing `_summary()`/pump pattern:

```dart
  testWidgets('Home links to Rankings, Seasons and Hall of Fame', (tester) async {
    final visited = <String>[];
    await tester.pumpWidget(ProviderScope(
      retry: (_, _) => null,
      overrides: [homeRepositoryProvider.overrideWithValue(_FakeHomeRepository(_summary()))],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: HomeScreen(onGoTo: visited.add),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('home-link-rankings')));
    await tester.tap(find.byKey(const Key('home-link-seasons')));
    await tester.tap(find.byKey(const Key('home-link-hall-of-fame')));
    expect(visited, ['/rankings', '/seasons', '/hall-of-fame']);
  });
```
(Copy the extra overrides the neighboring tests in that file already use for `onboardingGateProvider`/`meProvider`/`sessionStartedProvider`.)

- [ ] **Step 2:** run → FAIL.
- [ ] **Step 3: Implement** — in `HomeScreen`'s `ListView`, directly after the "Top Players" block (`for (final p in summary.leaderboardTeaser) …`), add:

```dart
              ListTile(key: const Key('home-link-rankings'), title: Text(l10n.homeFullRankingsLink), trailing: const Icon(Icons.chevron_right), onTap: () => onGoTo('/rankings')),
              ListTile(key: const Key('home-link-seasons'), title: Text(l10n.seasonsTitle), trailing: const Icon(Icons.chevron_right), onTap: () => onGoTo('/seasons')),
              ListTile(key: const Key('home-link-hall-of-fame'), title: Text(l10n.hallOfFameTitle), trailing: const Icon(Icons.chevron_right), onTap: () => onGoTo('/hall-of-fame')),
```
- [ ] **Step 4:** run the file, then full `flutter analyze && flutter test` → clean.
- [ ] **Step 5:** Commit `feat(home): entry links to rankings, seasons, hall of fame`.

---

### Task 9: Rebase, contract re-copy, exit check

- [ ] **Step 1: Rebase and refresh**

```bash
git fetch origin && git rebase origin/master
copy C:\Users\gorok\Videos\sentinelx\openapi\mobile-v1.json api\openapi.json   # from web main once PR 2 has merged
flutter pub get && flutter gen-l10n
flutter analyze && flutter test
```
If ARB/l10n or `api_client.dart` conflict during the rebase, resolve by keeping *both* sides' additions (they are append-only), then re-run `flutter gen-l10n`.

- [ ] **Step 2: Run against staging**

```bash
flutter run --dart-define=API_BASE_URL=<staging web URL> ...   # use the exact dev-flavor flags in README.md / TESTING-NOTES.md
```
On a device/emulator at 375px width verify: Rankings loads, chips filter, paging works, no overflow; Seasons list → detail tabs; Hall of Fame all sections; signed-in "your rank" card; a tombstone row (if any exists in staging) shows "Deleted player".

- [ ] **Step 3: The exit check (spec §1)** — for 10 players on Rankings, the season standings for one season, and the Hall of Fame blocks, open the **web page** for the same scope on staging and compare rank, wins, SX Score, trend, streak, season points, provisional flags, awards. Record the side-by-side table in the PR description; any mismatch is a bug against this plan or the web plan, not a "known difference".

- [ ] **Step 4:** Update `TESTING-NOTES.md` with the staging run (date, build, what was verified), push `phase3a/screens`, open the PR.
