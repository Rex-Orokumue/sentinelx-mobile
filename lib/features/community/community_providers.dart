import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/community_models.dart';
import '../../core/providers.dart';
import 'community_repository.dart';

const _pageSize = 20;
const _maxLimit = 50; // the feed endpoint's contract maximum

/// Who is looking: the signed-in user's id, or null for a guest. The feed, post detail, status rings
/// and best-play answers carry caller-specific fields (myReaction, canDelete/canBoost, isSelf/hasUnseen,
/// myVoteNominationId), so each of those providers watches this and rebuilds on login/logout instead of
/// serving the previous viewer's answer. Keyed on the user id, not the token, so a token refresh for
/// the same user does not refetch. Awaits the session's first value so a signed-in cold start doesn't
/// fetch once as a guest and again as the user.
final communityViewerIdProvider = FutureProvider.autoDispose<String?>((ref) async => (await ref.watch(sessionProvider.future))?.user.id);

class CommunityFeedState {
  const CommunityFeedState({required this.pinned, required this.posts, required this.hasMore, this.loadingMore = false});
  final List<PostView> pinned, posts;
  final bool hasMore, loadingMore;
  CommunityFeedState copyWith({List<PostView>? pinned, List<PostView>? posts, bool? hasMore, bool? loadingMore}) =>
      CommunityFeedState(pinned: pinned ?? this.pinned, posts: posts ?? this.posts, hasMore: hasMore ?? this.hasMore, loadingMore: loadingMore ?? this.loadingMore);
}

class CommunityFeedNotifier extends AsyncNotifier<CommunityFeedState> {
  // loadMore and refreshInPlace both rewrite the post list, so they never overlap: a refresh that
  // arrives mid-loadMore is queued and runs once the page lands.
  bool _inFlight = false;
  bool _refreshQueued = false;

  @override
  Future<CommunityFeedState> build() async {
    await ref.watch(communityViewerIdProvider.future);
    final page = await ref.watch(communityRepositoryProvider).feed(offset: 0, limit: _pageSize);
    return CommunityFeedState(pinned: page.pinned, posts: page.posts, hasMore: page.hasMore);
  }

  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || !current.hasMore || _inFlight) return;
    _inFlight = true;
    state = AsyncData(current.copyWith(loadingMore: true));
    try {
      final page = await ref.read(communityRepositoryProvider).feed(offset: current.posts.length, limit: _pageSize);
      if (!ref.mounted) return;
      final base = state.value ?? current;
      // A post can slide across the page boundary while the player scrolls (new posts push the list
      // down), so drop anything already shown rather than listing it twice.
      final seen = {for (final p in base.posts) p.id};
      state = AsyncData(base.copyWith(
        posts: [...base.posts, ...page.posts.where((p) => !seen.contains(p.id))],
        hasMore: page.hasMore,
        loadingMore: false,
      ));
    } catch (_) {
      if (!ref.mounted) return;
      state = AsyncData((state.value ?? current).copyWith(loadingMore: false));
    } finally {
      _inFlight = false;
      if (_refreshQueued && ref.mounted) {
        _refreshQueued = false;
        unawaited(refreshInPlace());
      }
    }
  }

  /// Pull-to-refresh: back to page one. Never throws — on failure the last good feed stays and this
  /// returns false so the caller can say so.
  Future<bool> refresh() async {
    try {
      final page = await ref.read(communityRepositoryProvider).feed(offset: 0, limit: _pageSize);
      if (!ref.mounted) return true;
      state = AsyncData(CommunityFeedState(pinned: page.pinned, posts: page.posts, hasMore: page.hasMore));
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Background refresh (realtime ticks): re-reads the window the player has already scrolled
  /// through, in requests of at most the API's 50-row limit, so their place and "load more" position
  /// survive. A failure is silent — the loaded feed simply stays as it was.
  Future<void> refreshInPlace() async {
    final current = state.value;
    if (current == null) return;
    if (_inFlight) {
      _refreshQueued = true;
      return;
    }
    _inFlight = true;
    try {
      final repo = ref.read(communityRepositoryProvider);
      final loaded = current.posts.length;
      final first = await repo.feed(offset: 0, limit: loaded.clamp(_pageSize, _maxLimit));
      final posts = [...first.posts];
      var hasMore = first.hasMore;
      while (hasMore && posts.length < loaded) {
        final page = await repo.feed(offset: posts.length, limit: (loaded - posts.length).clamp(1, _maxLimit));
        posts.addAll(page.posts);
        hasMore = page.hasMore;
        if (page.posts.isEmpty) break;
      }
      if (!ref.mounted) return;
      state = AsyncData(CommunityFeedState(pinned: first.pinned, posts: posts, hasMore: hasMore));
    } catch (_) {
      // keep the last good state
    } finally {
      _inFlight = false;
    }
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
  Future<CommunityPostDetail> build() async {
    await ref.watch(communityViewerIdProvider.future);
    return ref.watch(communityRepositoryProvider).postDetail(postId);
  }

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

final communityBestPlayProvider = FutureProvider.autoDispose<BestPlayBanner?>((ref) async {
  await ref.watch(communityViewerIdProvider.future);
  return ref.watch(communityRepositoryProvider).bestPlay();
});

final communityStatusRingsProvider = FutureProvider.autoDispose<List<StatusRing>>((ref) async {
  await ref.watch(communityViewerIdProvider.future);
  return ref.watch(communityRepositoryProvider).statuses();
});

final communityStatusViewersProvider = FutureProvider.autoDispose.family<List<StatusViewer>, String>(
  (ref, id) => ref.watch(communityRepositoryProvider).statusViewers(id),
);

final communityTopMembersProvider = FutureProvider.autoDispose<List<TopMember>>((ref) => ref.watch(communityRepositoryProvider).topMembers());

final communityUpcomingEventsProvider = FutureProvider.autoDispose<List<UpcomingEvent>>((ref) => ref.watch(communityRepositoryProvider).upcomingEvents());

final communityGalleryProvider = FutureProvider.autoDispose<CommunityGalleryPage>((ref) => ref.watch(communityRepositoryProvider).gallery(offset: 0, limit: 8));

final communityStatsProvider = FutureProvider.autoDispose<CommunityStats>((ref) => ref.watch(communityRepositoryProvider).stats());
