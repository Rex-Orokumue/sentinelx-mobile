import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/core/api/models.dart';
import 'package:sentinelx_mobile/core/auth/auth_providers.dart';
import 'package:sentinelx_mobile/core/auth/auth_repository.dart';
import 'package:sentinelx_mobile/core/l10n/gen/app_localizations.dart';
import 'package:sentinelx_mobile/core/notifications/push/push_registration.dart';
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
  testWidgets('loading: shows progress without authentication actions', (tester) async {
    final pending = Completer<MeResponse?>();
    addTearDown(() {
      if (!pending.isCompleted) pending.complete(null);
    });
    await tester.pumpWidget(_app(
      [meProvider.overrideWith((ref) => pending.future)],
      AccountScreen(onLogIn: () {}, onSignUp: () {}, onLogoTap: () {}),
    ));
    await tester.pump();
    expect(find.byKey(const Key('account-loading')), findsOneWidget);
    expect(find.byKey(const Key('account-login')), findsNothing);
    expect(find.byKey(const Key('account-signup')), findsNothing);
  });

  testWidgets('load failure: shows retry without authentication actions', (tester) async {
    await tester.pumpWidget(_app(
      [meProvider.overrideWith((ref) async => throw Exception('boom'))],
      AccountScreen(onLogIn: () {}, onSignUp: () {}, onLogoTap: () {}),
    ));
    await tester.pumpAndSettle();
    expect(find.text("Couldn't load your account."), findsOneWidget);
    expect(find.byKey(const Key('account-retry')), findsOneWidget);
    expect(find.byKey(const Key('account-login')), findsNothing);
    expect(find.byKey(const Key('account-signup')), findsNothing);
  });

  testWidgets('load failure: retry refetches and shows the account', (tester) async {
    var attempts = 0;
    await tester.pumpWidget(_app(
      [
        meProvider.overrideWith((ref) async {
          attempts++;
          if (attempts == 1) throw Exception('boom');
          return _me();
        }),
      ],
      AccountScreen(onLogIn: () {}, onSignUp: () {}, onLogoTap: () {}),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('account-retry')));
    await tester.pumpAndSettle();
    expect(attempts, 2);
    expect(find.text('Ada'), findsOneWidget);
    expect(find.byKey(const Key('account-sign-out')), findsOneWidget);
  });

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

  testWidgets('signed in with onEditProfile: shows the Edit profile tile and reports the tap', (tester) async {
    var tapped = false;
    await tester.pumpWidget(_app(
      [meProvider.overrideWith((ref) async => _me())],
      AccountScreen(onLogIn: () {}, onSignUp: () {}, onLogoTap: () {}, onEditProfile: () => tapped = true),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('account-edit-profile')));
    expect(tapped, isTrue);
  });

  testWidgets('signed out: no Edit profile tile even if a handler is supplied', (tester) async {
    await tester.pumpWidget(_app(
      [meProvider.overrideWith((ref) async => null)],
      AccountScreen(onLogIn: () {}, onSignUp: () {}, onLogoTap: () {}, onEditProfile: () {}),
    ));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('account-edit-profile')), findsNothing);
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

  testWidgets('sign-out unregisters this device BEFORE clearing the session', (tester) async {
    final log = <String>[];
    await tester.pumpWidget(_app(
      [
        meProvider.overrideWith((ref) async => _me()),
        authRepositoryProvider.overrideWithValue(_RecordingSignOutRepository(log)),
        pushRegistrationProvider.overrideWithValue(_FakePushRegistration(log)),
      ],
      AccountScreen(onLogIn: () {}, onSignUp: () {}, onLogoTap: () {}),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('account-sign-out')));
    await tester.pumpAndSettle();
    expect(log, ['unregister', 'signOut']);
  });

  testWidgets('a failing device unregister never blocks sign-out and shows no error', (tester) async {
    final log = <String>[];
    await tester.pumpWidget(_app(
      [
        meProvider.overrideWith((ref) async => _me()),
        authRepositoryProvider.overrideWithValue(_RecordingSignOutRepository(log)),
        pushRegistrationProvider.overrideWithValue(_FakePushRegistration(log, throwOnUnregister: true)),
      ],
      AccountScreen(onLogIn: () {}, onSignUp: () {}, onLogoTap: () {}),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('account-sign-out')));
    await tester.pumpAndSettle();
    expect(log, ['unregister', 'signOut']);
    expect(find.text('Could not sign out. Please try again.'), findsNothing);
  });

  testWidgets('when sign-out itself fails the device is registered again', (tester) async {
    final log = <String>[];
    await tester.pumpWidget(_app(
      [
        meProvider.overrideWith((ref) async => _me()),
        authRepositoryProvider.overrideWithValue(_RecordingSignOutRepository(log, fail: true)),
        pushRegistrationProvider.overrideWithValue(_FakePushRegistration(log)),
      ],
      AccountScreen(onLogIn: () {}, onSignUp: () {}, onLogoTap: () {}),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('account-sign-out')));
    await tester.pumpAndSettle();
    expect(log, ['unregister', 'signOut', 'reregister']);
    expect(find.text('Could not sign out. Please try again.'), findsOneWidget);
  });

  testWidgets('signed in: the My progress tile opens progress', (tester) async {
    var opened = 0;
    await tester.pumpWidget(_app(
      [meProvider.overrideWith((ref) async => _me())],
      AccountScreen(onLogIn: () {}, onSignUp: () {}, onLogoTap: () {}, onOpenProgress: () => opened++),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('account-progress')));
    expect(opened, 1);
  });

  testWidgets('signed in: the Notifications tile opens notification settings', (tester) async {
    var opened = 0;
    await tester.pumpWidget(_app(
      [meProvider.overrideWith((ref) async => _me())],
      AccountScreen(onLogIn: () {}, onSignUp: () {}, onLogoTap: () {}, onOpenNotifications: () => opened++),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('account-notifications')));
    expect(opened, 1);
  });

  testWidgets('signed out: there is no Notifications tile', (tester) async {
    await tester.pumpWidget(_app(
      [meProvider.overrideWith((ref) async => null)],
      AccountScreen(onLogIn: () {}, onSignUp: () {}, onLogoTap: () {}, onOpenNotifications: () {}),
    ));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('account-notifications')), findsNothing);
  });

  testWidgets('signed out: there is no My progress tile', (tester) async {
    await tester.pumpWidget(_app(
      [meProvider.overrideWith((ref) async => null)],
      AccountScreen(onLogIn: () {}, onSignUp: () {}, onLogoTap: () {}, onOpenProgress: () {}),
    ));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('account-progress')), findsNothing);
  });
}

class _FakePushRegistration implements PushRegistration {
  _FakePushRegistration(this.log, {this.throwOnUnregister = false});
  final List<String> log;
  final bool throwOnUnregister;

  @override
  Future<void> unregister() async {
    log.add('unregister');
    if (throwOnUnregister) throw StateError('device call blew up');
  }

  @override
  Future<void> reregister() async => log.add('reregister');

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _RecordingSignOutRepository extends _FailingSignOutRepository {
  _RecordingSignOutRepository(this.log, {this.fail = false});
  final List<String> log;
  final bool fail;

  @override
  Future<void> signOut() async {
    log.add('signOut');
    if (fail) throw Exception('boom');
  }
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
