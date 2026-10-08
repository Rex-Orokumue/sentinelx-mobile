import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sentinelx_mobile/core/api/account_models.dart';
import 'package:sentinelx_mobile/core/api/api_client.dart';
import 'package:sentinelx_mobile/core/api/models.dart';
import 'package:sentinelx_mobile/core/auth/auth_providers.dart';
import 'package:sentinelx_mobile/core/auth/auth_repository.dart';
import 'package:sentinelx_mobile/core/l10n/gen/app_localizations.dart';
import 'package:sentinelx_mobile/core/providers.dart';
import 'package:sentinelx_mobile/features/account/settings/account_repository.dart';
import 'package:sentinelx_mobile/features/account/settings/delete_account_screen.dart';

import '../../../fakes/fake_account_repository.dart';

class _FakeAuth implements AuthRepository {
  int signOuts = 0;
  Object? signOutError;
  @override
  Future<void> signOut() async {
    signOuts++;
    if (signOutError != null) throw signOutError!;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

MeResponse _me({String? deletionRequestedAt}) => MeResponse(
      id: 'u1', email: 'a@b.com', roles: const [], isStaff: false, isAdmin: false,
      profile: MeProfile(
        username: 'Rex', displayName: 'Rex', avatarUrl: null, whatsappNumber: null, country: null, locale: 'en',
        membershipTier: null, kycVerified: false, deletionRequestedAt: deletionRequestedAt,
      ),
    );

Future<AppLocalizations> _pump(WidgetTester tester, FakeAccountRepository repo, _FakeAuth auth, {MeResponse? me}) async {
  tester.view.physicalSize = const Size(375, 1200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final router = GoRouter(routes: [
    GoRoute(path: '/', builder: (_, _) => const DeleteAccountScreen()),
    GoRoute(path: '/login', builder: (_, _) => const Scaffold(body: Text('LOGIN PAGE'))),
  ]);
  await tester.pumpWidget(ProviderScope(
    retry: (_, _) => null,
    overrides: [
      accountRepositoryProvider.overrideWithValue(repo),
      authRepositoryProvider.overrideWithValue(auth),
      viewerIdProvider.overrideWith((ref) async => 'u1'),
      meProvider.overrideWith((ref) async => me ?? _me()),
    ],
    child: MaterialApp.router(
      routerConfig: router,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    ),
  ));
  await tester.pumpAndSettle();
  return AppLocalizations.of(tester.element(find.byType(DeleteAccountScreen)));
}

void main() {
  testWidgets('not pending: scheduling needs the literal DELETE', (tester) async {
    final repo = FakeAccountRepository();
    await _pump(tester, repo, _FakeAuth());
    await tester.ensureVisible(find.byKey(const Key('delete-schedule')));
    await tester.enterText(find.byKey(const Key('delete-confirm-field')), 'delete');
    await tester.tap(find.byKey(const Key('delete-schedule')));
    await tester.pumpAndSettle();
    expect(repo.calls.where((c) => c == 'requestDeletion'), isEmpty);

    await tester.enterText(find.byKey(const Key('delete-confirm-field')), 'DELETE');
    await tester.pump();
    repo.accountResult = testAccount(
      deletion: DeletionState(requestedAt: DateTime.utc(2026, 10, 7), dueAt: DateTime.utc(2026, 10, 22), daysRemaining: 15),
    );
    await tester.tap(find.byKey(const Key('delete-schedule')));
    await tester.pumpAndSettle();
    expect(repo.calls, contains('requestDeletion'));
    expect(find.byKey(const Key('delete-pending')), findsOneWidget); // refreshed into the pending state
  });

  testWidgets('blockers are listed with their copy and nothing is scheduled', (tester) async {
    final repo = FakeAccountRepository()
      ..deletionError = const ApiException(
        status: 409,
        code: 'deletion_blocked',
        message: 'x',
        details: {
          'blockers': [
            {'code': 'wallet_balance', 'amount': 5000},
            {'code': 'pending_withdrawal', 'count': 2},
            {'code': 'brand_new_blocker', 'count': 1},
          ],
        },
      );
    final l10n = await _pump(tester, repo, _FakeAuth());
    await tester.ensureVisible(find.byKey(const Key('delete-schedule')));
    await tester.enterText(find.byKey(const Key('delete-confirm-field')), 'DELETE');
    await tester.pump();
    await tester.tap(find.byKey(const Key('delete-schedule')));
    await tester.pumpAndSettle();
    expect(find.text(l10n.accountDeletionBlockedTitle), findsOneWidget);
    expect(find.text(l10n.accountDeletionBlockerWalletBalance('₦5,000')), findsOneWidget);
    expect(find.text(l10n.accountDeletionBlockerWithdrawal('2')), findsOneWidget);
    expect(find.byKey(const Key('blocker-unknown')), findsOneWidget); // an unknown code still gets a line
  });

  testWidgets('pending: shows the countdown and Cancel deletion cancels', (tester) async {
    final repo = FakeAccountRepository()
      ..accountResult = testAccount(
        deletion: DeletionState(requestedAt: DateTime.utc(2026, 10, 5), dueAt: DateTime.utc(2026, 10, 20), daysRemaining: 13),
      );
    await _pump(tester, repo, _FakeAuth(), me: _me(deletionRequestedAt: '2026-10-05T00:00:00.000Z'));
    expect(find.byKey(const Key('delete-pending')), findsOneWidget);
    repo.accountResult = testAccount();
    await tester.tap(find.byKey(const Key('delete-cancel')));
    await tester.pumpAndSettle();
    expect(repo.calls, contains('cancelDeletion'));
    expect(find.byKey(const Key('delete-schedule')), findsOneWidget);
  });

  testWidgets('delete now: wrong username is refused client-side, the right one deletes, signs out and goes to login', (tester) async {
    final repo = FakeAccountRepository();
    final auth = _FakeAuth();
    await _pump(tester, repo, auth);
    await tester.ensureVisible(find.byKey(const Key('delete-now-field')));
    await tester.enterText(find.byKey(const Key('delete-now-field')), 'someone');
    await tester.tap(find.byKey(const Key('delete-now')));
    await tester.pumpAndSettle();
    expect(repo.calls.where((c) => c == 'deleteNow'), isEmpty);

    await tester.enterText(find.byKey(const Key('delete-now-field')), '  rex ');
    await tester.tap(find.byKey(const Key('delete-now')));
    await tester.pumpAndSettle();
    expect(repo.lastUsername, 'rex');
    expect(auth.signOuts, 1);
    expect(find.text('LOGIN PAGE'), findsOneWidget);
  });

  testWidgets('delete now still ends on login when signOut itself fails (the auth user is already gone)', (tester) async {
    final repo = FakeAccountRepository();
    final auth = _FakeAuth()..signOutError = StateError('401');
    await _pump(tester, repo, auth);
    await tester.ensureVisible(find.byKey(const Key('delete-now-field')));
    await tester.enterText(find.byKey(const Key('delete-now-field')), 'Rex');
    await tester.tap(find.byKey(const Key('delete-now')));
    await tester.pumpAndSettle();
    expect(find.text('LOGIN PAGE'), findsOneWidget);
  });

  testWidgets('delete now blocked: stays signed in and lists the blockers', (tester) async {
    final repo = FakeAccountRepository()
      ..deleteNowError = const ApiException(status: 409, code: 'deletion_blocked', message: 'x', details: {
        'blockers': [{'code': 'active_listing', 'count': 1}],
      });
    final auth = _FakeAuth();
    final l10n = await _pump(tester, repo, auth);
    await tester.ensureVisible(find.byKey(const Key('delete-now-field')));
    await tester.enterText(find.byKey(const Key('delete-now-field')), 'Rex');
    await tester.tap(find.byKey(const Key('delete-now')));
    await tester.pumpAndSettle();
    expect(auth.signOuts, 0);
    expect(find.text(l10n.accountDeletionBlockerListing('1')), findsOneWidget);
    expect(find.text('LOGIN PAGE'), findsNothing);
  });
}
