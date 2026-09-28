// Plain-JSON builders for the Phase 4 Community wire shapes. Field names are the exact
// camelCase JSON keys the web repo's lib/mobile-api/endpoints/community-reads.ts /
// community-writes.ts return — no snake_case translation, mirroring community_models.dart.

Map<String, dynamic> playerRefJson({
  String? id = 'u1',
  String? username = 'ada',
  String? displayName = 'Ada Lovelace',
  String? avatarUrl,
  String membershipTier = 'free',
  String? sentinelTier,
  String? frameUrl,
}) =>
    {
      'id': id,
      'username': username,
      'displayName': displayName,
      'avatarUrl': avatarUrl,
      'membershipTier': membershipTier,
      'sentinelTier': sentinelTier,
      'frameUrl': frameUrl,
    };

Map<String, dynamic> reactionCountsJson({int fire = 0, int crown = 0, int strong = 0, int wow = 0}) =>
    {'fire': fire, 'crown': crown, 'strong': strong, 'wow': wow};

Map<String, dynamic> matchResultDetailJson({
  String matchId = 'm1',
  String tournamentTitle = 'Champions Cup',
  String roundLabel = 'Final',
  int? scoreA = 2,
  int? scoreB = 1,
  Map<String, dynamic>? playerA,
  Map<String, dynamic>? playerB,
  String? scheduledAt = '2026-10-01T18:00:00Z',
}) =>
    {
      'matchId': matchId,
      'tournamentTitle': tournamentTitle,
      'roundLabel': roundLabel,
      'scoreA': scoreA,
      'scoreB': scoreB,
      'playerA': playerA ?? playerRefJson(),
      'playerB': playerB ?? playerRefJson(id: 'u2', username: 'bola', displayName: 'Bola'),
      'scheduledAt': scheduledAt,
    };

Map<String, dynamic> postViewJson({
  String id = 'p1',
  String postType = 'manual',
  String content = 'Hello community',
  String? imageUrl,
  List<String> imageUrls = const [],
  String? referenceId,
  bool isPinned = false,
  String? boostedUntil,
  String createdAt = '2026-09-28T12:00:00Z',
  Map<String, dynamic>? author,
  bool canDelete = true,
  bool canBoost = true,
  Map<String, dynamic>? reactionCounts,
  String? myReaction,
  int commentCount = 0,
  Map<String, dynamic>? matchResult,
  bool mutedByViewer = false,
}) =>
    {
      'id': id,
      'postType': postType,
      'content': content,
      'imageUrl': imageUrl,
      'imageUrls': imageUrls,
      'referenceId': referenceId,
      'isPinned': isPinned,
      'boostedUntil': boostedUntil,
      'createdAt': createdAt,
      'author': author ?? playerRefJson(),
      'canDelete': canDelete,
      'canBoost': canBoost,
      'reactionCounts': reactionCounts ?? reactionCountsJson(),
      'myReaction': myReaction,
      'commentCount': commentCount,
      'matchResult': matchResult,
      'mutedByViewer': mutedByViewer,
    };

Map<String, dynamic> commentViewJson({
  String id = 'c1',
  String content = 'Nice play',
  String createdAt = '2026-09-28T12:05:00Z',
  Map<String, dynamic>? author,
  bool canDelete = true,
}) =>
    {
      'id': id,
      'content': content,
      'createdAt': createdAt,
      'author': author ?? playerRefJson(),
      'canDelete': canDelete,
    };

Map<String, dynamic> feedPageJson({
  List<Map<String, dynamic>> pinned = const [],
  List<Map<String, dynamic>>? posts,
  bool hasMore = false,
}) =>
    {
      'pinned': pinned,
      'posts': posts ?? [postViewJson()],
      'hasMore': hasMore,
    };

Map<String, dynamic> challengeProgressJson({
  String slug = 'react-5',
  String title = 'React to 5 posts',
  String description = 'React to 5 posts this week',
  int goal = 5,
  int progress = 2,
  bool completed = false,
  int coinReward = 10,
  int xpReward = 20,
}) =>
    {
      'slug': slug,
      'title': title,
      'description': description,
      'goal': goal,
      'progress': progress,
      'completed': completed,
      'coinReward': coinReward,
      'xpReward': xpReward,
    };

