import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/core/l10n/gen/app_localizations.dart';
import 'package:sentinelx_mobile/features/hall_of_fame/hall_of_fame_screen.dart';
import 'package:sentinelx_mobile/features/rankings/rankings_screen.dart';
import 'package:sentinelx_mobile/features/seasons/season_detail_screen.dart';
import 'package:sentinelx_mobile/router/app_router.dart';

Future<void> _pump(WidgetTester tester, String location) => tester.pumpWidget(
  ProviderScope(
    child: MaterialApp.router(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: buildAppRouter(initialLocation: location),
    ),
  ),
);

void main() {
  testWidgets('/rankings resolves to RankingsScreen', (tester) async {
    await _pump(tester, '/rankings');
    await tester.pump();
    expect(find.byType(RankingsScreen), findsOneWidget);
  });

  testWidgets('/seasons/:slug resolves with the slug', (tester) async {
    await _pump(tester, '/seasons/season-one');
    await tester.pump();
    expect(
      tester.widget<SeasonDetailScreen>(find.byType(SeasonDetailScreen)).slug,
      'season-one',
    );
  });

  testWidgets('/hall-of-fame resolves to HallOfFameScreen', (tester) async {
    await _pump(tester, '/hall-of-fame');
    await tester.pump();
    expect(find.byType(HallOfFameScreen), findsOneWidget);
  });
}
