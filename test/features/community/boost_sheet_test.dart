import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/core/api/api_client.dart';
import 'package:sentinelx_mobile/core/api/community_models.dart';
import 'package:sentinelx_mobile/features/community/boost_sheet.dart';
import 'package:sentinelx_mobile/features/community/community_providers.dart';

import '../../fakes/fake_community_repository.dart';
import '../../support/community_fixtures.dart';
import '../../support/pump_compete.dart';

ApiException _apiEx(String code, {int status = 409}) => ApiException(status: status, code: code, message: 'x');

PostView _post({String id = 'p1'}) => PostView.fromJson(postViewJson(id: id));

Future<FakeCommunityRepository> _pump(WidgetTester tester, {FakeCommunityRepository? repo, PostView? post}) async {
  final fake = repo ?? FakeCommunityRepository();
  await pumpCompete(
    tester,
    // Watches both providers this sheet invalidates on success, so the test can observe the
    // invalidation actually causing a refetch (mirrors lobby_result_screen_test.dart's pattern).
    Consumer(builder: (context, ref, _) {
      ref.watch(communityFeedProvider);
      ref.watch(communityPostDetailProvider((post ?? _post()).id));
      return Builder(builder: (context) {
        return ElevatedButton(onPressed: () => showBoostSheet(context, post: post ?? _post()), child: const Text('open'));
      });
    }),
    overrides: [
      communityRepositoryProvider.overrideWithValue(fake),
    ],
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return fake;
}

void main() {
  testWidgets('renders the boost confirm title and body; confirming boosts the post', (tester) async {
    final repo = await _pump(tester);
    expect(find.text('Boost this post?'), findsOneWidget);
    expect(find.text('Your post will be pinned to the top of the feed for 24 hours for 200 SX Coins.'), findsOneWidget);

    await tester.tap(find.byKey(const Key('boost-confirm')));
    await tester.pumpAndSettle();

    final call = repo.calls.singleWhere((c) => c.startsWith('boostPost:'));
    final parts = call.split(':');
    expect(parts[1], 'p1');
    expect(parts[2], isNotEmpty); // idempotency key
  });

  testWidgets('success shows the success message, invalidates the feed and post detail, and pops the sheet', (tester) async {
    final repo = await _pump(tester);
    final feedCallsBefore = repo.calls.where((c) => c.startsWith('feed:')).length;
    final detailCallsBefore = repo.calls.where((c) => c.startsWith('postDetail:')).length;

    await tester.tap(find.byKey(const Key('boost-confirm')));
    await tester.pumpAndSettle();

    expect(find.text('Post boosted!'), findsOneWidget);
    expect(find.text('Boost this post?'), findsNothing); // sheet closed
    expect(repo.calls.where((c) => c.startsWith('feed:')).length, greaterThan(feedCallsBefore));
    expect(repo.calls.where((c) => c.startsWith('postDetail:')).length, greaterThan(detailCallsBefore));
  });

  testWidgets('insufficient_coins shows its copy inline, keeps the sheet open, and the retry button is re-enabled', (tester) async {
    final repo = FakeCommunityRepository();
    repo.writeErrors['boostPost'] = _apiEx('insufficient_coins');
    await _pump(tester, repo: repo);

    await tester.tap(find.byKey(const Key('boost-confirm')));
    await tester.pumpAndSettle();

    expect(find.text('Not enough SX Coins to boost.'), findsOneWidget);
    expect(find.text('Boost this post?'), findsOneWidget); // sheet still open
    final button = tester.widget<FilledButton>(find.byKey(const Key('boost-confirm')));
    expect(button.onPressed, isNotNull); // retry re-enabled
  });

  testWidgets('already_boosted shows its own distinct copy', (tester) async {
    final repo = FakeCommunityRepository();
    repo.writeErrors['boostPost'] = _apiEx('already_boosted');
    await _pump(tester, repo: repo);
    await tester.tap(find.byKey(const Key('boost-confirm')));
    await tester.pumpAndSettle();
    expect(find.text('This post is already boosted.'), findsOneWidget);
    expect(find.text('You already have an active boost on another post.'), findsNothing);
  });

  testWidgets('active_boost_exists shows its own distinct copy (not the already_boosted copy)', (tester) async {
    final repo = FakeCommunityRepository();
    repo.writeErrors['boostPost'] = _apiEx('active_boost_exists');
    await _pump(tester, repo: repo);
    await tester.tap(find.byKey(const Key('boost-confirm')));
    await tester.pumpAndSettle();
    expect(find.text('You already have an active boost on another post.'), findsOneWidget);
    expect(find.text('This post is already boosted.'), findsNothing);
  });

  testWidgets('the sheet cannot be closed while busy', (tester) async {
    final repo = FakeCommunityRepository()..boostGate = Completer<void>();
    await _pump(tester, repo: repo);

    await tester.tap(find.byKey(const Key('boost-confirm')));
    await tester.pump();
    expect(find.text('Boost this post?'), findsOneWidget); // still open mid-flight

    repo.boostGate!.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('the sheet cannot be dragged closed mid-flight (drag bypasses PopScope)', (tester) async {
    final repo = FakeCommunityRepository()..boostGate = Completer<void>();
    await _pump(tester, repo: repo);

    await tester.tap(find.byKey(const Key('boost-confirm')));
    await tester.pump();
    await tester.fling(find.byType(BottomSheet), const Offset(0, 400), 1000);
    await tester.pump();
    expect(find.text('Boost this post?'), findsOneWidget);

    repo.boostGate!.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('a second tap while busy is a no-op: exactly one boostPost call is sent', (tester) async {
    final repo = FakeCommunityRepository()..boostGate = Completer<void>();
    await _pump(tester, repo: repo);

    await tester.tap(find.byKey(const Key('boost-confirm')));
    await tester.tap(find.byKey(const Key('boost-confirm')));
    await tester.pump();

    expect(repo.calls.where((c) => c.startsWith('boostPost:')).length, 1);

    repo.boostGate!.complete();
    await tester.pumpAndSettle();
    expect(repo.calls.where((c) => c.startsWith('boostPost:')).length, 1);
  });
}
