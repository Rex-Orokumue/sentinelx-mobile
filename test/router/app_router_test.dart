import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sentinelx_mobile/core/api/match_models.dart';
import 'package:sentinelx_mobile/core/auth/onboarding_gate.dart';
import 'package:sentinelx_mobile/core/l10n/gen/app_localizations.dart';
import 'package:sentinelx_mobile/features/compete/compete_models.dart';
import 'package:sentinelx_mobile/features/match/evidence.dart';
import 'package:sentinelx_mobile/features/match/match_providers.dart';
import 'package:sentinelx_mobile/features/match/match_reads_repository.dart';
import 'package:sentinelx_mobile/router/app_router.dart';
import 'package:sentinelx_mobile/router/auth_redirect.dart';

import '../fakes/fake_compete_reads.dart';
import '../fakes/fake_evidence.dart';
import '../fakes/fake_match_repositories.dart';
import '../support/compete_fixtures.dart';
import '../support/match_fixtures.dart';
import '../support/pump_app.dart';
import '../support/pump_compete.dart';

void main() {
  testWidgets('navigates list -> detail -> bracket, and a fixture tap opens the Match Centre', (tester) async {
    final reads = FakeCompeteReads(
      tournaments: [CompeteTournament.fromJson(tournamentRow(id: 't1', title: 'FC Mobile Premier League'))],
    );
    final matchRepo = FakeMatchRepository()
      ..bracketView = BracketView.fromJson(bracketJson(withKnockout: false)
        ..['fixtures'] = {
          'live': <Map<String, dynamic>>[],
          'upcoming': [fixtureJson(id: 'm1')],
          'completed': <Map<String, dynamic>>[],
          'disputedOrCancelled': <Map<String, dynamic>>[],
        });
    await pumpRouterWithRepo(tester, reads: reads, matchRepo: matchRepo);
    await tester.pumpAndSettle();

    expect(find.text('FC Mobile Premier League'), findsOneWidget);

    await tester.tap(find.byKey(const Key('tournament-tile-t1')));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const Key('view-bracket-button')));
    await tester.tap(find.byKey(const Key('view-bracket-button')));
    await tester.pumpAndSettle();

    expect(find.text('Bracket'), findsOneWidget);
    await tester.tap(find.byKey(const Key('tab-fixtures')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('fixture-m1')));
    await tester.pumpAndSettle();

    expect(find.text('Match'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Bracket'), findsOneWidget);
  });

  testWidgets('/matches/m1 renders the Match Centre inside the tab shell (bottom nav still present)', (tester) async {
    await pumpRouterWithRepo(tester, initialLocation: '/matches/m1');
    await tester.pumpAndSettle();
    expect(find.text('Match'), findsOneWidget);
    expect(find.text('Compete'), findsOneWidget);
    expect(find.text('Account'), findsOneWidget);
  });

  testWidgets('/matches/m1/result with extra renders the result screen', (tester) async {
    const match = MatchInfo(
      id: 'm1',
      tournamentId: 't1',
      round: 'quarter_final',
      status: 'scheduled',
      isFullDay: false,
      nameA: 'Ada',
      nameB: 'Bola',
    );
    final router = buildAppRouter(initialLocation: '/matches/m1');
    await tester.pumpWidget(ProviderScope(
      retry: (_, _) => null,
      overrides: [
        ...competeBaseOverrides(),
        matchRepositoryProvider.overrideWithValue(FakeMatchRepository()),
        evidenceUploaderProvider.overrideWithValue(FakeUploader()),
        imagePickerProvider.overrideWithValue(FakePicker()),
      ],
      child: MaterialApp.router(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
      ),
    ));
    await tester.pumpAndSettle();
    router.push('/matches/m1/result', extra: match);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('score-a')), findsOneWidget);
  });

  testWidgets('/matches/m1/result without extra loads the match then renders', (tester) async {
    final reads = FakeMatchReads(matches: {
      'm1': const MatchInfo(
        id: 'm1',
        tournamentId: 't1',
        round: 'quarter_final',
        status: 'scheduled',
        isFullDay: false,
        nameA: 'Ada',
        nameB: 'Bola',
      ),
    });
    await pumpRouterWithRepo(tester, matchReads: reads, initialLocation: '/matches/m1/result');
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('score-a')), findsOneWidget);
  });

  testWidgets('/lobbies/l1/result renders the lobby screen, with and without extra', (tester) async {
    await pumpRouterWithRepo(tester, initialLocation: '/lobbies/l1/result');
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('placement')), findsOneWidget);

    final router = buildAppRouter();
    await tester.pumpWidget(ProviderScope(
      key: UniqueKey(),
      retry: (_, _) => null,
      overrides: [
        ...competeBaseOverrides(),
        matchRepositoryProvider.overrideWithValue(FakeMatchRepository()),
        evidenceUploaderProvider.overrideWithValue(FakeUploader()),
        imagePickerProvider.overrideWithValue(FakePicker()),
      ],
      child: MaterialApp.router(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
      ),
    ));
    await tester.pumpAndSettle();
    router.push('/lobbies/l1/result', extra: NextLobby.fromJson(nextLobbyJson(lobbyId: 'l1')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('placement')), findsOneWidget);
    expect(find.textContaining('Round 2'), findsOneWidget);
  });

  testWidgets('/tournaments/t1/stages/s1 without extra renders the standings table', (tester) async {
    final matchRepo = FakeMatchRepository()
      ..stageRows = [
        const PointsStandingRow(
          entrantId: 'e1',
          displayName: 'Ada',
          played: 2,
          totalPoints: 30,
          totalKills: 5,
          bestPlacement: 1,
          lastRoundPlacement: 1,
          rank: 1,
          advancing: true,
          unresolvedTieWith: [],
        ),
      ];
    await pumpRouterWithRepo(tester, matchRepo: matchRepo, initialLocation: '/tournaments/t1/stages/s1');
    await tester.pumpAndSettle();
    expect(find.text('Ada'), findsOneWidget);
  });

  testWidgets('/games, /invitations and /account/profile resolve to their screens', (tester) async {
    for (final c in [('/games', 'No games yet.'), ('/invitations', 'No pending invitations.'), ('/account/profile', 'Edit profile')]) {
      await pumpRouterWithRepo(tester, initialLocation: c.$1);
      await tester.pumpAndSettle();
      expect(find.text(c.$2), findsOneWidget, reason: c.$1);
      await tester.pumpWidget(const SizedBox());
    }
  });

  testWidgets('a tournament web link (slug) opens the detail screen', (tester) async {
    final reads = FakeCompeteReads(tournaments: [CompeteTournament.fromJson(tournamentRow(title: 'Slug Cup'))]);
    await pumpRouterWithRepo(tester, reads: reads, initialLocation: 'https://sentinelxesports.com.ng/tournaments/fc-mobile-cup');
    await tester.pumpAndSettle();
    expect(find.text('Slug Cup'), findsOneWidget);
    expect(find.byKey(const Key('reg-cta')), findsOneWidget);
  });

  testWidgets('the tab bar has all five destinations and Home lives outside it', (tester) async {
    await pumpRouterWithRepo(tester);
    await tester.pumpAndSettle();
    expect(find.text('Compete'), findsOneWidget);
    expect(find.text('Watch'), findsOneWidget);
    expect(find.text('Community'), findsOneWidget);
    expect(find.text('Trade'), findsOneWidget);
    expect(find.text('Account'), findsOneWidget);
  });

  test('the /debug route exists only when debug tools are enabled', () {
    bool hasDebug(bool tools) => buildAppRouter(debugTools: tools)
        .configuration
        .routes
        .whereType<GoRoute>()
        .any((r) => r.path == '/debug');
    expect(hasDebug(false), isFalse);
    expect(hasDebug(true), isTrue);
  });

  testWidgets('an incoming App Link with the full web URL resolves to the in-app route instead of 404ing',
      (tester) async {
    final router = buildAppRouter();

    await tester.pumpWidget(ProviderScope(
      retry: (_, _) => null,
      overrides: [...competeBaseOverrides(), matchRepositoryProvider.overrideWithValue(FakeMatchRepository())],
      child: MaterialApp.router(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
      ),
    ));
    await tester.pumpAndSettle();

    router.go('https://sentinelxesports.com.ng/tournaments');
    await tester.pumpAndSettle();

    expect(router.routerDelegate.currentConfiguration.uri.toString(), '/tournaments');
    expect(find.text('Tournaments'), findsOneWidget);
  });

  testWidgets('a signed-in user needing a username is redirected there on initial load', (tester) async {
    final router = buildAppRouter(
      initialLocation: '/tournaments',
      authGate: () => const AuthGateSnapshot(isLoading: false, isSignedIn: true, onboardingGate: OnboardingGate.username),
    );
    await tester.pumpWidget(ProviderScope(
      child: MaterialApp.router(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
      ),
    ));
    await tester.pumpAndSettle();
    expect(router.routerDelegate.currentConfiguration.uri.toString(), '/onboarding/username');
  });
}
