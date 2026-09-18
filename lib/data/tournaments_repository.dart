import '../models/tournament.dart';

abstract class TournamentsRepository {
  Future<List<Tournament>> fetchTournaments();
  Future<Tournament> fetchTournament(String id);
}
