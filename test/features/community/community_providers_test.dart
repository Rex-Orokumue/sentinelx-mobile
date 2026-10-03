import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/core/api/community_models.dart';
import 'package:sentinelx_mobile/core/api/models.dart';
import 'package:sentinelx_mobile/core/providers.dart';
import 'package:sentinelx_mobile/features/community/community_providers.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../fakes/fake_community_repository.dart';
import '../../support/community_fixtures.dart';
import '../../support/pump_compete.dart' show testSession;

PostView _post(String id, {bool isPinned = false, int commentCount = 0}) =>
    PostView.fromJson(postViewJson(id: id, isPinned: isPinned, commentCount: commentCount));

CommunityFeedPage _page({List<PostView> pinned = const [], List<PostView> posts = const [], bool hasMore = false}) =>
    CommunityFeedPage(pinned: pinned, posts: posts, hasMore: hasMore);

CommentView _comment(String id) => CommentView.fromJson(commentViewJson(id: id));

CommunityPostDetail _detail(PostView post, {List<CommentView> comments = const []}) =>
    CommunityPostDetail(post: post, comments: comments);

/// Keeps an autoDispose provider alive for the test, like a mounted screen would.
class _Rig {
  factory _Rig({FakeCommunityRepository? repo, MeResponse? me, Stream<Session?>? session}) =>
      _Rig._(repo ?? FakeCommunityRepository(), me, session ?? Stream.value(null));

  _Rig._(this.repo, MeResponse? me, Stream<Session?> session)
      : container = ProviderContainer(
          retry: (_, _) => null,
          overrides: [
            communityRepositoryProvider.overrideWithValue(repo),
            meProvider.overrideWith((ref) async => me),
            sessionProvider.overrideWith((ref) => session),
          ],
        );

  final FakeCommunityRepository repo;
  final ProviderContainer container;

  CommunityFeedNotifier get feedNotifier => container.read(communityFeedProvider.notifier);
  CommunityFeedState get feedState => container.read(communityFeedProvider).requireValue;

  CommunityPostDetailNotifier detailNotifier(String id) => container.read(communityPostDetailProvider(id).notifier);
  CommunityPostDetail detailState(String id) => container.read(communityPostDetailProvider(id)).requireValue;

  /// Keeps the feed family provider alive for the rest of the test (as a mounted screen would).
  void keepFeedAlive() => container.listen(communityFeedProvider, (_, _) {});

  /// Keeps the post-detail family provider alive for [id] for the rest of the test.
  void keepDetailAlive(String id) => container.listen(communityPostDetailProvider(id), (_, _) {});
}

