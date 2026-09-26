import 'package:supabase_flutter/supabase_flutter.dart';

class StageInfo {
  const StageInfo({required this.id, required this.seq, required this.name, required this.status});
  factory StageInfo.fromJson(Map<String, dynamic> j) => StageInfo(
        id: j['id'] as String,
        seq: (j['seq'] as num).toInt(),
        name: j['name'] as String,
        status: j['status'] as String,
      );
  final String id;
  final int seq;
  final String name;
  final String status;
}

/// PostgREST returns a to-one join as a map or, depending on the relationship, a one-element list.
Map<String, dynamic>? _one(Object? v) {
  if (v is List) return v.isEmpty ? null : v.first as Map<String, dynamic>;
  return v as Map<String, dynamic>?;
}

class MatchInfo {
  const MatchInfo({
    required this.id,
    this.tournamentId,
    this.tournamentTitle,
    required this.round,
    required this.status,
    this.scoreA,
    this.scoreB,
    this.scheduledAt,
    this.isFullDay = false,
    this.streamUrl,
    this.replayUrl,
    this.playerAId,
    this.playerBId,
    required this.nameA,
    required this.nameB,
  });

  factory MatchInfo.fromJson(Map<String, dynamic> j) {
    String name(Object? team, Object? player) {
      final t = _one(team);
      if (t != null && t['name'] != null) return t['name'] as String;
      final p = _one(player);
      return (p?['display_name'] ?? p?['username'] ?? '—') as String;
    }

    return MatchInfo(
      id: j['id'] as String,
      tournamentId: j['tournament_id'] as String?,
      tournamentTitle: _one(j['tournaments'])?['title'] as String?,
      round: j['round'] as String,
      status: j['status'] as String,
      scoreA: (j['score_a'] as num?)?.toInt(),
      scoreB: (j['score_b'] as num?)?.toInt(),
      scheduledAt: j['scheduled_at'] as String?,
      isFullDay: (j['is_full_day'] as bool?) ?? false,
      streamUrl: j['youtube_stream_url'] as String?,
      replayUrl: j['replay_url'] as String?,
      playerAId: j['player_a_id'] as String?,
      playerBId: j['player_b_id'] as String?,
      nameA: name(j['team_a'], j['player_a']),
      nameB: name(j['team_b'], j['player_b']),
    );
  }

  final String id;
  final String? tournamentId;
  final String? tournamentTitle;
  final String round;
  final String status;
  final int? scoreA;
  final int? scoreB;
  final String? scheduledAt;
  final bool isFullDay;
  final String? streamUrl;
  final String? replayUrl;
  final String? playerAId;
  final String? playerBId;
  final String nameA;
  final String nameB;
}

/// The only direct Supabase reads Phase 2b makes (public-read tables, explicit columns): the match row and a
/// tournament's stages. Everything else — and every write — goes through `/api/mobile/v1/*`.
abstract class MatchReadsRepository {
  Future<MatchInfo> fetchMatch(String matchId);
  Future<List<StageInfo>> fetchStages(String tournamentId);
}

class SupabaseMatchReadsRepository implements MatchReadsRepository {
  SupabaseMatchReadsRepository(this._client);
  final SupabaseClient _client;

  static const _matchCols = 'id, tournament_id, round, status, score_a, score_b, scheduled_at, is_full_day, '
      'youtube_stream_url, replay_url, player_a_id, player_b_id, team_a_id, team_b_id, tournaments(title), '
      'player_a:profiles!matches_player_a_id_fkey(username, display_name), '
      'player_b:profiles!matches_player_b_id_fkey(username, display_name), '
      'team_a:squads!matches_team_a_id_fkey(name), team_b:squads!matches_team_b_id_fkey(name)';

  @override
  Future<MatchInfo> fetchMatch(String matchId) async {
    final row = await _client.from('matches').select(_matchCols).eq('id', matchId).single();
    return MatchInfo.fromJson(row);
  }

  @override
  Future<List<StageInfo>> fetchStages(String tournamentId) async {
    final rows = await _client
        .from('tournament_stages')
        .select('id, seq, name, status')
        .eq('tournament_id', tournamentId)
        .order('seq');
    return rows.map(StageInfo.fromJson).toList();
  }
}
