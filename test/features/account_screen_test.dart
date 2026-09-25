import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/core/api/models.dart';
import 'package:sentinelx_mobile/core/auth/auth_providers.dart';
import 'package:sentinelx_mobile/core/auth/auth_repository.dart';
import 'package:sentinelx_mobile/core/l10n/gen/app_localizations.dart';
import 'package:sentinelx_mobile/core/providers.dart';
import 'package:sentinelx_mobile/features/account/account_screen.dart';

MeResponse _me() => MeResponse(
      id: 'u1', email: 'a@b.com', roles: const [], isStaff: false, isAdmin: false,
      profile: const MeProfile(
        username: 'ada', displayName: 'Ada', avatarUrl: null, whatsappNumber: null, country: null,
        locale: 'en', membershipTier: null, kycVerified: false, deletionRequestedAt: null,
      ),
    );

Widget _app(List<Override> overrides, AccountScreen screen) => ProviderScope(
      retry: (_, _) => null,
      overrides: overrides,
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: screen,
      ),
    );

void main() {
  testWidgets('signed out: shows log in and create account actions', (tester) async {
    var loginTapped = false;
    await tester.pumpWidget(_app(
      [meProvider.overrideWith((ref) async => null)],
      AccountScreen(onLogIn: () => loginTapped = true, onSignUp: () {}, onLogoTap: () {}),
    ));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('account-login')), findsOneWidget);
    await tester.tap(find.byKey(const Key('account-login')));
    expect(loginTapped, isTrue);
  });

  testWidgets('signed in: shows the display name and a sign-out action', (tester) async {
    await tester.pumpWidget(_app(
      [meProvider.overrideWith((ref) async => _me())],
      AccountScreen(onLogIn: () {}, onSignUp: () {}, onLogoTap: () {}),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Ada'), findsOneWidget);
    expect(find.byKey(const Key('account-sign-out')), findsOneWidget);
  });

  testWidgets('sign-out failure shows an error and re-enables the button', (tester) async {
    await tester.pumpWidget(_app(
      [
        meProvider.overrideWith((ref) async => _me()),
        authRepositoryProvider.overrideWithValue(_FailingSignOutRepository()),
      ],
      AccountScreen(onLogIn: () {}, onSignUp: () {}, onLogoTap: () {}),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('account-sign-out')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Could not sign out. Please try again.'), findsOneWidget);
    expect(tester.widget<TextButton>(find.byKey(const Key('account-sign-out'))).onPressed, isNotNull);
  });
}

class _FailingSignOutRepository implements AuthRepository {
  @override
  Future<void> signOut() async => throw Exception('boom');
  @override
  Future<void> signInWithPassword({required String email, required String password}) async {}
  @override
  Future<void> signUp({required String username, required String email, required String password, String? ref, String? locale}) async {}
  @override
  Future<void> resendConfirmation(String email) async {}
  @override
  Future<void> requestReset(String email) async {}
  @override
  Future<void> resetPassword(String newPassword) async {}
  @override
  Future<String> claimUsername(String username) async => username;
  @override
  Future<void> signInWithGoogle() async {}
}
