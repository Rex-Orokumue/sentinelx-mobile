// Phase 4 Community wire models (feed, posts, reactions, comments, statuses, challenges,
// best-play, top members, upcoming events, gallery, stats). Parsed strictly from the shapes
// in the web repo's lib/mobile-api/endpoints/community-reads.ts / community-writes.ts.
// JSON keys are identical camelCase to the Dart field names throughout this file, unlike
// match_models.dart — no snake_case translation is needed anywhere here.

List<T> _list<T>(Object? v, T Function(Map<String, dynamic>) f) =>
    (v! as List<dynamic>).map((e) => f(e as Map<String, dynamic>)).toList();

Map<String, dynamic>? _obj(Object? v) => v == null ? null : v as Map<String, dynamic>;

int _int(Object? v) => (v as num).toInt();
int? _intOrNull(Object? v) => (v as num?)?.toInt();

enum ReactionType { fire, crown, strong, wow }

extension ReactionTypeWire on ReactionType {
  String get wireName => name;
}

ReactionType reactionTypeFromJson(String s) => switch (s) {
      'fire' => ReactionType.fire,
      'crown' => ReactionType.crown,
      'strong' => ReactionType.strong,
      'wow' => ReactionType.wow,
      _ => throw FormatException('Unknown reaction: $s'),
    };

enum PostType { manual, matchResult, achievement, announcement }

PostType postTypeFromJson(String s) => switch (s) {
      'manual' => PostType.manual,
      'match_result' => PostType.matchResult,
      'achievement' => PostType.achievement,
      'announcement' => PostType.announcement,
      _ => throw FormatException('Unknown post type: $s'),
    };

enum ReportReasonCode { spam, harassment, hateSpeech, nudityOrSexualContent, violence, misinformation, other }

extension ReportReasonCodeWire on ReportReasonCode {
  String get wireName => switch (this) {
        ReportReasonCode.spam => 'spam',
        ReportReasonCode.harassment => 'harassment',
        ReportReasonCode.hateSpeech => 'hate_speech',
        ReportReasonCode.nudityOrSexualContent => 'nudity_or_sexual_content',
        ReportReasonCode.violence => 'violence',
        ReportReasonCode.misinformation => 'misinformation',
        ReportReasonCode.other => 'other',
      };
}

class PlayerRef {
  const PlayerRef({this.id, this.username, this.displayName, this.avatarUrl, required this.membershipTier, this.sentinelTier, this.frameUrl});
  factory PlayerRef.fromJson(Map<String, dynamic> j) => PlayerRef(
        id: j['id'] as String?,
        username: j['username'] as String?,
        displayName: j['displayName'] as String?,
        avatarUrl: j['avatarUrl'] as String?,
        membershipTier: j['membershipTier'] as String,
        sentinelTier: j['sentinelTier'] as String?,
        frameUrl: j['frameUrl'] as String?,
      );
  static PlayerRef? maybe(Object? v) => v == null ? null : PlayerRef.fromJson(v as Map<String, dynamic>);
  final String? id, username, displayName, avatarUrl, sentinelTier, frameUrl;
  final String membershipTier;
  String get name => displayName ?? username ?? '—';
}

class MatchResultDetail {
  const MatchResultDetail({required this.matchId, required this.tournamentTitle, required this.roundLabel, this.scoreA, this.scoreB, this.playerA, this.playerB, this.scheduledAt});
  factory MatchResultDetail.fromJson(Map<String, dynamic> j) => MatchResultDetail(
        matchId: j['matchId'] as String,
        tournamentTitle: j['tournamentTitle'] as String,
        roundLabel: j['roundLabel'] as String,
        scoreA: _intOrNull(j['scoreA']),
        scoreB: _intOrNull(j['scoreB']),
        playerA: PlayerRef.maybe(j['playerA']),
        playerB: PlayerRef.maybe(j['playerB']),
        scheduledAt: j['scheduledAt'] as String?,
      );
  final String matchId, tournamentTitle, roundLabel;
  final int? scoreA, scoreB;
  final PlayerRef? playerA, playerB;
  final String? scheduledAt;
}

