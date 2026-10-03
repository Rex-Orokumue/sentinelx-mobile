import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/core/l10n/gen/app_localizations.dart';
import 'package:sentinelx_mobile/core/notifications/push/push_banner_host.dart';
import 'package:sentinelx_mobile/core/notifications/push/push_models.dart';
import 'package:sentinelx_mobile/core/notifications/push/push_tap_router.dart';
import 'package:sentinelx_mobile/features/notifications/notifications_repository.dart';

import '../fakes/fake_notifications_repository.dart';

class _Rig {
  final visited = <String>[];
  late final ProviderContainer container = ProviderContainer(overrides: [
    pushNavigatorProvider.overrideWithValue(visited.add),
    notificationsRepositoryProvider.overrideWithValue(FakeNotificationsRepository()),
  ]);

  Future<void> pump(WidgetTester tester) async {
    container.read(pushTapRouterProvider).markReady();
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => PushBannerHost(child: child ?? const SizedBox.shrink()),
        home: const Scaffold(body: Text('page')),
      ),
    ));
  }
}

void main() {
  testWidgets('shows nothing and leaves the child alone when there is no message', (tester) async {
    final r = _Rig();
    addTearDown(r.container.dispose);
    await r.pump(tester);
    expect(find.text('page'), findsOneWidget);
    expect(find.byKey(const Key('push-banner')), findsNothing);
  });

  testWidgets('a foreground message shows a banner with its title and body', (tester) async {
    final r = _Rig();
    addTearDown(r.container.dispose);
    await r.pump(tester);
    r.container.read(foregroundPushProvider.notifier).show(const PushMessage(title: 'New fixture', body: 'You face Ada', url: '/matches/m1'));
    await tester.pump();
    expect(find.byKey(const Key('push-banner')), findsOneWidget);
    expect(find.text('New fixture'), findsOneWidget);
    expect(find.text('You face Ada'), findsOneWidget);
    await tester.pump(const Duration(seconds: 6)); // let the auto-dismiss timer finish
  });

  testWidgets('tapping the banner routes via the tap router and hides it', (tester) async {
    final r = _Rig();
    addTearDown(r.container.dispose);
    await r.pump(tester);
    r.container.read(foregroundPushProvider.notifier).show(const PushMessage(title: 'T', body: 'B', url: '/matches/m1'));
    await tester.pump();
    await tester.tap(find.byKey(const Key('push-banner')));
    await tester.pump();
    expect(r.visited, ['/matches/m1']);
    expect(find.byKey(const Key('push-banner')), findsNothing);
  });

  testWidgets('auto-dismisses after 5 seconds', (tester) async {
    final r = _Rig();
    addTearDown(r.container.dispose);
    await r.pump(tester);
    r.container.read(foregroundPushProvider.notifier).show(const PushMessage(title: 'T', body: 'B'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 4));
    expect(find.byKey(const Key('push-banner')), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    expect(find.byKey(const Key('push-banner')), findsNothing);
  });

  testWidgets('a second message replaces the first and restarts the timer', (tester) async {
    final r = _Rig();
    addTearDown(r.container.dispose);
    await r.pump(tester);
    final c = r.container.read(foregroundPushProvider.notifier);
    c.show(const PushMessage(title: 'first', body: 'B'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 4));
    c.show(const PushMessage(title: 'second', body: 'B'));
    await tester.pump();
    expect(find.text('first'), findsNothing);
    expect(find.text('second'), findsOneWidget);
    await tester.pump(const Duration(seconds: 4)); // 8s after the first, 4s after the second
    expect(find.text('second'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    expect(find.byKey(const Key('push-banner')), findsNothing);
  });

  testWidgets('a message with no title or body still renders and never throws', (tester) async {
    final r = _Rig();
    addTearDown(r.container.dispose);
    await r.pump(tester);
    r.container.read(foregroundPushProvider.notifier).show(const PushMessage(url: '/matches/m1'));
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('push-banner')), findsOneWidget);
    await tester.pump(const Duration(seconds: 6));
  });

  testWidgets('a very long title and body do not overflow at 375px', (tester) async {
    tester.view.physicalSize = const Size(375, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final r = _Rig();
    addTearDown(r.container.dispose);
    await r.pump(tester);
    r.container.read(foregroundPushProvider.notifier).show(PushMessage(title: 'T' * 200, body: 'word ' * 120));
    await tester.pump();
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(seconds: 6));
  });
}
