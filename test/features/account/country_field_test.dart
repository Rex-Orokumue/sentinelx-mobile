import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/features/account/country_field.dart';

void main() {
  testWidgets('shows the canonical value and returns an English country name', (
    tester,
  ) async {
    String? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CountryField(
            label: 'Country',
            placeholder: 'Choose country',
            value: 'Ghana',
            onChanged: (value) => selected = value,
          ),
        ),
      ),
    );

    expect(find.text('Ghana'), findsOneWidget);
    await tester.tap(find.byKey(const Key('country-field')));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Nigeria');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nigeria').last);
    await tester.pumpAndSettle();
    expect(selected, 'Nigeria');
  });

  testWidgets('disabled field does not open the picker and renders its error', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: CountryField(
            label: 'Country',
            placeholder: 'Choose country',
            value: null,
            enabled: false,
            errorText: 'Country is required',
            onChanged: _unreachable,
          ),
        ),
      ),
    );
    expect(find.text('Country is required'), findsOneWidget);
    await tester.tap(find.byKey(const Key('country-field')));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNothing);
  });
}

void _unreachable(String _) => throw StateError('must not be called');
