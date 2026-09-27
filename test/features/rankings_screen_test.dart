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

class _RankingsRepo implements RankingsRepository {
  _RankingsRepo({
    this.trendDirection = 'new',
    this.trendDelta = 0,
    this.totalPages = 1,
    this.playerId = 'p1',
    this.displayName = 'Ada',
    this.isDeleted = false,
    this.empty = false,
    this.includeScoreTab = false,
    this.includeSubGames = false,
  });

  final String trendDirection;
  final int trendDelta;
  final int totalPages;
  final String playerId;
  final String? displayName;
  final bool isDeleted;
  final bool empty;
  final bool includeScoreTab;
  final bool includeSubGames;

  @override
  Future<RankingsPage> fetch(RankingsQuery q) async => RankingsPage.fromJson({
    'scope': {
      'game': null,
      'region': null,
      'serverMetric': 'wins',
      'metric': 'wins',
      'metricLabel': 'Wins',
      'tabGame': null,
    },
    'rows': empty
        ? []
        : [
            {
              'rank': 1,
              'player': {
                'id': playerId,
                'username': 'ada',
                'displayName': displayName,
                'avatarUrl': null,
                'frameUrl': null,
                'country': null,
                'sxScore': 99,
                'sentinelTier': null,
                'membershipTier': 'free',
                'kycVerified': false,
                'isDeleted': isDeleted,
              },
              'wins': 7,
              'losses': 1,
              'totalMatches': 8,
              'winRate': 0.875,
              'goalsScored': 12,
              'goalsConceded': 3,
              'goalDiff': 9,
              'totalTitles': 1,
              'metricValue': 7,
              'winsByGame': [],
              'trend': {'direction': trendDirection, 'delta': trendDelta},
              'streak': 3,
            },
          ],
    'tabs': [
      {'key': 'wins', 'label': 'Wins'},
      if (includeScoreTab) {'key': 'score', 'label': 'SX Score'},
    ],
    'subGames': includeSubGames
        ? [
            {'slug': 'dls', 'name': 'DLS'},
            {'slug': 'efootball', 'name': 'eFootball'},
          ]
        : [],
    'subGamesAllLabel': includeSubGames ? 'All goals' : null,
    'page': {
      'page': q.page,
      'totalPages': totalPages,
      'total': totalPages,
      'perPage': 10,
    },
    'games': [],
    'regions': <String>[],
    'stats': {
      'playersRanked': 1,
      'gamesIncluded': 1,
      'totalMatches': 8,
      'prizesAwarded': 0,
    },
    'highlights': {
      'topScore': null,
      'topTitles': null,
      'topWinRate': null,
      'topStreak': null,
      'topStreakValue': 0,
    },
  });

  @override
  Future<RankingsMe> fetchMe(RankingsQuery q) async =>
      const RankingsMe(row: null);
}

class _RecordingRepo extends _RankingsRepo {
  _RecordingRepo({
    super.includeScoreTab,
    super.includeSubGames,
    super.totalPages,
  });
  final queries = <RankingsQuery>[];
  int meCalls = 0;

  @override
  Future<RankingsPage> fetch(RankingsQuery q) {
    queries.add(q);
    return super.fetch(q);
  }

  @override
  Future<RankingsMe> fetchMe(RankingsQuery q) async {
    meCalls++;
    return const RankingsMe(row: null);
  }
}

class _PinnedRepo extends _RankingsRepo {
  _PinnedRepo(this.mePlayerId);
  final String mePlayerId;

  @override
  Future<RankingsMe> fetchMe(RankingsQuery q) async {
    final page = await _RankingsRepo(
      playerId: mePlayerId,
      displayName: mePlayerId == 'p1' ? 'Ada' : 'Bola',
    ).fetch(q);
    return RankingsMe(row: page.rows.single);
  }
}

class _FailingRepo extends _RankingsRepo {
  _FailingRepo({super.totalPages});

