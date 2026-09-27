import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/core/api/models.dart';
import 'package:sentinelx_mobile/core/api/progress_models.dart';
import 'package:sentinelx_mobile/core/l10n/gen/app_localizations.dart';
import 'package:sentinelx_mobile/core/providers.dart';
import 'package:sentinelx_mobile/features/seasons/season_detail_screen.dart';
import 'package:sentinelx_mobile/features/seasons/seasons_list_screen.dart';
import 'package:sentinelx_mobile/features/seasons/seasons_providers.dart';
import 'package:sentinelx_mobile/features/seasons/seasons_repository.dart';

const _season = SeasonSummary(
  id: 's1',
  slug: 'season-one',
  name: 'Season One',
  startDate: '2026-01-01',
  endDate: '2026-03-31',
);

SeasonGame _game({
  required List<SeasonLeaderboardRow> rows,
  bool invitationOnly = false,
}) => SeasonGame(
  gameId: 'g1',
  gameName: 'DLS',
  gameSlug: 'dls',
  tournaments: [
    SeasonTournament(
      id: 't1',
      title: 'Season Cup',
      slug: 'season-cup',
      tournamentType: 'masters',
      status: 'upcoming',
      tournamentStart: null,
      invitationOnly: invitationOnly,
    ),
  ],
  leaderboard: rows,
  tierLabels: const SeasonTierLabels(
    communityClub: 'Community',
    masters: 'Masters',
    qualificationNote: 'Top players qualify.',
    showChampionsCupSpotlight: false,
  ),
);

class _Repo implements SeasonsRepository {
  _Repo(this.game);
  final SeasonGame game;

  @override
  Future<List<SeasonSummary>> list() async => const [_season];

  @override
  Future<SeasonDetail> detail(String slug) async =>
      SeasonDetail(season: _season, games: [game]);
}

class _CountingRepo extends _Repo {
  _CountingRepo(super.game, {this.failList = false, this.failDetail = false});
  final bool failList;
  final bool failDetail;
  int listCalls = 0;
  int detailCalls = 0;

  @override
  Future<List<SeasonSummary>> list() async {
    listCalls++;
    if (failList) throw Exception('list failed');
    return super.list();
  }

  @override
  Future<SeasonDetail> detail(String slug) async {
    detailCalls++;
    if (failDetail) throw Exception('detail failed');
    return super.detail(slug);
  }
}

Widget _app(SeasonGame game) => ProviderScope(
  retry: (_, _) => null,
  overrides: [
    seasonsRepositoryProvider.overrideWithValue(_Repo(game)),
    meProvider.overrideWith((_) async => null),
  ],
  child: const MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: SeasonDetailScreen(slug: 'season-one'),
  ),
);

void main() {
  testWidgets(
    'season detail shows you, provisional note and invite-only chip',
    (tester) async {
      final game = _game(
        invitationOnly: true,
        rows: const [
          SeasonLeaderboardRow(
            playerId: 'p1',
            username: 'ada',
            displayName: 'Ada',
            avatarUrl: null,
            sxScore: 1200,
            points: 20,
            isProvisional: true,
          ),
        ],
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            seasonsRepositoryProvider.overrideWithValue(_Repo(game)),
            meProvider.overrideWith(
              (_) async => const MeResponse(
                id: 'p1',
                email: null,
                roles: [],
                isStaff: false,
                isAdmin: false,
                profile: null,
              ),
            ),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: SeasonDetailScreen(slug: 'season-one'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('season-row-me')), findsOneWidget);
      expect(find.text('You'), findsOneWidget);
      expect(find.text('Provisional'), findsOneWidget);
      expect(
        find.text('Points can still change while tournaments are in progress.'),
        findsOneWidget,
      );
      expect(find.text('Invite only'), findsOneWidget);
    },
  );

  testWidgets('season list error retries when tapped', (tester) async {
    final repo = _CountingRepo(_game(rows: const []), failList: true);
    await tester.pumpWidget(
      ProviderScope(
        retry: (_, _) => null,
        overrides: [seasonsRepositoryProvider.overrideWithValue(repo)],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: SeasonsListScreen(onSeasonTap: (_) {}),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text("Couldn't load. Tap to retry."));
    await tester.pumpAndSettle();
    expect(repo.listCalls, 2);
  });

  testWidgets('season detail error keeps an app bar and retries when tapped', (
    tester,
  ) async {
    final repo = _CountingRepo(_game(rows: const []), failDetail: true);
    await tester.pumpWidget(
      ProviderScope(
        retry: (_, _) => null,
        overrides: [
          seasonsRepositoryProvider.overrideWithValue(repo),
          meProvider.overrideWith((_) async => null),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: SeasonDetailScreen(slug: 'bad-slug'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(AppBar), findsOneWidget);
    await tester.tap(find.text("Couldn't load. Tap to retry."));
    await tester.pumpAndSettle();
    expect(repo.detailCalls, 2);
  });

  testWidgets('season list supports pull to refresh', (tester) async {
    final repo = _CountingRepo(_game(rows: const []));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [seasonsRepositoryProvider.overrideWithValue(repo)],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: SeasonsListScreen(onSeasonTap: (_) {}),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, 300));
    await tester.pumpAndSettle();
    expect(repo.listCalls, 2);
  });

  testWidgets('season detail supports pull to refresh', (tester) async {
    final repo = _CountingRepo(_game(rows: const []));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          seasonsRepositoryProvider.overrideWithValue(repo),
          meProvider.overrideWith((_) async => null),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: SeasonDetailScreen(slug: 'season-one'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, 300));
    await tester.pumpAndSettle();
    expect(repo.detailCalls, 2);
  });

  testWidgets('season leaderboard caps rows at 50 and medals the top three', (
    tester,
  ) async {
    final rows = List.generate(
      51,
      (i) => SeasonLeaderboardRow(
        playerId: 'p${i + 1}',
        username: 'player${i + 1}',
        displayName: 'Player ${i + 1}',
        avatarUrl: null,
        sxScore: 1000 - i,
        points: 100 - i,
        isProvisional: false,
      ),
    );
    await tester.pumpWidget(_app(_game(rows: rows)));
    await tester.pumpAndSettle();

    expect(find.text('🥇'), findsOneWidget);
    expect(find.text('🥈'), findsOneWidget);
    expect(find.text('🥉'), findsOneWidget);
    await tester.fling(find.byType(ListView), const Offset(0, -5000), 10000);
    await tester.pumpAndSettle();
    expect(find.text('Player 50'), findsOneWidget);
    expect(find.text('Player 51'), findsNothing);
  });

  testWidgets('season game names an empty leaderboard', (tester) async {
    await tester.pumpWidget(_app(_game(rows: const [])));
    await tester.pumpAndSettle();

    expect(find.text('No season points awarded yet.'), findsOneWidget);
  });
}
