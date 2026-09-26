import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sentinelx_mobile/core/auth/onboarding_gate.dart';
import 'package:sentinelx_mobile/core/l10n/gen/app_localizations.dart';
import 'package:sentinelx_mobile/features/compete/compete_models.dart';
import 'package:sentinelx_mobile/features/tournaments/tournaments_providers.dart';
import 'package:sentinelx_mobile/models/tournament.dart';
import 'package:sentinelx_mobile/router/app_router.dart';
import 'package:sentinelx_mobile/router/auth_redirect.dart';

import '../fakes/fake_compete_reads.dart';
import '../fakes/fake_tournaments_repository.dart';
import '../support/compete_fixtures.dart';
import '../support/pump_app.dart';

Tournament _tournament() {
  return const Tournament(
    id: 't1',
    title: 'FC Mobile Premier League',
    slug: 'fc-mobile-premier-league',
    description: null,
    bannerUrl: null,
    cardImageUrl: null,
    status: 'active',
    format: 'group_knockout',
    competitionFormat: 'head_to_head',
    entryUnit: 'solo',
    prizePool: 10000,
    prizeSecond: null,
    prizeThird: null,
    registrationFee: 500,
    maxPlayers: 16,
    registrationStart: null,
    registrationEnd: null,
    tournamentStart: null,
    tournamentEnd: null,
    rules: null,
    gameName: 'EA FC Mobile',
  );
}

void main() {
  testWidgets('navigates list -> detail -> bracket and back', (tester) async {
    final repository = FakeTournamentsRepository(
      tournaments: [_tournament()],
      tournamentById: _tournament(),
      matchesByTournament: const {},
    );

    final reads = FakeCompeteReads(
      tournaments: [CompeteTournament.fromJson(tournamentRow(id: 't1', title: 'FC Mobile Premier League'))],
    );
    await pumpRouterWithRepo(tester, repository, reads: reads);
    await tester.pumpAndSettle();

    expect(find.text('FC Mobile Premier League'), findsOneWidget);

    await tester.tap(find.byKey(const Key('tournament-tile-t1')));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const Key('view-bracket-button')));
    expect(find.byKey(const Key('view-bracket-button')), findsOneWidget);

    await tester.tap(find.byKey(const Key('view-bracket-button')));
    await tester.pumpAndSettle();

    expect(find.text('No matches yet.'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('view-bracket-button')), findsOneWidget);
  });

  testWidgets('/games, /invitations and /account/profile resolve to their screens', (tester) async {
    final repository = FakeTournamentsRepository(tournaments: const []);
    for (final c in [('/games', 'No games yet.'), ('/invitations', 'No pending invitations.'), ('/account/profile', 'Edit profile')]) {
      await pumpRouterWithRepo(tester, repository, initialLocation: c.$1);
      await tester.pumpAndSettle();
      expect(find.text(c.$2), findsOneWidget, reason: c.$1);
      await tester.pumpWidget(const SizedBox());
    }
  });

  testWidgets('a tournament web link (slug) opens the detail screen', (tester) async {
    final repository = FakeTournamentsRepository(tournaments: const []);
    final reads = FakeCompeteReads(tournaments: [CompeteTournament.fromJson(tournamentRow(title: 'Slug Cup'))]);
    await pumpRouterWithRepo(tester, repository, reads: reads, initialLocation: 'https://sentinelxesports.com.ng/tournaments/fc-mobile-cup');
    await tester.pumpAndSettle();
    expect(find.text('Slug Cup'), findsOneWidget);
    expect(find.byKey(const Key('reg-cta')), findsOneWidget);
  });

  testWidgets('the tab bar has all five destinations and Home lives outside it', (tester) async {
    await pumpRouterWithRepo(
      tester,
      FakeTournamentsRepository(tournaments: const [], tournamentById: null, matchesByTournament: const {}),
    );
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
    final repository = FakeTournamentsRepository(tournaments: const []);
    final router = buildAppRouter();

    await tester.pumpWidget(ProviderScope(
      retry: (_, _) => null,
      overrides: [tournamentsRepositoryProvider.overrideWithValue(repository)],
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