Map<String, dynamic> challengesJson({
  String weekLabel = 'Week 39',
  List<Map<String, dynamic>>? challenges,
}) =>
    {
      'weekLabel': weekLabel,
      'challenges': challenges ?? [challengeProgressJson()],
    };

Map<String, dynamic> bestPlayNominationJson({
  String nominationId = 'n1',
  String postId = 'p1',
  String content = 'Amazing clutch',
  String authorName = 'Ada',
  int voteCount = 3,
}) =>
    {
      'nominationId': nominationId,
      'postId': postId,
      'content': content,
      'authorName': authorName,
      'voteCount': voteCount,
    };

Map<String, dynamic> bestPlayJson({
  List<Map<String, dynamic>>? nominations,
  String? myVoteNominationId,
}) =>
    {
      'nominations': nominations ?? [bestPlayNominationJson()],
      'myVoteNominationId': myVoteNominationId,
    };

Map<String, dynamic> statusRowJson({
  String id = 's1',
  String playerId = 'u1',
  String? imageUrl = 'https://x/img.png',
  String? caption,
  String createdAt = '2026-09-28T10:00:00Z',
  String expiresAt = '2026-09-29T10:00:00Z',
  String authorName = 'Ada',
  String? authorUsername = 'ada',
  String? authorAvatarUrl,
}) =>
    {
      'id': id,
      'playerId': playerId,
      'imageUrl': imageUrl,
      'caption': caption,
      'createdAt': createdAt,
      'expiresAt': expiresAt,
      'authorName': authorName,
      'authorUsername': authorUsername,
      'authorAvatarUrl': authorAvatarUrl,
    };

Map<String, dynamic> statusRingJson({
  String playerId = 'u1',
  String authorName = 'Ada',
  String? authorUsername = 'ada',
  String? authorAvatarUrl,
  List<Map<String, dynamic>>? statuses,
  bool hasUnseen = true,
  bool isSelf = false,
  String latestAt = '2026-09-28T10:00:00Z',
}) =>
    {
      'playerId': playerId,
      'authorName': authorName,
      'authorUsername': authorUsername,
      'authorAvatarUrl': authorAvatarUrl,
      'statuses': statuses ?? [statusRowJson()],
      'hasUnseen': hasUnseen,
      'isSelf': isSelf,
      'latestAt': latestAt,
    };

Map<String, dynamic> statusViewerJson({
  String viewerId = 'u2',
  String name = 'Bola',
  String? username = 'bola',
  String? avatarUrl,
  String viewedAt = '2026-09-28T10:05:00Z',
}) =>
    {
      'viewerId': viewerId,
      'name': name,
      'username': username,
      'avatarUrl': avatarUrl,
      'viewedAt': viewedAt,
    };

Map<String, dynamic> topMemberJson({
  int rank = 1,
  String id = 'u1',
  String? username = 'ada',
  String? displayName = 'Ada',
  String? avatarUrl,
  String membershipTier = 'free',
  int xp = 100,
  String? frameUrl,
}) =>
    {
      'rank': rank,
      'id': id,
      'username': username,
      'displayName': displayName,
      'avatarUrl': avatarUrl,
      'membershipTier': membershipTier,
      'xp': xp,
      'frameUrl': frameUrl,
    };

Map<String, dynamic> upcomingEventJson({
  String id = 'e1',
  String title = 'Weekly Cup',
  String date = '2026-10-05',
  String time = '18:00',
  String ctaLabel = 'Register',
  String ctaHref = '/tournaments/e1',
}) =>
    {
      'id': id,
      'title': title,
      'date': date,
      'time': time,
      'ctaLabel': ctaLabel,
      'ctaHref': ctaHref,
    };

Map<String, dynamic> galleryItemJson({
  String id = 'g1',
  String imageUrl = 'https://x/g.png',
  String caption = 'Great win',
  String authorName = 'Ada',
}) =>
    {
      'id': id,
      'imageUrl': imageUrl,
      'caption': caption,
      'authorName': authorName,
    };

Map<String, dynamic> galleryPageJson({
  List<Map<String, dynamic>>? items,
  bool hasMore = false,
}) =>
    {
      'items': items ?? [galleryItemJson()],
      'hasMore': hasMore,
    };

Map<String, dynamic> communityStatsJson({
  int memberCount = 1000,
  int countryCount = 20,
  int tournamentCount = 50,
}) =>
    {
      'memberCount': memberCount,
      'countryCount': countryCount,
      'tournamentCount': tournamentCount,
    };