class ReactionCounts {
  const ReactionCounts({required this.fire, required this.crown, required this.strong, required this.wow});
  factory ReactionCounts.fromJson(Map<String, dynamic> j) => ReactionCounts(
        fire: _int(j['fire']),
        crown: _int(j['crown']),
        strong: _int(j['strong']),
        wow: _int(j['wow']),
      );
  final int fire, crown, strong, wow;
  int get total => fire + crown + strong + wow;
  int operator [](ReactionType t) => switch (t) {
        ReactionType.fire => fire,
        ReactionType.crown => crown,
        ReactionType.strong => strong,
        ReactionType.wow => wow,
      };
  ReactionCounts _with(ReactionType t, int delta) => switch (t) {
        ReactionType.fire => ReactionCounts(fire: fire + delta, crown: crown, strong: strong, wow: wow),
        ReactionType.crown => ReactionCounts(fire: fire, crown: crown + delta, strong: strong, wow: wow),
        ReactionType.strong => ReactionCounts(fire: fire, crown: crown, strong: strong + delta, wow: wow),
        ReactionType.wow => ReactionCounts(fire: fire, crown: crown, strong: strong, wow: wow + delta),
      };
  ReactionCounts increment(ReactionType t) => _with(t, 1);
  ReactionCounts decrement(ReactionType t) => _with(t, -1);
}

class PostView {
  const PostView({
    required this.id, required this.postType, required this.content, this.imageUrl, required this.imageUrls,
    this.referenceId, required this.isPinned, this.boostedUntil, required this.createdAt, required this.author,
    required this.canDelete, required this.canBoost, required this.reactionCounts, this.myReaction,
    required this.commentCount, this.matchResult, required this.mutedByViewer,
  });
  factory PostView.fromJson(Map<String, dynamic> j) {
    final mr = _obj(j['matchResult']);
    final myReaction = j['myReaction'];
    return PostView(
      id: j['id'] as String,
      postType: postTypeFromJson(j['postType'] as String),
      content: j['content'] as String,
      imageUrl: j['imageUrl'] as String?,
      imageUrls: (j['imageUrls'] as List<dynamic>).cast<String>(),
      referenceId: j['referenceId'] as String?,
      isPinned: j['isPinned'] as bool,
      boostedUntil: j['boostedUntil'] as String?,
      createdAt: j['createdAt'] as String,
      author: PlayerRef.fromJson(j['author'] as Map<String, dynamic>),
      canDelete: j['canDelete'] as bool,
      canBoost: j['canBoost'] as bool,
      reactionCounts: ReactionCounts.fromJson(j['reactionCounts'] as Map<String, dynamic>),
      myReaction: myReaction == null ? null : reactionTypeFromJson(myReaction as String),
      commentCount: _int(j['commentCount']),
      matchResult: mr == null ? null : MatchResultDetail.fromJson(mr),
      mutedByViewer: j['mutedByViewer'] as bool,
    );
  }
  final String id, content, createdAt;
  final PostType postType;
  final String? imageUrl, referenceId, boostedUntil;
  final List<String> imageUrls;
  final bool isPinned, canDelete, canBoost, mutedByViewer;
  final PlayerRef author;
  final ReactionCounts reactionCounts;
  final ReactionType? myReaction;
  final int commentCount;
  final MatchResultDetail? matchResult;

  PostView copyWith({ReactionCounts? reactionCounts, ReactionType? myReaction, bool clearMyReaction = false, int? commentCount}) => PostView(
        id: id, postType: postType, content: content, imageUrl: imageUrl, imageUrls: imageUrls, referenceId: referenceId,
        isPinned: isPinned, boostedUntil: boostedUntil, createdAt: createdAt, author: author, canDelete: canDelete, canBoost: canBoost,
        reactionCounts: reactionCounts ?? this.reactionCounts,
        myReaction: clearMyReaction ? null : (myReaction ?? this.myReaction),
        commentCount: commentCount ?? this.commentCount, matchResult: matchResult, mutedByViewer: mutedByViewer,
      );
}

