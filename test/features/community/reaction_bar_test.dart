import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/core/api/api_client.dart';
import 'package:sentinelx_mobile/core/api/community_models.dart';
import 'package:sentinelx_mobile/features/community/community_providers.dart';
import 'package:sentinelx_mobile/features/community/reaction_bar.dart';

import '../../fakes/fake_community_repository.dart';
import '../../support/pump_compete.dart';

const _zero = ReactionCounts(fire: 0, crown: 0, strong: 0, wow: 0);

PlayerRef _author() => const PlayerRef(id: 'a1', username: 'ada', membershipTier: 'free');

PostView _post({
  String id = 'p1',
  ReactionType? myReaction,
  ReactionCounts counts = _zero,
}) =>
    PostView(
      id: id,
      postType: PostType.manual,
      content: 'hello',
      imageUrls: const [],
      isPinned: false,
      createdAt: '2026-01-01T00:00:00Z',
      author: _author(),
      canDelete: false,
      canBoost: false,
      reactionCounts: counts,
      myReaction: myReaction,
      commentCount: 0,
      mutedByViewer: false,
    );

/// Wraps [ReactionBar] with local state so it behaves like a real feed/detail item: `onUpdate`
/// applies the transform to the held [PostView] and triggers a rebuild, and every applied result
/// is recorded in [onApplied] in order.
class _Harness extends StatefulWidget {
  const _Harness({super.key, required this.initial, required this.onApplied, required this.onSignIn});
  final PostView initial;
  final void Function(PostView) onApplied;
  final VoidCallback onSignIn;

  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  late PostView _post = widget.initial;

  /// Simulates something other than the tap changing the post (a realtime refetch landing).
  void external(PostView Function(PostView) transform) => setState(() => _post = transform(_post));

  @override
  Widget build(BuildContext context) => ReactionBar(
        post: _post,
        onUpdate: (transform) {
          setState(() => _post = transform(_post));
          widget.onApplied(_post);
        },
        onSignInRequired: widget.onSignIn,
      );
}

class _Ctx {
  _Ctx(this.repo, this.applied, this.signIns, this.harness);
  final FakeCommunityRepository repo;
  final List<PostView> applied;
  final List<void> signIns;
  final GlobalKey<_HarnessState> harness;
}

Future<_Ctx> _pumpBar(
  WidgetTester tester, {
  required PostView initial,
  FakeCommunityRepository? repo,
  bool signedOut = false,
}) async {
  final fake = repo ?? FakeCommunityRepository();
  final applied = <PostView>[];
  final signIns = <void>[];
  final harness = GlobalKey<_HarnessState>();
  await pumpCompete(
    tester,
    _Harness(key: harness, initial: initial, onApplied: applied.add, onSignIn: () => signIns.add(null)),
    overrides: [...competeBaseOverrides(signedOut: signedOut), communityRepositoryProvider.overrideWithValue(fake)],
  );
  await tester.pumpAndSettle();
  return _Ctx(fake, applied, signIns, harness);
}

