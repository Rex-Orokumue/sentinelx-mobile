import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/models/bracket_match.dart';

void main() {
  group('BracketMatch.fromJson', () {
    test('prefers display_name over username for a solo match', () {
      final json = {
        'id': 'm1',
        'tournament_id': 't1',
        'round': 'final',
        'status': 'completed',
        'score_a': 3,
        'score_b': 1,
        'scheduled_at': '2026-09-20T18:00:00+00:00',
        'completed_at': '2026-09-20T19:00:00+00:00',
        'player_a': {'username': 'shadow_striker', 'display_name': 'Shadow Striker'},
        'player_b': {'username': 'goal_machine', 'display_name': null},
        'team_a': null,
        'team_b': null,
      };

      final match = BracketMatch.fromJson(json);

      expect(match.participantALabel, 'Shadow Striker');
      expect(match.participantBLabel, 'goal_machine');
      expect(match.scoreA, 3);
      expect(match.scoreB, 1);
      expect(match.status, 'completed');
    });

    test('uses squad name for a team match, ignoring player fields', () {
      final json = {
        'id': 'm2',
        'tournament_id': 't1',
        'round': 'group',
        'status': 'scheduled',
        'score_a': null,
        'score_b': null,
        'scheduled_at': null,
        'completed_at': null,
        'player_a': null,
        'player_b': null,
        'team_a': {'name': 'Phoenix Squad'},
        'team_b': {'name': 'Night Owls'},
      };

      final match = BracketMatch.fromJson(json);

      expect(match.participantALabel, 'Phoenix Squad');
      expect(match.participantBLabel, 'Night Owls');
    });

    test('falls back to TBD when neither player nor team is assigned yet', () {
      final json = {
        'id': 'm3',
        'tournament_id': 't1',
        'round': 'quarter_final',
        'status': 'scheduled',
        'score_a': null,
        'score_b': null,
        'scheduled_at': null,
        'completed_at': null,
        'player_a': null,
        'player_b': null,
        'team_a': null,
        'team_b': null,
      };

      final match = BracketMatch.fromJson(json);

      expect(match.participantALabel, 'TBD');
      expect(match.participantBLabel, 'TBD');
    });
  });

  group('round ordering and display', () {
    test('sorts bracket rounds from group stage to final', () {
      final rounds = ['final', 'group', 'semi_final', 'quarter_final', 'round_of_16', 'third_place'];
      rounds.sort((a, b) => roundSortIndex(a).compareTo(roundSortIndex(b)));

      expect(rounds, [
        'group',
        'round_of_16',
        'quarter_final',
        'semi_final',
        'third_place',
        'final',
      ]);
    });

    test('unknown rounds sort after all known rounds', () {
      expect(roundSortIndex('mystery_round'), greaterThan(roundSortIndex('final')));
    });

    test('produces human-readable round names', () {
      expect(roundDisplayName('group'), 'Group Stage');
      expect(roundDisplayName('round_of_16'), 'Round of 16');
      expect(roundDisplayName('quarter_final'), 'Quarterfinal');
      expect(roundDisplayName('semi_final'), 'Semifinal');
      expect(roundDisplayName('third_place'), 'Third Place');
      expect(roundDisplayName('final'), 'Final');
      expect(roundDisplayName('mystery_round'), 'Mystery Round');
    });
  });
}
