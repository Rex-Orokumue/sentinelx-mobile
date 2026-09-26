import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/core/api/progress_models.dart';

const _card = {
  'id': 'p1',
  'username': 'ada',
  'displayName': 'Ada',
  'avatarUrl': null,
  'frameUrl': null,
  'country': 'NG',
  'sxScore': 980,
  'sentinelTier': 'trusted',
  'membershipTier': 'bronze',
  'kycVerified': true,
  'isDeleted': false,
};

Map<String, dynamic> _row(int rank) => {
  'rank': rank,
  'player': _card,
  'wins': 5,
  'losses': 2,
  'totalMatches': 7,
  'winRate': 0.7142857,
  'goalsScored': 20,
  'goalsConceded': 8,
  'goalDiff': 12,
  'totalTitles': 1,
  'metricValue': 20,
  'winsByGame': [
    {'gameId': 'g1', 'gameName': 'DLS', 'wins': 5},
  ],
  'trend': {'direction': 'up', 'delta': 2},
  'streak': 3,
};

void main() {
  test('RankingsPage parses rows, scope, chips, stats and highlights', () {
    final page = RankingsPage.fromJson({
      'scope': {
        'game': null,
        'region': null,
        'serverMetric': 'score',
        'metric': 'wins',
        'metricLabel': 'W',
        'tabGame': null,
      },
      'tabs': [
        {'key': 'wins', 'label': 'Wins'},
      ],
      'subGames': [
        {'slug': 'dls', 'name': 'DLS'},
      ],
      'subGamesAllLabel': 'All Goals',
      'rows': [_row(1), _row(2)],
      'page': {'page': 1, 'totalPages': 3, 'total': 25, 'perPage': 10},
      'games': [
        {
          'id': 'g1',
          'slug': 'dls',
          'name': 'Dream League Soccer',
          'category': 'football',
        },
      ],
      'regions': ['GH', 'NG'],
      'stats': {
        'playersRanked': 25,
        'gamesIncluded': 1,
        'totalMatches': 100,
        'prizesAwarded': 50000,
      },
      'highlights': {
        'topScore': _card,
        'topTitles': null,
        'topWinRate': null,
        'topStreak': null,
        'topStreakValue': 4,
      },
    });
    expect(page.rows.map((r) => r.rank), [1, 2]);
    expect(page.rows.first.trend.direction, 'up');
    expect(page.page.totalPages, 3);
    expect(page.scope.metric, 'wins');
    expect(page.tabs.single.key, 'wins');
    expect(page.subGames.single.slug, 'dls');
    expect(page.rows.first.metricValue, 20);
    expect(page.rows.first.winsByGame.single.gameId, 'g1');
    expect(page.highlights.topScore?.label, 'Ada');
    expect(page.highlights.topTitles, isNull);
  });

  test('PlayerCard tombstone has an empty label', () {
    final c = PlayerCard.fromJson({
      ..._card,
      'username': null,
      'displayName': null,
      'isDeleted': true,
    });
    expect(c.isDeleted, isTrue);
    expect(c.label, '');
  });

  test('RankingsMe accepts a null row', () {
    expect(RankingsMe.fromJson({'row': null}).row, isNull);
    expect(RankingsMe.fromJson({'row': _row(4)}).row?.rank, 4);
  });

  test('SeasonDetail parses per-game sections with provisional rows', () {
    final d = SeasonDetail.fromJson({
      'season': {
        'id': 's1',
        'slug': 'season-1',
        'name': 'Season 1',
        'startDate': '2026-08-01',
        'endDate': '2026-10-31',
      },
      'games': [
        {
          'gameId': 'g1',
          'gameName': 'Dream League Soccer',
          'gameSlug': 'dls',
          'tournaments': [
            {
              'id': 't1',
              'title': 'Masters Sept',
              'slug': 'masters-sept',
              'tournamentType': 'masters',
              'status': 'completed',
              'tournamentStart': null,
              'invitationOnly': true,
            },
          ],
          'leaderboard': [
            {
              'playerId': 'p1',
              'username': 'ada',
              'displayName': 'Ada',
              'avatarUrl': null,
              'sxScore': 1200,
              'points': 40,
              'isProvisional': true,
            },
          ],
          'tierLabels': {
            'communityClub': 'Community Clubs',
            'masters': 'Masters',
            'qualificationNote': 'Top 16 earn an invitation.',
            'showChampionsCupSpotlight': true,
          },
        },
      ],
    });
    expect(d.games.single.leaderboard.single.isProvisional, isTrue);
    expect(d.games.single.tournaments.single.invitationOnly, isTrue);
    expect(d.games.single.tierLabels.masters, 'Masters');
  });

  test('HallOfFame parses awards, grouped champions and bronze finishes', () {
    final champ = {
      'tournamentId': 't1',
      'slug': 'masters-sept',
      'title': 'Masters Sept',
      'tournamentType': 'masters',
      'gameId': 'g1',
      'gameName': 'Dream League Soccer',
      'date': '2026-09-20',
      'prizePool': 10000,
      'champion': {'id': 'p1', 'name': 'Ada'},
      'runnerUp': null,
      'championAvatarUrl': null,
      'seasonName': 'Season 1',
    };
    final h = HallOfFame.fromJson({
      'games': [],
      'selectedGame': null,
      'awards': {
        'mvp': _card,
        'goldenBoot': [
          {
            'gameId': null,
            'gameLabel': 'All Goals',
            'winner': _card,
            'metricValue': 40,
          },
        ],
        'categories': [],
      },
      'champions': {
        'championsCup': [],
        'masters': [champ],
        'communityClub': [],
        'open': [],
      },
      'bronze': [
        {
          'tournamentId': 't1',
          'slug': 'masters-sept',
          'title': 'Masters Sept',
          'gameName': null,
          'date': null,
          'player': {'id': 'p3', 'name': 'Chidi'},
        },
      ],
    });
    expect(h.awards.mvp?.label, 'Ada');
    expect(h.champions.masters.single.champion.name, 'Ada');
    expect(h.champions.masters.single.runnerUp, isNull);
    expect(h.bronze.single.player.name, 'Chidi');
  });
}
