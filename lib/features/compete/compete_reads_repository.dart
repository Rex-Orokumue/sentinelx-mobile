import 'package:supabase_flutter/supabase_flutter.dart';

import 'compete_models.dart';

const int kTournamentPageSize = 20;

final _uuid = RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');

/// Web links carry a slug, in-app routes carry an id; the detail read accepts either.
bool looksLikeUuid(String v) => _uuid.hasMatch(v);

abstract class CompeteReadsRepository {
  Future<List<CompeteTournament>> fetchTournaments({required TournamentTab tab, String? gameSlug, int page = 1});
  Future<CompeteTournament> fetchTournament(String idOrSlug);
  Future<List<GameSummary>> fetchGames();
  Future<List<PendingInvitation>> fetchMyPendingInvitations(String userId);
  Future<String?> fetchMyPendingReference(String tournamentId, String userId);
}

class SupabaseCompeteReadsRepository implements CompeteReadsRepository {
  SupabaseCompeteReadsRepository(this._client);
  final SupabaseClient _client;

  static const _cols = 'id, title, slug, description, banner_url, card_image_url, status, format, '
      'competition_format, prize_pool, prize_second, prize_third, registration_fee, max_players, '
      'registration_start, registration_end, tournament_start, tournament_end, rules, invitation_only';

  @override
  Future<List<CompeteTournament>> fetchTournaments({required TournamentTab tab, String? gameSlug, int page = 1}) async {
    // Mirrors the web list page: an !inner join only when filtering by game.
    final games = gameSlug == null ? 'games(name, slug)' : 'games!inner(name, slug)';
    var q = _client.from('tournaments').select('$_cols, $games');
    if (gameSlug != null) q = q.eq('games.slug', gameSlug);
    q = switch (tab) {
      TournamentTab.live => q.eq('status', 'active'),
      TournamentTab.upcoming => q.inFilter('status', ['registration_open', 'registration_closed']),
      TournamentTab.completed => q.eq('status', 'completed'),
      TournamentTab.all => q.neq('status', 'draft'),
    };
    final from = (page - 1) * kTournamentPageSize;
    final rows = await q.order('created_at', ascending: false).range(from, from + kTournamentPageSize - 1);
    return rows.map(CompeteTournament.fromJson).toList();
  }

  @override
  Future<CompeteTournament> fetchTournament(String idOrSlug) async {
    final row = await _client
        .from('tournaments')
        .select('$_cols, games(name, slug)')
        .eq(looksLikeUuid(idOrSlug) ? 'id' : 'slug', idOrSlug)
        .single();
    return CompeteTournament.fromJson(row);
  }

  @override
  Future<List<GameSummary>> fetchGames() async {
    final rows = await _client.from('games').select('id, name, slug, icon_url').eq('active', true).order('name');
    return rows.map(GameSummary.fromJson).toList();
  }

  @override
  Future<List<PendingInvitation>> fetchMyPendingInvitations(String userId) async {
    final rows = await _client
        .from('tournament_invitations')
        .select('id, tournament_id, expires_at, tournament:tournaments(title, registration_fee)')
        .eq('player_id', userId)
        .eq('status', 'pending')
        .gt('expires_at', DateTime.now().toUtc().toIso8601String())
        .order('expires_at');
    return rows.map(PendingInvitation.fromJson).toList();
  }

  @override
  Future<String?> fetchMyPendingReference(String tournamentId, String userId) async {
    final row = await _client
        .from('tournament_registrations')
        .select('paystack_reference')
        .eq('tournament_id', tournamentId)
        .eq('player_id', userId)
        .eq('payment_status', 'pending')
        .maybeSingle();
    return row?['paystack_reference'] as String?;
  }
}
