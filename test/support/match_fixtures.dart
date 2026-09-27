// Plain-JSON builders for the Phase 2b wire shapes (bracket, match centre, summary).
Map<String, dynamic> nameRefJson(String id, String name) => {'id': id, 'name': name};

Map<String, dynamic> fixtureJson({
  String id = 'm1',
  String round = 'group',
  String status = 'scheduled',
  int? scoreA,
  int? scoreB,
  String? groupId,
  String? groupName,
  Map<String, dynamic>? playerA,
  Map<String, dynamic>? playerB,
  String? scheduledAt = '2026-10-01T18:00:00Z',
  bool isFullDay = false,
}) =>
    {
      'id': id,
      'round': round,
      'group_id': groupId,
      'groupName': groupName,
      'status': status,
      'score_a': scoreA,
      'score_b': scoreB,
      'scheduled_at': scheduledAt,
      'is_full_day': isFullDay,
      'playerA': playerA ?? nameRefJson('p1', 'Ada'),
      'playerB': playerB ?? nameRefJson('p2', 'Bola'),
    };

Map<String, dynamic> standingRowJson({
  String playerId = 'p1',
  String name = 'Ada',
  String? clubName = 'FC Ada',
  int rank = 1,
  bool advancing = true,
}) =>
    {
      'playerId': playerId,
      'name': name,
      'clubName': clubName,
      'played': 3,
      'wins': 2,
      'draws': 1,
      'losses': 0,
      'goalsFor': 6,
      'goalsAgainst': 2,
      'goalDiff': 4,
      'points': 7,
      'rank': rank,
      'advancing': advancing,
    };

Map<String, dynamic> bracketJson({int groups = 1, bool withKnockout = true, Map<String, dynamic>? champion}) => {
      'standings': [
        for (var g = 0; g < groups; g++)
          {
            'groupId': 'g$g',
            'groupName': 'Group ${String.fromCharCode(65 + g)}',
            'rows': [
              standingRowJson(),
              standingRowJson(playerId: 'p2', name: 'Bola', clubName: null, rank: 2, advancing: false),
            ],
          },
      ],
      'fixtures': {
        'live': [fixtureJson(id: 'live1', status: 'live')],
        'upcoming': [fixtureJson(id: 'up1')],
        'completed': [fixtureJson(id: 'done1', status: 'completed', scoreA: 2, scoreB: 1)],
        'disputedOrCancelled': <Map<String, dynamic>>[],
      },
      'rounds': withKnockout
          ? [
              {
                'round': 'semi_final',
                'label': 'Semi-finals',
                'matches': [fixtureJson(id: 'sf1', round: 'semi_final')],
              },
            ]
          : <Map<String, dynamic>>[],
      'projected': withKnockout
          ? [
              {'round': 'final', 'label': 'Final', 'matchCount': 1},
            ]
          : <Map<String, dynamic>>[],
      'champion': champion,
      'thirdPlace': null,
      'thirdPlaceMatch': null,
      'hasGroups': groups > 0,
      'hasKnockout': withKnockout,
    };

Map<String, dynamic> centreJson({
  bool isParticipant = false,
  bool canCheckIn = false,
  String status = 'scheduled',
  bool windowOpen = true,
  String? myPick,
  int? myStake,
  List<String> checkedIn = const [],
  String verdict = 'none',
}) =>
    {
      'matchId': 'm1',
      'status': status,
      'scheduledAt': '2026-10-01T18:00:00Z',
      'isFullDay': false,
      'isParticipant': isParticipant,
      'canCheckIn': canCheckIn,
      'checkedInPlayerIds': checkedIn,
      'checkInVerdict': verdict,
      'soleAttendeeId': null,
      'wager': {
        'windowOpen': windowOpen,
        'pools': {'playerA': 300, 'playerB': 200},
        'feeRate': 0.1,
        'minStake': 10,
        'maxStake': 1000,
        'myPickPlayerId': myPick,
        'myStakeCoins': myStake,
        'estimatedPayoutIfIStakeA100': 166.5,
      },
      'noShowEligible': false,
    };

Map<String, dynamic> summaryJson({
  Map<String, dynamic>? nextMatch,
  Map<String, dynamic>? nextLobby,
  List<Map<String, dynamic>> banners = const [],
  List<Map<String, dynamic>> registrations = const [],
  bool hasSubmittableMatch = false,
}) =>
    {
      'nextMatch': nextMatch,
      'nextLobby': nextLobby,
      'hasSubmittableMatch': hasSubmittableMatch,
      'registrations': registrations,
      'banners': banners,
    };

Map<String, dynamic> nextMatchJson({String id = 'm1'}) => {
      'id': id,
      'status': 'scheduled',
      'round': 'quarter_final',
      'scheduledAt': '2026-10-01T18:00:00Z',
      'isFullDay': false,
      'tournamentTitle': 'Champions Cup',
    };

Map<String, dynamic> nextLobbyJson({String lobbyId = 'l1', bool submitted = false}) => {
      'lobbyId': lobbyId,
      'tournamentTitle': 'BR Open',
      'stageName': 'Stage 1',
      'roundNo': 2,
      'label': 'Round 2',
      'scheduledAt': null,
      'hasRoomCode': true,
      'submitted': submitted,
    };
