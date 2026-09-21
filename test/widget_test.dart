import 'package:flutter_test/flutter_test.dart';

import 'fakes/fake_tournaments_repository.dart';
import 'support/pump_app.dart';

void main() {
  testWidgets('the Compete tab shows the tournament list app bar', (tester) async {
    final repository = FakeTournamentsRepository(tournaments: const []);

    await pumpRouterWithRepo(tester, repository);
    await tester.pumpAndSettle();

    expect(find.text('Tournaments'), findsOneWidget);
  });
}
