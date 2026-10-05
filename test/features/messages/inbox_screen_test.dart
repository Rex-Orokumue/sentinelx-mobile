import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sentinelx_mobile/core/api/messages_models.dart';
import 'package:sentinelx_mobile/core/l10n/gen/app_localizations.dart';
import 'package:sentinelx_mobile/core/realtime/realtime_hub.dart';
import 'package:sentinelx_mobile/features/messages/inbox_providers.dart';
import 'package:sentinelx_mobile/features/messages/inbox_screen.dart';
import 'package:sentinelx_mobile/features/messages/requests_screen.dart';

import '../../fakes/fake_messages_repository.dart';

Future<GoRouter> pumpInbox(
  WidgetTester tester,
  FakeMessagesRepository repo, {
  bool signedIn = true,
  Locale locale = const Locale('en'),
  String location = '/messages',
  List<Override> overrides = const [],
}) async {
  tester.view.physicalSize = const Size(375, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final router = GoRouter(
    initialLocation: location,
    routes: [
      GoRoute(path: '/', builder: (_, _) => const Scaffold(body: Text('HOME'))),
      GoRoute(path: '/messages', builder: (_, _) => const InboxScreen()),
      GoRoute(path: '/messages/requests', builder: (_, _) => const RequestsScreen()),
      GoRoute(path: '/messages/:threadId', builder: (_, s) => Scaffold(appBar: AppBar(), body: Text('THREAD ${s.pathParameters['threadId']}'))),
      GoRoute(path: '/login', builder: (_, _) => const Scaffold(body: Text('LOGIN PAGE'))),
    ],
  );
  await tester.pumpWidget(ProviderScope(
    key: UniqueKey(),
    retry: (_, _) => null,
    overrides: [
      messagesRepositoryProvider.overrideWithValue(repo),
      dmViewerIdProvider.overrideWith((ref) async => signedIn ? 'u1' : null),
      dmNudgeProvider.overrideWith((ref) => const Stream<RealtimeSignal>.empty()),
      ...overrides,
    ],
    child: MaterialApp.router(
      routerConfig: router,
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    ),
  ));
  await tester.pumpAndSettle();
  return router;
}

void main() {
  testWidgets('rows render newest first with the name and the text preview', (tester) async {
    final repo = FakeMessagesRepository(inbox: [thread('a', text: 'first preview'), thread('b', text: 'second preview')]);
    await pumpInbox(tester, repo);
    expect(find.text('Messages'), findsOneWidget);
    expect(find.text('Player a'), findsOneWidget);
    expect(find.text('first preview'), findsOneWidget);
    expect(tester.getTopLeft(find.text('Player a')).dy, lessThan(tester.getTopLeft(find.text('Player b')).dy));
  });

  testWidgets('the unread badge shows only when unread > 0, with singular and plural semantics', (tester) async {
    final repo = FakeMessagesRepository(inbox: [thread('a', unread: 1), thread('b', unread: 3), thread('c')]);
    final handle = tester.ensureSemantics();
    await pumpInbox(tester, repo);
    expect(find.byKey(const Key('dm-unread-a')), findsOneWidget);
    expect(find.byKey(const Key('dm-unread-b')), findsOneWidget);
    expect(find.byKey(const Key('dm-unread-c')), findsNothing);
    Finder labelled(String label) => find.byWidgetPredicate((w) => w is Semantics && w.properties.label == label);
    expect(labelled('1 unread message'), findsOneWidget);
    expect(labelled('3 unread messages'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('every preview kind renders, including an unknown one', (tester) async {
    final repo = FakeMessagesRepository(inbox: [
      thread('t', kind: PreviewKind.text, text: 'plain text'),
      thread('i', kind: PreviewKind.image),
      thread('s', kind: PreviewKind.sticker, stickerId: 'goat'),
      thread('s2', kind: PreviewKind.sticker, stickerId: 'bogus'),
      thread('v', kind: PreviewKind.voice),
      thread('r', kind: PreviewKind.removed),
      thread('u', kind: PreviewKind.unknown),
    ]);
    await pumpInbox(tester, repo);
    expect(find.text('plain text'), findsOneWidget);
    expect(find.text('Photo'), findsOneWidget);
    expect(find.text('🐐'), findsOneWidget);
    expect(find.text('Voice message'), findsOneWidget);
    expect(find.text('Message removed'), findsOneWidget);
    expect(find.text('Message'), findsNWidgets(2), reason: 'unknown kind and unknown sticker use the generic label');
    expect(tester.takeException(), isNull);
  });

  testWidgets('a player with no username and no avatar still renders', (tester) async {
    final repo = FakeMessagesRepository(inbox: [thread('a', name: '', username: null)]);
    await pumpInbox(tester, repo);
    expect(find.text('?'), findsOneWidget);
    expect(find.byKey(const Key('avatar-placeholder')), findsOneWidget);
  });

  testWidgets('a long name and a long preview do not overflow at 375x800', (tester) async {
    final repo = FakeMessagesRepository(inbox: [
      thread('a', unread: 12, name: 'A' * 120, text: 'word ' * 200),
      thread('b', name: 'B' * 120, text: 'x' * 400),
    ]);
    await pumpInbox(tester, repo);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an outgoing pending row says who it is waiting for instead of showing a preview', (tester) async {
    final repo = FakeMessagesRepository(inbox: [
      thread('a', name: 'Ada', text: 'hidden text', requestState: RequestState.pending, direction: RequestDirection.outgoing),
    ]);
    await pumpInbox(tester, repo);
    expect(find.text('Waiting for Ada to accept'), findsOneWidget);
    expect(find.text('hidden text'), findsNothing);
  });

  testWidgets('the requests row is hidden at zero and shown with the plural count', (tester) async {
    await pumpInbox(tester, FakeMessagesRepository(inbox: [thread('a')]));
    expect(find.byKey(const Key('dm-requests-row')), findsNothing);

    await pumpInbox(tester, FakeMessagesRepository(inbox: [thread('a')], requestCount: 2));
    expect(find.byKey(const Key('dm-requests-row')), findsOneWidget);
    expect(find.text('Message requests (2)'), findsOneWidget);
  });

  testWidgets('tapping the requests row pushes /messages/requests; tapping a thread pushes it and Back returns', (tester) async {
    final repo = FakeMessagesRepository(inbox: [thread('a')], requests: [thread('q', requestState: RequestState.pending, direction: RequestDirection.incoming)], requestCount: 1);
    await pumpInbox(tester, repo);
    await tester.tap(find.byKey(const Key('dm-requests-row')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('dm-thread-q')), findsOneWidget);
    expect(find.byKey(const Key('dm-request-chip-q')), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('dm-thread-a')));
    await tester.pumpAndSettle();
    expect(find.text('THREAD a'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('dm-thread-a')), findsOneWidget);
  });

  testWidgets('scrolling to the end loads the next page with the cursor', (tester) async {
    final repo = FakeMessagesRepository(inbox: [for (var i = 0; i < 30; i++) thread('t$i')]);
    await pumpInbox(tester, repo);
    expect(repo.threadsCalls, hasLength(1));
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -3000));
    await tester.pumpAndSettle();
    expect(repo.threadsCalls.last.cursor, '20');
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -3000));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('dm-thread-t29')), findsOneWidget);
  });

  testWidgets('pull to refresh reloads page one', (tester) async {
    final repo = FakeMessagesRepository(inbox: [thread('a')]);
    await pumpInbox(tester, repo);
    repo.inbox = [thread('fresh'), thread('a')];
    await tester.fling(find.byType(Scrollable).first, const Offset(0, 400), 1000);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('dm-thread-fresh')), findsOneWidget);
    expect(repo.threadsCalls.last.cursor, isNull);
  });

  testWidgets('a failed first load shows the error with a working retry', (tester) async {
    final repo = FakeMessagesRepository(inbox: [thread('a')])..failures['threads'] = networkError;
    await pumpInbox(tester, repo);
    expect(find.text("Couldn't load your messages."), findsOneWidget);
    repo.failures.clear();
    await tester.tap(find.byKey(const Key('dm-retry')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('dm-thread-a')), findsOneWidget);
  });

  testWidgets('signed out shows the login call to action', (tester) async {
    await pumpInbox(tester, FakeMessagesRepository(), signedIn: false);
    expect(find.text('Log in to see your messages.'), findsOneWidget);
    await tester.tap(find.byKey(const Key('dm-login')));
    await tester.pumpAndSettle();
    expect(find.text('LOGIN PAGE'), findsOneWidget);
  });

  testWidgets('an empty inbox shows the empty state', (tester) async {
    await pumpInbox(tester, FakeMessagesRepository());
    expect(find.byKey(const Key('dm-empty')), findsOneWidget);
  });

  testWidgets('French smoke: title, requests row and the unread plural', (tester) async {
    final repo = FakeMessagesRepository(inbox: [thread('a', unread: 1)], requestCount: 2);
    await pumpInbox(tester, repo, locale: const Locale('fr'));
    expect(find.text('Messages'), findsOneWidget);
    expect(find.text('Demandes de message (2)'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
