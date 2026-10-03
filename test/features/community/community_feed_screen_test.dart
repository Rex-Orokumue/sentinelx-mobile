import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/core/api/api_client.dart';
import 'package:sentinelx_mobile/core/api/community_models.dart';
import 'package:sentinelx_mobile/features/community/community_feed_screen.dart';
import 'package:sentinelx_mobile/features/community/community_providers.dart';
import 'package:sentinelx_mobile/features/community/community_realtime.dart';

import '../../fakes/fake_community_repository.dart';
import '../../support/community_fixtures.dart';
import '../../support/pump_compete.dart';

PostView _post(String id, String content, {bool pinned = false}) =>
    PostView.fromJson(postViewJson(id: id, content: content, isPinned: pinned));

class _Capture {
  var compose = 0, login = 0, addStatus = 0;
  PostView? tappedPost;
  StatusRing? tappedRing;
  UpcomingEvent? tappedEvent;
}

class _ThrowingTopMembersRepo extends FakeCommunityRepository {
  _ThrowingTopMembersRepo({super.stats});
  @override
  Future<List<TopMember>> topMembers() async => throw Exception('top members down');
}

int _feedCalls(FakeCommunityRepository repo) => repo.calls.where((c) => c.startsWith('feed:')).length;

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
    CommunityFeedScreen(
      onCompose: () => capture.compose++,
      onLogin: () => capture.login++,
      onAddStatus: () => capture.addStatus++,
      onPostTap: (p) => capture.tappedPost = p,
      onStatusTap: (r) => capture.tappedRing = r,
      onEventTap: (e) => capture.tappedEvent = e,
    ),
    size: const Size(375, 4000),
    overrides: [
      ...competeBaseOverrides(signedOut: signedOut),
      communityRepositoryProvider.overrideWithValue(repo),
      communityFeedRealtimeProvider.overrideWith((ref) => realtime.stream),
    ],
  );
  return (capture: capture, realtime: realtime);
}

