import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sentinelx_mobile/core/api/api_client.dart';
import 'package:sentinelx_mobile/core/api/chat_models.dart';
import 'package:sentinelx_mobile/core/l10n/gen/app_localizations.dart';
import 'package:sentinelx_mobile/core/lifecycle/app_lifecycle_provider.dart';
import 'package:sentinelx_mobile/core/providers.dart';
import 'package:sentinelx_mobile/core/storage/local_kv.dart';
import 'package:sentinelx_mobile/features/support_chat/chat_repository.dart';
import 'package:sentinelx_mobile/features/support_chat/chat_screen.dart';
import '../../fakes/fake_chat_repository.dart';
import '../../fakes/fake_realtime.dart' show FakeLifecycle;

Widget chatApp(FakeChatRepository repo, {String? viewer = 'u1'}) {
  final router = GoRouter(initialLocation: '/chat', routes: [
    GoRoute(path: '/chat', builder: (_, _) => const ChatScreen()),
    GoRoute(path: '/tournaments', builder: (_, _) => const Scaffold(body: Text('TOURNAMENTS SCREEN'))),
  ]);
  return ProviderScope(
    overrides: [
      viewerIdProvider.overrideWith((ref) async => viewer),
      chatRepositoryProvider.overrideWithValue(repo),
      appLifecycleSourceProvider.overrideWithValue(FakeLifecycle()),
      chatDeviceIdProvider.overrideWith((ref) async => 'device-abc-123'),
    ],
    child: MaterialApp.router(
      routerConfig: router,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    ),
  );
}

Future<void> typeAndSend(WidgetTester tester, String text) async {
  await tester.enterText(find.byKey(const Key('chat-input')), text);
  await tester.pump(); // the send button enables on this frame
  await tester.tap(find.byKey(const Key('chat-send')));
  await tester.pump();
}

void main() {
  testWidgets('send streams into the assistant bubble and the composer re-enables', (tester) async {
    final repo = FakeChatRepository();
    await tester.pumpWidget(chatApp(repo));
    await tester.pumpAndSettle();
    await typeAndSend(tester, 'how do fees work');
    expect(find.text('how do fees work'), findsOneWidget);
    repo.last.add(const ChatDelta('Entry is '));
    await tester.pump();
    repo.last.add(const ChatDelta('₦500.'));
    repo.last.add(const ChatDone(true));
    await repo.last.close();
    await tester.pumpAndSettle();
    expect(find.text('Entry is ₦500.'), findsOneWidget);
    expect(tester.widget<IconButton>(find.byKey(const Key('chat-send'))).onPressed, isNull); // empty composer
  });
  testWidgets('rate limited shows the countdown copy and Retry stays disabled until it elapses', (tester) async {
    final repo = FakeChatRepository()
      ..sendError = const ApiException(status: 429, code: 'chat_rate_limited', message: 'x', fields: {'retryAfterSeconds': '5'});
    await tester.pumpWidget(chatApp(repo));
    await tester.pumpAndSettle();
    await typeAndSend(tester, 'hi');
    await tester.pump();
    expect(find.textContaining('5 s'), findsOneWidget);
    expect(tester.widget<TextButton>(find.byKey(const Key('chat-retry'))).onPressed, isNull);
    await tester.pump(const Duration(seconds: 6));
    expect(tester.widget<TextButton>(find.byKey(const Key('chat-retry'))).onPressed, isNotNull);
  });
  testWidgets('chips show only for destinations with a route and navigate through the fixed table', (tester) async {
    final repo = FakeChatRepository();
    await tester.pumpWidget(chatApp(repo));
    await tester.pumpAndSettle();
    await typeAndSend(tester, 'where do I sign up');
    repo.last.add(const ChatDelta('See tournaments.'));
    repo.last.add(const ChatActions([ChatDestination.tournaments, ChatDestination.wallet]));
    repo.last.add(const ChatDone(false));
    await repo.last.close();
    await tester.pumpAndSettle();
    expect(find.text('Open tournaments'), findsOneWidget);
    expect(find.byKey(const Key('chat-chip-wallet')), findsNothing); // no wallet screen yet
    await tester.tap(find.text('Open tournaments'));
    await tester.pumpAndSettle();
    expect(find.text('TOURNAMENTS SCREEN'), findsOneWidget);
  });
  testWidgets('an interrupted turn shows the dropped-connection copy and Retry reuses the same turn id', (tester) async {
    final repo = FakeChatRepository();
    await tester.pumpWidget(chatApp(repo));
    await tester.pumpAndSettle();
    await typeAndSend(tester, 'q');
    repo.last.add(const ChatDelta('part'));
    await repo.last.close(); // end of stream without a terminal event
    await tester.pumpAndSettle();
    expect(find.text('The connection dropped. Tap Retry.'), findsOneWidget);
    await tester.tap(find.byKey(const Key('chat-retry')));
    await tester.pump();
    expect(repo.sends, hasLength(2));
    expect(repo.sends.last.turnId, repo.sends.first.turnId);
    repo.last.add(const ChatDone(true));
    await repo.last.close();
    await tester.pumpAndSettle();
  });
  testWidgets('signed out: notice says chats are not saved, no history request, unavailable shows the sign-in copy', (tester) async {
    final repo = FakeChatRepository()..sendError = const ApiException(status: 503, code: 'chat_unavailable', message: 'x');
    await tester.pumpWidget(chatApp(repo, viewer: null));
    await tester.pumpAndSettle();
    expect(find.text("Chats aren't saved. Sign in for answers about your account."), findsOneWidget);
    expect(repo.historyCalls, 0);
    await typeAndSend(tester, 'hi');
    await tester.pump();
    expect(find.text('The assistant is busy right now. Sign in to keep chatting.'), findsOneWidget);
    expect(repo.sends.single.deviceId, 'device-abc-123');
  });
  testWidgets('signed in: retention notice, and Clear chat asks first then empties', (tester) async {
    final repo = FakeChatRepository()
      ..historyPage = ChatHistoryPage(messages: [ChatHistoryItem(id: 'a', role: 'user', content: 'old question', createdAt: DateTime.utc(2026))]);
    await tester.pumpWidget(chatApp(repo));
    await tester.pumpAndSettle();
    expect(find.text('Chats are kept for 30 days.'), findsOneWidget);
    expect(find.text('old question'), findsOneWidget);
    await tester.tap(find.byKey(const Key('chat-clear')));
    await tester.pumpAndSettle();
    expect(repo.clears, 0); // confirmation first
    await tester.tap(find.byKey(const Key('chat-clear-confirm')));
    await tester.pumpAndSettle();
    expect(repo.clears, 1);
    expect(find.text('old question'), findsNothing);
  });
  testWidgets('blank messages are not sent and the composer enforces 1000 characters', (tester) async {
    final repo = FakeChatRepository();
    await tester.pumpWidget(chatApp(repo));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('chat-input')), '   ');
    await tester.tap(find.byKey(const Key('chat-send')));
    await tester.pump();
    expect(repo.sends, isEmpty);
    await tester.enterText(find.byKey(const Key('chat-input')), 'x' * 1500);
    final field = tester.widget<TextField>(find.byKey(const Key('chat-input')));
    expect(field.controller!.text.length, lessThanOrEqualTo(1000));
  });
}
