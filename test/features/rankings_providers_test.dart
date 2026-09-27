import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/core/api/progress_models.dart';
import 'package:sentinelx_mobile/features/rankings/rankings_providers.dart';
import 'package:sentinelx_mobile/features/rankings/rankings_repository.dart';

RankingsPage _page() => RankingsPage.fromJson({
  'scope': {
    'game': null,
    'region': null,
    'serverMetric': 'wins',
    'metric': 'wins',
    'metricLabel': 'Wins',
    'tabGame': null,
  },
  'rows': [],
  'tabs': [],
  'subGames': [],
  'subGamesAllLabel': null,
  'page': {'page': 1, 'totalPages': 1, 'total': 1, 'perPage': 10},
  'games': [],
  'regions': <String>[],
  'stats': {
    'playersRanked': 0,
    'gamesIncluded': 0,
    'totalMatches': 0,
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

void main() {
  test('rankings cache evicts the oldest entry once it exceeds its cap', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(rankingsCacheProvider.notifier);

    // One more than the cap: distinct filter combos, each a separate key.
    for (var i = 0; i < 9; i++) {
      notifier.store(RankingsQuery(game: 'game-$i'), _page());
    }

    final cache = container.read(rankingsCacheProvider);
    expect(cache.length, 8);
    expect(cache.containsKey(const RankingsQuery(game: 'game-0')), isFalse);
    expect(cache.containsKey(const RankingsQuery(game: 'game-8')), isTrue);
  });

  test('re-storing an existing key does not evict anything', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(rankingsCacheProvider.notifier);

    for (var i = 0; i < 8; i++) {
      notifier.store(RankingsQuery(game: 'game-$i'), _page());
    }
    // Overwrite an already-cached key; the map must not grow past the cap
    // and every original key must still be present.
    notifier.store(const RankingsQuery(game: 'game-0'), _page());

    final cache = container.read(rankingsCacheProvider);
    expect(cache.length, 8);
    for (var i = 0; i < 8; i++) {
      expect(cache.containsKey(RankingsQuery(game: 'game-$i')), isTrue);
    }
  });
}