void main() {
  group('PostView.withMyReaction', () {
    test('from no reaction, setting fire increments fire and sets myReaction', () {
      final post = _post();
      final next = post.withMyReaction(ReactionType.fire);
      expect(next.reactionCounts.fire, 1);
      expect(next.myReaction, ReactionType.fire);
    });

    test('from fire, clearing to null decrements fire and clears myReaction', () {
      final post = _post(myReaction: ReactionType.fire, counts: const ReactionCounts(fire: 1, crown: 0, strong: 0, wow: 0));
      final next = post.withMyReaction(null);
      expect(next.reactionCounts.fire, 0);
      expect(next.myReaction, isNull);
    });

    test('switching from fire to crown decrements fire and increments crown in one call', () {
      final post = _post(myReaction: ReactionType.fire, counts: const ReactionCounts(fire: 1, crown: 0, strong: 0, wow: 0));
      final next = post.withMyReaction(ReactionType.crown);
      expect(next.reactionCounts.fire, 0);
      expect(next.reactionCounts.crown, 1);
      expect(next.myReaction, ReactionType.crown);
    });
  });

  group('ReactionBar', () {
    testWidgets('signed-out tap asks to sign in and sends no API call', (tester) async {
      final ctx = await _pumpBar(tester, initial: _post(), signedOut: true);
      await tester.tap(find.byKey(const Key('react-crown')));
      await tester.pumpAndSettle();
      expect(ctx.signIns, hasLength(1));
      expect(ctx.repo.calls, isEmpty);
      expect(ctx.applied, isEmpty);
    });

    testWidgets('signed-in tap applies the optimistic count before the API call resolves, and keeps it on success', (tester) async {
      final repo = FakeCommunityRepository()..reactionGate = Completer<void>();
      final ctx = await _pumpBar(tester, initial: _post(), repo: repo);

      await tester.tap(find.byKey(const Key('react-crown')));
      await tester.pump();

      expect(ctx.applied, hasLength(1));
      expect(ctx.applied.single.reactionCounts.crown, 1);
      expect(ctx.applied.single.myReaction, ReactionType.crown);
      expect(ctx.repo.calls, hasLength(1));
      expect(ctx.repo.calls.single, startsWith('setReaction:p1:crown:'));

      repo.reactionGate!.complete();
      await tester.pumpAndSettle();

      // No rollback on success: the optimistic state is the last (and only) applied update.
      expect(ctx.applied, hasLength(1));
    });

    testWidgets('tapping the currently-active reaction calls removeReaction, not setReaction', (tester) async {
      final ctx = await _pumpBar(
        tester,
        initial: _post(myReaction: ReactionType.fire, counts: const ReactionCounts(fire: 1, crown: 0, strong: 0, wow: 0)),
      );

      await tester.tap(find.byKey(const Key('react-fire')));
      await tester.pumpAndSettle();

      expect(ctx.repo.calls, hasLength(1));
      expect(ctx.repo.calls.single, 'removeReaction:p1');
      expect(ctx.applied.last.reactionCounts.fire, 0);
      expect(ctx.applied.last.myReaction, isNull);
    });

    testWidgets('a failure rolls back only the own-reaction slot, keeping counts that landed while the request was in flight', (tester) async {
      final repo = FakeCommunityRepository()
        ..reactionGate = Completer<void>()
        ..writeErrors['setReaction'] = const ApiException(status: 0, code: 'network', message: 'offline');
      final ctx = await _pumpBar(
        tester,
        initial: _post(counts: const ReactionCounts(fire: 5, crown: 0, strong: 0, wow: 0)),
        repo: repo,
      );

      await tester.tap(find.byKey(const Key('react-crown')));
      await tester.pump();
      expect(ctx.applied.last.reactionCounts.crown, 1); // optimistic

      // Meanwhile a realtime refetch lands: others reacted, and the server doesn't have our tap.
      ctx.harness.currentState!.external((p) => p.copyWith(
            reactionCounts: const ReactionCounts(fire: 7, crown: 4, strong: 0, wow: 0),
            clearMyReaction: true,
          ));
      await tester.pump();

      repo.reactionGate!.complete();
      await tester.pumpAndSettle();

      final shown = tester.widget<ReactionBar>(find.byType(ReactionBar)).post;
      expect(shown.myReaction, isNull);
      expect(shown.reactionCounts.fire, 7, reason: 'the refetched count must survive the rollback');
      expect(shown.reactionCounts.crown, 4, reason: 'the rollback must not restore the pre-tap snapshot');
    });

    testWidgets('a failed setReaction rolls back to the exact pre-tap post and shows the error copy', (tester) async {
      final repo = FakeCommunityRepository();
      repo.writeErrors['setReaction'] = const ApiException(status: 409, code: 'not_found', message: 'gone');
      final before = _post();
      final ctx = await _pumpBar(tester, initial: before, repo: repo);

      await tester.tap(find.byKey(const Key('react-crown')));
      await tester.pumpAndSettle();

      expect(ctx.applied, hasLength(2));
      expect(ctx.applied.first.myReaction, ReactionType.crown); // optimistic
      expect(ctx.applied.last.myReaction, before.myReaction); // rolled back
      expect(ctx.applied.last.reactionCounts.crown, before.reactionCounts.crown);
      expect(ctx.applied.last.reactionCounts.fire, before.reactionCounts.fire);
      expect(find.text('This content is no longer available.'), findsOneWidget);
    });

    testWidgets(
        'two rapid taps on the same emoji before the first resolves send exactly one API call, '
        'end up applied (not rolled back), and show no error', (tester) async {
      final repo = FakeCommunityRepository()..reactionGate = Completer<void>();
      final ctx = await _pumpBar(tester, initial: _post(), repo: repo);

      await tester.tap(find.byKey(const Key('react-fire')));
      await tester.tap(find.byKey(const Key('react-fire')));
      await tester.pump();

      expect(ctx.repo.calls, hasLength(1));

      repo.reactionGate!.complete();
      await tester.pumpAndSettle();

      // The absorbed second tap is a true no-op: no rollback of the first tap's (successful)
      // optimistic update, and no spurious error toast for a request that was never sent.
      expect(ctx.applied.last.reactionCounts.fire, 1);
      expect(ctx.applied.last.myReaction, ReactionType.fire);
      expect(find.text('No connection. Check your internet and try again.'), findsNothing);
    });
  });
}
