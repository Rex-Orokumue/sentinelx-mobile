import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/bracket_match.dart';
import '../models/tournament.dart';
import 'tournaments_repository.dart';

class SupabaseTournamentsRepository implements TournamentsRepository {
  SupabaseTournamentsRepository(this._client);

  final SupabaseClient _client;

  static const _tournamentColumns = '''
    id, title, slug, description, banner_url, card_image_url, status, format,
    competition_format, entry_unit, prize_pool, prize_second, prize_third,
    registration_fee, max_players, registration_start, registration_end,
    tournament_start, tournament_end, rules, games(name)
  ''';

  @override
  Future<List<Tournament>> fetchTournaments() async {
    final rows = await _client
        .from('tournaments')
        .select(_tournamentColumns)
        .neq('status', 'draft')
        .order('created_at', ascending: false);
    return rows.map((row) => Tournament.fromJson(row)).toList();
  }

  @override
  Future<Tournament> fetchTournament(String id) async {
    final row = await _client
        .from('tournaments')
        .select(_tournamentColumns)
        .eq('id', id)
        .single();
    return Tournament.fromJson(row);
  }

  @override
  Future<List<BracketMatch>> fetchBracket(String tournamentId) async {
    final rows = await _client
        .from('matches')
        .select('id, tournament_id, round')
        .eq('tournament_id', tournamentId);
    return rows
        .map((row) => BracketMatch(
              id: row['id'] as String,
              tournamentId: row['tournament_id'] as String,
              round: row['round'] as String,
            ))
        .toList();
  }
}
