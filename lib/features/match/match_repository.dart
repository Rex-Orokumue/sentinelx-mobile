import '../../core/api/api_client.dart';
import '../../core/api/match_models.dart';

/// Thin wrapper over the Phase 2b `ApiClient` calls so screens and tests can inject fakes.
abstract class MatchRepository {
  Future<BracketView> bracket(String tournamentId);
  Future<List<PointsStandingRow>> stageStandings(String tournamentId, String stageId);
  Future<TournamentResults> results(String tournamentId);
  Future<MatchCentre> centre(String matchId);
  Future<void> checkIn(String matchId);
  Future<void> submitResult(
    String matchId, {
    required int scoreA,
    required int scoreB,
    required String recordingUrl,
    required String screenshotPath,
    required String idempotencyKey,
  });
  Future<void> rate(String matchId, {required int stars, required String idempotencyKey});
  Future<void> wager(String matchId, {required String pickPlayerId, required int stakeCoins, required String idempotencyKey});
  Future<void> submitLobbyResult(
    String lobbyId, {
    required int placement,
    required int kills,
    required String screenshotPath,
    required String idempotencyKey,
  });
  Future<MeSummary> summary();
}

class ApiMatchRepository implements MatchRepository {
  ApiMatchRepository(this._api);
  final ApiClient _api;

  @override
  Future<BracketView> bracket(String tournamentId) => _api.getTournamentBracket(tournamentId);

  @override
  Future<List<PointsStandingRow>> stageStandings(String tournamentId, String stageId) =>
      _api.getTournamentStandings(tournamentId, stageId);

  @override
  Future<TournamentResults> results(String tournamentId) => _api.getTournamentResults(tournamentId);

  @override
  Future<MatchCentre> centre(String matchId) => _api.getMatchCentre(matchId);

  @override
  Future<void> checkIn(String matchId) => _api.postMatchCheckIn(matchId);

  @override
  Future<void> submitResult(
    String matchId, {
    required int scoreA,
    required int scoreB,
    required String recordingUrl,
    required String screenshotPath,
    required String idempotencyKey,
  }) =>
      _api.postMatchResult(matchId,
          scoreA: scoreA, scoreB: scoreB, recordingUrl: recordingUrl, screenshotPath: screenshotPath, idempotencyKey: idempotencyKey);

  @override
  Future<void> rate(String matchId, {required int stars, required String idempotencyKey}) =>
      _api.postMatchRating(matchId, stars: stars, idempotencyKey: idempotencyKey);

  @override
  Future<void> wager(String matchId, {required String pickPlayerId, required int stakeCoins, required String idempotencyKey}) =>
      _api.postMatchWager(matchId, pickPlayerId: pickPlayerId, stakeCoins: stakeCoins, idempotencyKey: idempotencyKey);

  @override
  Future<void> submitLobbyResult(
    String lobbyId, {
    required int placement,
    required int kills,
    required String screenshotPath,
    required String idempotencyKey,
  }) =>
      _api.postLobbyResult(lobbyId, placement: placement, kills: kills, screenshotPath: screenshotPath, idempotencyKey: idempotencyKey);

  @override
  Future<MeSummary> summary() => _api.getMeSummary();
}
