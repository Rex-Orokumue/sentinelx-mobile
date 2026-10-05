import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sentinelx_mobile/core/notifications/push/push_models.dart';
import 'package:sentinelx_mobile/core/notifications/push/push_tap_router.dart';

const _id = '3f2b8c1e-9d4a-4b7e-8a61-5c0d2e7f9a10';
const _other = '9a1b2c3d-4e5f-4a6b-8c7d-0e1f2a3b4c5d';

GoRouter _router({String initial = '/community'}) => GoRouter(
      initialLocation: initial,
      routes: [
        GoRoute(path: '/', builder: (_, _) => const Scaffold(body: Text('HOME'))),
        GoRoute(path: '/community', builder: (_, _) => const Scaffold(body: Text('COMMUNITY TAB'))),
        GoRoute(path: '/tournaments', builder: (_, _) => const Scaffold(body: Text('COMPETE TAB'))),
        GoRoute(path: '/notifications', builder: (_, _) => Scaffold(appBar: AppBar(), body: const Text('BELL'))),
        GoRoute(path: '/messages/:id', builder: (_, s) => Scaffold(appBar: AppBar(), body: Text('THREAD ${s.pathParameters['id']}'))),
      ],
    );

Future<GoRouter> _pump(WidgetTester tester, {String initial = '/community'}) async {
  final router = _router(initial: initial);
  await tester.pumpWidget(MaterialApp.router(routerConfig: router));
  await tester.pumpAndSettle();
  return router;
}

void main() {
  group('PushMessage.fromData', () {
    test('parses threadId, blank becomes null, non-string becomes null', () {
      expect(PushMessage.fromData({'threadId': _id, 'type': 'direct_message'}).threadId, _id);
      expect(PushMessage.fromData({'threadId': '   '}).threadId, isNull);
      expect(PushMessage.fromData({'threadId': 7}).threadId, isNull);
      expect(PushMessage.fromData(const {}).threadId, isNull);
    });
  });

  group('destinationFor (direct messages)', () {
    test('a DM with a thread id opens that thread', () {
      expect(destinationFor(const PushMessage(type: 'direct_message', threadId: _id)), '/messages/$_id');
      expect(destinationFor(PushMessage(type: 'direct_message', threadId: _id.toUpperCase())), '/messages/$_id');
    });

    test('the thread id wins over the url', () {
      expect(destinationFor(const PushMessage(type: 'direct_message', threadId: _id, url: '/matches/m1')), '/messages/$_id');
    });

    test('a non-UUID thread id with no url falls back to the bell', () {
      expect(destinationFor(const PushMessage(type: 'direct_message', threadId: 'not-a-uuid')), '/notifications');
    });

    test('a DM without a thread id but with a thread url resolves through the url', () {
      expect(destinationFor(const PushMessage(type: 'direct_message', url: '/messages/$_id')), '/messages/$_id');
    });

    test('non-DM pushes are unchanged, even with a thread id', () {
      expect(destinationFor(const PushMessage(type: 'match_assigned', threadId: _id, url: '/matches/m1')), '/matches/m1');
    });
  });

  group('pushNavigate (stack over the current tab)', () {
    testWidgets('a DM tap from /community pushes: Back returns to /community', (tester) async {
      final router = await _pump(tester);
      pushNavigate(router, '/messages/$_id');
      await tester.pumpAndSettle();
      expect(find.text('THREAD $_id'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('COMMUNITY TAB'), findsOneWidget);
    });

    testWidgets('a tab-root destination still go()es', (tester) async {
      final router = await _pump(tester);
      pushNavigate(router, '/tournaments');
      await tester.pumpAndSettle();
      expect(find.text('COMPETE TAB'), findsOneWidget);
      expect(router.canPop(), isFalse, reason: 'switched to, not stacked on');
    });

    testWidgets('/ goes to Home', (tester) async {
      final router = await _pump(tester);
      pushNavigate(router, '/');
      await tester.pumpAndSettle();
      expect(find.text('HOME'), findsOneWidget);
    });

    testWidgets('a tap while that exact thread is already on top does not push a second copy', (tester) async {
      final router = await _pump(tester);
      pushNavigate(router, '/messages/$_id');
      await tester.pumpAndSettle();
      pushNavigate(router, '/messages/$_id');
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('COMMUNITY TAB'), findsOneWidget, reason: 'one Back returns to the tab: there was only one thread page');
    });

    testWidgets('the /notifications fallback now pushes too', (tester) async {
      final router = await _pump(tester);
      pushNavigate(router, '/notifications');
      await tester.pumpAndSettle();
      expect(find.text('BELL'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('COMMUNITY TAB'), findsOneWidget);
    });

    testWidgets('a different thread pushes over an open one', (tester) async {
      final router = await _pump(tester);
      pushNavigate(router, '/messages/$_id');
      await tester.pumpAndSettle();
      pushNavigate(router, '/messages/$_other');
      await tester.pumpAndSettle();
      expect(find.text('THREAD $_other'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('THREAD $_id'), findsOneWidget);
    });
  });
}
