import 'package:flutter_test/flutter_test.dart';

import 'support/pump_app.dart';

void main() {
  testWidgets('the Compete tab shows the tournament list app bar', (tester) async {
    await pumpRouterWithRepo(tester);
    await tester.pumpAndSettle();

    expect(find.text('Tournaments'), findsOneWidget);
  });
}
