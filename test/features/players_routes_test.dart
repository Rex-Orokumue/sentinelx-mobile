import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/core/api/models.dart';
import 'package:sentinelx_mobile/core/api/players_models.dart';
import 'package:sentinelx_mobile/core/l10n/gen/app_localizations.dart';
import 'package:sentinelx_mobile/core/providers.dart';
import 'package:sentinelx_mobile/core/realtime/realtime_hub.dart';
import 'package:sentinelx_mobile/features/messages/conversation_screen.dart';
import 'package:sentinelx_mobile/features/messages/inbox_providers.dart';
import 'package:sentinelx_mobile/features/players/follow_list_screen.dart';
import 'package:sentinelx_mobile/features/players/player_profile_screen.dart';
import 'package:sentinelx_mobile/features/players/players_directory_screen.dart';
import 'package:sentinelx_mobile/features/players/players_providers.dart';
import 'package:sentinelx_mobile/features/progress/history_list_screen.dart';
import 'package:sentinelx_mobile/features/progress/my_progress_screen.dart';
import 'package:sentinelx_mobile/features/progress/progress_providers.dart';
import 'package:sentinelx_mobile/router/app_router.dart';

import '../fakes/fake_messages_repository.dart';
import '../support/fake_players_repository.dart';
import '../support/fake_progress_repository.dart';

Future<void> _pump(WidgetTester tester, String location) async {
  final progress = FakeProgressRepository()
    ..xpPager = ((_) => const HistoryPage<XpEvent>(items: [], nextCursor: null))
    ..scorePager = ((_) => const HistoryPage<SxScoreEvent>(items: [], nextCursor: null))
    ..coinPager = ((_) => const HistoryPage<CoinTransaction>(items: [], nextCursor: null));
  await tester.pumpWidget(ProviderScope(
    retry: (_, _) => null,
    overrides: [
      playersRepositoryProvider.overrideWithValue(FakePlayersRepository()),
      progressRepositoryProvider.overrideWithValue(progress),
      meProvider.overrideWith((ref) async => const MeResponse(id: 'me1', email: null, roles: [], isStaff: false, isAdmin: false, profile: null)),
    ],
    child: MaterialApp.router(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: buildAppRouter(initialLocation: location),
    ),
  ));
  await tester.pump();
}

void main() {
  testWidgets('/players resolves to the directory', (tester) async {
    await _pump(tester, '/players');
    expect(find.byType(PlayersDirectoryScreen), findsOneWidget);
  });
  testWidgets('/players/ada resolves to the profile with the username', (tester) async {
    await _pump(tester, '/players/ada');
    expect(tester.widget<PlayerProfileScreen>(find.byType(PlayerProfileScreen)).username, 'ada');
  });
  testWidgets('followers / following resolve with the right kind', (tester) async {
    await _pump(tester, '/players/ada/followers');
    expect(tester.widget<FollowListScreen>(find.byType(FollowListScreen)).kind, FollowListKind.followers);
    await _pump(tester, '/players/ada/following');
    expect(tester.widget<FollowListScreen>(find.byType(FollowListScreen)).kind, FollowListKind.following);
  });
  testWidgets('/account/progress and its three histories resolve inside the Account branch', (tester) async {
    await _pump(tester, '/account/progress');
    expect(find.byType(MyProgressScreen), findsOneWidget);
    await _pump(tester, '/account/progress/xp');
    expect(find.byType(HistoryListScreen<XpEvent>), findsOneWidget);
  });

  testWidgets('the profile Message button starts a thread, pushes the conversation, and Back returns to the profile', (tester) async {
    final messages = FakeMessagesRepository();
    await tester.pumpWidget(ProviderScope(
      retry: (_, _) => null,
      overrides: [
        playersRepositoryProvider.overrideWithValue(FakePlayersRepository()),
        messagesRepositoryProvider.overrideWithValue(messages),
        dmViewerIdProvider.overrideWith((ref) async => 'me1'),
        dmNudgeProvider.overrideWith((ref) => const Stream<RealtimeSignal>.empty()),
        meProvider.overrideWith((ref) async => const MeResponse(id: 'me1', email: null, roles: [], isStaff: false, isAdmin: false, profile: null)),
      ],
      child: MaterialApp.router(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: buildAppRouter(initialLocation: '/players/ada'),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('message-button')));
    await tester.pumpAndSettle();
    expect(messages.startCalls, hasLength(1));
    expect(find.byType(ConversationScreen), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(PlayerProfileScreen), findsOneWidget);
    expect(find.byType(ConversationScreen), findsNothing);
  });
}
