import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sentinelx_mobile/core/l10n/gen/app_localizations.dart';
import 'package:sentinelx_mobile/core/lifecycle/app_lifecycle_provider.dart';
import 'package:sentinelx_mobile/core/providers.dart';
import 'package:sentinelx_mobile/features/guide/guide_repository.dart';
import 'package:sentinelx_mobile/features/guide/quest_card.dart';
import '../../fakes/fake_guide_repository.dart';
import '../../fakes/fake_realtime.dart' show FakeLifecycle;
import '../../support/guide_fixtures.dart';

Widget cardApp(FakeGuideRepository repo, {String? viewer = 'u1', FakeLifecycle? life}) {
  final router = GoRouter(routes: [
    GoRoute(path: '/', builder: (_, _) => const Scaffold(body: QuestCard())),
    GoRoute(path: '/guide', builder: (_, _) => const Scaffold(body: Text('GUIDE SCREEN'))),
  ]);
  return ProviderScope(
    key: UniqueKey(),
    overrides: <Override>[
      viewerIdProvider.overrideWith((ref) async => viewer),
      guideRepositoryProvider.overrideWithValue(repo),
      appLifecycleSourceProvider.overrideWithValue(life ?? FakeLifecycle()),
    ],
    child: MaterialApp.router(
      routerConfig: router,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    ),
  );
}

void main() {
  testWidgets('shows N of M and opens /guide on tap', (tester) async {
    await tester.pumpWidget(cardApp(FakeGuideRepository(seed: [quest(done: 1)])));
    await tester.pumpAndSettle();
    expect(find.text('1 of 3 done'), findsOneWidget);
    await tester.tap(find.byType(QuestCard));
    await tester.pumpAndSettle();
    expect(find.text('GUIDE SCREEN'), findsOneWidget);
  });
  testWidgets('hidden when claimed, when signed out and when there is no battle_ready quest', (tester) async {
    await tester.pumpWidget(cardApp(FakeGuideRepository(seed: [quest(done: 3, claimed: true)])));
    await tester.pumpAndSettle();
    expect(find.byType(LinearProgressIndicator), findsNothing);
    final signedOut = FakeGuideRepository(seed: [quest()]);
    await tester.pumpWidget(cardApp(signedOut, viewer: null));
    await tester.pumpAndSettle();
    expect(signedOut.questsCalls, 0);
    expect(find.byType(LinearProgressIndicator), findsNothing);
    await tester.pumpWidget(cardApp(FakeGuideRepository(seed: const [])));
    await tester.pumpAndSettle();
    expect(find.byType(LinearProgressIndicator), findsNothing);
  });
  testWidgets('refetches the quests when the app resumes', (tester) async {
    final repo = FakeGuideRepository(seed: [quest()]);
    final life = FakeLifecycle();
    await tester.pumpWidget(cardApp(repo, life: life));
    await tester.pumpAndSettle();
    expect(repo.questsCalls, 1);
    life.push(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(repo.questsCalls, 2);
  });
}
