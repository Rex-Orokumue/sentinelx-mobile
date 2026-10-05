import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sentinelx_mobile/core/api/messages_models.dart';
import 'package:sentinelx_mobile/core/notifications/unread_counts.dart';
import 'package:sentinelx_mobile/core/realtime/realtime_hub.dart';
import 'package:sentinelx_mobile/features/messages/conversation_screen.dart';
import 'package:sentinelx_mobile/features/messages/inbox_providers.dart';
import 'package:sentinelx_mobile/features/messages/inbox_screen.dart';
import 'package:sentinelx_mobile/features/messages/requests_screen.dart';
import 'package:sentinelx_mobile/features/notifications/notifications_providers.dart';
import 'package:sentinelx_mobile/features/notifications/notifications_repository.dart';

import '../fakes/fake_messages_repository.dart';
import '../fakes/fake_notifications_repository.dart';
import '../fakes/fake_realtime.dart';
import '../support/pump_app.dart';

const _id = '3f2b8c1e-9d4a-4b7e-8a61-5c0d2e7f9a10';

Future<void> _pump(WidgetTester tester, String location, {int dmCount = 0}) => pumpRouterWithRepo(
      tester,
      initialLocation: location,
      overrides: [
        messagesRepositoryProvider.overrideWithValue(
          FakeMessagesRepository(inbox: [thread('a')], requests: [thread('q', requestState: RequestState.pending, direction: RequestDirection.incoming)], requestCount: 1),
        ),
        dmNudgeProvider.overrideWith((ref) => const Stream<RealtimeSignal>.empty()),
        realtimeHubProvider.overrideWithValue(RealtimeHub(factory: FakeChannelFactory(), lifecycle: FakeLifecycle())),
        notificationsRepositoryProvider.overrideWithValue(FakeNotificationsRepository(rows: [bell('a')])),
        notificationsRealtimeProvider.overrideWith((ref) => const Stream<int>.empty()),
        unreadNotificationCountProvider.overrideWith((ref) => Stream.value(0)),
        unreadMessageCountProvider.overrideWith((ref) => Stream.value(dmCount)),
      ],
    );

void main() {
  testWidgets('/messages renders the inbox', (tester) async {
    await _pump(tester, '/messages');
    await tester.pumpAndSettle();
    expect(find.byType(InboxScreen), findsOneWidget);
  });

  testWidgets('/messages/requests builds the requests screen, not the thread screen (lesson 9)', (tester) async {
    await _pump(tester, '/messages/requests');
    await tester.pumpAndSettle();
    expect(find.byType(RequestsScreen), findsOneWidget);
    expect(find.byType(ConversationScreen), findsNothing);
    expect(find.byKey(const Key('dm-thread-q')), findsOneWidget);
  });

  testWidgets('/messages/<uuid> builds the conversation', (tester) async {
    await _pump(tester, '/messages/$_id');
    await tester.pumpAndSettle();
    expect(find.byType(ConversationScreen), findsOneWidget);
  });

  testWidgets('pushing a thread from /community leaves /community underneath: Back returns to it', (tester) async {
    await _pump(tester, '/community');
    await tester.pumpAndSettle();
    final ctx = tester.element(find.byType(Scaffold).first);
    unawaited(GoRouter.of(ctx).push<void>('/messages/$_id'));
    await tester.pumpAndSettle();
    expect(find.byType(ConversationScreen), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(ConversationScreen), findsNothing);
    expect(find.byType(NavigationBar), findsOneWidget);
  });

  testWidgets('the messages bell on a tab pushes /messages and Back returns to the tab', (tester) async {
    await _pump(tester, '/account', dmCount: 3);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('account-sign-out')), findsOneWidget);
    await tester.tap(find.byKey(const Key('bell-messages')));
    await tester.pumpAndSettle();
    expect(find.byType(InboxScreen), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('account-sign-out')), findsOneWidget);
  });

  testWidgets('the messages bell tooltip carries the unread plural', (tester) async {
    await _pump(tester, '/account', dmCount: 3);
    await tester.pumpAndSettle();
    expect(find.byTooltip('3 unread messages'), findsOneWidget);
  });
}
