import '../models/bracket_match.dart';
import '../models/tournament.dart';

abstract class TournamentsRepository {
  Future<List<Tournament>> fetchTournaments();
  Future<Tournament> fetchTournament(String id);
  Future<List<BracketMatch>> fetchBracket(String tournamentId);
}
