import 'package:sentinelx_mobile/core/api/match_models.dart';
import 'package:sentinelx_mobile/features/match/match_reads_repository.dart';
import 'package:sentinelx_mobile/features/match/match_repository.dart';

import '../support/match_fixtures.dart';

class FakeMatchReads implements MatchReadsRepository {
  FakeMatchReads({Map<String, MatchInfo>? matches, this.stages = const [], this.failAll = false, this.failStages = false})
      : matches = matches ?? {};

  final Map<String, MatchInfo> matches;
  List<StageInfo> stages;
  bool failAll;
  bool failStages;
  final matchCalls = <String>[];
  int stageCalls = 0;

  @override
  Future<MatchInfo> fetchMatch(String matchId) async {
    matchCalls.add(matchId);
    if (failAll) throw Exception('boom');
    final m = matches[matchId];
    if (m == null) throw Exception('missing match $matchId');
    return m;
  }

  @override
  Future<List<StageInfo>> fetchStages(String tournamentId) async {
    stageCalls++;
    if (failAll || failStages) throw Exception('boom');
    return stages;
  }
}

typedef ResultCall = ({String matchId, int scoreA, int scoreB, String recordingUrl, String screenshotPath, String key});
typedef RatingCall = ({String matchId, int stars, String key});
typedef WagerCall = ({String matchId, String pickPlayerId, int stakeCoins, String key});
typedef LobbyCall = ({String lobbyId, int placement, int kills, String screenshotPath, String key});

class FakeMatchRepository implements MatchRepository {
  FakeMatchRepository({BracketView? bracket, MatchCentre? centre, TournamentResults? results, MeSummary? summary})
      : bracketView = bracket ?? BracketView.fromJson(bracketJson()),
        centreView = centre ?? MatchCentre.fromJson(centreJson()),
        resultsView = results ?? const TournamentResults(champion: null, noWinner: false),
        summaryView = summary ?? MeSummary.fromJson(summaryJson());

  BracketView bracketView;
  MatchCentre centreView;
  TournamentResults resultsView;
  MeSummary summaryView;
  List<PointsStandingRow> stageRows = const [];

  /// When set, the matching read throws this instead of returning.
  Object? bracketError, centreError, resultsError, summaryError, stageError;

  int bracketCalls = 0, centreCalls = 0, resultsCalls = 0, summaryCalls = 0, stageCalls = 0;
  final checkIns = <String>[];
  final resultCalls = <ResultCall>[];
  final ratingCalls = <RatingCall>[];
  final wagerCalls = <WagerCall>[];
  final lobbyCalls = <LobbyCall>[];

  /// Per-method queues: `null` = succeed, anything else is thrown. The last entry repeats once one is left.
  final checkInResults = <Object?>[];
  final resultResults = <Object?>[];
  final ratingResults = <Object?>[];
  final wagerResults = <Object?>[];
  final lobbyResults = <Object?>[];

  /// When set, the write awaits it before answering (holds a request in flight).
  Future<void>? checkInGate, resultGate, ratingGate, wagerGate, lobbyGate;

  /// When set, a `centre()` call awaits it before answering (holds a refetch in flight, to test that
  /// a refresh keeps showing the previous data instead of blanking to a spinner).
  Future<void>? centreGate;

  Object? _next(List<Object?> q) => q.isEmpty ? null : (q.length > 1 ? q.removeAt(0) : q.first);

  @override
  Future<BracketView> bracket(String tournamentId) async {
    bracketCalls++;
    final e = bracketError;
    if (e != null) throw e;
    return bracketView;
  }

  @override
  Future<List<PointsStandingRow>> stageStandings(String tournamentId, String stageId) async {
    stageCalls++;
    final e = stageError;
    if (e != null) throw e;
    return stageRows;
  }

  @override
  Future<TournamentResults> results(String tournamentId) async {
    resultsCalls++;
    final e = resultsError;
    if (e != null) throw e;
    return resultsView;
  }

  @override
  Future<MatchCentre> centre(String matchId) async {
    centreCalls++;
    if (centreGate != null) await centreGate;
    final e = centreError;
    if (e != null) throw e;
    return centreView;
  }

  @override
  Future<void> checkIn(String matchId) async {
    checkIns.add(matchId);
    if (checkInGate != null) await checkInGate;
    final r = _next(checkInResults);
    if (r != null) throw r;
  }

  @override
  Future<void> submitResult(
    String matchId, {
    required int scoreA,
    required int scoreB,
    required String recordingUrl,
    required String screenshotPath,
    required String idempotencyKey,
  }) async {
    resultCalls.add((
      matchId: matchId,
      scoreA: scoreA,
      scoreB: scoreB,
      recordingUrl: recordingUrl,
      screenshotPath: screenshotPath,
      key: idempotencyKey,
    ));
    if (resultGate != null) await resultGate;
    final r = _next(resultResults);
    if (r != null) throw r;
  }

  @override
  Future<void> rate(String matchId, {required int stars, required String idempotencyKey}) async {
    ratingCalls.add((matchId: matchId, stars: stars, key: idempotencyKey));
    if (ratingGate != null) await ratingGate;
    final r = _next(ratingResults);
    if (r != null) throw r;
  }

  @override
  Future<void> wager(String matchId, {required String pickPlayerId, required int stakeCoins, required String idempotencyKey}) async {
    wagerCalls.add((matchId: matchId, pickPlayerId: pickPlayerId, stakeCoins: stakeCoins, key: idempotencyKey));
    if (wagerGate != null) await wagerGate;
    final r = _next(wagerResults);
    if (r != null) throw r;
  }

  @override
  Future<void> submitLobbyResult(
    String lobbyId, {
    required int placement,
    required int kills,
    required String screenshotPath,
    required String idempotencyKey,
  }) async {
    lobbyCalls.add((lobbyId: lobbyId, placement: placement, kills: kills, screenshotPath: screenshotPath, key: idempotencyKey));
    if (lobbyGate != null) await lobbyGate;
    final r = _next(lobbyResults);
    if (r != null) throw r;
  }

  @override
  Future<MeSummary> summary() async {
    summaryCalls++;
    final e = summaryError;
    if (e != null) throw e;
    return summaryView;
  }
}
