Map<String, dynamic> profileJson({
  String id = 'p1',
  String username = 'ada',
  String? bio = 'Plays DLS.',
  int totalAchievements = 5,
  int unlockedAchievements = 2,
  int followerCount = 10,
  int? rank = 3,
  int? totalRanked = 120,
  bool withActivity = true,
}) =>
    {
      'player': {
        'id': id, 'username': username, 'displayName': 'Ada', 'avatarUrl': null, 'frameUrl': null,
        'profileTheme': null, 'usernameColour': null, 'country': 'NG', 'bio': bio,
        'createdAt': '2026-01-05T10:00:00+00:00', 'sxScore': 980, 'sentinelTier': 'trusted',
        'membershipTier': 'guardian', 'xp': 1500,
      },
      'stats': {
        'totalMatches': 20, 'wins': 12, 'losses': 6, 'goalsScored': 40, 'goalsConceded': 22, 'totalTitles': 1,
        'tournamentsPlayed': 4, 'currentStreak': 3, 'rank': rank, 'totalRankedPlayers': totalRanked,
        'followerCount': followerCount, 'followingCount': 4,
        'categoryStats': [
          {'category': 'football', 'scored': 40, 'conceded': 22},
        ],
      },
      'titles': withActivity
          ? [
              {'tournamentTitle': 'Masters Sept', 'tournamentSlug': 'masters-sept', 'gameName': 'DLS', 'date': '2026-09-20'},
            ]
          : [],
      'recentMatches': withActivity
          ? [
              {
                'id': 'm1', 'opponentName': 'Bola', 'playerScore': 3, 'opponentScore': 1, 'outcome': 'win',
                'tournamentTitle': 'Masters Sept', 'completedAt': '2026-09-20T18:00:00+00:00',
              },
              {
                'id': 'm2', 'opponentName': 'TBD', 'playerScore': 0, 'opponentScore': 0, 'outcome': 'draw',
                'tournamentTitle': null, 'completedAt': null,
              },
            ]
          : [],
      'achievements': {
        'total': totalAchievements,
        'unlockedCount': unlockedAchievements,
        'unlocked': [
          for (var i = 0; i < unlockedAchievements; i++)
            {
              'slug': 'a$i', 'name': 'Achievement $i', 'description': 'Desc $i', 'category': 'match',
              'unlockedAt': '2026-02-0${i + 1}T00:00:00+00:00', 'unlockCount': i + 1,
            },
        ],
        'showcase': unlockedAchievements > 0 ? ['a0'] : <String>[],
      },
      'posts': withActivity
          ? [
              {'id': 'po1', 'content': 'GG everyone', 'postType': 'manual', 'createdAt': '2026-09-21T10:00:00+00:00'},
            ]
          : [],
      'gallery': withActivity
          ? [
              {'id': 'g1', 'imageUrl': 'https://img.test/1.png'},
            ]
          : [],
    };

Map<String, dynamic> followEntryJson(String id, String? username, {String tier = 'recruit'}) => {
      'id': id, 'username': username, 'displayName': username?.toUpperCase(),
      'avatarUrl': null, 'membershipTier': tier,
    };
