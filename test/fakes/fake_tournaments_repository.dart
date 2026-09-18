import 'package:sentinelx_mobile/data/tournaments_repository.dart';
import 'package:sentinelx_mobile/models/bracket_match.dart';
import 'package:sentinelx_mobile/models/tournament.dart';

class FakeTournamentsRepository implements TournamentsRepository {
  FakeTournamentsRepository({
    this.tournaments = const [],
    this.tournamentById,
    this.matchesByTournament = const {},
    this.tournamentsError,
    this.tournamentError,
    this.bracketError,
  });

  final List<Tournament> tournaments;
  final Tournament? tournamentById;
  final Map<String, List<BracketMatch>> matchesByTournament;
  final Object? tournamentsError;
  final Object? tournamentError;
  final Object? bracketError;

  @override
  Future<List<Tournament>> fetchTournaments() async {
    if (tournamentsError != null) throw tournamentsError!;
    return tournaments;
  }

  @override
  Future<Tournament> fetchTournament(String id) async {
    if (tournamentError != null) throw tournamentError!;
    final tournament = tournamentById;
    if (tournament == null) {
      throw StateError('FakeTournamentsRepository: no tournament configured for id $id');
    }
    return tournament;
  }

  @override
  Future<List<BracketMatch>> fetchBracket(String tournamentId) async {
    if (bracketError != null) throw bracketError!;
    return matchesByTournament[tournamentId] ?? const [];
  }
}
