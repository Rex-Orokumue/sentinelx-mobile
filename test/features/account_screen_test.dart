import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/core/api/models.dart';
import 'package:sentinelx_mobile/core/l10n/gen/app_localizations.dart';
import 'package:sentinelx_mobile/core/providers.dart';
import 'package:sentinelx_mobile/features/account/account_screen.dart';

void main() {
  testWidgets('signed out: shows log in and create account actions', (tester) async {
    var loginTapped = false;
    await tester.pumpWidget(ProviderScope(
      retry: (_, _) => null,
      overrides: [meProvider.overrideWith((ref) async => null)],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: AccountScreen(onLogIn: () => loginTapped = true, onSignUp: () {}, onLogoTap: () {}, onOpenProgress: () {})),
    ));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('account-login')), findsOneWidget);
    await tester.tap(find.byKey(const Key('account-login')));
    expect(loginTapped, isTrue);
  });

  testWidgets('signed in: shows the display name and a sign-out action', (tester) async {
    final me = MeResponse(
      id: 'u1', email: 'a@b.com', roles: const [], isStaff: false, isAdmin: false,
      profile: const MeProfile(
        username: 'ada', displayName: 'Ada', avatarUrl: null, whatsappNumber: null, country: null,
        locale: 'en', membershipTier: null, kycVerified: false, deletionRequestedAt: null,
      ),
    );
    await tester.pumpWidget(ProviderScope(
      retry: (_, _) => null,
      overrides: [meProvider.overrideWith((ref) async => me)],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: AccountScreen(onLogIn: () {}, onSignUp: () {}, onLogoTap: () {}, onOpenProgress: () {})),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Ada'), findsOneWidget);
    expect(find.byKey(const Key('account-sign-out')), findsOneWidget);
  });

  Widget accountApp(MeResponse? me, VoidCallback onOpenProgress) => ProviderScope(
        retry: (_, _) => null,
        overrides: [meProvider.overrideWith((ref) async => me)],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: AccountScreen(onLogIn: () {}, onSignUp: () {}, onLogoTap: () {}, onOpenProgress: onOpenProgress),
        ),
      );

  testWidgets('signed in: the My progress tile opens progress', (tester) async {
    var opened = 0;
    const me = MeResponse(id: 'u1', email: 'a@b.com', roles: [], isStaff: false, isAdmin: false, profile: null);
    await tester.pumpWidget(accountApp(me, () => opened++));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('account-progress')));
    expect(opened, 1);
  });

  testWidgets('signed out: there is no My progress tile', (tester) async {
    await tester.pumpWidget(accountApp(null, () {}));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('account-progress')), findsNothing);
  });
}
