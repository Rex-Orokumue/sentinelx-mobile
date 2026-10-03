import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/core/api/community_models.dart';
import 'package:sentinelx_mobile/features/community/community_providers.dart';
import 'package:sentinelx_mobile/features/community/community_realtime.dart';
import 'package:sentinelx_mobile/features/community/post_detail_screen.dart';

import '../../fakes/fake_community_repository.dart';
import '../../support/community_fixtures.dart';
import '../../support/pump_compete.dart';

PostView _post({
  String postType = 'manual',
  int commentCount = 0,
  bool canDelete = false,
  bool canBoost = false,
  Map<String, dynamic>? matchResult,
}) =>
    PostView.fromJson(postViewJson(
      id: 'p1',
      postType: postType,
      content: 'Post body',
      commentCount: commentCount,
      canDelete: canDelete,
      canBoost: canBoost,
      matchResult: matchResult,
    ));

CommentView _comment(String id, {String content = 'Nice play', bool canDelete = false}) =>
    CommentView.fromJson(commentViewJson(id: id, content: content, canDelete: canDelete));

FakeCommunityRepository _repo(PostView post, [List<CommentView> comments = const []]) =>
    FakeCommunityRepository(postDetails: {'p1': CommunityPostDetail(post: post, comments: comments)});

class _Capture {
  var login = 0, deleted = 0;
}

Future<({_Capture capture, StreamController<int> realtime})> _pump(
  WidgetTester tester,
  FakeCommunityRepository repo, {
  bool signedOut = false,
}) async {
  final capture = _Capture();
  final realtime = StreamController<int>.broadcast();
  addTearDown(realtime.close);
  await pumpCompete(
    tester,
    PostDetailScreen(postId: 'p1', onLogin: () => capture.login++, onDeleted: () => capture.deleted++),
    size: const Size(375, 6000),
    overrides: [
      ...competeBaseOverrides(signedOut: signedOut),
      communityRepositoryProvider.overrideWithValue(repo),
      communityPostDetailRealtimeProvider('p1').overrideWith((ref) => realtime.stream),
    ],
  );
  await tester.pumpAndSettle();
  return (capture: capture, realtime: realtime);
}

int _detailCalls(FakeCommunityRepository repo) => repo.calls.where((c) => c.startsWith('postDetail:')).length;

