import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sentinelx_mobile/core/api/notifications_models.dart';
import 'package:sentinelx_mobile/core/l10n/gen/app_localizations.dart';
import 'package:sentinelx_mobile/core/notifications/push/push_gateway.dart';
import 'package:sentinelx_mobile/core/notifications/push/push_models.dart';
import 'package:sentinelx_mobile/features/notifications/notification_models.dart';
import 'package:sentinelx_mobile/features/notifications/notifications_providers.dart';
import 'package:sentinelx_mobile/features/notifications/notifications_repository.dart';
import 'package:sentinelx_mobile/features/notifications/notifications_screen.dart';

import '../../fakes/fake_notifications_repository.dart';
import '../../fakes/fake_push_gateway.dart';

const _post = '3f2b8c1e-9d4a-4b7e-8a61-5c0d2e7f9a10';

Future<void> _pump(
  WidgetTester tester,
  FakeNotificationsRepository repo, {
  bool signedIn = true,
  FakePushGateway? gateway,
  Locale locale = const Locale('en'),
  List<Override> overrides = const [],
}) async {
  final router = GoRouter(
    initialLocation: '/notifications',
    routes: [
      GoRoute(path: '/notifications', builder: (_, _) => const NotificationsScreen()),
      GoRoute(path: '/login', builder: (_, _) => const Scaffold(body: Text('LOGIN PAGE'))),
      GoRoute(path: '/matches/:id', builder: (_, s) => Scaffold(body: Text('MATCH ${s.pathParameters['id']}'))),
      GoRoute(path: '/community/:id', builder: (_, s) => Scaffold(body: Text('POST ${s.pathParameters['id']}'))),
    ],
  );
  await tester.pumpWidget(ProviderScope(
    key: UniqueKey(), // a fresh container per pump, even twice in one test
    retry: (_, _) => null,
    overrides: [
      notificationsRepositoryProvider.overrideWithValue(repo),
      notificationsViewerIdProvider.overrideWith((ref) async => signedIn ? 'u1' : null),
      notificationsRealtimeProvider.overrideWith((ref) => const Stream<int>.empty()),
      pushGatewayProvider.overrideWithValue(gateway ?? FakePushGateway(available: false)),
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
}

List<BellNotification> _rows(int n) => [for (var i = 0; i < n; i++) bell('n$i', link: '/matches/m$i', at: DateTime.now().toUtc().subtract(Duration(minutes: i + 2)))];

void main() {
  setUp(() {});

  testWidgets('lists notifications newest first with an unread dot only on unread rows', (tester) async {
    final repo = FakeNotificationsRepository(rows: [bell('a'), bell('b', read: true)]);
    await _pump(tester, repo);
    expect(find.text('Title a'), findsOneWidget);
    expect(find.text('Title b'), findsOneWidget);
    expect(tester.getTopLeft(find.text('Title a')).dy, lessThan(tester.getTopLeft(find.text('Title b')).dy));
    expect(find.byKey(const Key('ntf-dot-a')), findsOneWidget);
    expect(find.byKey(const Key('ntf-dot-b')), findsNothing);
  });

  testWidgets('shows the unread count with correct plurals', (tester) async {
    await _pump(tester, FakeNotificationsRepository(rows: [bell('a'), bell('b', read: true)]));
    expect(find.text('1 unread notification'), findsOneWidget);
    await _pump(tester, FakeNotificationsRepository(rows: [bell('a'), bell('b'), bell('c')]));
    expect(find.text('3 unread notifications'), findsOneWidget);
  });

  testWidgets('french copy renders with the french plural', (tester) async {
    await _pump(tester, FakeNotificationsRepository(rows: [bell('a')]), locale: const Locale('fr'));
    expect(find.text('1 notification non lue'), findsOneWidget);
    expect(find.text('Tout marquer comme lu'), findsOneWidget);
  });

  group('unknown and odd rows (Review Focus 2)', () {
    testWidgets('an unknown type with no link renders, and tapping it marks it read and stays put', (tester) async {
      final repo = FakeNotificationsRepository(rows: [bell('x', type: 'something_new')]);
      await _pump(tester, repo);
      await tester.tap(find.byKey(const Key('ntf-row-x')));
      await tester.pumpAndSettle();
      expect(repo.markReadCalls, ['x']);
      expect(find.text('Title x'), findsOneWidget);
      expect(find.byKey(const Key('ntf-dot-x')), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a link the app cannot map navigates nowhere', (tester) async {
      final repo = FakeNotificationsRepository(rows: [bell('w', link: '/dashboard/wallet')]);
      await _pump(tester, repo);
      await tester.tap(find.byKey(const Key('ntf-row-w')));
      await tester.pumpAndSettle();
      expect(find.text('Title w'), findsOneWidget);
      expect(find.textContaining('MATCH'), findsNothing);
    });

    testWidgets('empty title and body do not break the row', (tester) async {
      final repo = FakeNotificationsRepository(rows: [BellNotification(id: 'e', type: 'x', title: '', body: '', read: false, createdAt: DateTime.utc(2026))]);
      await _pump(tester, repo);
      expect(find.byKey(const Key('ntf-row-e')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('very long title and body do not overflow at 375px', (tester) async {
      tester.view.physicalSize = const Size(375, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final repo = FakeNotificationsRepository(rows: [
        BellNotification(id: 'l', type: 'post_reaction', title: 'T' * 300, body: 'word ' * 200, link: '/community/$_post', read: false, createdAt: DateTime.utc(2026)),
      ]);
      await _pump(tester, repo);
      expect(tester.takeException(), isNull);
    });
  });

  group('tapping a row', () {
    testWidgets('a mapped link opens the destination and marks the row read', (tester) async {
      final repo = FakeNotificationsRepository(rows: [bell('m', link: '/matches/m1')]);
      await _pump(tester, repo);
      await tester.tap(find.byKey(const Key('ntf-row-m')));
      await tester.pumpAndSettle();
      expect(find.text('MATCH m1'), findsOneWidget);
      expect(repo.markReadCalls, ['m']);
    });

    testWidgets('a failing mark-read reverts the row and says so', (tester) async {
      final repo = FakeNotificationsRepository(rows: [bell('m')])..markReadFails = true;
      await _pump(tester, repo);
      await tester.tap(find.byKey(const Key('ntf-row-m')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('ntf-dot-m')), findsOneWidget, reason: 'reverted to unread');
      expect(find.text("That didn't work. Try again."), findsOneWidget);
    });
  });

  group('mark all read', () {
    testWidgets('marks every row read, then disables itself', (tester) async {
      final repo = FakeNotificationsRepository(rows: [bell('a'), bell('b')]);
      await _pump(tester, repo);
      await tester.tap(find.byKey(const Key('ntf-mark-all')));
      await tester.pumpAndSettle();
      expect(repo.markAllCalls, 1);
      expect(find.byKey(const Key('ntf-dot-a')), findsNothing);
      expect(find.byKey(const Key('ntf-dot-b')), findsNothing);
      expect(tester.widget<TextButton>(find.byKey(const Key('ntf-mark-all'))).onPressed, isNull);
    });

    testWidgets('is disabled when nothing is unread', (tester) async {
      await _pump(tester, FakeNotificationsRepository(rows: [bell('a', read: true)]));
      expect(tester.widget<TextButton>(find.byKey(const Key('ntf-mark-all'))).onPressed, isNull);
    });

    testWidgets('a failure restores the unread dots and says so', (tester) async {
      final repo = FakeNotificationsRepository(rows: [bell('a')])..markAllFails = true;
      await _pump(tester, repo);
      await tester.tap(find.byKey(const Key('ntf-mark-all')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('ntf-dot-a')), findsOneWidget);
      expect(find.text("That didn't work. Try again."), findsOneWidget);
    });
  });

  group('mute menu', () {
    testWidgets('"Mute this thread" appears only for a community post link; "Mute this type" only for mutable types', (tester) async {
      final repo = FakeNotificationsRepository(rows: [
        bell('p', type: 'post_comment', link: '/community/$_post'),
        bell('t', type: 'post_reaction'),
        bell('u', type: 'something_new'),
        bell('s', type: 'status_removed', link: '/community'),
      ]);
      await _pump(tester, repo);

      await tester.tap(find.byKey(const Key('ntf-menu-p')));
      await tester.pumpAndSettle();
      expect(find.text('Mute this thread'), findsOneWidget);
      expect(find.text('Mute this type'), findsOneWidget);
      await tester.tapAt(const Offset(5, 5)); // dismiss
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('ntf-menu-t')));
      await tester.pumpAndSettle();
      expect(find.text('Mute this thread'), findsNothing);
      expect(find.text('Mute this type'), findsOneWidget);
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('ntf-menu-u')), findsNothing, reason: 'nothing to offer for an unknown type');
      expect(find.byKey(const Key('ntf-menu-s')), findsNothing, reason: 'status_removed is always delivered');
    });

    testWidgets('muting a type for a duration calls the repository and confirms', (tester) async {
      final repo = FakeNotificationsRepository(rows: [bell('t', type: 'post_reaction')]);
      await _pump(tester, repo);
      await tester.tap(find.byKey(const Key('ntf-menu-t')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mute this type'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('ntf-mute-always')));
      await tester.pumpAndSettle();
      expect(repo.muteCalls, ['muteType post_reaction always']);
      expect(find.text('Muted'), findsOneWidget);
    });

    testWidgets('muting a thread sends the post id from the link', (tester) async {
      final repo = FakeNotificationsRepository(rows: [bell('p', type: 'post_comment', link: '/community/$_post')]);
      await _pump(tester, repo);
      await tester.tap(find.byKey(const Key('ntf-menu-p')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mute this thread'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('ntf-mute-1h')));
      await tester.pumpAndSettle();
      expect(repo.muteCalls, ['mutePost $_post 1h']);
    });

    testWidgets('an already muted type offers Unmute and unmutes directly', (tester) async {
      final repo = FakeNotificationsRepository(rows: [bell('t', type: 'post_reaction')])
        ..mutesResult = NotificationMutes(types: [MutedType('post_reaction', DateTime.utc(2099))], posts: const []);
      await _pump(tester, repo);
      await tester.tap(find.byKey(const Key('ntf-menu-t')));
      await tester.pumpAndSettle();
      expect(find.text('Mute this type'), findsNothing);
      await tester.tap(find.text('Unmute this type'));
      await tester.pumpAndSettle();
      expect(repo.muteCalls, ['unmuteType post_reaction']);
      expect(find.text('Unmuted'), findsOneWidget);
    });

    testWidgets('a type muted "always" (push false in prefs) also reads as muted', (tester) async {
      final repo = FakeNotificationsRepository(rows: [bell('t', type: 'post_reaction')])
        ..prefsResult = const NotificationPrefs(push: {'post_reaction': false}, whatsapp: {}, achievementSharing: {});
      await _pump(tester, repo);
      await tester.tap(find.byKey(const Key('ntf-menu-t')));
      await tester.pumpAndSettle();
      expect(find.text('Unmute this type'), findsOneWidget);
    });
  });

  testWidgets('scrolling near the end loads the next page', (tester) async {
    final repo = FakeNotificationsRepository(rows: _rows(30));
    await _pump(tester, repo);
    expect(repo.pageCalls, hasLength(1));
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -2000));
    await tester.pumpAndSettle();
    expect(repo.pageCalls.any((c) => c.offset == 20), isTrue);
  });

  testWidgets('pull to refresh refetches', (tester) async {
    final repo = FakeNotificationsRepository(rows: [bell('a')]);
    await _pump(tester, repo);
    await tester.drag(find.byType(Scrollable).first, const Offset(0, 400));
    await tester.pumpAndSettle();
    expect(repo.pageCalls.length, greaterThan(1));
  });

  group('states', () {
    testWidgets('empty: friendly message and the permission row', (tester) async {
      final gateway = FakePushGateway(permissionResult: PushPermission.notDetermined, requestResult: PushPermission.authorized);
      await _pump(tester, FakeNotificationsRepository(), gateway: gateway);
      expect(find.text("You're all caught up"), findsOneWidget);
      expect(find.byKey(const Key('ntf-perm-row')), findsOneWidget);
      await tester.tap(find.byKey(const Key('ntf-perm-enable')));
      await tester.pumpAndSettle();
      expect(gateway.requestPermissionCalls, 1);
      expect(find.byKey(const Key('ntf-perm-row')), findsNothing, reason: 'authorized now: the row goes away');
    });

    testWidgets('empty and permanently denied: offers system settings', (tester) async {
      final gateway = FakePushGateway(permissionResult: PushPermission.deniedPermanently, requestResult: PushPermission.deniedPermanently);
      await _pump(tester, FakeNotificationsRepository(), gateway: gateway);
      expect(find.text('Notifications are turned off for this app in your phone settings.'), findsOneWidget);
      await tester.tap(find.byKey(const Key('ntf-perm-settings')));
      await tester.pumpAndSettle();
      expect(gateway.openSettingsCalls, 1);
    });

    testWidgets('returning from system settings with notifications now on hides the row (resume)', (tester) async {
      final gateway = FakePushGateway(permissionResult: PushPermission.deniedPermanently);
      await _pump(tester, FakeNotificationsRepository(), gateway: gateway);
      expect(find.byKey(const Key('ntf-perm-row')), findsOneWidget);
      gateway.permissionResult = PushPermission.authorized; // flipped in system settings
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('ntf-perm-row')), findsNothing);
    });

    testWidgets('no permission row when push is unavailable or already authorized', (tester) async {
      await _pump(tester, FakeNotificationsRepository(), gateway: FakePushGateway(available: false));
      expect(find.byKey(const Key('ntf-perm-row')), findsNothing);
      await _pump(tester, FakeNotificationsRepository(), gateway: FakePushGateway(permissionResult: PushPermission.authorized));
      expect(find.byKey(const Key('ntf-perm-row')), findsNothing);
    });

    testWidgets('error: message and retry that refetches', (tester) async {
      final repo = FakeNotificationsRepository(rows: [bell('a')])..pageFails = true;
      await _pump(tester, repo);
      expect(find.text("Couldn't load your notifications."), findsOneWidget);
      repo.pageFails = false;
      await tester.tap(find.byKey(const Key('ntf-retry')));
      await tester.pumpAndSettle();
      expect(find.text('Title a'), findsOneWidget);
    });

    testWidgets('signed out: a login call to action, never an error', (tester) async {
      final repo = FakeNotificationsRepository(rows: [bell('a')]);
      await _pump(tester, repo, signedIn: false);
      expect(find.text('Log in to see your notifications.'), findsOneWidget);
      expect(find.text('Title a'), findsNothing);
      expect(repo.pageCalls, isEmpty);
      await tester.tap(find.byKey(const Key('ntf-login')));
      await tester.pumpAndSettle();
      expect(find.text('LOGIN PAGE'), findsOneWidget);
    });
  });
}