class CommentView {
  const CommentView({required this.id, required this.content, required this.createdAt, required this.author, required this.canDelete});
  factory CommentView.fromJson(Map<String, dynamic> j) => CommentView(
        id: j['id'] as String,
        content: j['content'] as String,
        createdAt: j['createdAt'] as String,
        author: PlayerRef.fromJson(j['author'] as Map<String, dynamic>),
        canDelete: j['canDelete'] as bool,
      );
  final String id, content, createdAt;
  final PlayerRef author;
  final bool canDelete;
}

class CommunityFeedPage {
  const CommunityFeedPage({required this.pinned, required this.posts, required this.hasMore});
  factory CommunityFeedPage.fromJson(Map<String, dynamic> j) => CommunityFeedPage(
        pinned: _list(j['pinned'], PostView.fromJson),
        posts: _list(j['posts'], PostView.fromJson),
        hasMore: j['hasMore'] as bool,
      );
  final List<PostView> pinned, posts;
  final bool hasMore;
}

class CommunityPostDetail {
  const CommunityPostDetail({required this.post, required this.comments});
  factory CommunityPostDetail.fromJson(Map<String, dynamic> j) => CommunityPostDetail(
        post: PostView.fromJson(j['post'] as Map<String, dynamic>),
        comments: _list(j['comments'], CommentView.fromJson),
      );
  final PostView post;
  final List<CommentView> comments;
}

class ChallengeProgress {
  const ChallengeProgress({required this.slug, required this.title, required this.description, required this.goal, required this.progress, required this.completed, required this.coinReward, required this.xpReward});
  factory ChallengeProgress.fromJson(Map<String, dynamic> j) => ChallengeProgress(
        slug: j['slug'] as String,
        title: j['title'] as String,
        description: j['description'] as String,
        goal: _int(j['goal']),
        progress: _int(j['progress']),
        completed: j['completed'] as bool,
        coinReward: _int(j['coinReward']),
        xpReward: _int(j['xpReward']),
      );
  final String slug, title, description;
  final int goal, progress, coinReward, xpReward;
  final bool completed;
}

class ChallengesWidget {
  const ChallengesWidget({required this.weekLabel, required this.challenges});
  factory ChallengesWidget.fromJson(Map<String, dynamic> j) => ChallengesWidget(
        weekLabel: j['weekLabel'] as String,
        challenges: _list(j['challenges'], ChallengeProgress.fromJson),
      );
  final String weekLabel;
  final List<ChallengeProgress> challenges;
}

class BestPlayNomination {
  const BestPlayNomination({required this.nominationId, required this.postId, required this.content, required this.authorName, required this.voteCount});
  factory BestPlayNomination.fromJson(Map<String, dynamic> j) => BestPlayNomination(
        nominationId: j['nominationId'] as String,
        postId: j['postId'] as String,
        content: j['content'] as String,
        authorName: j['authorName'] as String,
        voteCount: _int(j['voteCount']),
      );
  final String nominationId, postId, content, authorName;
  final int voteCount;
}

class BestPlayBanner {
  const BestPlayBanner({required this.nominations, this.myVoteNominationId});
  factory BestPlayBanner.fromJson(Map<String, dynamic> j) => BestPlayBanner(
        nominations: _list(j['nominations'], BestPlayNomination.fromJson),
        myVoteNominationId: j['myVoteNominationId'] as String?,
      );
  final List<BestPlayNomination> nominations;
  final String? myVoteNominationId;
}

class StatusRow {
  const StatusRow({required this.id, required this.playerId, this.imageUrl, this.caption, required this.createdAt, required this.expiresAt, required this.authorName, this.authorUsername, this.authorAvatarUrl});
  factory StatusRow.fromJson(Map<String, dynamic> j) => StatusRow(
        id: j['id'] as String,
        playerId: j['playerId'] as String,
        imageUrl: j['imageUrl'] as String?,
        caption: j['caption'] as String?,
        createdAt: j['createdAt'] as String,
        expiresAt: j['expiresAt'] as String,
        authorName: j['authorName'] as String,
        authorUsername: j['authorUsername'] as String?,
        authorAvatarUrl: j['authorAvatarUrl'] as String?,
      );
  final String id, playerId, createdAt, expiresAt, authorName;
  final String? imageUrl, caption, authorUsername, authorAvatarUrl;
}

