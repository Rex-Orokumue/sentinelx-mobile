import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/core/api/models.dart';
import 'package:sentinelx_mobile/core/l10n/gen/app_localizations.dart';
import 'package:sentinelx_mobile/core/providers.dart';
import 'package:sentinelx_mobile/features/account/account_screen.dart';

MeResponse _me() => MeResponse(
      id: 'u1', email: 'a@b.com', roles: const [], isStaff: false, isAdmin: false,
      profile: MeProfile(
        username: 'ada', displayName: 'Ada', avatarUrl: null, whatsappNumber: null, country: null, locale: 'en',
        membershipTier: null, kycVerified: false, deletionRequestedAt: null,
      ),
    );

void main() {
  testWidgets('the signed-in hub offers every settings destination and scrolls on a small phone', (tester) async {
    tester.view.physicalSize = const Size(320, 480);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final opened = <String>[];
    await tester.pumpWidget(ProviderScope(
      retry: (_, _) => null,
      overrides: [meProvider.overrideWith((ref) async => _me())],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: AccountScreen(
          onLogIn: () {},
          onSignUp: () {},
          onLogoTap: () {},
          onEditProfile: () => opened.add('profile'),
          onOpenNotifications: () => opened.add('notifications'),
          onOpenLanguage: () => opened.add('language'),
          onOpenSecurity: () => opened.add('security'),
          onOpenSignInMethods: () => opened.add('sign-in-methods'),
          onOpenPhone: () => opened.add('phone'),
          onOpenDeleteAccount: () => opened.add('delete'),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull); // no overflow on a 320x480 screen

    for (final (key, name) in [
      ('account-language', 'language'),
      ('account-security', 'security'),
      ('account-sign-in-methods', 'sign-in-methods'),
      ('account-phone', 'phone'),
      ('account-delete', 'delete'),
    ]) {
      await tester.ensureVisible(find.byKey(Key(key)));
      await tester.tap(find.byKey(Key(key)));
      await tester.pump();
      expect(opened.last, name);
    }
  });
}