void main() {
  group('communityFeedProvider', () {
    test('initial build calls feed(offset: 0, limit: 20) and exposes pinned/posts/hasMore', () async {
      final repo = FakeCommunityRepository(
        feedPage: _page(pinned: [_post('pinned1')], posts: [_post('p1'), _post('p2')], hasMore: true),
      );
      final r = _Rig(repo: repo);
      addTearDown(r.container.dispose);
      r.keepFeedAlive();
      await r.container.read(communityFeedProvider.future);

      expect(repo.calls, ['feed:0:20']);
      expect(r.feedState.pinned.map((p) => p.id), ['pinned1']);
      expect(r.feedState.posts.map((p) => p.id), ['p1', 'p2']);
      expect(r.feedState.hasMore, isTrue);
    });

    test('loadMore calls feed(offset: <post count>, limit: 20) and appends', () async {
      final repo = FakeCommunityRepository(feedPages: [
        _page(posts: [_post('p1'), _post('p2')], hasMore: true),
        _page(posts: [_post('p3')], hasMore: false),
      ]);
      final r = _Rig(repo: repo);
      addTearDown(r.container.dispose);
      r.keepFeedAlive();
      await r.container.read(communityFeedProvider.future);

      await r.feedNotifier.loadMore();

      expect(repo.calls, ['feed:0:20', 'feed:2:20']);
      expect(r.feedState.posts.map((p) => p.id), ['p1', 'p2', 'p3']);
      expect(r.feedState.hasMore, isFalse);
      expect(r.feedState.loadingMore, isFalse);
    });

    test('a second concurrent loadMore call is a no-op while the first is in flight', () async {
      final repo = FakeCommunityRepository(feedPages: [
        _page(posts: [_post('p1')], hasMore: true),
        _page(posts: [_post('p2')], hasMore: true),
      ]);
      final r = _Rig(repo: repo);
      addTearDown(r.container.dispose);
      r.keepFeedAlive();
      await r.container.read(communityFeedProvider.future);

      final gate = Completer<void>();
      repo.feedGate = gate;
      final first = r.feedNotifier.loadMore();
      final second = r.feedNotifier.loadMore();
      gate.complete();
      await first;
      await second;

      expect(repo.calls.where((c) => c.startsWith('feed:')).length, 2); // initial build + exactly one loadMore
      expect(r.feedState.posts.map((p) => p.id), ['p1', 'p2']);
    });

    test('loadMore does nothing when hasMore is false', () async {
      final repo = FakeCommunityRepository(feedPage: _page(posts: [_post('p1')], hasMore: false));
      final r = _Rig(repo: repo);
      addTearDown(r.container.dispose);
      r.keepFeedAlive();
      await r.container.read(communityFeedProvider.future);

      await r.feedNotifier.loadMore();

      expect(repo.calls, ['feed:0:20']);
      expect(r.feedState.posts.map((p) => p.id), ['p1']);
    });

    test('refresh replaces pinned/posts/hasMore from a fresh offset-0 fetch', () async {
      final repo = FakeCommunityRepository(feedPages: [
        _page(posts: [_post('p1')], hasMore: true),
        _page(pinned: [_post('pinned2')], posts: [_post('p2'), _post('p3')], hasMore: false),
      ]);
      final r = _Rig(repo: repo);
      addTearDown(r.container.dispose);
      r.keepFeedAlive();
      await r.container.read(communityFeedProvider.future);

      await r.feedNotifier.refresh();

      expect(repo.calls, ['feed:0:20', 'feed:0:20']);
      expect(r.feedState.pinned.map((p) => p.id), ['pinned2']);
      expect(r.feedState.posts.map((p) => p.id), ['p2', 'p3']);
      expect(r.feedState.hasMore, isFalse);
    });

    test('updatePost mutates the post wherever it is and is a no-op for a missing id', () async {
      final repo = FakeCommunityRepository(
        feedPage: _page(pinned: [_post('pinned1', commentCount: 1)], posts: [_post('p1', commentCount: 2), _post('p2', commentCount: 3)]),
      );
      final r = _Rig(repo: repo);
      addTearDown(r.container.dispose);
      r.keepFeedAlive();
      await r.container.read(communityFeedProvider.future);

      r.feedNotifier.updatePost('p1', (p) => p.copyWith(commentCount: p.commentCount + 1));
      expect(r.feedState.posts.firstWhere((p) => p.id == 'p1').commentCount, 3);
      expect(r.feedState.posts.firstWhere((p) => p.id == 'p2').commentCount, 3); // untouched

      r.feedNotifier.updatePost('pinned1', (p) => p.copyWith(commentCount: p.commentCount + 1));
      expect(r.feedState.pinned.firstWhere((p) => p.id == 'pinned1').commentCount, 2);

      final before = r.feedState;
      r.feedNotifier.updatePost('missing', (p) => p.copyWith(commentCount: 99));
      expect(identical(r.feedState, before), isTrue);
    });

    test('removePost removes it from both pinned and posts', () async {
      final repo = FakeCommunityRepository(
        feedPage: _page(pinned: [_post('p1')], posts: [_post('p1'), _post('p2')]),
      );
      final r = _Rig(repo: repo);
      addTearDown(r.container.dispose);
      r.keepFeedAlive();
      await r.container.read(communityFeedProvider.future);

      r.feedNotifier.removePost('p1');

      expect(r.feedState.pinned, isEmpty);
      expect(r.feedState.posts.map((p) => p.id), ['p2']);
    });
  });

  group('communityPostDetailProvider', () {
    test('calls postDetail(id); updatePost/addComment/removeComment mutate state and adjust commentCount', () async {
      final post = _post('p1', commentCount: 1);
      final repo = FakeCommunityRepository(postDetails: {'p1': _detail(post, comments: [_comment('c1')])});
      final r = _Rig(repo: repo);
      addTearDown(r.container.dispose);
      r.keepDetailAlive('p1');

      await r.container.read(communityPostDetailProvider('p1').future);
      expect(repo.calls, contains('postDetail:p1'));
      expect(r.detailState('p1').comments.map((c) => c.id), ['c1']);

      r.detailNotifier('p1').updatePost((p) => p.copyWith(commentCount: 42));
      expect(r.detailState('p1').post.commentCount, 42);

      r.detailNotifier('p1').addComment(_comment('c2'));
      expect(r.detailState('p1').comments.map((c) => c.id), ['c1', 'c2']);
      expect(r.detailState('p1').post.commentCount, 43);

      r.detailNotifier('p1').removeComment('c1');
      expect(r.detailState('p1').comments.map((c) => c.id), ['c2']);
      expect(r.detailState('p1').post.commentCount, 42);

      // Removing an id that isn't present is a no-op.
      final before = r.detailState('p1');
      r.detailNotifier('p1').removeComment('does-not-exist');
      expect(identical(r.detailState('p1'), before), isTrue);
    });
  });

  group('communityChallengesProvider', () {
    test('never calls challenges() when signed out and returns null', () async {
      final repo = FakeCommunityRepository();
      final r = _Rig(repo: repo, me: null);
      addTearDown(r.container.dispose);

      final result = await r.container.read(communityChallengesProvider.future);

      expect(result, isNull);
      expect(repo.calls, isEmpty);
    });

    test('calls challenges() when signed in', () async {
      final repo = FakeCommunityRepository(challengesWidget: ChallengesWidget.fromJson(challengesJson()));
      final r = _Rig(repo: repo, me: const MeResponse(id: 'me1', email: null, roles: [], isStaff: false, isAdmin: false, profile: null));
      addTearDown(r.container.dispose);

      final result = await r.container.read(communityChallengesProvider.future);

      expect(result, isNotNull);
      expect(repo.calls, ['challenges']);
    });
  });

  group('viewer-specific providers follow the signed-in user', () {
    test('login and logout each refetch feed, post detail, status rings and best play', () async {
      final repo = FakeCommunityRepository(
        feedPage: _page(posts: [_post('p1')]),
        postDetails: {'p1': _detail(_post('p1'))},
      );
      final session = StreamController<Session?>();
      addTearDown(session.close);
      final r = _Rig(repo: repo, session: session.stream);
      addTearDown(r.container.dispose);
      r.container.listen(communityFeedProvider, (_, _) {});
      r.container.listen(communityPostDetailProvider('p1'), (_, _) {});
      r.container.listen(communityStatusRingsProvider, (_, _) {});
      r.container.listen(communityBestPlayProvider, (_, _) {});

      int count(String prefix) => repo.calls.where((c) => c.startsWith(prefix)).length;
      Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 20));

      session.add(null); // a guest opens Community
      await settle();
      final before = [count('feed:'), count('postDetail:'), count('statuses'), count('bestPlay')];
      expect(before, [1, 1, 1, 1]);

      session.add(testSession()); // ...then logs in: the guest's answer (no myReaction, no canDelete) is stale
      await settle();
      expect([count('feed:'), count('postDetail:'), count('statuses'), count('bestPlay')], [2, 2, 2, 2]);

      session.add(null); // ...and logs out: the previous user's flags must not linger
      await settle();
      expect([count('feed:'), count('postDetail:'), count('statuses'), count('bestPlay')], [3, 3, 3, 3]);
    });

    test('a token refresh for the same user does not refetch', () async {
      final repo = FakeCommunityRepository(feedPage: _page(posts: [_post('p1')]));
      final session = StreamController<Session?>();
      addTearDown(session.close);
      final r = _Rig(repo: repo, session: session.stream);
      addTearDown(r.container.dispose);
      r.container.listen(communityFeedProvider, (_, _) {});
      session.add(testSession());
      await Future<void>.delayed(const Duration(milliseconds: 20));
      session.add(testSession()); // same user id, e.g. an access-token refresh
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(repo.calls.where((c) => c.startsWith('feed:')), hasLength(1));
    });
  });
}
