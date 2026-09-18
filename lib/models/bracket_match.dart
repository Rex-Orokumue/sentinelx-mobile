const List<String> kBracketRoundOrder = [
  'group',
  'round_of_16',
  'quarter_final',
  'semi_final',
  'third_place',
  'final',
];

int roundSortIndex(String round) {
  final index = kBracketRoundOrder.indexOf(round);
  return index == -1 ? kBracketRoundOrder.length : index;
}

String roundDisplayName(String round) {
  const knownNames = {
    'group': 'Group Stage',
    'round_of_16': 'Round of 16',
    'quarter_final': 'Quarterfinal',
    'semi_final': 'Semifinal',
    'third_place': 'Third Place',
    'final': 'Final',
  };
  return knownNames[round] ?? _titleCase(round.replaceAll('_', ' '));
}

String _titleCase(String value) {
  return value
      .split(' ')
      .where((word) => word.isNotEmpty)
      .map((word) => word[0].toUpperCase() + word.substring(1))
      .join(' ');
}

class BracketMatch {
  const BracketMatch({
    required this.id,
    required this.tournamentId,
    required this.round,
    required this.status,
    required this.scoreA,
    required this.scoreB,
    required this.scheduledAt,
    required this.completedAt,
    required this.participantALabel,
    required this.participantBLabel,
  });

  final String id;
  final String tournamentId;
  final String round;
  final String status;
  final int? scoreA;
  final int? scoreB;
  final DateTime? scheduledAt;
  final DateTime? completedAt;
  final String participantALabel;
  final String participantBLabel;

  factory BracketMatch.fromJson(Map<String, dynamic> json) {
    final playerA = json['player_a'] as Map<String, dynamic>?;
    final playerB = json['player_b'] as Map<String, dynamic>?;
    final teamA = json['team_a'] as Map<String, dynamic>?;
    final teamB = json['team_b'] as Map<String, dynamic>?;

    return BracketMatch(
      id: json['id'] as String,
      tournamentId: json['tournament_id'] as String,
      round: json['round'] as String,
      status: json['status'] as String,
      scoreA: json['score_a'] as int?,
      scoreB: json['score_b'] as int?,
      scheduledAt: _parseDate(json['scheduled_at']),
      completedAt: _parseDate(json['completed_at']),
      participantALabel: _participantLabel(playerA, teamA),
      participantBLabel: _participantLabel(playerB, teamB),
    );
  }

  static String _participantLabel(
    Map<String, dynamic>? player,
    Map<String, dynamic>? team,
  ) {
    if (team != null) return team['name'] as String? ?? 'TBD';
    if (player != null) {
      return (player['display_name'] as String?) ??
          (player['username'] as String?) ??
          'TBD';
    }
    return 'TBD';
  }

  static DateTime? _parseDate(dynamic value) =>
      value == null ? null : DateTime.parse(value as String);
}
