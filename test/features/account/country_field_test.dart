import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:country_picker/country_picker.dart';
import 'package:sentinelx_mobile/features/account/country_field.dart';

void main() {
  test(
    'canonicalizes every picker label known to differ from the web contract',
    () {
      const expected = <String, String>{
        'AG': 'Antigua & Barbuda',
        'BA': 'Bosnia & Herzegovina',
        'CD': 'Congo - Kinshasa',
        'CG': 'Congo - Brazzaville',
        'CZ': 'Czechia',
        'TL': 'Timor-Leste',
        'FK': 'Falkland Islands',
        'GN': 'Guinea',
        'HK': 'Hong Kong SAR China',
        'MO': 'Macao SAR China',
        'BL': 'St. Barthélemy',
        'SH': 'St. Helena',
        'KN': 'St. Kitts & Nevis',
        'MF': 'St. Martin',
        'PM': 'St. Pierre & Miquelon',
        'VC': 'St. Vincent & Grenadines',
        'ST': 'São Tomé & Príncipe',
        'SJ': 'Svalbard & Jan Mayen',
        'TR': 'Türkiye',
        'TC': 'Turks & Caicos Islands',
        'WF': 'Wallis & Futuna',
      };

      for (final entry in expected.entries) {
        expect(
          canonicalCountryName(Country.parse(entry.key)),
          entry.value,
          reason: entry.key,
        );
      }
    },
  );

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

  testWidgets('submits the web canonical name when the picker label differs', (
    tester,
  ) async {
    String? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CountryField(
            label: 'Country',
            placeholder: 'Choose country',
            value: null,
            onChanged: (value) => selected = value,
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('country-field')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Turkey');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Turkey').last);
    await tester.pumpAndSettle();

    expect(selected, 'Türkiye');
  });

  testWidgets('does not offer regions unsupported by server phone validation', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: CountryField(
            label: 'Country',
            placeholder: 'Choose country',
            value: null,
            onChanged: _unreachable,
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('country-field')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextField),
      'Heard Island and McDonald Islands',
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Heard Island and McDonald Islands'),
      findsOneWidget,
      reason:
          'only the search input contains the query; no country row remains',
    );
  });
}

void _unreachable(String _) => throw StateError('must not be called');
