import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/community_models.dart';
import '../../core/providers.dart';
import 'community_repository.dart';

const _pageSize = 20;

class CommunityFeedState {
  const CommunityFeedState({required this.pinned, required this.posts, required this.hasMore, this.loadingMore = false});
  final List<PostView> pinned, posts;
  final bool hasMore, loadingMore;
  CommunityFeedState copyWith({List<PostView>? pinned, List<PostView>? posts, bool? hasMore, bool? loadingMore}) =>
      CommunityFeedState(pinned: pinned ?? this.pinned, posts: posts ?? this.posts, hasMore: hasMore ?? this.hasMore, loadingMore: loadingMore ?? this.loadingMore);
}

class CommunityFeedNotifier extends AsyncNotifier<CommunityFeedState> {
  bool _loadingMore = false;

  @override
  Future<CommunityFeedState> build() async {
    final page = await ref.watch(communityRepositoryProvider).feed(offset: 0, limit: _pageSize);
    return CommunityFeedState(pinned: page.pinned, posts: page.posts, hasMore: page.hasMore);
  }

  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || !current.hasMore || _loadingMore) return;
    _loadingMore = true;
    state = AsyncData(current.copyWith(loadingMore: true));
    try {
      final page = await ref.read(communityRepositoryProvider).feed(offset: current.posts.length, limit: _pageSize);
      if (!ref.mounted) return;
      final base = state.value ?? current;
      state = AsyncData(base.copyWith(posts: [...base.posts, ...page.posts], hasMore: page.hasMore, loadingMore: false));
    } catch (_) {
      if (!ref.mounted) return;
      state = AsyncData((state.value ?? current).copyWith(loadingMore: false));
    } finally {
      _loadingMore = false;
    }
  }

  Future<void> refresh() async {
    final page = await ref.read(communityRepositoryProvider).feed(offset: 0, limit: _pageSize);
    if (!ref.mounted) return;
    state = AsyncData(CommunityFeedState(pinned: page.pinned, posts: page.posts, hasMore: page.hasMore));
  }

  void updatePost(String id, PostView Function(PostView) transform) {
    final current = state.value;
    if (current == null) return;
    var changed = false;
    List<PostView> apply(List<PostView> list) => list
        .map((p) {
          if (p.id != id) return p;
          changed = true;
          return transform(p);
        })
        .toList();
    final pinned = apply(current.pinned);
    final posts = apply(current.posts);
    if (!changed) return;
    state = AsyncData(current.copyWith(pinned: pinned, posts: posts));
  }

  void removePost(String id) {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(current.copyWith(
      pinned: current.pinned.where((p) => p.id != id).toList(),
      posts: current.posts.where((p) => p.id != id).toList(),
    ));
  }
}

final communityFeedProvider = AsyncNotifierProvider.autoDispose<CommunityFeedNotifier, CommunityFeedState>(CommunityFeedNotifier.new);

class CommunityPostDetailNotifier extends AsyncNotifier<CommunityPostDetail> {
  CommunityPostDetailNotifier(this.postId);
  final String postId;

  @override
  Future<CommunityPostDetail> build() => ref.watch(communityRepositoryProvider).postDetail(postId);

  void updatePost(PostView Function(PostView) transform) {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(CommunityPostDetail(post: transform(current.post), comments: current.comments));
  }

  void addComment(CommentView comment) {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(CommunityPostDetail(
      post: current.post.copyWith(commentCount: current.post.commentCount + 1),
      comments: [...current.comments, comment],
    ));
  }

  void removeComment(String commentId) {
    final current = state.value;
    if (current == null) return;
    if (!current.comments.any((c) => c.id == commentId)) return;
    state = AsyncData(CommunityPostDetail(
      post: current.post.copyWith(commentCount: current.post.commentCount - 1),
      comments: current.comments.where((c) => c.id != commentId).toList(),
    ));
  }
}

final communityPostDetailProvider =
    AsyncNotifierProvider.autoDispose.family<CommunityPostDetailNotifier, CommunityPostDetail, String>(CommunityPostDetailNotifier.new);

final communityRepositoryProvider = Provider<CommunityRepository>((ref) => ApiCommunityRepository(ref.watch(apiClientProvider)));

/// Null when signed out; never calls the API signed out.
final communityChallengesProvider = FutureProvider.autoDispose<ChallengesWidget?>((ref) async {
  final me = await ref.watch(meProvider.future);
  if (me == null) return null;
  return ref.watch(communityRepositoryProvider).challenges();
});

final communityBestPlayProvider = FutureProvider.autoDispose<BestPlayBanner?>((ref) => ref.watch(communityRepositoryProvider).bestPlay());

final communityStatusRingsProvider = FutureProvider.autoDispose<List<StatusRing>>((ref) => ref.watch(communityRepositoryProvider).statuses());

final communityStatusViewersProvider = FutureProvider.autoDispose.family<List<StatusViewer>, String>(
  (ref, id) => ref.watch(communityRepositoryProvider).statusViewers(id),
);

final communityTopMembersProvider = FutureProvider.autoDispose<List<TopMember>>((ref) => ref.watch(communityRepositoryProvider).topMembers());

final communityUpcomingEventsProvider = FutureProvider.autoDispose<List<UpcomingEvent>>((ref) => ref.watch(communityRepositoryProvider).upcomingEvents());

final communityGalleryProvider = FutureProvider.autoDispose<CommunityGalleryPage>((ref) => ref.watch(communityRepositoryProvider).gallery(offset: 0, limit: 8));

final communityStatsProvider = FutureProvider.autoDispose<CommunityStats>((ref) => ref.watch(communityRepositoryProvider).stats());
