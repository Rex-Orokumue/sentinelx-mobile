import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/match_models.dart';
import '../../core/providers.dart';
import 'match_reads_repository.dart';
import 'match_repository.dart';

final matchReadsRepositoryProvider =
    Provider<MatchReadsRepository>((ref) => SupabaseMatchReadsRepository(ref.watch(supabaseClientProvider)));

final matchRepositoryProvider = Provider<MatchRepository>((ref) => ApiMatchRepository(ref.watch(apiClientProvider)));

/// Names, score and stream URLs — the centre endpoint returns none of these.
final matchInfoProvider = FutureProvider.autoDispose.family<MatchInfo, String>(
  (ref, matchId) => ref.watch(matchReadsRepositoryProvider).fetchMatch(matchId),
);

final bracketProvider = FutureProvider.autoDispose.family<BracketView, String>(
  (ref, tournamentId) => ref.watch(matchRepositoryProvider).bracket(tournamentId),
);

final stagesProvider = FutureProvider.autoDispose.family<List<StageInfo>, String>(
  (ref, tournamentId) => ref.watch(matchReadsRepositoryProvider).fetchStages(tournamentId),
);

final stageStandingsProvider = FutureProvider.autoDispose.family<List<PointsStandingRow>, ({String tournamentId, String stageId})>(
  (ref, k) => ref.watch(matchRepositoryProvider).stageStandings(k.tournamentId, k.stageId),
);

final tournamentResultsProvider = FutureProvider.autoDispose.family<TournamentResults, String>(
  (ref, tournamentId) => ref.watch(matchRepositoryProvider).results(tournamentId),
);

final matchCentreProvider = FutureProvider.autoDispose.family<MatchCentre, String>(
  (ref, matchId) => ref.watch(matchRepositoryProvider).centre(matchId),
);

/// Null when signed out; never calls the API signed out.
final meSummaryProvider = FutureProvider.autoDispose<MeSummary?>((ref) async {
  final me = await ref.watch(meProvider.future);
  if (me == null) return null;
  return ref.watch(matchRepositoryProvider).summary();
});
