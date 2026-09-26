import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/core/api/progress_models.dart';
import 'package:sentinelx_mobile/core/l10n/gen/app_localizations.dart';
import 'package:sentinelx_mobile/core/providers.dart';
import 'package:sentinelx_mobile/features/hall_of_fame/hall_of_fame_providers.dart';
import 'package:sentinelx_mobile/features/hall_of_fame/hall_of_fame_repository.dart';
import 'package:sentinelx_mobile/features/hall_of_fame/hall_of_fame_screen.dart';
import 'package:sentinelx_mobile/features/rankings/rankings_providers.dart';
import 'package:sentinelx_mobile/features/rankings/rankings_repository.dart';
import 'package:sentinelx_mobile/features/rankings/rankings_screen.dart';
import 'package:sentinelx_mobile/features/seasons/season_detail_screen.dart';
import 'package:sentinelx_mobile/features/seasons/seasons_list_screen.dart';
import 'package:sentinelx_mobile/features/seasons/seasons_providers.dart';
import 'package:sentinelx_mobile/features/seasons/seasons_repository.dart';

Widget _app(Widget home, List<Override> overrides) => ProviderScope(
  retry: (_, _) => null,
  overrides: overrides,
  child: MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: home,
  ),
);

void main() {
  testWidgets('rankings renders rows and expands wins by game', (tester) async {
    await tester.pumpWidget(
      _app(RankingsScreen(onGoTo: (_) {}), [
        rankingsRepositoryProvider.overrideWithValue(_RankingsRepo()),
        meProvider.overrideWith((_) async => null),
      ]),
    );
    await tester.pumpAndSettle();

    expect(find.text('Ada'), findsOneWidget);
    expect(find.text('EA FC: 7'), findsNothing);
    await tester.tap(find.byKey(const Key('rank-row-1')));
    await tester.pump();
    expect(find.text('EA FC: 7'), findsOneWidget);
  });

  testWidgets('seasons list opens the selected native detail route', (
    tester,
  ) async {
    SeasonSummary? selected;
    await tester.pumpWidget(
      _app(SeasonsListScreen(onSeasonTap: (season) => selected = season), [
        seasonsRepositoryProvider.overrideWithValue(_SeasonsRepo()),
      ]),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Season One'));
    expect(selected?.slug, 'season-one');
  });

  testWidgets('season detail handles a season without game tabs', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(const SeasonDetailScreen(slug: 'empty-season'), [
        seasonsRepositoryProvider.overrideWithValue(_SeasonsRepo()),
        meProvider.overrideWith((_) async => null),
      ]),
    );
    await tester.pumpAndSettle();

    expect(find.text('Nothing here yet.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('hall of fame renders award and champion sections', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(const HallOfFameScreen(), [
        hallOfFameRepositoryProvider.overrideWithValue(_HallOfFameRepo()),
      ]),
    );
    await tester.pumpAndSettle();

    expect(find.text('All-Time MVP'), findsOneWidget);
    expect(find.text('Ada'), findsWidgets);
    expect(find.text('Champions Cup'), findsOneWidget);
  });
}

class _RankingsRepo implements RankingsRepository {
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
    'rows': [
      {
        'rank': 1,
        'player': _player,
        'wins': 7,
        'losses': 1,
        'totalMatches': 8,
        'winRate': 87.5,
        'goalsScored': 12,
        'goalsConceded': 3,
        'goalDiff': 9,
        'totalTitles': 1,
        'metricValue': 7,
        'winsByGame': [
          {'gameId': 'g1', 'gameName': 'EA FC', 'wins': 7},
        ],
        'trend': {'direction': 'new', 'delta': 0},
        'streak': 3,
      },
    ],
    'tabs': [
      {'key': 'wins', 'label': 'Wins'},
    ],
    'subGames': [],
    'subGamesAllLabel': null,
    'page': {'page': 1, 'totalPages': 1, 'total': 1, 'perPage': 20},
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

class _SeasonsRepo implements SeasonsRepository {
  static const season = SeasonSummary(
    id: 's1',
    slug: 'season-one',
    name: 'Season One',
    startDate: '2026-01-01',
    endDate: '2026-03-31',
  );

  @override
  Future<List<SeasonSummary>> list() async => const [season];

  @override
  Future<SeasonDetail> detail(String slug) async =>
      const SeasonDetail(season: season, games: []);
}

class _HallOfFameRepo implements HallOfFameRepository {
  @override
  Future<HallOfFame> fetch({String? game}) async => HallOfFame.fromJson({
    'games': [],
    'selectedGame': null,
    'awards': {'mvp': _player, 'goldenBoot': [], 'categories': []},
    'champions': {
      'championsCup': [
        {
          'tournamentId': 't1',
          'slug': 'cup',
          'title': 'Cup Final',
          'tournamentType': 'champions_cup',
          'gameId': 'g1',
          'gameName': 'EA FC',
          'date': null,
          'prizePool': null,
          'champion': {'id': 'p1', 'name': 'Ada'},
          'runnerUp': null,
          'championAvatarUrl': null,
          'seasonName': null,
        },
      ],
      'masters': [],
      'communityClub': [],
      'open': [],
    },
    'bronze': [],
  });
}

const _player = {
  'id': 'p1',
  'username': 'ada',
  'displayName': 'Ada',
  'avatarUrl': null,
  'frameUrl': null,
  'country': null,
  'sxScore': 99,
  'sentinelTier': null,
  'membershipTier': 'free',
  'kycVerified': false,
  'isDeleted': false,
};
