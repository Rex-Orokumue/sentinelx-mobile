import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sentinelx_mobile/core/api/models.dart';
import 'package:sentinelx_mobile/core/providers.dart';
import 'package:sentinelx_mobile/features/account/account_screen.dart';
import 'package:sentinelx_mobile/features/wallet/deposit_screen.dart';
import 'package:sentinelx_mobile/features/wallet/payout_account_screen.dart';
import 'package:sentinelx_mobile/features/wallet/transactions_screen.dart';
import 'package:sentinelx_mobile/features/wallet/wallet_providers.dart';
import 'package:sentinelx_mobile/features/wallet/wallet_screen.dart';
import 'package:sentinelx_mobile/features/wallet/withdraw_screen.dart';

import '../fakes/fake_wallet_repository.dart';
import '../support/pump_app.dart';

MeResponse _staff() => const MeResponse(id: 'u1', email: 'm@test.dev', roles: ['moderator'], isStaff: true, isAdmin: false, profile: null);

Future<void> _open(WidgetTester tester, String location, {bool signedOut = false, MeResponse? me}) async {
  final repo = FakeWalletRepository();
  await pumpRouterWithRepo(tester, initialLocation: location, me: me, signedOut: signedOut, overrides: [
    viewerIdProvider.overrideWith((ref) async => signedOut ? null : 'u1'),
    walletRepositoryProvider.overrideWithValue(repo),
  ]);
  await tester.pumpAndSettle();
}

void main() {
  for (final entry in {
    '/account/wallet': WalletScreen,
    '/account/wallet/deposit': DepositScreen,
    '/account/wallet/withdraw': WithdrawScreen,
    '/account/wallet/transactions': TransactionsScreen,
    '/account/wallet/payout-account': PayoutAccountScreen,
  }.entries) {
    testWidgets('${entry.key} opens ${entry.value} for a player', (tester) async {
      await _open(tester, entry.key);
      expect(find.byType(entry.value), findsOneWidget);
    });
  }

  testWidgets('a signed-out visitor to any wallet route sees the log-in prompt, not a wallet screen', (tester) async {
    await _open(tester, '/account/wallet/deposit', signedOut: true);
    expect(find.byKey(const Key('wallet-gate-login')), findsOneWidget);
    expect(find.byType(DepositScreen), findsNothing);
  });

  testWidgets('a moderator is sent back to the Account tab and never sees a wallet screen', (tester) async {
    await _open(tester, '/account/wallet', me: _staff());
    expect(find.byType(WalletScreen), findsNothing);
    expect(find.byType(AccountScreen), findsOneWidget);
    final router = GoRouter.of(tester.element(find.byType(AccountScreen)));
    expect(router.routerDelegate.currentConfiguration.last.matchedLocation, '/account');
  });

  testWidgets('the Account hub opens the wallet for a player', (tester) async {
    await _open(tester, '/account');
    await tester.tap(find.byKey(const Key('account-wallet')));
    await tester.pumpAndSettle();
    expect(find.byType(WalletScreen), findsOneWidget);
  });

  testWidgets('a web wallet link resolves to the in-app wallet route', (tester) async {
    await _open(tester, 'https://sentinelxesports.com.ng/dashboard/wallet/transactions');
    expect(find.byType(TransactionsScreen), findsOneWidget);
  });
}
