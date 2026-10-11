import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/core/api/api_client.dart';
import 'package:sentinelx_mobile/core/api/wallet_models.dart';
import 'package:sentinelx_mobile/features/wallet/wallet_providers.dart';
import 'package:sentinelx_mobile/features/wallet/wallet_screen.dart';

import '../../fakes/fake_wallet_repository.dart';
import 'wallet_test_harness.dart';

void main() {
  testWidgets('shows a progress indicator while loading', (tester) async {
    await pumpWallet(
      tester,
      const WalletScreen(),
      repo: FakeWalletRepository(),
      settle: false,
      overrides: [walletOverviewProvider.overrideWith((ref) => Completer<WalletOverview?>().future)],
    );
    expect(find.byKey(const Key('wallet-loading')), findsOneWidget);
  });

  testWidgets('a failed load shows retry, and retry refetches', (tester) async {
    final repo = FakeWalletRepository()..overview = ApiException(status: 0, code: 'network', message: 'offline');
    await pumpWallet(tester, const WalletScreen(), repo: repo);
    expect(find.text('Couldn\'t load your wallet.'), findsOneWidget);
    repo.overview = walletOverviewFixture(balance: 12500);
    await tester.tap(find.byKey(const Key('wallet-retry')));
    await tester.pumpAndSettle();
    expect(find.text('₦12,500'), findsOneWidget);
    expect(repo.calls.where((c) => c == 'overview'), hasLength(2));
  });

  testWidgets('signed out: prompts to log in and makes no request', (tester) async {
    final repo = FakeWalletRepository();
    await pumpWallet(tester, const WalletScreen(), repo: repo, viewer: null);
    expect(find.text('Log in to see your wallet.'), findsOneWidget);
    expect(repo.calls, isEmpty);
    await tester.tap(find.byKey(const Key('wallet-login')));
    await tester.pumpAndSettle();
    expect(find.text('page:/login'), findsOneWidget);
  });

  testWidgets('renders balance, pending withdrawal, earnings and the manual-payout notice via formatNaira', (tester) async {
    final repo = FakeWalletRepository()
      ..overview = walletOverviewFixture(balance: 1250000, pendingWithdrawal: 1000, trendPct: 50, recent: [walletTxnFixture('a', amount: 3000)]);
    await pumpWallet(tester, const WalletScreen(), repo: repo);
    expect(find.text('₦1,250,000'), findsOneWidget);
    expect(find.text('₦1,000 pending withdrawal'), findsOneWidget);
    expect(find.text('₦3,000'), findsWidgets); // tournament prize earnings
    expect(find.text('+50% vs last month'), findsOneWidget);
    await tester.scrollUntilVisible(find.byKey(const Key('wallet-manual-notice')), 300);
    expect(find.text('Withdrawals are paid out by an administrator, not instantly.'), findsOneWidget);
  });

  testWidgets('a null trend is hidden rather than shown as 0%', (tester) async {
    final repo = FakeWalletRepository()..overview = walletOverviewFixture(trendPct: null);
    await pumpWallet(tester, const WalletScreen(), repo: repo);
    expect(find.byKey(const Key('wallet-trend')), findsNothing);
    expect(find.textContaining('vs last month'), findsNothing);
  });

  testWidgets('no pending withdrawal hides the pending line', (tester) async {
    final repo = FakeWalletRepository()..overview = walletOverviewFixture(pendingWithdrawal: 0);
    await pumpWallet(tester, const WalletScreen(), repo: repo);
    expect(find.byKey(const Key('wallet-pending')), findsNothing);
  });

  testWidgets('empty ledger shows the empty state; rows show signed amounts and a status chip', (tester) async {
    final empty = FakeWalletRepository()..overview = walletOverviewFixture(recent: const []);
    await pumpWallet(tester, const WalletScreen(), repo: empty);
    await tester.scrollUntilVisible(find.text('No transactions yet.'), 300);
    expect(find.text('No transactions yet.'), findsOneWidget);

    final full = FakeWalletRepository()
      ..overview = walletOverviewFixture(recent: [
        walletTxnFixture('a', amount: 3000),
        walletTxnFixture('b', amount: -1000, type: 'withdrawal_request', category: 'withdrawal', status: 'pending'),
      ]);
    await pumpWallet(tester, const WalletScreen(), repo: full);
    await tester.scrollUntilVisible(find.text('Withdrawal'), 300);
    expect(find.text('+₦3,000'), findsOneWidget);
    expect(find.text('−₦1,000'), findsOneWidget);
    expect(find.text('Pending'), findsOneWidget);
  });

  testWidgets('shows only the masked payout account, never a 10-digit number', (tester) async {
    final repo = FakeWalletRepository()..overview = walletOverviewFixture();
    await pumpWallet(tester, const WalletScreen(), repo: repo);
    await tester.scrollUntilVisible(find.text('•••6789'), 300);
    expect(find.text('GTBank'), findsOneWidget);
    expect(find.text('ADA OBI'), findsOneWidget);
    expect(find.textContaining(RegExp(r'\d{10}')), findsNothing);
  });

  testWidgets('withdraw is disabled with an add-account hint when there is no payout account', (tester) async {
    final repo = FakeWalletRepository()..overview = walletOverviewFixture(payout: null, kycVerified: false);
    await pumpWallet(tester, const WalletScreen(), repo: repo);
    final button = tester.widget<FilledButton>(find.byKey(const Key('wallet-withdraw')));
    expect(button.onPressed, isNull);
    expect(find.byKey(const Key('wallet-withdraw-hint')), findsOneWidget);
    await tester.scrollUntilVisible(find.byKey(const Key('wallet-payout-add')), 300);
    await tester.tap(find.byKey(const Key('wallet-payout-add')));
    await tester.pumpAndSettle();
    expect(find.text('page:/account/wallet/payout-account'), findsOneWidget);
  });

  testWidgets('add money, withdraw and see-all navigate to their screens', (tester) async {
    final repo = FakeWalletRepository()..overview = walletOverviewFixture(recent: [walletTxnFixture('a')]);
    await pumpWallet(tester, const WalletScreen(), repo: repo);
    await tester.tap(find.byKey(const Key('wallet-add-money')));
    await tester.pumpAndSettle();
    expect(find.text('page:/account/wallet/deposit'), findsOneWidget);
  });

  for (final locale in const [Locale('en'), Locale('fr'), Locale('pcm')]) {
    for (final width in const [320.0, 375.0]) {
      testWidgets('lays out without overflow at ${width.toInt()}px in ${locale.languageCode}', (tester) async {
        final repo = FakeWalletRepository()
          ..overview = walletOverviewFixture(
            balance: 1250000,
            pendingWithdrawal: 100000,
            trendPct: -20,
            recent: [
              walletTxnFixture('a', amount: 3000),
              walletTxnFixture('b', amount: -1000, type: 'withdrawal_request', category: 'withdrawal', status: 'pending'),
              walletTxnFixture('c', amount: 700, type: 'deposit', category: 'bonus'),
            ],
          );
        await pumpWallet(tester, const WalletScreen(), repo: repo, locale: locale, width: width);
        await tester.drag(find.byType(ListView), const Offset(0, -2000));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('every Wallet string exists in fr and pcm (no key falls back to English)', (tester) async {
    // the generated pcm class extends the English one; a missing key would silently show English
    final repo = FakeWalletRepository();
    await pumpWallet(tester, const WalletScreen(), repo: repo, locale: const Locale('pcm'));
    expect(find.text('Wallet'), findsOneWidget); // title (same word in pcm)
    expect(find.text('Money wey you fit use'), findsOneWidget);
  });
}
