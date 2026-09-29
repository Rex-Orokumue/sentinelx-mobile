import 'dart:async';

import 'package:sentinelx_mobile/core/api/community_models.dart';
import 'package:sentinelx_mobile/features/community/community_repository.dart';

/// In-memory `CommunityRepository` for tests. Reads return seeded fixtures; every call (read or
/// write) is recorded in [calls] as a descriptive string so tests can assert invocations (including
/// payload + idempotency key for writes) without a real Dio stack. A write throws when a matching
/// entry has been seeded in [writeErrors] (consumed once).
class FakeCommunityRepository implements CommunityRepository {
  FakeCommunityRepository({
    CommunityFeedPage? feedPage,
    List<CommunityFeedPage>? feedPages,
    Map<String, CommunityPostDetail> postDetails = const {},
    this.challengesWidget,
    this.bestPlayBanner,
    this.statusRings = const [],
    this.statusViewersList = const [],
    this.topMembersList = const [],
    this.upcomingEventsList = const [],
    CommunityGalleryPage? galleryPage,
    CommunityStats? stats,
  })  : feedPages = feedPages ?? [feedPage ?? const CommunityFeedPage(pinned: [], posts: [], hasMore: false)],
        postDetails = Map.of(postDetails),
        galleryPage = galleryPage ?? const CommunityGalleryPage(items: [], hasMore: false),
        communityStats = stats ?? const CommunityStats(memberCount: 0, countryCount: 0, tournamentCount: 0);

  /// Consumed in call order for `feed()`; the last entry repeats once exhausted.
  final List<CommunityFeedPage> feedPages;
  final Map<String, CommunityPostDetail> postDetails;
  ChallengesWidget? challengesWidget;
  BestPlayBanner? bestPlayBanner;
  List<StatusRing> statusRings;
  List<StatusViewer> statusViewersList;
  List<TopMember> topMembersList;
  List<UpcomingEvent> upcomingEventsList;
  CommunityGalleryPage galleryPage;
  CommunityStats communityStats;

  /// Ids returned by the create* writes.
  String newPostId = 'new-post-id';
  String newCommentId = 'new-comment-id';
  String newStatusId = 'new-status-id';

  /// Every call, read or write, recorded as a descriptive string in invocation order.
  final calls = <String>[];

  /// Held open while `feed()` is awaited, to simulate a request still in flight.
  Completer<void>? feedGate;
  Object? feedError;
  Object? postDetailError;

  /// Held open while `setReaction`/`removeReaction` is awaited, to simulate a request still in
  /// flight (e.g. to test a busy-guarded second tap, or that an optimistic update is visible
  /// before the request resolves).
  Completer<void>? reactionGate;

  /// Held open while `createPost` is awaited, to simulate a request still in flight (e.g. to test
  /// that back navigation is blocked while a post is being created).
  Completer<void>? createPostGate;

  /// Held open while `boostPost` is awaited, to simulate a request still in flight (e.g. to test
  /// that the boost sheet blocks close/drag mid-flight, or that a second tap while busy sends no
  /// second request).
  Completer<void>? boostGate;

  /// Held open while `postStatus` is awaited, to simulate a request still in flight (e.g. to test
  /// that the status compose screen blocks back navigation while a story is being posted).
  Completer<void>? postStatusGate;

  /// Held open while `statusViewers` is awaited (e.g. to test the loading state).
  Completer<void>? statusViewersGate;
  Object? statusViewersError;

  /// Errors to throw for a write, keyed by method name (e.g. `'createPost'`). Consumed once.
  final Map<String, Object> writeErrors = {};

  int _feedCallCount = 0;

  void _maybeThrow(String method) {
    final e = writeErrors.remove(method);
    if (e != null) throw e;
  }

  @override
  Future<CommunityFeedPage> feed({required int offset, required int limit}) async {
    calls.add('feed:$offset:$limit');
    final idx = _feedCallCount++;
    if (feedGate != null) await feedGate!.future;
    if (feedError != null) throw feedError!;
    return idx < feedPages.length ? feedPages[idx] : feedPages.last;
  }

  @override
  Future<CommunityPostDetail> postDetail(String id) async {
    calls.add('postDetail:$id');
    if (postDetailError != null) throw postDetailError!;
    final d = postDetails[id];
    if (d == null) throw Exception('missing post detail $id');
    return d;
  }

