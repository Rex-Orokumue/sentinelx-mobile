import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/features/compete/compete_models.dart';
import 'package:sentinelx_mobile/features/compete/compete_providers.dart';
import 'package:sentinelx_mobile/features/compete/games_screen.dart';

import '../../fakes/fake_compete_reads.dart';
import '../../support/pump_compete.dart';

Future<void> _pump(WidgetTester tester, FakeCompeteReads fake) async {
  await pumpCompete(tester, const GamesScreen(), overrides: [competeReadsRepositoryProvider.overrideWithValue(fake)]);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('lists the active games', (tester) async {
    await _pump(
      tester,
      FakeCompeteReads(games: const [
        GameSummary(id: '1', name: 'FC Mobile', slug: 'fc-mobile', iconUrl: null),
        GameSummary(id: '2', name: 'DLS', slug: 'dls', iconUrl: 'https://cdn.test/broken.png'),
      ]),
    );
    expect(find.text('FC Mobile'), findsOneWidget);
    expect(find.text('DLS'), findsOneWidget);
    expect(tester.takeException(), isNull); // a null icon and a broken icon URL both render
  });

  testWidgets('empty catalogue says so', (tester) async {
    await _pump(tester, FakeCompeteReads());
    expect(find.text('No games yet.'), findsOneWidget);
  });

  testWidgets('a load failure shows friendly copy with a retry, never the exception', (tester) async {
    await _pump(tester, FakeCompeteReads(failAll: true));
    expect(find.text("Couldn't load this. Check your connection and try again."), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
    expect(find.textContaining('Exception'), findsNothing);
  });
}
