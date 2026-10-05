import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sentinelx_mobile/core/l10n/gen/app_localizations.dart';
import 'package:sentinelx_mobile/core/realtime/realtime_hub.dart';
import 'package:sentinelx_mobile/features/messages/conversation_screen.dart';
import 'package:sentinelx_mobile/features/messages/inbox_providers.dart';
import 'package:sentinelx_mobile/features/messages/thread_providers.dart';

import '../fakes/fake_messages_repository.dart';

/// The fixed "now" the conversation tests run at (midday UTC so local dates stay on the same day anywhere).
final kNow = DateTime.utc(2026, 10, 5, 12);

class ConvRig {
  ConvRig(this.router, this.nudges, this.container);

  final GoRouter router;
  final StreamController<RealtimeSignal> nudges;
  final ProviderContainer container;
  var _seq = 0;

  Future<void> nudge(WidgetTester tester, [RealtimeSignalKind kind = RealtimeSignalKind.event]) async {
    nudges.add(RealtimeSignal(++_seq, kind));
    await tester.pump();
    await tester.pump();
  }
}

Future<ConvRig> pumpConversation(
  WidgetTester tester,
  FakeMessagesRepository repo, {
  String threadId = 't1',
  String viewer = 'me',
  DateTime? now,
  Locale locale = const Locale('en'),
  List<Override> overrides = const [],
  Size size = const Size(375, 800),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final nudges = StreamController<RealtimeSignal>.broadcast();
  addTearDown(nudges.close);
  final router = GoRouter(
    initialLocation: '/messages/$threadId',
    routes: [
      GoRoute(path: '/', builder: (_, _) => const Scaffold(body: Text('HOME'))),
      GoRoute(path: '/messages/:threadId', builder: (_, s) => ConversationScreen(threadId: s.pathParameters['threadId']!)),
      GoRoute(path: '/players/:username', builder: (_, s) => Scaffold(appBar: AppBar(), body: Text('PLAYER ${s.pathParameters['username']}'))),
    ],
  );
  late ProviderContainer container;
  await tester.pumpWidget(ProviderScope(
    key: UniqueKey(),
    retry: (_, _) => null,
    overrides: [
      messagesRepositoryProvider.overrideWithValue(repo),
      dmViewerIdProvider.overrideWith((ref) async => viewer),
      dmNudgeProvider.overrideWith((ref) => nudges.stream),
      deliveredThrottleProvider.overrideWithValue(DeliveredThrottle(send: repo.markAllDelivered)),
      dmClockProvider.overrideWithValue(() => now ?? kNow),
      ...overrides,
    ],
    child: Builder(builder: (context) {
      container = ProviderScope.containerOf(context);
      return MaterialApp.router(
        routerConfig: router,
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      );
    }),
  ));
  await tester.pumpAndSettle();
  return ConvRig(router, nudges, container);
}
