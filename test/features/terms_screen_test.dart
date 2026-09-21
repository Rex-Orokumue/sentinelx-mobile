import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/core/l10n/gen/app_localizations.dart';
import 'package:sentinelx_mobile/features/static/terms_screen.dart';

void main() {
  testWidgets('renders the title and the leading section headings', (tester) async {
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const TermsScreen(),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Terms of Service'), findsWidgets);
    expect(find.textContaining('Who We Are'), findsOneWidget);
    expect(find.textContaining('Eligibility'), findsOneWidget);
  });

  testWidgets('never renders raw next-intl rich-text tags', (tester) async {
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const TermsScreen(),
    ));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.textContaining('15.'), 500, scrollable: find.byType(Scrollable));
    expect(find.textContaining(RegExp(r'</?(email|link|whatsapp)>')), findsNothing);
  });
}
