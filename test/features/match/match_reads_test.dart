import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/features/match/match_reads_repository.dart';

Map<String, dynamic> _row({
  Object? tournaments = const {'title': 'Champions Cup'},
  Object? playerA = const {'username': 'ada', 'display_name': 'Ada'},
  Object? playerB = const {'username': 'bola', 'display_name': null},
  Object? teamA,
  Object? teamB,
  int? scoreA,
  int? scoreB,
}) =>
    {
      'id': 'm1',
      'tournament_id': 't1',
      'round': 'quarter_final',
      'status': 'completed',
      'score_a': scoreA,
      'score_b': scoreB,
      'scheduled_at': '2026-10-01T18:00:00Z',
      'is_full_day': false,
      'youtube_stream_url': 'https://youtu.be/x',
      'replay_url': null,
      'player_a_id': 'p1',
      'player_b_id': 'p2',
      'team_a_id': null,
      'team_b_id': null,
      'tournaments': tournaments,
      'player_a': playerA,
      'player_b': playerB,
      'team_a': teamA,
      'team_b': teamB,
    };

void main() {
  test('MatchInfo.fromJson parses a full row', () {
    final m = MatchInfo.fromJson(_row(scoreA: 2, scoreB: 1));
    expect(m.id, 'm1');
    expect(m.tournamentId, 't1');
    expect(m.tournamentTitle, 'Champions Cup');
    expect(m.round, 'quarter_final');
    expect(m.status, 'completed');
    expect(m.scoreA, 2);
    expect(m.scoreB, 1);
    expect(m.streamUrl, 'https://youtu.be/x');
    expect(m.replayUrl, isNull);
    expect(m.playerAId, 'p1');
    expect(m.playerBId, 'p2');
    expect(m.nameA, 'Ada');
    expect(m.nameB, 'bola'); // display_name null → username
  });

  test('team names win over player names', () {
    final m = MatchInfo.fromJson(_row(teamA: {'name': 'Lions'}, teamB: {'name': 'Tigers'}));
    expect(m.nameA, 'Lions');
    expect(m.nameB, 'Tigers');
  });

  test('joins returned as a one-element list are accepted', () {
    final m = MatchInfo.fromJson(_row(
      tournaments: [
        {'title': 'Cup'}
      ],
      playerA: [
        {'username': 'ada', 'display_name': 'Ada L'}
      ],
      teamB: [
        {'name': 'Tigers'}
      ],
    ));
    expect(m.tournamentTitle, 'Cup');
    expect(m.nameA, 'Ada L');
    expect(m.nameB, 'Tigers');
  });

  test('null scores stay null', () {
    final m = MatchInfo.fromJson(_row());
    expect(m.scoreA, isNull);
    expect(m.scoreB, isNull);
  });

  test('a missing profile join renders an em dash', () {
    final m = MatchInfo.fromJson(_row(playerA: null, playerB: null, tournaments: null));
    expect(m.nameA, '—');
    expect(m.nameB, '—');
    expect(m.tournamentTitle, isNull);
  });

  test('StageInfo.fromJson', () {
    final s = StageInfo.fromJson({'id': 's1', 'seq': 2, 'name': 'Stage 2', 'status': 'active'});
    expect(s.id, 's1');
    expect(s.seq, 2);
    expect(s.name, 'Stage 2');
    expect(s.status, 'active');
  });
}
