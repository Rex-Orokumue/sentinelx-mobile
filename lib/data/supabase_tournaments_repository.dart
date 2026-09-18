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

  static const _matchColumns = '''
    id, tournament_id, round, status, score_a, score_b, scheduled_at, completed_at,
    player_a:profiles!matches_player_a_id_fkey(username, display_name),
    player_b:profiles!matches_player_b_id_fkey(username, display_name),
    team_a:squads!matches_team_a_id_fkey(name),
    team_b:squads!matches_team_b_id_fkey(name)
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
        .select(_matchColumns)
        .eq('tournament_id', tournamentId);
    final matches = rows.map((row) => BracketMatch.fromJson(row)).toList();
    matches.sort((a, b) => roundSortIndex(a.round).compareTo(roundSortIndex(b.round)));
    return matches;
  }
}
