import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/core/api/community_models.dart';
import 'package:sentinelx_mobile/features/community/community_providers.dart';
import 'package:sentinelx_mobile/features/community/post_card.dart';
import 'package:sentinelx_mobile/features/community/reaction_bar.dart';
import 'package:sentinelx_mobile/shared/widgets/player_avatar.dart';

import '../../fakes/fake_community_repository.dart';
import '../../support/community_fixtures.dart';
import '../../support/pump_compete.dart';

PostView _post({
  String id = 'p1',
  String content = 'Hello community',
  String? imageUrl,
  List<String> imageUrls = const [],
  bool isPinned = false,
  String? boostedUntil,
  bool canDelete = false,
  bool canBoost = false,
  int commentCount = 3,
}) =>
    PostView.fromJson(postViewJson(
      id: id,
      content: content,
      imageUrl: imageUrl,
      imageUrls: imageUrls,
      isPinned: isPinned,
      boostedUntil: boostedUntil,
      canDelete: canDelete,
      canBoost: canBoost,
      commentCount: commentCount,
    ));

class _Capture {
  var tapped = 0;
  var signInRequired = 0;
}

Future<_Capture> _pump(WidgetTester tester, PostView post, {bool compact = false, FakeCommunityRepository? repo}) async {
  final capture = _Capture();
  await pumpCompete(
    tester,
    SingleChildScrollView(
      child: PostCard(
        post: post,
        compact: compact,
        onTap: () => capture.tapped++,
        onSignInRequired: () => capture.signInRequired++,
      ),
    ),
    overrides: [
      ...competeBaseOverrides(),
      communityRepositoryProvider.overrideWithValue(repo ?? FakeCommunityRepository()),
    ],
  );
  await tester.pumpAndSettle();
  return capture;
}

void main() {
  testWidgets('renders author, content, image, reaction bar and comment count', (tester) async {
    await _pump(tester, _post(imageUrl: 'https://x/a.png', imageUrls: ['https://x/a.png']));
    expect(find.text('Ada Lovelace'), findsOneWidget);
    expect(find.byType(PlayerAvatar), findsOneWidget);
    expect(find.text('Hello community'), findsOneWidget);
    expect(find.byKey(const Key('post-image')), findsOneWidget);
    expect(find.byType(ReactionBar), findsOneWidget);
    expect(find.text('3 comments'), findsOneWidget);
  });

  testWidgets('a pinned post shows Pinned, a live-boosted post shows Boosted, a plain post neither', (tester) async {
    await _pump(tester, _post(isPinned: true));
    expect(find.text('Pinned'), findsOneWidget);
    expect(find.text('Boosted'), findsNothing);

    final future = DateTime.now().add(const Duration(hours: 5)).toUtc().toIso8601String();
    await _pump(tester, _post(boostedUntil: future));
    expect(find.text('Boosted'), findsOneWidget);
    expect(find.text('Pinned'), findsNothing);

    await _pump(tester, _post());
    expect(find.text('Pinned'), findsNothing);
    expect(find.text('Boosted'), findsNothing);
  });

  testWidgets('an expired boost shows no Boosted badge', (tester) async {
    final past = DateTime.now().subtract(const Duration(hours: 1)).toUtc().toIso8601String();
    await _pump(tester, _post(boostedUntil: past));
    expect(find.text('Boosted'), findsNothing);
  });

  testWidgets('canDelete and canBoost both false render no menu at all', (tester) async {
    await _pump(tester, _post(canDelete: false, canBoost: false));
    expect(find.byKey(const Key('post-menu-p1')), findsNothing);
  });

  testWidgets('delete-only post offers delete and no boost', (tester) async {
    await _pump(tester, _post(canDelete: true, canBoost: false));
    await tester.tap(find.byKey(const Key('post-menu-p1')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('post-delete-p1')), findsOneWidget);
    expect(find.byKey(const Key('post-boost-p1')), findsNothing);
  });

  testWidgets('boost-only post offers boost and no delete', (tester) async {
    await _pump(tester, _post(canDelete: false, canBoost: true));
    await tester.tap(find.byKey(const Key('post-menu-p1')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('post-boost-p1')), findsOneWidget);
    expect(find.byKey(const Key('post-delete-p1')), findsNothing);
  });

  testWidgets('a text-only post renders no image and no placeholder', (tester) async {
    await _pump(tester, _post(imageUrl: null));
    expect(find.byType(Image), findsNothing);
    expect(find.byKey(const Key('post-image')), findsNothing);
  });

  testWidgets('extra images render as a thumbnail strip on the full card only', (tester) async {
    final post = _post(imageUrl: 'https://x/a.png', imageUrls: ['https://x/a.png', 'https://x/b.png', 'https://x/c.png']);
    await _pump(tester, post);
    expect(find.byKey(const Key('post-thumb-0')), findsOneWidget);
    expect(find.byKey(const Key('post-thumb-1')), findsOneWidget);
    expect(find.byKey(const Key('post-thumb-2')), findsNothing);

    await _pump(tester, post, compact: true);
    expect(find.byKey(const Key('post-thumb-0')), findsNothing);
  });

  testWidgets('compact renders no reaction bar, comment count or menu', (tester) async {
    await _pump(tester, _post(canDelete: true, canBoost: true), compact: true);
    expect(find.byType(ReactionBar), findsNothing);
    expect(find.text('3 comments'), findsNothing);
    expect(find.byKey(const Key('post-menu-p1')), findsNothing);
  });

  testWidgets('tapping the card body calls onTap', (tester) async {
    final capture = await _pump(tester, _post());
    await tester.tap(find.text('Hello community'));
    expect(capture.tapped, 1);
  });

  testWidgets('tapping the comment count calls onTap', (tester) async {
    final capture = await _pump(tester, _post());
    await tester.tap(find.text('3 comments'));
    expect(capture.tapped, 1);
  });

  testWidgets('confirming delete calls deletePost', (tester) async {
    final repo = FakeCommunityRepository(
      feedPage: CommunityFeedPage(pinned: const [], posts: [_post(canDelete: true)], hasMore: false),
    );
    await _pump(tester, _post(canDelete: true), repo: repo);
    await tester.tap(find.byKey(const Key('post-menu-p1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('post-delete-p1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('post-delete-confirm')));
    await tester.pumpAndSettle();
    expect(repo.calls, contains('deletePost:p1'));
  });

  testWidgets('cancelling the delete dialog sends nothing', (tester) async {
    final repo = FakeCommunityRepository();
    await _pump(tester, _post(canDelete: true), repo: repo);
    await tester.tap(find.byKey(const Key('post-menu-p1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('post-delete-p1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('post-delete-cancel')));
    await tester.pumpAndSettle();
    expect(repo.calls.where((c) => c.startsWith('deletePost')), isEmpty);
  });
}