  @override
  Future<RankingsPage> fetch(RankingsQuery q) {
    if (q.page > 1) throw Exception('page failed');
    return super.fetch(q);
  }
}

class _AlwaysFailingRepo extends _RankingsRepo {
  @override
  Future<RankingsPage> fetch(RankingsQuery q) => throw Exception('failed');
}

void main() {
  testWidgets('rankings me does not refetch for page-only changes', (
    tester,
  ) async {
    final repo = _RecordingRepo(totalPages: 2);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          rankingsRepositoryProvider.overrideWithValue(repo),
          meProvider.overrideWith(
            (_) async => const MeResponse(
              id: 'p1',
              email: null,
              roles: [],
              isStaff: false,
              isAdmin: false,
              profile: null,
            ),
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: RankingsScreen(onGoTo: (_) {}),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(repo.meCalls, 1);
    await tester.tap(find.byKey(const Key('page-next')));
    await tester.pumpAndSettle();
    expect(repo.meCalls, 1);
  });

  testWidgets('signed out rankings never calls rankings me', (tester) async {
    final repo = _RecordingRepo();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          rankingsRepositoryProvider.overrideWithValue(repo),
          meProvider.overrideWith((_) async => null),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: RankingsScreen(onGoTo: (_) {}),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(repo.meCalls, 0);
  });

  testWidgets('your rank card appears off-page and hides on-page', (
    tester,
  ) async {
    Future<void> pump(RankingsRepository repo, String meId) =>
        tester.pumpWidget(
          ProviderScope(
            key: UniqueKey(),
            overrides: [
              rankingsRepositoryProvider.overrideWithValue(repo),
              meProvider.overrideWith(
                (_) async => MeResponse(
                  id: meId,
                  email: null,
                  roles: const [],
                  isStaff: false,
                  isAdmin: false,
                  profile: null,
                ),
              ),
            ],
            child: MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: RankingsScreen(onGoTo: (_) {}),
            ),
          ),
        );

    await pump(_PinnedRepo('p2'), 'p2');
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('your-rank-card')), findsOneWidget);

    await pump(_PinnedRepo('p1'), 'p1');
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('your-rank-card')), findsNothing);
  });

  test('filter changes reset page while paging and metric keep filters', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(rankingsQueryProvider.notifier);
    notifier.setGame('dls');
    notifier.setRegion('NG');
    notifier.setPage(3);
    notifier.setMetric('score');
    var query = container.read(rankingsQueryProvider);
    expect(query.page, 3);
    expect(query.game, 'dls');
    expect(query.region, 'NG');
    expect(query.metric, 'score');
    notifier.setRegion('GH');
    query = container.read(rankingsQueryProvider);
    expect(query.page, 1);
    expect(query.game, 'dls');
    expect(query.metric, 'score');
  });

  testWidgets('metric tab refetches the same page and sub-game chips work', (
    tester,
  ) async {
    final repo = _RecordingRepo(includeScoreTab: true, includeSubGames: true);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          rankingsRepositoryProvider.overrideWithValue(repo),
          meProvider.overrideWith((_) async => null),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: RankingsScreen(onGoTo: (_) {}),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('chip-tabgame-dls')), findsOneWidget);
    await tester.tap(find.byKey(const Key('chip-tabgame-dls')));
    await tester.pumpAndSettle();
    expect(repo.queries.last.tabGame, 'dls');
    await tester.tap(find.byKey(const Key('tab-metric-score')));
    await tester.pumpAndSettle();
    expect(repo.queries.last.metric, 'score');
    expect(repo.queries.last.page, 1);
  });

  testWidgets('rankings shows tombstone and empty states', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          rankingsRepositoryProvider.overrideWithValue(
            _RankingsRepo(displayName: null, isDeleted: true),
          ),
          meProvider.overrideWith((_) async => null),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: RankingsScreen(onGoTo: (_) {}),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Deleted player'), findsOneWidget);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          rankingsRepositoryProvider.overrideWithValue(
            _RankingsRepo(empty: true),
          ),
          meProvider.overrideWith((_) async => null),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: RankingsScreen(onGoTo: (_) {}),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('No ranked players yet.'), findsOneWidget);
  });

  testWidgets('page load error keeps existing rows and controls', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        retry: (_, _) => null,
        overrides: [
          rankingsRepositoryProvider.overrideWithValue(
            _FailingRepo(totalPages: 2),
          ),
          meProvider.overrideWith((_) async => null),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: RankingsScreen(onGoTo: (_) {}),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('page-next')));
    await tester.pumpAndSettle();
    await tester.fling(find.byType(ListView), const Offset(0, 1000), 10000);
    await tester.pumpAndSettle();

    expect(find.text('Ada'), findsOneWidget);
    expect(find.byKey(const Key('chip-game-all')), findsOneWidget);
    expect(find.text("Couldn't load. Tap to retry."), findsOneWidget);
  });

  testWidgets('initial load error keeps basic filters and pager', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        retry: (_, _) => null,
        overrides: [
          rankingsRepositoryProvider.overrideWithValue(_AlwaysFailingRepo()),
          meProvider.overrideWith((_) async => null),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: RankingsScreen(onGoTo: (_) {}),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('chip-game-all')), findsOneWidget);
    expect(find.byKey(const Key('chip-region-all')), findsOneWidget);
    expect(find.byKey(const Key('page-prev')), findsOneWidget);
    expect(find.byKey(const Key('page-next')), findsOneWidget);
  });

  test('game clears region while region keeps game and both keep metric', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(rankingsQueryProvider.notifier);

    notifier.setMetric('score');
    notifier.setRegion('NG');
    notifier.setPage(3);
    notifier.setGame('dls');
    var query = container.read(rankingsQueryProvider);
    expect(query.game, 'dls');
    expect(query.region, isNull);
    expect(query.metric, 'score');
    expect(query.page, 1);

    notifier.setRegion('GH');
    query = container.read(rankingsQueryProvider);
    expect(query.game, 'dls');
    expect(query.region, 'GH');
    expect(query.metric, 'score');
  });

  testWidgets('highlights the signed-in viewer on the current page', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        retry: (_, _) => null,
        overrides: [
          rankingsRepositoryProvider.overrideWithValue(_RankingsRepo()),
          meProvider.overrideWith(
            (_) async => const MeResponse(
              id: 'p1',
              email: null,
              roles: [],
              isStaff: false,
              isAdmin: false,
              profile: null,
            ),
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: RankingsScreen(onGoTo: (_) {}),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('rank-row-me')), findsOneWidget);
    expect(find.text('(you)'), findsOneWidget);
  });

  testWidgets('formats ranking trends like the web table', (tester) async {
    Future<void> pumpTrend(String direction, int delta) async {
      await tester.pumpWidget(
        ProviderScope(
          retry: (_, _) => null,
          overrides: [
            rankingsRepositoryProvider.overrideWithValue(
              _RankingsRepo(trendDirection: direction, trendDelta: delta),
            ),
            meProvider.overrideWith((_) async => null),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: RankingsScreen(onGoTo: (_) {}),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    await pumpTrend('up', 4);
    expect(find.text('▲ 4'), findsOneWidget);

    await pumpTrend('down', 2);
    expect(find.text('▼ 2'), findsOneWidget);

    for (final direction in ['flat', 'new', 'unexpected']) {
      await pumpTrend(direction, 9);
      expect(find.text('—'), findsOneWidget);
      expect(find.text(direction), findsNothing);
    }
  });

  testWidgets('shows rounded win percentage from the server ratio', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        retry: (_, _) => null,
        overrides: [
          rankingsRepositoryProvider.overrideWithValue(_RankingsRepo()),
          meProvider.overrideWith((_) async => null),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: RankingsScreen(onGoTo: (_) {}),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('88%'), findsOneWidget);
  });
}
