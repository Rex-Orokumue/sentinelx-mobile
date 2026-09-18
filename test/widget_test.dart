import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/main.dart';

void main() {
  testWidgets('SentinelXApp boots and shows the placeholder home', (tester) async {
    await tester.pumpWidget(const SentinelXApp());

    expect(find.text('Sentinel X'), findsOneWidget);
  });
}
