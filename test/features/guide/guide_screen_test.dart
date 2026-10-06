import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/core/api/api_client.dart';
import 'package:sentinelx_mobile/core/api/guide_models.dart';
import 'package:sentinelx_mobile/core/l10n/gen/app_localizations.dart';
import 'package:sentinelx_mobile/core/providers.dart';
import 'package:sentinelx_mobile/features/guide/guide_repository.dart';
import 'package:sentinelx_mobile/features/guide/guide_screen.dart';
import 'package:sentinelx_mobile/features/progress/progress_providers.dart' show progressProvider;

import '../../fakes/fake_guide_repository.dart';
import '../../support/guide_fixtures.dart';

Widget guideApp(FakeGuideRepository repo, {String? viewer = 'u1'}) => ProviderScope(
      key: UniqueKey(),
      overrides: <Override>[
        viewerIdProvider.overrideWith((ref) async => viewer),
        meProvider.overrideWith((ref) async => null),
        guideRepositoryProvider.overrideWithValue(repo),
        progressProvider.overrideWith((ref) async => throw StateError('not needed')),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const GuideScreen(),
      ),
    );

void main() {
  testWidgets('signed in: checklist with one Take me there per pending step', (tester) async {
    await tester.pumpWidget(guideApp(FakeGuideRepository(seed: [quest(done: 1)])));
    await tester.pumpAndSettle();
    expect(find.text('Complete your profile'), findsOneWidget);
    expect(find.text('Take me there'), findsNWidgets(2)); // the done step has no link
  });
  testWidgets('an unknown step key shows the generic label; an unknown target shows no link', (tester) async {
    const q = Quest(id: 'battle_ready', steps: [QuestStep(key: 'brand_new', done: false)], totalCount: 1, allComplete: false, claimed: false, rewardXp: 1, rewardCoins: 1);
    await tester.pumpWidget(guideApp(FakeGuideRepository(seed: const [q])));
    await tester.pumpAndSettle();
    expect(find.text('Complete this step'), findsOneWidget);
    expect(find.text('Take me there'), findsNothing);
  });
  testWidgets('claim is disabled until all steps are done, then claims once and shows Badge earned', (tester) async {
    final repo = FakeGuideRepository(seed: [quest(done: 2)], claimResult: const BadgeClaim(alreadyClaimed: false, xp: 100, coins: 50));
    await tester.pumpWidget(guideApp(repo));
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(find.byKey(const Key('quest-claim'))).onPressed, isNull);
    repo.seed = [quest(done: 3)];
    await tester.pumpWidget(guideApp(repo)); // a fresh scope refetches
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('quest-claim')));
    await tester.pumpAndSettle();
    expect(repo.claimCalls, 1);
    expect(find.text('Badge earned'), findsOneWidget);
  });
  testWidgets('a failed claim shows the mapped copy, never the server text, and the button stays usable', (tester) async {
    final repo = FakeGuideRepository(
      seed: [quest(done: 3)],
      claimError: const ApiException(status: 409, code: 'quest_incomplete', message: 'server text must not show'),
    );
    await tester.pumpWidget(guideApp(repo));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('quest-claim')));
    await tester.pumpAndSettle();
    expect(find.text('Finish all three steps first.'), findsOneWidget);
    expect(find.text('server text must not show'), findsNothing);
    expect(tester.widget<FilledButton>(find.byKey(const Key('quest-claim'))).onPressed, isNotNull);
  });
  testWidgets('signed out: visitor tour pages and no quest request', (tester) async {
    final repo = FakeGuideRepository(seed: [quest()]);
    await tester.pumpWidget(guideApp(repo, viewer: null));
    await tester.pumpAndSettle();
    expect(find.text('What is Sentinel X?'), findsOneWidget);
    await tester.tap(find.byKey(const Key('tour-next')));
    await tester.pumpAndSettle();
    expect(find.text('The four pillars'), findsOneWidget);
    expect(repo.questsCalls, 0);
  });
}
