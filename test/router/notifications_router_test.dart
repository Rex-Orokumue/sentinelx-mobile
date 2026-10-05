import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sentinelx_mobile/core/l10n/gen/app_localizations.dart';
import 'package:sentinelx_mobile/core/notifications/push/push_models.dart';
import 'package:sentinelx_mobile/core/notifications/push/push_tap_router.dart';
import 'package:sentinelx_mobile/core/notifications/unread_counts.dart';
import 'package:sentinelx_mobile/features/notifications/notifications_providers.dart';
import 'package:sentinelx_mobile/features/notifications/notifications_repository.dart';
import 'package:sentinelx_mobile/router/app_router.dart';

import '../fakes/fake_notifications_repository.dart';
import '../support/pump_app.dart';
import '../support/pump_compete.dart' show competeBaseOverrides;

List<Override> _bellOverrides(FakeNotificationsRepository repo) => [
      notificationsRepositoryProvider.overrideWithValue(repo),
      notificationsViewerIdProvider.overrideWith((ref) async => 'u1'),
      notificationsRealtimeProvider.overrideWith((ref) => const Stream<int>.empty()),
      unreadNotificationCountProvider.overrideWith((ref) => Stream.value(2)),
      unreadMessageCountProvider.overrideWith((ref) => Stream.value(0)),
    ];

Future<void> _pump(WidgetTester tester, String location) => pumpRouterWithRepo(
      tester,
      initialLocation: location,
      overrides: [
        notificationsRepositoryProvider.overrideWithValue(FakeNotificationsRepository(rows: [bell('a')])),
        notificationsViewerIdProvider.overrideWith((ref) async => 'u1'),
        notificationsRealtimeProvider.overrideWith((ref) => const Stream<int>.empty()),
        unreadNotificationCountProvider.overrideWith((ref) => Stream.value(2)),
        unreadMessageCountProvider.overrideWith((ref) => Stream.value(0)),
      ],
    );

void main() {
  testWidgets('/notifications renders the bell (the router redirect leaves in-app paths alone)', (tester) async {
    await _pump(tester, '/notifications');
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('ntf-mark-all')), findsOneWidget);
    expect(find.text('Title a'), findsOneWidget);
  });

  testWidgets('the app bar bell opens /notifications and Back returns to the tab it was tapped from', (tester) async {
    await _pump(tester, '/account');
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('account-sign-out')), findsOneWidget);

    await tester.tap(find.byKey(const Key('bell-notifications')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('ntf-mark-all')), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('account-sign-out')), findsOneWidget);
    expect(find.byKey(const Key('ntf-mark-all')), findsNothing);
  });

  testWidgets('/account/notifications renders Settings -> Notifications', (tester) async {
    await _pump(tester, '/account/notifications');
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('ntf-push-post_reaction')), findsOneWidget);
  });

  testWidgets('the Account tile opens Settings -> Notifications', (tester) async {
    await _pump(tester, '/account');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('account-notifications')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('ntf-push-post_reaction')), findsOneWidget);
  });

  Future<GoRouter> pumpBell(WidgetTester tester, {required String link}) async {
    final repo = FakeNotificationsRepository(rows: [bell('a', link: link)]);
    final router = buildAppRouter(initialLocation: '/notifications');
    await tester.pumpWidget(ProviderScope(
      retry: (_, _) => null,
      overrides: [...competeBaseOverrides(), ..._bellOverrides(repo)],
      child: MaterialApp.router(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
      ),
    ));
    await tester.pumpAndSettle();
    return router;
  }

  testWidgets('a bell row linking to a tab goes to that tab, like a push tap: tab bar, nothing stacked under it', (tester) async {
    final router = await pumpBell(tester, link: 'https://sentinelxesports.com.ng/community');
    await tester.tap(find.text('Title a'));
    await tester.pumpAndSettle();
    expect(router.routerDelegate.currentConfiguration.last.matchedLocation, '/community');
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(router.canPop(), isFalse, reason: 'a tab page pushed over the bell would have no visible Back control');
    expect(tester.takeException(), isNull);
  });

  testWidgets('a bell row linking to a detail screen pushes it, so Back returns to the bell', (tester) async {
    final router = await pumpBell(tester, link: 'https://sentinelxesports.com.ng/tournaments/some-slug');
    await tester.tap(find.text('Title a'));
    await tester.pumpAndSettle();
    expect(router.routerDelegate.currentConfiguration.last.matchedLocation, '/tournaments/some-slug');
    expect(router.canPop(), isTrue);
  });

  testWidgets('a push tap routed through the real router lands on its destination in one hop', (tester) async {
    final repo = FakeNotificationsRepository(rows: [bell('a')]);
    final router = buildAppRouter(initialLocation: '/account');
    final visited = <String>[];
    router.routerDelegate.addListener(() => visited.add(router.routerDelegate.currentConfiguration.uri.toString()));
    await tester.pumpWidget(ProviderScope(
      retry: (_, _) => null,
      overrides: [
        ...competeBaseOverrides(),
        ..._bellOverrides(repo),
        pushNavigatorProvider.overrideWithValue((location) => router.go(location)),
      ],
      child: MaterialApp.router(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
      ),
    ));
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(tester.element(find.byType(MaterialApp)));
    container.read(pushTapRouterProvider)
      ..markReady()
      ..onTap(const PushMessage(url: 'https://sentinelxesports.com.ng/community'));
    await tester.pumpAndSettle();

    expect(router.routerDelegate.currentConfiguration.last.matchedLocation, '/community');
    expect(visited.where((v) => v.startsWith('/login') || v.startsWith('/onboarding')), isEmpty, reason: 'no bounce through the gate');
  });
}
