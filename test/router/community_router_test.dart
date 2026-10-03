import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/core/api/community_models.dart';
import 'package:sentinelx_mobile/features/community/community_feed_screen.dart';
import 'package:sentinelx_mobile/features/community/community_providers.dart';
import 'package:sentinelx_mobile/features/community/community_realtime.dart';
import 'package:sentinelx_mobile/features/community/compose_screen.dart';
import 'package:sentinelx_mobile/features/community/post_detail_screen.dart';
import 'package:sentinelx_mobile/features/community/status_compose_screen.dart';
import 'package:sentinelx_mobile/features/community/status_viewer_screen.dart';

import '../fakes/fake_community_repository.dart';
import '../support/community_fixtures.dart';
import '../support/pump_app.dart';

FakeCommunityRepository _repo() => FakeCommunityRepository(
      feedPage: CommunityFeedPage(
        pinned: const [],
        posts: [PostView.fromJson(postViewJson(id: 'p1', content: 'Hello feed'))],
        hasMore: false,
      ),
      postDetails: {
        'p1': CommunityPostDetail(post: PostView.fromJson(postViewJson(id: 'p1', content: 'Hello feed')), comments: const []),
        'abc123': CommunityPostDetail(post: PostView.fromJson(postViewJson(id: 'abc123', content: 'Linked post')), comments: const []),
      },
    )..statusRings = [
        StatusRing.fromJson(statusRingJson(
          playerId: 'u9',
          // Viewer auto-skips expired statuses, so the fixture must outlive the test run.
          statuses: [statusRowJson(playerId: 'u9', expiresAt: DateTime.now().add(const Duration(hours: 6)).toUtc().toIso8601String())],
        )),
      ];

Future<void> _pump(WidgetTester tester, String location) => pumpRouterWithRepo(
      tester,
      initialLocation: location,
      overrides: [
        communityRepositoryProvider.overrideWithValue(_repo()),
        communityFeedRealtimeProvider.overrideWith((ref) => const Stream<int>.empty()),
        communityPostDetailRealtimeProvider('p1').overrideWith((ref) => const Stream<int>.empty()),
        communityPostDetailRealtimeProvider('abc123').overrideWith((ref) => const Stream<int>.empty()),
      ],
    );

void main() {
  testWidgets('/community renders the feed inside the tab shell', (tester) async {
    await _pump(tester, '/community');
    await tester.pumpAndSettle();
    expect(find.byType(CommunityFeedScreen), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
  });

  testWidgets('/community/compose renders the compose screen', (tester) async {
    await _pump(tester, '/community/compose');
    await tester.pumpAndSettle();
    expect(find.byType(ComposeScreen), findsOneWidget);
  });

  testWidgets('tapping a post in the feed opens its detail', (tester) async {
    await _pump(tester, '/community');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hello feed'));
    await tester.pumpAndSettle();
    expect(find.byType(PostDetailScreen), findsOneWidget);
  });

  testWidgets('/community/statuses/compose renders the status compose screen', (tester) async {
    await _pump(tester, '/community/statuses/compose');
    await tester.pumpAndSettle();
    expect(find.byType(StatusComposeScreen), findsOneWidget);
  });

  testWidgets('tapping a status ring opens the viewer with that ring', (tester) async {
    await _pump(tester, '/community');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('status-ring-unseen-u9')));
    await tester.pumpAndSettle();
    expect(find.byType(StatusViewerScreen), findsOneWidget);
  });

  testWidgets('a cold status link with no ring falls back to the feed instead of crashing', (tester) async {
    await _pump(tester, '/community/statuses/u9');
    await tester.pumpAndSettle();
    expect(find.byType(CommunityFeedScreen), findsOneWidget);
    expect(find.byType(StatusViewerScreen), findsNothing);
  });

  testWidgets('a community web link with a post id opens that post', (tester) async {
    await _pump(tester, 'https://sentinelxesports.com.ng/community/abc123');
    await tester.pumpAndSettle();
    expect(find.byType(PostDetailScreen), findsOneWidget);
    expect(find.text('Linked post'), findsOneWidget);
  });

  testWidgets('the bare community web link still opens the feed', (tester) async {
    await _pump(tester, 'https://sentinelxesports.com.ng/community');
    await tester.pumpAndSettle();
    expect(find.byType(CommunityFeedScreen), findsOneWidget);
  });

  Future<void> deleteViewedPost(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('detail-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('detail-delete')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('post-delete-confirm')));
    await tester.pumpAndSettle();
  }

  testWidgets('deleting a post opened from a cold web link lands on the feed instead of popping an empty stack', (tester) async {
    await _pump(tester, 'https://sentinelxesports.com.ng/community/p1');
    await tester.pumpAndSettle();
    expect(find.byType(PostDetailScreen), findsOneWidget);
    await deleteViewedPost(tester);
    expect(tester.takeException(), isNull);
    expect(find.byType(PostDetailScreen), findsNothing);
    expect(find.byType(CommunityFeedScreen), findsOneWidget);
  });

  testWidgets('deleting a post opened from the feed returns to the feed', (tester) async {
    await _pump(tester, '/community');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hello feed'));
    await tester.pumpAndSettle();
    await deleteViewedPost(tester);
    expect(find.byType(PostDetailScreen), findsNothing);
    expect(find.byType(CommunityFeedScreen), findsOneWidget);
  });
}