void main() {
  testWidgets('loading shows a spinner', (tester) async {
    final gate = Completer<void>();
    final repo = FakeCommunityRepository()..feedGate = gate;
    await _pump(tester, repo);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    gate.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('error shows retry that refetches', (tester) async {
    final failing = FakeCommunityRepository()..feedError = Exception('boom');
    await _pump(tester, failing);
    await tester.pumpAndSettle();
    expect(find.text("Couldn't load the feed."), findsOneWidget);
    failing.feedError = null;
    final before = _feedCalls(failing);
    await tester.tap(find.byKey(const Key('feed-retry')));
    await tester.pumpAndSettle();
    expect(_feedCalls(failing), before + 1);
    expect(find.text("Couldn't load the feed."), findsNothing);
  });

  testWidgets('an empty feed shows the empty copy and the other sections still render', (tester) async {
    final repo = FakeCommunityRepository(
      stats: const CommunityStats(memberCount: 1000, countryCount: 20, tournamentCount: 50),
    )
      ..topMembersList = [TopMember.fromJson(topMemberJson(displayName: 'Champ'))]
      ..upcomingEventsList = [UpcomingEvent.fromJson(upcomingEventJson(title: 'Weekly Cup'))]
      ..galleryPage = CommunityGalleryPage.fromJson(galleryPageJson())
      ..challengesWidget = ChallengesWidget.fromJson(challengesJson())
      ..bestPlayBanner = BestPlayBanner.fromJson(bestPlayJson());
    await _pump(tester, repo);
    await tester.pumpAndSettle();
    expect(find.text('No posts yet. Be the first to share something!'), findsOneWidget);
    expect(find.text('Weekly challenges'), findsOneWidget);
    expect(find.text('Best Play of the Week'), findsOneWidget);
    expect(find.text('Top members'), findsOneWidget);
    expect(find.text('Champ'), findsOneWidget);
    expect(find.text('Upcoming events'), findsOneWidget);
    expect(find.text('Weekly Cup'), findsOneWidget);
    expect(find.text('Gallery'), findsOneWidget);
    expect(find.byKey(const Key('gallery-g1')), findsOneWidget);
    expect(find.text('1000 members'), findsOneWidget);
    expect(find.text('20 countries'), findsOneWidget);
    expect(find.text('50 tournaments'), findsOneWidget);
  });

  testWidgets('pinned posts render above regular posts in API order', (tester) async {
    final repo = FakeCommunityRepository(
      feedPage: CommunityFeedPage(
        pinned: [_post('a', 'pinned A', pinned: true), _post('b', 'pinned B', pinned: true)],
        posts: [_post('c', 'regular C')],
        hasMore: false,
      ),
    );
    await _pump(tester, repo);
    await tester.pumpAndSettle();
    double y(String t) => tester.getTopLeft(find.text(t)).dy;
    expect(y('pinned A'), lessThan(y('pinned B')));
    expect(y('pinned B'), lessThan(y('regular C')));
  });

  testWidgets('load more appends the next page and keeps what was already shown', (tester) async {
    final repo = FakeCommunityRepository(feedPages: [
      CommunityFeedPage(pinned: [_post('a', 'pinned A', pinned: true)], posts: [_post('b', 'first post')], hasMore: true),
      CommunityFeedPage(pinned: const [], posts: [_post('c', 'second post')], hasMore: false),
    ]);
    await _pump(tester, repo);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('feed-load-more')), findsOneWidget);
    await tester.tap(find.byKey(const Key('feed-load-more')));
    await tester.pumpAndSettle();
    expect(repo.calls, contains('feed:1:20'));
    expect(find.text('pinned A'), findsOneWidget);
    expect(find.text('first post'), findsOneWidget);
    expect(find.text('second post'), findsOneWidget);
    expect(find.byKey(const Key('feed-load-more')), findsNothing);
  });

  testWidgets('pull to refresh refetches the feed', (tester) async {
    final repo = FakeCommunityRepository(feedPage: CommunityFeedPage(pinned: const [], posts: [_post('a', 'one')], hasMore: false));
    await _pump(tester, repo);
    await tester.pumpAndSettle();
    final before = _feedCalls(repo);
    await tester.drag(find.byType(CustomScrollView), const Offset(0, 1500));
    await tester.pumpAndSettle();
    expect(_feedCalls(repo), before + 1);
  });

  testWidgets('signed out: FAB asks to log in, challenges rail shows the prompt and never calls the API', (tester) async {
    final repo = FakeCommunityRepository();
    final h = await _pump(tester, repo, signedOut: true);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('feed-compose-fab')), findsOneWidget);
    await tester.tap(find.byKey(const Key('feed-compose-fab')));
    expect(h.capture.login, 1);
    expect(h.capture.compose, 0);
    expect(find.text('Log in to track weekly challenges.'), findsOneWidget);
    expect(repo.calls, isNot(contains('challenges')));
  });

  testWidgets('signed out: adding a status asks to log in instead', (tester) async {
    final h = await _pump(tester, FakeCommunityRepository(), signedOut: true);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('status-add-yours')));
    expect(h.capture.login, 1);
    expect(h.capture.addStatus, 0);
  });

  testWidgets('signed in: FAB opens compose', (tester) async {
    final h = await _pump(tester, FakeCommunityRepository());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('feed-compose-fab')));
    expect(h.capture.compose, 1);
    expect(h.capture.login, 0);
  });

  group('best play', () {
    testWidgets('null response renders no banner', (tester) async {
      await _pump(tester, FakeCommunityRepository());
      await tester.pumpAndSettle();
      expect(find.text('Best Play of the Week'), findsNothing);
    });

    testWidgets('shows nominations and a vote button each; voting calls the API and refetches', (tester) async {
      final repo = FakeCommunityRepository(
        feedPage: CommunityFeedPage(pinned: const [], posts: [_post('a', 'x')], hasMore: false),
      )..bestPlayBanner = BestPlayBanner.fromJson(bestPlayJson(nominations: [
          bestPlayNominationJson(nominationId: 'n1', voteCount: 3),
          bestPlayNominationJson(nominationId: 'n2', content: 'Other play', voteCount: 1),
        ]));
      await _pump(tester, repo);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('bestplay-vote-n1')), findsOneWidget);
      expect(find.byKey(const Key('bestplay-vote-n2')), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      final before = repo.calls.where((c) => c == 'bestPlay').length;
      await tester.tap(find.byKey(const Key('bestplay-vote-n1')));
      await tester.pumpAndSettle();
      expect(repo.calls.where((c) => c.startsWith('voteBestPlay:n1:')), hasLength(1));
      expect(repo.calls.where((c) => c == 'bestPlay').length, before + 1);
      expect(find.text('Vote recorded!'), findsOneWidget);
    });

    for (final entry in {
      'voting_closed': 'Voting is closed right now.',
      'already_voted': "You've already voted this week.",
    }.entries) {
      testWidgets('${entry.key} shows its own copy inline', (tester) async {
        final repo = FakeCommunityRepository()..bestPlayBanner = BestPlayBanner.fromJson(bestPlayJson());
        repo.writeErrors['voteBestPlay'] = ApiException(status: 409, code: entry.key, message: 'RAW');
        await _pump(tester, repo);
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('bestplay-vote-n1')));
        await tester.pumpAndSettle();
        expect(find.text(entry.value), findsOneWidget);
        expect(find.text('RAW'), findsNothing);
      });
    }

    testWidgets('signed out: tapping vote asks to log in and sends nothing', (tester) async {
      final repo = FakeCommunityRepository()..bestPlayBanner = BestPlayBanner.fromJson(bestPlayJson());
      final h = await _pump(tester, repo, signedOut: true);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('bestplay-vote-n1')));
      await tester.pumpAndSettle();
      expect(h.capture.login, 1);
      expect(repo.calls.where((c) => c.startsWith('voteBestPlay')), isEmpty);
    });

    testWidgets('after voting the buttons are disabled and the chosen one reads Voted', (tester) async {
      final repo = FakeCommunityRepository()..bestPlayBanner = BestPlayBanner.fromJson(bestPlayJson(myVoteNominationId: 'n1'));
      await _pump(tester, repo);
      await tester.pumpAndSettle();
      expect(find.text('Voted'), findsOneWidget);
      await tester.tap(find.byKey(const Key('bestplay-vote-n1')), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(repo.calls.where((c) => c.startsWith('voteBestPlay')), isEmpty);
    });
  });

  group('challenges', () {
    testWidgets('null response renders nothing', (tester) async {
      await _pump(tester, FakeCommunityRepository());
      await tester.pumpAndSettle();
      expect(find.text('Weekly challenges'), findsNothing);
    });

    testWidgets('lists progress, marks completed ones, and has no controls', (tester) async {
      final repo = FakeCommunityRepository()
        ..challengesWidget = ChallengesWidget.fromJson(challengesJson(challenges: [
          challengeProgressJson(slug: 'a', title: 'React to 5 posts', progress: 2, goal: 5),
          challengeProgressJson(slug: 'b', title: 'Post once', progress: 1, goal: 1, completed: true),
        ]));
      await _pump(tester, repo);
      await tester.pumpAndSettle();
      expect(find.text('React to 5 posts'), findsOneWidget);
      expect(find.text('2/5'), findsOneWidget);
      expect(find.text('Completed'), findsOneWidget);
      expect(find.descendant(of: find.byKey(const Key('challenges-rail')), matching: find.byType(ElevatedButton)), findsNothing);
      expect(find.descendant(of: find.byKey(const Key('challenges-rail')), matching: find.byType(FilledButton)), findsNothing);
      expect(find.descendant(of: find.byKey(const Key('challenges-rail')), matching: find.byType(TextButton)), findsNothing);
    });
  });

  testWidgets('one discovery section failing does not blank the others', (tester) async {
    final repo = _ThrowingTopMembersRepo(stats: const CommunityStats(memberCount: 7, countryCount: 2, tournamentCount: 3))
      ..upcomingEventsList = [UpcomingEvent.fromJson(upcomingEventJson(title: 'Weekly Cup'))];
    await _pump(tester, repo);
    await tester.pumpAndSettle();
    expect(find.text('Top members'), findsNothing);
    expect(find.text('Weekly Cup'), findsOneWidget);
    expect(find.text('7 members'), findsOneWidget);
  });

  testWidgets('status tray taps are forwarded', (tester) async {
    final ring = StatusRing.fromJson(statusRingJson(playerId: 'u9'));
    final repo = FakeCommunityRepository()..statusRings = [ring];
    final h = await _pump(tester, repo);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('status-ring-unseen-u9')));
    expect(h.capture.tappedRing?.playerId, 'u9');
    await tester.tap(find.byKey(const Key('status-add-yours')));
    expect(h.capture.addStatus, 1);
  });

  testWidgets('tapping a post and an event are forwarded', (tester) async {
    final repo = FakeCommunityRepository(feedPage: CommunityFeedPage(pinned: const [], posts: [_post('a', 'tap me')], hasMore: false))
      ..upcomingEventsList = [UpcomingEvent.fromJson(upcomingEventJson(id: 'e9', title: 'Weekly Cup'))];
    final h = await _pump(tester, repo);
    await tester.pumpAndSettle();
    await tester.tap(find.text('tap me'));
    expect(h.capture.tappedPost?.id, 'a');
    await tester.tap(find.text('Weekly Cup'));
    expect(h.capture.tappedEvent?.id, 'e9');
  });

  testWidgets('each realtime event refetches the feed exactly once', (tester) async {
    final repo = FakeCommunityRepository(feedPage: CommunityFeedPage(pinned: const [], posts: [_post('a', 'one')], hasMore: false));
    final h = await _pump(tester, repo);
    await tester.pumpAndSettle();
    var ticks = 0;
    final before = _feedCalls(repo);
    h.realtime.add(++ticks);
    await tester.pumpAndSettle();
    expect(_feedCalls(repo), before + 1);
    h.realtime.add(++ticks);
    await tester.pumpAndSettle();
    expect(_feedCalls(repo), before + 2);
  });

  testWidgets('a realtime refetch does not flash the spinner over loaded posts', (tester) async {
    final gateRepo = FakeCommunityRepository(feedPage: CommunityFeedPage(pinned: const [], posts: [_post('a', 'stay put')], hasMore: false));
    final h = await _pump(tester, gateRepo);
    await tester.pumpAndSettle();
    gateRepo.feedGate = Completer<void>();
    h.realtime.add(1);
    await tester.pump();
    await tester.pump();
    expect(find.text('stay put'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    gateRepo.feedGate!.complete();
    await tester.pumpAndSettle();
  });
}
