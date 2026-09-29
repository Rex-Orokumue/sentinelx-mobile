import '../../core/api/api_client.dart';
import '../../core/api/community_models.dart';

/// Thin wrapper over the Phase 4 `ApiClient` community calls so screens and tests can inject fakes.
abstract class CommunityRepository {
  Future<CommunityFeedPage> feed({required int offset, required int limit});
  Future<CommunityPostDetail> postDetail(String id);
  Future<ChallengesWidget?> challenges();
  Future<BestPlayBanner?> bestPlay();
  Future<List<StatusRing>> statuses();
  Future<List<StatusViewer>> statusViewers(String statusId);
  Future<List<TopMember>> topMembers();
  Future<List<UpcomingEvent>> upcomingEvents();
  Future<CommunityGalleryPage> gallery({required int offset, required int limit});
  Future<CommunityStats> stats();
  Future<String> createPost({required String content, required List<String> imageUrls, required String idempotencyKey});
  Future<void> deletePost(String id);
  Future<void> boostPost(String id, {required String idempotencyKey});
  Future<ReactionType> setReaction(String postId, ReactionType reaction, {required String idempotencyKey});
  Future<void> removeReaction(String postId);
  Future<String> createComment(String postId, {required String content, required String idempotencyKey});
  Future<void> deleteComment(String id);
  Future<String> postStatus({String? imageUrl, String? caption, required String idempotencyKey});
  Future<void> deleteStatus(String id);
  Future<void> viewStatus(String id);
  Future<void> voteBestPlay(String nominationId, {required String idempotencyKey});
  Future<void> reportPost(String id, {required ReportReasonCode reasonCode, String? note, required String idempotencyKey});
  Future<void> reportComment(String id, {required ReportReasonCode reasonCode, String? note, required String idempotencyKey});
}

class ApiCommunityRepository implements CommunityRepository {
  ApiCommunityRepository(this._api);
  final ApiClient _api;

  @override
  Future<CommunityFeedPage> feed({required int offset, required int limit}) =>
      _api.getCommunityFeed(offset: offset, limit: limit);

  @override
  Future<CommunityPostDetail> postDetail(String id) => _api.getCommunityPost(id);

  @override
  Future<ChallengesWidget?> challenges() => _api.getCommunityChallenges();

  @override
  Future<BestPlayBanner?> bestPlay() => _api.getCommunityBestPlay();

  @override
  Future<List<StatusRing>> statuses() => _api.getCommunityStatuses();

  @override
  Future<List<StatusViewer>> statusViewers(String statusId) => _api.getCommunityStatusViewers(statusId);

  @override
  Future<List<TopMember>> topMembers() => _api.getCommunityTopMembers();

  @override
  Future<List<UpcomingEvent>> upcomingEvents() => _api.getCommunityUpcomingEvents();

  @override
  Future<CommunityGalleryPage> gallery({required int offset, required int limit}) =>
      _api.getCommunityGallery(offset: offset, limit: limit);

  @override
  Future<CommunityStats> stats() => _api.getCommunityStats();

  @override
  Future<String> createPost({required String content, required List<String> imageUrls, required String idempotencyKey}) =>
      _api.postCommunityPost(content: content, imageUrls: imageUrls, idempotencyKey: idempotencyKey);

  @override
  Future<void> deletePost(String id) => _api.deleteCommunityPost(id);

  @override
  Future<void> boostPost(String id, {required String idempotencyKey}) =>
      _api.postCommunityPostBoost(id, idempotencyKey: idempotencyKey);

  @override
  Future<ReactionType> setReaction(String postId, ReactionType reaction, {required String idempotencyKey}) =>
      _api.putCommunityPostReaction(postId, reaction: reaction, idempotencyKey: idempotencyKey);

  @override
  Future<void> removeReaction(String postId) => _api.deleteCommunityPostReaction(postId);

  @override
  Future<String> createComment(String postId, {required String content, required String idempotencyKey}) =>
      _api.postCommunityComment(postId, content: content, idempotencyKey: idempotencyKey);

  @override
  Future<void> deleteComment(String id) => _api.deleteCommunityComment(id);

  @override
  Future<String> postStatus({String? imageUrl, String? caption, required String idempotencyKey}) =>
      _api.postCommunityStatus(imageUrl: imageUrl, caption: caption, idempotencyKey: idempotencyKey);

  @override
  Future<void> deleteStatus(String id) => _api.deleteCommunityStatus(id);

  @override
  Future<void> viewStatus(String id) => _api.postCommunityStatusView(id);

  @override
  Future<void> voteBestPlay(String nominationId, {required String idempotencyKey}) =>
      _api.postCommunityBestPlayVote(nominationId, idempotencyKey: idempotencyKey);

  @override
  Future<void> reportPost(String id, {required ReportReasonCode reasonCode, String? note, required String idempotencyKey}) =>
      _api.postCommunityPostReport(id, reasonCode: reasonCode, note: note, idempotencyKey: idempotencyKey);

  @override
  Future<void> reportComment(String id, {required ReportReasonCode reasonCode, String? note, required String idempotencyKey}) =>
      _api.postCommunityCommentReport(id, reasonCode: reasonCode, note: note, idempotencyKey: idempotencyKey);
}
