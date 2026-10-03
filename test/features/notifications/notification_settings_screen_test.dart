import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sentinelx_mobile/core/api/api_client.dart';
import 'package:sentinelx_mobile/core/api/notifications_models.dart';
import 'package:sentinelx_mobile/core/l10n/gen/app_localizations.dart';
import 'package:sentinelx_mobile/core/notifications/push/push_gateway.dart';
import 'package:sentinelx_mobile/core/notifications/push/push_models.dart';
import 'package:sentinelx_mobile/features/notifications/notification_settings_screen.dart';
import 'package:sentinelx_mobile/features/notifications/notifications_providers.dart';
import 'package:sentinelx_mobile/features/notifications/notifications_repository.dart';

import '../../fakes/fake_notifications_repository.dart';
import '../../fakes/fake_push_gateway.dart';

NotificationPrefs _prefs() => NotificationPrefs(
      push: {for (final k in kPushPrefKeys) k: true},
      whatsapp: {for (final k in kWhatsappPrefKeys) k: false},
      achievementSharing: {for (final k in kSharingPrefKeys) k: true},
    );

Future<void> _pump(
  WidgetTester tester,
  FakeNotificationsRepository repo, {
  bool signedIn = true,
  FakePushGateway? gateway,
  Locale locale = const Locale('en'),
}) async {
  tester.view.physicalSize = const Size(375, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final router = GoRouter(
    initialLocation: '/account/notifications',
    routes: [
      GoRoute(path: '/account/notifications', builder: (_, _) => const NotificationSettingsScreen()),
      GoRoute(path: '/login', builder: (_, _) => const Scaffold(body: Text('LOGIN PAGE'))),
    ],
  );
  await tester.pumpWidget(ProviderScope(
    key: UniqueKey(),
    retry: (_, _) => null,
    overrides: [
      notificationsRepositoryProvider.overrideWithValue(repo),
      notificationsViewerIdProvider.overrideWith((ref) async => signedIn ? 'u1' : null),
      pushGatewayProvider.overrideWithValue(gateway ?? FakePushGateway(available: false)),
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

Future<void> _tap(WidgetTester tester, Key key) async {
  await tester.ensureVisible(find.byKey(key));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(key));
}

bool _on(WidgetTester tester, String key) => tester.widget<SwitchListTile>(find.byKey(Key(key))).value;

void main() {
  testWidgets('renders all 28 switches with their server values and web labels', (tester) async {
    await _pump(tester, FakeNotificationsRepository()..prefsResult = _prefs());
    for (final k in kPushPrefKeys) {
      expect(find.byKey(Key('ntf-push-$k')), findsOneWidget, reason: k);
    }
    for (final k in kWhatsappPrefKeys) {
      expect(find.byKey(Key('ntf-wa-$k')), findsOneWidget, reason: k);
    }
    for (final k in kSharingPrefKeys) {
      expect(find.byKey(Key('ntf-share-$k')), findsOneWidget, reason: k);
    }
    expect(_on(tester, 'ntf-push-post_reaction'), isTrue);
    expect(_on(tester, 'ntf-wa-challenge_completed'), isFalse);
    expect(find.text('New fixture assigned'), findsOneWidget);
    expect(find.text('Match reminders (1h before kickoff)'), findsOneWidget);
    expect(find.text('Tournament wins'), findsOneWidget);
  });

  testWidgets('toggling flips immediately and sends exactly that key', (tester) async {
    final repo = FakeNotificationsRepository()
      ..prefsResult = _prefs()
      ..holdPatch = Completer<void>();
    await _pump(tester, repo);
    await _tap(tester, const Key('ntf-push-post_reaction'));
    await tester.pump();
    expect(_on(tester, 'ntf-push-post_reaction'), isFalse, reason: 'optimistic');
    repo.holdPatch!.complete();
    await tester.pumpAndSettle();
    expect(repo.patchCalls.single.section, PrefSection.push);
    expect(repo.patchCalls.single.values, {'post_reaction': false});
    expect(_on(tester, 'ntf-push-post_reaction'), isFalse);
  });

  testWidgets('each section patches its own section', (tester) async {
    final repo = FakeNotificationsRepository()..prefsResult = _prefs();
    await _pump(tester, repo);
    await _tap(tester, const Key('ntf-wa-challenge_completed'));
    await tester.pumpAndSettle();
    await _tap(tester, const Key('ntf-share-social'));
    await tester.pumpAndSettle();
    expect(repo.patchCalls.map((c) => c.section), [PrefSection.whatsapp, PrefSection.achievementSharing]);
    expect(repo.patchCalls[0].values, {'challenge_completed': true});
    expect(repo.patchCalls[1].values, {'social': false});
  });

  testWidgets('a failing patch flips the switch back and says so', (tester) async {
    final repo = FakeNotificationsRepository()
      ..prefsResult = _prefs()
      ..failPatchKeys.add('post_reaction');
    await _pump(tester, repo);
    await _tap(tester, const Key('ntf-push-post_reaction'));
    await tester.pumpAndSettle();
    expect(_on(tester, 'ntf-push-post_reaction'), isTrue);
    expect(find.text("Couldn't save that change."), findsOneWidget);
  });

  group('test notification', () {
    testWidgets('success says it was sent', (tester) async {
      final repo = FakeNotificationsRepository()..prefsResult = _prefs();
      await _pump(tester, repo);
      await _tap(tester, const Key('ntf-test-push'));
      await tester.pumpAndSettle();
      expect(repo.testPushCalls, 1);
      expect(find.text('Test sent — it should arrive in a moment.'), findsOneWidget);
    });

    testWidgets('not_found means this phone is not registered', (tester) async {
      final repo = FakeNotificationsRepository()
        ..prefsResult = _prefs()
        ..testPushError = ApiException(status: 404, code: 'not_found', message: 'x');
      await _pump(tester, repo);
      await _tap(tester, const Key('ntf-test-push'));
      await tester.pumpAndSettle();
      expect(find.text("This phone isn't registered for notifications yet."), findsOneWidget);
    });

    testWidgets('any other failure says it could not be delivered', (tester) async {
      final repo = FakeNotificationsRepository()
        ..prefsResult = _prefs()
        ..testPushError = ApiException(status: 500, code: 'internal', message: 'x');
      await _pump(tester, repo);
      await _tap(tester, const Key('ntf-test-push'));
      await tester.pumpAndSettle();
      expect(find.text("The test notification couldn't be delivered."), findsOneWidget);
    });

    testWidgets('is disabled while in flight, so a double tap sends one', (tester) async {
      final repo = FakeNotificationsRepository()
        ..prefsResult = _prefs()
        ..holdTestPush = Completer<void>();
      await _pump(tester, repo);
      await _tap(tester, const Key('ntf-test-push'));
      await tester.pump();
      expect(tester.widget<OutlinedButton>(find.byKey(const Key('ntf-test-push'))).onPressed, isNull);
      await tester.tap(find.byKey(const Key('ntf-test-push')), warnIfMissed: false);
      repo.holdTestPush!.complete();
      await tester.pumpAndSettle();
      expect(repo.testPushCalls, 1);
    });
  });

  group('permission row', () {
    testWidgets('shows the enable action when never asked', (tester) async {
      await _pump(tester, FakeNotificationsRepository()..prefsResult = _prefs(), gateway: FakePushGateway(permissionResult: PushPermission.notDetermined));
      expect(find.byKey(const Key('ntf-perm-enable')), findsOneWidget);
    });

    testWidgets('shows the on confirmation when authorized (settings keeps the row)', (tester) async {
      await _pump(tester, FakeNotificationsRepository()..prefsResult = _prefs(), gateway: FakePushGateway(permissionResult: PushPermission.authorized));
      expect(find.text('Notifications are on for this phone.'), findsOneWidget);
    });

    testWidgets('permanently denied offers system settings', (tester) async {
      final gateway = FakePushGateway(permissionResult: PushPermission.deniedPermanently, requestResult: PushPermission.deniedPermanently);
      await _pump(tester, FakeNotificationsRepository()..prefsResult = _prefs(), gateway: gateway);
      await _tap(tester, const Key('ntf-perm-settings'));
      await tester.pumpAndSettle();
      expect(gateway.openSettingsCalls, 1);
    });

    testWidgets('hidden when push is unavailable', (tester) async {
      await _pump(tester, FakeNotificationsRepository()..prefsResult = _prefs());
      expect(find.byKey(const Key('ntf-perm-row')), findsNothing);
    });
  });

  testWidgets('error shows retry that reloads', (tester) async {
    final repo = FakeNotificationsRepository();
    repo.prefsResult = _prefs();
    // The prefs read fails once: the fake has no failure hook for reads, so use a repository subclass.
    final failing = _FailOncePrefs(repo);
    await _pump(tester, failing);
    expect(find.text("Couldn't load your notifications."), findsOneWidget);
    await tester.tap(find.byKey(const Key('ntf-retry')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('ntf-push-post_reaction')), findsOneWidget);
  });

  testWidgets('signed out shows the login call to action and loads nothing', (tester) async {
    final repo = FakeNotificationsRepository()..prefsResult = _prefs();
    await _pump(tester, repo, signedIn: false);
    expect(find.text('Log in to see your notifications.'), findsOneWidget);
    expect(find.byKey(const Key('ntf-push-post_reaction')), findsNothing);
    await tester.tap(find.byKey(const Key('ntf-login')));
    await tester.pumpAndSettle();
    expect(find.text('LOGIN PAGE'), findsOneWidget);
  });

  testWidgets('french labels fit at 375px without overflow', (tester) async {
    await _pump(tester, FakeNotificationsRepository()..prefsResult = _prefs(), locale: const Locale('fr'));
    expect(find.text('Rappels de match'), findsOneWidget);
    for (final key in ['ntf-wa-match_reminder', 'ntf-share-milestone', 'ntf-share-social']) {
      await tester.ensureVisible(find.byKey(Key(key)));
      await tester.pumpAndSettle();
    }
    expect(tester.takeException(), isNull);
  });
}

class _FailOncePrefs extends FakeNotificationsRepository {
  _FailOncePrefs(FakeNotificationsRepository base) {
    prefsResult = base.prefsResult;
  }
  bool _failed = false;

  @override
  Future<NotificationPrefs> prefs() async {
    if (!_failed) {
      _failed = true;
      throw StateError('boom');
    }
    return super.prefs();
  }
}
