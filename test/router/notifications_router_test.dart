import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/core/notifications/unread_counts.dart';
import 'package:sentinelx_mobile/features/notifications/notifications_providers.dart';
import 'package:sentinelx_mobile/features/notifications/notifications_repository.dart';

import '../fakes/fake_notifications_repository.dart';
import '../support/pump_app.dart';

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

  testWidgets('the messages bell still goes to coming-soon until 5b', (tester) async {
    await _pump(tester, '/account');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('bell-messages')));
    await tester.pumpAndSettle();
    expect(find.text('Coming soon'), findsWidgets);
  });
}