void main() {
  testWidgets('loading shows a spinner', (tester) async {
    final repo = _repo(_post());
    final gate = Completer<void>();
    // postDetail has no gate in the fake, so hold the provider open with a never-ready override.
    await pumpCompete(
      tester,
      PostDetailScreen(postId: 'p1', onLogin: () {}, onDeleted: () {}),
      overrides: [
        ...competeBaseOverrides(),
        communityRepositoryProvider.overrideWithValue(_GatedRepo(repo, gate)),
        communityPostDetailRealtimeProvider('p1').overrideWith((ref) => const Stream<int>.empty()),
      ],
    );
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    gate.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('error shows retry that refetches', (tester) async {
    final repo = _repo(_post())..postDetailError = Exception('boom');
    await _pump(tester, repo);
    expect(find.byKey(const Key('detail-retry')), findsOneWidget);
    repo.postDetailError = null;
    final before = _detailCalls(repo);
    await tester.tap(find.byKey(const Key('detail-retry')));
    await tester.pumpAndSettle();
    expect(_detailCalls(repo), before + 1);
    expect(find.text('Post body'), findsOneWidget);
  });

  testWidgets('renders the post and its comments', (tester) async {
    await _pump(tester, _repo(_post(commentCount: 2), [_comment('c1', content: 'first'), _comment('c2', content: 'second')]));
    expect(find.text('Post body'), findsOneWidget);
    expect(find.text('first'), findsOneWidget);
    expect(find.text('second'), findsOneWidget);
    expect(find.text('2 comments'), findsOneWidget);
  });

  testWidgets('no comments shows the empty copy', (tester) async {
    await _pump(tester, _repo(_post()));
    expect(find.text('No comments yet.'), findsOneWidget);
  });

  testWidgets('exactly 50 comments shows the cap notice and no load-more control', (tester) async {
    final comments = [for (var i = 0; i < 50; i++) _comment('c$i', content: 'comment $i')];
    await _pump(tester, _repo(_post(commentCount: 120), comments));
    expect(find.byKey(const Key('comments-cap-notice')), findsOneWidget);
    expect(find.text('Load more'), findsNothing);
  });

  testWidgets('fewer than 50 comments shows no cap notice', (tester) async {
    await _pump(tester, _repo(_post(), [_comment('c1')]));
    expect(find.byKey(const Key('comments-cap-notice')), findsNothing);
  });

  testWidgets('signed out: a sign-in prompt replaces the input and asks to log in', (tester) async {
    final h = await _pump(tester, _repo(_post()), signedOut: true);
    expect(find.byKey(const Key('comment-input')), findsNothing);
    expect(find.byKey(const Key('comment-signin-prompt')), findsOneWidget);
    await tester.tap(find.byKey(const Key('comment-signin-prompt')));
    expect(h.capture.login, 1);
  });

  testWidgets('signed in: submitting a comment sends it, shows it, bumps the count and clears the input', (tester) async {
    final repo = _repo(_post());
    await _pump(tester, repo);
    await tester.enterText(find.byKey(const Key('comment-input')), 'Great game');
    await tester.pump();
    await tester.tap(find.byKey(const Key('comment-submit')));
    await tester.pumpAndSettle();
    expect(repo.calls.where((c) => c.startsWith('createComment:p1:Great game:')), hasLength(1));
    expect(find.text('Great game'), findsOneWidget);
    expect(find.text('1 comments'), findsOneWidget);
    expect(tester.widget<TextField>(find.byKey(const Key('comment-input'))).controller!.text, isEmpty);
  });

  testWidgets('a failed comment keeps the text and shows the error', (tester) async {
    final repo = _repo(_post());
    repo.writeErrors['createComment'] = Exception('boom');
    await _pump(tester, repo);
    await tester.enterText(find.byKey(const Key('comment-input')), 'Great game');
    await tester.pump();
    await tester.tap(find.byKey(const Key('comment-submit')));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(find.byKey(const Key('comment-input'))).controller!.text, 'Great game');
    expect(find.text('Great game'), findsOneWidget); // only the input, not a posted comment
    expect(find.text('0 comments'), findsOneWidget);
  });

  testWidgets('empty and whitespace-only text disables submit', (tester) async {
    await _pump(tester, _repo(_post()));
    expect(tester.widget<IconButton>(find.byKey(const Key('comment-submit'))).onPressed, isNull);
    await tester.enterText(find.byKey(const Key('comment-input')), '   ');
    await tester.pump();
    expect(tester.widget<IconButton>(find.byKey(const Key('comment-submit'))).onPressed, isNull);
    await tester.enterText(find.byKey(const Key('comment-input')), 'hi');
    await tester.pump();
    expect(tester.widget<IconButton>(find.byKey(const Key('comment-submit'))).onPressed, isNotNull);
  });

  testWidgets('a deletable comment can be deleted after confirming; others show no control', (tester) async {
    final repo = _repo(_post(commentCount: 2), [_comment('c1', content: 'mine', canDelete: true), _comment('c2', content: 'theirs')]);
    await _pump(tester, repo);
    expect(find.byKey(const Key('comment-delete-c2')), findsNothing);
    await tester.tap(find.byKey(const Key('comment-delete-c1')));
    await tester.pumpAndSettle();
    expect(repo.calls.where((c) => c.startsWith('deleteComment')), isEmpty, reason: 'must confirm first');
    await tester.tap(find.byKey(const Key('comment-delete-confirm')));
    await tester.pumpAndSettle();
    expect(repo.calls, contains('deleteComment:c1'));
    expect(find.text('mine'), findsNothing);
    expect(find.text('1 comments'), findsOneWidget);
  });

  testWidgets('cancelling comment deletion sends nothing', (tester) async {
    final repo = _repo(_post(commentCount: 1), [_comment('c1', canDelete: true)]);
    await _pump(tester, repo);
    await tester.tap(find.byKey(const Key('comment-delete-c1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('comment-delete-cancel')));
    await tester.pumpAndSettle();
    expect(repo.calls.where((c) => c.startsWith('deleteComment')), isEmpty);
  });

  testWidgets('a deletable post is deleted after confirming and then onDeleted fires', (tester) async {
    final repo = _repo(_post(canDelete: true));
    final h = await _pump(tester, repo);
    await tester.tap(find.byKey(const Key('detail-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('detail-delete')));
    await tester.pumpAndSettle();
    expect(h.capture.deleted, 0, reason: 'must confirm first');
    await tester.tap(find.byKey(const Key('post-delete-confirm')));
    await tester.pumpAndSettle();
    expect(repo.calls, contains('deletePost:p1'));
    expect(h.capture.deleted, 1);
  });

  testWidgets('a failed post delete does not call onDeleted', (tester) async {
    final repo = _repo(_post(canDelete: true));
    repo.writeErrors['deletePost'] = Exception('boom');
    final h = await _pump(tester, repo);
    await tester.tap(find.byKey(const Key('detail-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('detail-delete')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('post-delete-confirm')));
    await tester.pumpAndSettle();
    expect(h.capture.deleted, 0);
  });

  testWidgets('delete and boost entries follow canDelete / canBoost exactly', (tester) async {
    await _pump(tester, _repo(_post(canDelete: false, canBoost: true)));
    await tester.tap(find.byKey(const Key('detail-menu')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('detail-boost')), findsOneWidget);
    expect(find.byKey(const Key('detail-delete')), findsNothing);
  });

  testWidgets('tapping boost opens the boost sheet', (tester) async {
    await _pump(tester, _repo(_post(canBoost: true)));
    await tester.tap(find.byKey(const Key('detail-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('detail-boost')));
    await tester.pumpAndSettle();
    expect(find.text('Boost this post?'), findsOneWidget);
  });

  testWidgets('a match-result post renders the result inline with no delete or boost entries', (tester) async {
    final repo = _repo(_post(postType: 'match_result', matchResult: matchResultDetailJson()));
    await _pump(tester, repo);
    expect(find.text('Champions Cup'), findsOneWidget);
    expect(find.text('Final'), findsOneWidget);
    expect(find.text('2 - 1'), findsOneWidget);
    await tester.tap(find.byKey(const Key('detail-menu')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('detail-delete')), findsNothing);
    expect(find.byKey(const Key('detail-boost')), findsNothing);
  });

  group('report entry points', () {
    testWidgets('signed in: reporting the post opens the report sheet for that post', (tester) async {
      final repo = _repo(_post());
      await _pump(tester, repo);
      await tester.tap(find.byKey(const Key('detail-menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('detail-report')));
      await tester.pumpAndSettle();
      expect(find.text('Report content'), findsOneWidget);
      await tester.tap(find.byKey(const Key('report-reason-spam')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('report-submit')));
      await tester.pumpAndSettle();
      expect(repo.calls.where((c) => c.startsWith('reportPost:p1:spam')), hasLength(1));
    });

    testWidgets('signed in: reporting a comment reports that comment', (tester) async {
      final repo = _repo(_post(commentCount: 1), [_comment('c1')]);
      await _pump(tester, repo);
      await tester.tap(find.byKey(const Key('comment-report-c1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('report-reason-violence')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('report-submit')));
      await tester.pumpAndSettle();
      expect(repo.calls.where((c) => c.startsWith('reportComment:c1:violence')), hasLength(1));
    });

    testWidgets('signed out: no report entry points are offered', (tester) async {
      await _pump(tester, _repo(_post(commentCount: 1), [_comment('c1')]), signedOut: true);
      expect(find.byKey(const Key('comment-report-c1')), findsNothing);
      expect(find.byKey(const Key('detail-menu')), findsNothing);
    });
  });

  testWidgets('each realtime event refetches the post exactly once', (tester) async {
    final repo = _repo(_post(), [_comment('c1')]);
    final h = await _pump(tester, repo);
    final before = _detailCalls(repo);
    h.realtime.add(1);
    await tester.pumpAndSettle();
    expect(_detailCalls(repo), before + 1);
    h.realtime.add(2);
    await tester.pumpAndSettle();
    expect(_detailCalls(repo), before + 2);
  });

  testWidgets('a realtime refetch keeps the typed draft and the loaded content', (tester) async {
    final repo = _repo(_post(), [_comment('c1', content: 'stays')]);
    final h = await _pump(tester, repo);
    await tester.enterText(find.byKey(const Key('comment-input')), 'half-typed');
    h.realtime.add(1);
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(find.byKey(const Key('comment-input'))).controller!.text, 'half-typed');
    expect(find.text('stays'), findsOneWidget);
  });
}

/// Delegates to [inner] but holds `postDetail` open until [gate] completes.
class _GatedRepo extends FakeCommunityRepository {
  _GatedRepo(this.inner, this.gate);
  final FakeCommunityRepository inner;
  final Completer<void> gate;

  @override
  Future<CommunityPostDetail> postDetail(String id) async {
    await gate.future;
    return inner.postDetail(id);
  }
}