  @override
  Future<ChallengesWidget?> challenges() async {
    calls.add('challenges');
    return challengesWidget;
  }

  @override
  Future<BestPlayBanner?> bestPlay() async {
    calls.add('bestPlay');
    return bestPlayBanner;
  }

  @override
  Future<List<StatusRing>> statuses() async {
    calls.add('statuses');
    return statusRings;
  }

  @override
  Future<List<StatusViewer>> statusViewers(String statusId) async {
    calls.add('statusViewers:$statusId');
    if (statusViewersGate != null) await statusViewersGate!.future;
    if (statusViewersError != null) throw statusViewersError!;
    return statusViewersList;
  }

  @override
  Future<List<TopMember>> topMembers() async {
    calls.add('topMembers');
    return topMembersList;
  }

  @override
  Future<List<UpcomingEvent>> upcomingEvents() async {
    calls.add('upcomingEvents');
    return upcomingEventsList;
  }

  @override
  Future<CommunityGalleryPage> gallery({required int offset, required int limit}) async {
    calls.add('gallery:$offset:$limit');
    return galleryPage;
  }

  @override
  Future<CommunityStats> stats() async {
    calls.add('stats');
    return communityStats;
  }

  @override
  Future<String> createPost({required String content, required List<String> imageUrls, required String idempotencyKey}) async {
    calls.add('createPost:$content:${imageUrls.join(",")}:$idempotencyKey');
    if (createPostGate != null) await createPostGate!.future;
    _maybeThrow('createPost');
    return newPostId;
  }

  @override
  Future<void> deletePost(String id) async {
    calls.add('deletePost:$id');
    _maybeThrow('deletePost');
  }

  @override
  Future<void> boostPost(String id, {required String idempotencyKey}) async {
    calls.add('boostPost:$id:$idempotencyKey');
    if (boostGate != null) await boostGate!.future;
    _maybeThrow('boostPost');
  }

  @override
  Future<ReactionType> setReaction(String postId, ReactionType reaction, {required String idempotencyKey}) async {
    calls.add('setReaction:$postId:${reaction.wireName}:$idempotencyKey');
    if (reactionGate != null) await reactionGate!.future;
    _maybeThrow('setReaction');
    return reaction;
  }

  @override
  Future<void> removeReaction(String postId) async {
    calls.add('removeReaction:$postId');
    if (reactionGate != null) await reactionGate!.future;
    _maybeThrow('removeReaction');
  }

  @override
  Future<String> createComment(String postId, {required String content, required String idempotencyKey}) async {
    calls.add('createComment:$postId:$content:$idempotencyKey');
    _maybeThrow('createComment');
    return newCommentId;
  }

  @override
  Future<void> deleteComment(String id) async {
    calls.add('deleteComment:$id');
    _maybeThrow('deleteComment');
  }

  @override
  Future<String> postStatus({String? imageUrl, String? caption, required String idempotencyKey}) async {
    calls.add('postStatus:$imageUrl:$caption:$idempotencyKey');
    if (postStatusGate != null) await postStatusGate!.future;
    _maybeThrow('postStatus');
    return newStatusId;
  }

  @override
  Future<void> deleteStatus(String id) async {
    calls.add('deleteStatus:$id');
    _maybeThrow('deleteStatus');
  }

  @override
  Future<void> viewStatus(String id) async {
    calls.add('viewStatus:$id');
    _maybeThrow('viewStatus');
  }

  @override
  Future<void> voteBestPlay(String nominationId, {required String idempotencyKey}) async {
    calls.add('voteBestPlay:$nominationId:$idempotencyKey');
    _maybeThrow('voteBestPlay');
  }

  @override
  Future<void> reportPost(String id, {required ReportReasonCode reasonCode, String? note, required String idempotencyKey}) async {
    calls.add('reportPost:$id:${reasonCode.wireName}:$note:$idempotencyKey');
    _maybeThrow('reportPost');
  }

  @override
  Future<void> reportComment(String id, {required ReportReasonCode reasonCode, String? note, required String idempotencyKey}) async {
    calls.add('reportComment:$id:${reasonCode.wireName}:$note:$idempotencyKey');
    _maybeThrow('reportComment');
  }
}