class StatusRing {
  const StatusRing({required this.playerId, required this.authorName, this.authorUsername, this.authorAvatarUrl, required this.statuses, required this.hasUnseen, required this.isSelf, required this.latestAt});
  factory StatusRing.fromJson(Map<String, dynamic> j) => StatusRing(
        playerId: j['playerId'] as String,
        authorName: j['authorName'] as String,
        authorUsername: j['authorUsername'] as String?,
        authorAvatarUrl: j['authorAvatarUrl'] as String?,
        statuses: _list(j['statuses'], StatusRow.fromJson),
        hasUnseen: j['hasUnseen'] as bool,
        isSelf: j['isSelf'] as bool,
        latestAt: j['latestAt'] as String,
      );
  final String playerId, authorName, latestAt;
  final String? authorUsername, authorAvatarUrl;
  final List<StatusRow> statuses;
  final bool hasUnseen, isSelf;
}

class StatusViewer {
  const StatusViewer({required this.viewerId, required this.name, this.username, this.avatarUrl, required this.viewedAt});
  factory StatusViewer.fromJson(Map<String, dynamic> j) => StatusViewer(
        viewerId: j['viewerId'] as String,
        name: j['name'] as String,
        username: j['username'] as String?,
        avatarUrl: j['avatarUrl'] as String?,
        viewedAt: j['viewedAt'] as String,
      );
  final String viewerId, name, viewedAt;
  final String? username, avatarUrl;
}

class TopMember {
  const TopMember({required this.rank, required this.id, this.username, this.displayName, this.avatarUrl, required this.membershipTier, required this.xp, this.frameUrl});
  factory TopMember.fromJson(Map<String, dynamic> j) => TopMember(
        rank: _int(j['rank']),
        id: j['id'] as String,
        username: j['username'] as String?,
        displayName: j['displayName'] as String?,
        avatarUrl: j['avatarUrl'] as String?,
        membershipTier: j['membershipTier'] as String,
        xp: _int(j['xp']),
        frameUrl: j['frameUrl'] as String?,
      );
  final int rank, xp;
  final String id, membershipTier;
  final String? username, displayName, avatarUrl, frameUrl;
  String get name => displayName ?? username ?? '—';
}

class UpcomingEvent {
  const UpcomingEvent({required this.id, required this.title, required this.date, required this.time, required this.ctaLabel, required this.ctaHref});
  factory UpcomingEvent.fromJson(Map<String, dynamic> j) => UpcomingEvent(
        id: j['id'] as String,
        title: j['title'] as String,
        date: j['date'] as String,
        time: j['time'] as String,
        ctaLabel: j['ctaLabel'] as String,
        ctaHref: j['ctaHref'] as String,
      );
  final String id, title, date, time, ctaLabel, ctaHref;
}

class GalleryItem {
  const GalleryItem({required this.id, required this.imageUrl, required this.caption, required this.authorName});
  factory GalleryItem.fromJson(Map<String, dynamic> j) => GalleryItem(
        id: j['id'] as String,
        imageUrl: j['imageUrl'] as String,
        caption: j['caption'] as String,
        authorName: j['authorName'] as String,
      );
  final String id, imageUrl, caption, authorName;
}

class CommunityGalleryPage {
  const CommunityGalleryPage({required this.items, required this.hasMore});
  factory CommunityGalleryPage.fromJson(Map<String, dynamic> j) => CommunityGalleryPage(
        items: _list(j['items'], GalleryItem.fromJson),
        hasMore: j['hasMore'] as bool,
      );
  final List<GalleryItem> items;
  final bool hasMore;
}

class CommunityStats {
  const CommunityStats({required this.memberCount, required this.countryCount, required this.tournamentCount});
  factory CommunityStats.fromJson(Map<String, dynamic> j) => CommunityStats(
        memberCount: _int(j['memberCount']),
        countryCount: _int(j['countryCount']),
        tournamentCount: _int(j['tournamentCount']),
      );
  final int memberCount, countryCount, tournamentCount;
}
