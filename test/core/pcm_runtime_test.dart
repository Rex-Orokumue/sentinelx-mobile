import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:sentinelx_mobile/core/l10n/fallback_delegates.dart';
import 'package:sentinelx_mobile/core/l10n/gen/app_localizations.dart';
import 'package:sentinelx_mobile/core/utils/date_locale.dart';

void main() {
  // The app's Material delegate initialises date data for the locales it loads; do the same here.
  setUpAll(() => initializeDateFormatting('fr'));

  test('dateLocale never throws, even before any date data is initialised', () {
    // A fresh isolate state is not available inside this file, so assert the contract on the unknowable case.
    expect(() => dateLocale('xx'), returnsNormally);
  });

  test('dateLocale keeps locales intl knows and falls back to English for Pidgin', () {
    expect(dateLocale('en'), 'en');
    expect(dateLocale('fr'), 'fr');
    expect(dateLocale('pcm'), 'en');
    // The point of the helper: the unguarded call throws.
    expect(() => DateFormat.yMMMd('pcm'), throwsA(anything));
    expect(DateFormat.yMMMd(dateLocale('pcm')).format(DateTime.utc(2026, 10, 7)), isNotEmpty);
  });

  test('numberLocale keeps French grouping and falls back to English for Pidgin', () {
    expect(numberLocale('fr'), 'fr');
    expect(numberLocale('pcm'), 'en');
    expect(NumberFormat.decimalPattern(numberLocale('fr')).format(5000), NumberFormat.decimalPattern('fr').format(5000));
    expect(NumberFormat.decimalPattern(numberLocale('pcm')).format(5000), '5,000');
  });

  testWidgets('a Pidgin app builds Material widgets and reads Pidgin strings', (tester) async {
    late AppLocalizations l10n;
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('pcm'),
      localizationsDelegates: appLocalizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(builder: (context) {
        l10n = AppLocalizations.of(context);
        return const Scaffold(body: TextField());
      }),
    ));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(l10n.localeName, 'pcm');
  });

  testWidgets('a locale with no delegate support still gets framework strings in English', (tester) async {
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('pcm'),
      localizationsDelegates: appLocalizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(builder: (context) {
        expect(MaterialLocalizations.of(context).okButtonLabel, 'OK');
        return const SizedBox();
      }),
    ));
    await tester.pumpAndSettle();
  });

  testWidgets('WITHOUT the fallback delegates a Pidgin app cannot build a TextField (why the wrapper exists)', (tester) async {
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('pcm'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const Scaffold(body: TextField()),
    ));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNotNull);
  });
}
