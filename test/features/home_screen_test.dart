import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/core/api/models.dart';
import 'package:sentinelx_mobile/core/l10n/gen/app_localizations.dart';
import 'package:sentinelx_mobile/features/home/home_providers.dart';
import 'package:sentinelx_mobile/features/home/home_repository.dart';
import 'package:sentinelx_mobile/features/home/home_screen.dart';

class _FakeHomeRepository implements HomeRepository {
  _FakeHomeRepository(this._summary);
  final HomeSummary _summary;
  @override
  Future<HomeSummary> fetchHome() async => _summary;
}

HomeSummary _summary({List<HomeTournamentCard> upcoming = const []}) =>
    HomeSummary(
      banner: null,
      featuredTournament: HomeTournamentCard(
        id: 't1',
        title: 'FC Mobile Cup',
        slug: 'fc-mobile-cup',
        status: 'active',
        prizePool: 8000,
        registrationFee: 500,
        tournamentStart: null,
        registrationEnd: null,
        tournamentEnd: null,
        maxPlayers: 16,
        format: 'knockout',
        tournamentType: 'masters',
        cardImageUrl: null,
        game: null,
      ),
      upcomingTournaments: upcoming,
      leaderboardTeaser: const [],
      hallOfFame: null,
      stats: const HomeStats(
        playerCount: 42,
        tournamentCount: 7,
        prizesPaidOut: 100000,
      ),
    );

void main() {
  testWidgets(
    'shows a loading indicator, then the featured tournament and stats',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          retry: (_, _) => null,
          overrides: [
            homeRepositoryProvider.overrideWithValue(
              _FakeHomeRepository(_summary()),
            ),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: HomeScreen(onGoTo: (_) {}),
          ),
        ),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.pumpAndSettle();
      expect(find.text('FC Mobile Cup'), findsOneWidget);
      expect(find.textContaining('42'), findsWidgets);
    },
  );

  testWidgets('pull-to-refresh re-fetches', (tester) async {
    var calls = 0;
    final repo = _CountingRepository(_summary(), onFetch: () => calls++);
    await tester.pumpWidget(
      ProviderScope(
        retry: (_, _) => null,
        overrides: [homeRepositoryProvider.overrideWithValue(repo)],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: HomeScreen(onGoTo: (_) {}),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(calls, 1);
    await tester.fling(
      find.byType(RefreshIndicator),
      const Offset(0, 300),
      1000,
    );
    await tester.pumpAndSettle();
    expect(calls, greaterThan(1));
  });

  testWidgets(
    'a load failure shows generic localized text, not the raw exception',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          retry: (_, _) => null,
          overrides: [
            homeRepositoryProvider.overrideWithValue(_FailingHomeRepository()),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: HomeScreen(onGoTo: (_) {}),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Something went wrong loading this page.'),
        findsOneWidget,
      );
      expect(find.textContaining('Exception'), findsNothing);
    },
  );

  testWidgets('progress links navigate to their native screens', (
    tester,
  ) async {
    final visited = <String>[];
    await tester.pumpWidget(
      ProviderScope(
        retry: (_, _) => null,
        overrides: [
          homeRepositoryProvider.overrideWithValue(
            _FakeHomeRepository(_summary()),
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: HomeScreen(onGoTo: visited.add),
        ),
      ),
    );
    await tester.pumpAndSettle();

    for (final entry in const [
      (Key('home-link-rankings'), '/rankings'),
      (Key('home-link-seasons'), '/seasons'),
      (Key('home-link-hall-of-fame'), '/hall-of-fame'),
    ]) {
      await tester.ensureVisible(find.byKey(entry.$1));
      await tester.tap(find.byKey(entry.$1));
      expect(visited.last, entry.$2);
    }
  });
}

class _FailingHomeRepository implements HomeRepository {
  @override
  Future<HomeSummary> fetchHome() async => throw Exception('network down');
}

class _CountingRepository implements HomeRepository {
  _CountingRepository(this._summary, {required this.onFetch});
  final HomeSummary _summary;
  final VoidCallback onFetch;
  @override
  Future<HomeSummary> fetchHome() async {
    onFetch();
    return _summary;
  }
}
