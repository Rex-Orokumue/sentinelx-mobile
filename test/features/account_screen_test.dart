import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/core/api/models.dart';
import 'package:sentinelx_mobile/core/providers.dart';
import 'package:sentinelx_mobile/features/account/account_screen.dart';

void main() {
  testWidgets('signed out: shows log in and create account actions', (tester) async {
    var loginTapped = false;
    await tester.pumpWidget(ProviderScope(
      retry: (_, _) => null,
      overrides: [meProvider.overrideWith((ref) async => null)],
      child: MaterialApp(home: AccountScreen(onLogIn: () => loginTapped = true, onSignUp: () {}, onLogoTap: () {})),
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
      child: MaterialApp(home: AccountScreen(onLogIn: () {}, onSignUp: () {}, onLogoTap: () {})),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Ada'), findsOneWidget);
    expect(find.byKey(const Key('account-sign-out')), findsOneWidget);
  });
}
