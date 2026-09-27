import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/core/api/progress_models.dart';
import 'package:sentinelx_mobile/core/l10n/gen/app_localizations.dart';
import 'package:sentinelx_mobile/features/hall_of_fame/hall_of_fame_providers.dart';
import 'package:sentinelx_mobile/features/hall_of_fame/hall_of_fame_repository.dart';
import 'package:sentinelx_mobile/features/hall_of_fame/hall_of_fame_screen.dart';

Map<String, Object?> _player(String id, String name) => {
  'id': id,
  'username': name.toLowerCase(),
  'displayName': name,
  'avatarUrl': null,
  'frameUrl': null,
  'country': null,
  'sxScore': 1000,
  'sentinelTier': null,
  'membershipTier': 'free',
  'kycVerified': false,
  'isDeleted': false,
};

HallOfFame _emptyHall({
  String? selectedGame,
  bool awards = false,
  bool shrinkAwards = false,
  bool emptyFilteredCategory = false,
}) => HallOfFame.fromJson({
  'games': [
    {'id': 'g1', 'slug': 'dls', 'name': 'DLS', 'category': 'football'},
  ],
  'selectedGame': selectedGame,
  'awards': {
    'mvp': null,
    'goldenBoot': awards
        ? [
            {
              'gameId': null,
              'gameLabel': 'All goals',
              'winner': _player('p1', 'Ada'),
              'metricValue': 20,
            },
            if (!shrinkAwards || selectedGame == null)
              {
                'gameId': 'g1',
                'gameLabel': 'DLS',
                'winner': _player('p2', 'Bola'),
                'metricValue': 12,
              },
          ]
        : [],
    'categories': emptyFilteredCategory
        ? [
            {
              'category': 'racing',
              'label': 'Fastest Driver',
              'metricLabel': 'Wins',
              'options': selectedGame == null
                  ? [
                      {
                        'gameId': 'g1',
                        'gameLabel': 'DLS',
                        'winner': _player('p1', 'Ada'),
                        'metricValue': 8,
                      },
                    ]
                  : [],
            },
          ]
        : [],
  },
  'champions': {
    'championsCup': [],
    'masters': [],
    'communityClub': [],
    'open': [],
  },
  'bronze': [],
});

class _Repo implements HallOfFameRepository {
  _Repo({
    this.fail = false,
    this.awards = false,
    this.shrinkAwards = false,
    this.emptyFilteredCategory = false,
  });
  final bool fail;
  final bool awards;
  final bool shrinkAwards;
  final bool emptyFilteredCategory;
  int calls = 0;

  @override
  Future<HallOfFame> fetch({String? game}) async {
    calls++;
    if (fail) throw Exception('failed');
    return _emptyHall(
      selectedGame: game,
      awards: awards,
      shrinkAwards: shrinkAwards,
      emptyFilteredCategory: emptyFilteredCategory,
    );
  }
}

Widget _app(_Repo repo) => ProviderScope(
  retry: (_, _) => null,
  overrides: [hallOfFameRepositoryProvider.overrideWithValue(repo)],
  child: const MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: HallOfFameScreen(),
  ),
);

void main() {
  testWidgets('game filter hides category awards with no options', (
    tester,
  ) async {
    await tester.pumpWidget(_app(_Repo(emptyFilteredCategory: true)));
    await tester.pumpAndSettle();
    expect(find.text('Fastest Driver'), findsOneWidget);

    await tester.tap(find.byKey(const Key('hof-chip-dls')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Fastest Driver'), findsNothing);
  });

  testWidgets('award selection clamps when filtering shrinks options', (
    tester,
  ) async {
    await tester.pumpWidget(_app(_Repo(awards: true, shrinkAwards: true)));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('award-option-Golden Boot-DLS')));
    await tester.pumpAndSettle();
    expect(find.text('Bola'), findsOneWidget);

    await tester.tap(find.byKey(const Key('hof-chip-dls')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Ada'), findsOneWidget);
  });

  testWidgets('hall of fame award options switch winners', (tester) async {
    await tester.pumpWidget(_app(_Repo(awards: true)));
    await tester.pumpAndSettle();
    expect(find.text('Ada'), findsOneWidget);

    await tester.tap(find.byKey(const Key('award-option-Golden Boot-DLS')));
    await tester.pumpAndSettle();
    expect(find.text('Bola'), findsOneWidget);
    expect(find.text('Ada'), findsNothing);
  });

  testWidgets('game filter hides empty hall sections', (tester) async {
    final repo = _Repo();
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();
    expect(find.text('Masters'), findsOneWidget);

    await tester.tap(find.byKey(const Key('hof-chip-dls')));
    await tester.pumpAndSettle();
    expect(find.text('Masters'), findsNothing);
  });

  testWidgets('hall of fame error retries when tapped', (tester) async {
    final repo = _Repo(fail: true);
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.text("Couldn't load. Tap to retry."));
    await tester.pumpAndSettle();
    expect(repo.calls, 2);
  });

  testWidgets('hall of fame supports pull to refresh', (tester) async {
    final repo = _Repo();
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    await tester.drag(find.byType(ListView), const Offset(0, 300));
    await tester.pumpAndSettle();
    expect(repo.calls, 2);
  });
}
