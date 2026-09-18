import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/router/app_router.dart';

import 'fakes/fake_tournaments_repository.dart';

void main() {
  testWidgets('the app boots into the tournament list app bar', (tester) async {
    final repository = FakeTournamentsRepository(tournaments: const []);

    await tester.pumpWidget(MaterialApp.router(
      routerConfig: buildAppRouter(repository: repository),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Tournaments'), findsOneWidget);
  });
}
