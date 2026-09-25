import 'package:sentinelx_mobile/core/api/players_models.dart';
import 'package:sentinelx_mobile/features/progress/progress_repository.dart';

typedef Pager<T> = HistoryPage<T> Function(String? cursor);

class FakeProgressRepository implements ProgressRepository {
  Map<String, dynamic> progressData = progressJson();
  Object? progressError;
  var progressCalls = 0;

  Pager<XpEvent>? xpPager;
  Pager<SxScoreEvent>? scorePager;
  Pager<CoinTransaction>? coinPager; // a pager may throw to simulate a failed page
  final xpCursors = <String?>[];
  final scoreCursors = <String?>[];
  final coinCursors = <String?>[];

  @override
  Future<MyProgress> progress() async {
    progressCalls++;
    if (progressError != null) throw progressError!;
    return MyProgress.fromJson(progressData);
  }

  @override
  Future<HistoryPage<XpEvent>> xp(String? cursor) async {
    xpCursors.add(cursor);
    return xpPager!(cursor);
  }

  @override
  Future<HistoryPage<SxScoreEvent>> score(String? cursor) async {
    scoreCursors.add(cursor);
    return scorePager!(cursor);
  }

  @override
  Future<HistoryPage<CoinTransaction>> coins(String? cursor) async {
    coinCursors.add(cursor);
    return coinPager!(cursor);
  }
}

Map<String, dynamic> progressJson({bool maxTier = false, bool withSeason = true}) => {
      'xp': maxTier ? 60000 : 1500,
      'membershipTier': maxTier ? 'legend' : 'guardian',
      'tierProgress': maxTier ? null : {'current': 'guardian', 'next': 'elite', 'xpIntoTier': 500, 'xpForNextTier': 4000},
      'sxScore': 980,
      'sentinelTier': 'trusted',
      'coinBalance': 1234,
      'seasonStanding': withSeason
          ? {'seasonName': 'Season 1', 'rank': 7, 'points': 40, 'pointsAtRankSixteen': 22, 'monthlyRank': null, 'monthlyPoints': 6}
          : null,
    };
