import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/core/api/api_client.dart';
import 'package:sentinelx_mobile/core/api/wallet_models.dart';
import 'package:sentinelx_mobile/features/wallet/transactions_screen.dart';

import '../../fakes/fake_wallet_repository.dart';
import 'wallet_test_harness.dart';

List<WalletTxn> _many(String prefix, int n) => [for (var i = 0; i < n; i++) walletTxnFixture('$prefix$i', amount: 100 + i)];

Future<void> _pump(WidgetTester tester, FakeWalletRepository repo, {Locale locale = const Locale('en'), double width = 375}) =>
    pumpWallet(tester, const TransactionsScreen(), repo: repo, locale: locale, width: width);

void main() {
  testWidgets('shows the four filters and the first page of the ledger', (tester) async {
    final repo = FakeWalletRepository()..txnPages.add(WalletTxnPage(items: _many('a', 3), nextCursor: null));
    await _pump(tester, repo);
    for (final label in ['All', 'Winnings', 'Withdrawals', 'Deposits']) {
      expect(find.widgetWithText(ChoiceChip, label), findsOneWidget);
    }
    expect(find.byType(ListTile), findsNothing); // rows are WalletTxnTile, not ListTile
    expect(find.text('+₦100'), findsOneWidget);
    expect(repo.txnRequests.single, (filter: 'all', cursor: null));
  });

  testWidgets('choosing a filter fetches that filter, and each filter keeps its own list', (tester) async {
    final repo = FakeWalletRepository()
      ..txnPages.add(WalletTxnPage(items: [walletTxnFixture('a', amount: 111)], nextCursor: null))
      ..txnPages.add(WalletTxnPage(items: [walletTxnFixture('w', amount: 222)], nextCursor: null));
    await _pump(tester, repo);
    await tester.tap(find.byKey(const Key('txn-filter-winnings')));
    await tester.pumpAndSettle();
    expect(repo.txnRequests.last.filter, 'winnings');
    expect(find.text('+₦222'), findsOneWidget);
    expect(find.text('+₦111'), findsNothing);
    repo.txnPages.add(WalletTxnPage(items: [walletTxnFixture('a2', amount: 333)], nextCursor: null));
    await tester.tap(find.byKey(const Key('txn-filter-all')));
    await tester.pumpAndSettle();
    // coming back to a filter refetches it, so the ledger is fresh; the winnings rows are not shown under All
    expect(repo.txnRequests.map((r) => r.filter), ['all', 'winnings', 'all']);
    expect(find.text('+₦333'), findsOneWidget);
    expect(find.text('+₦222'), findsNothing);
  });

  testWidgets('scrolling to the end loads the next page with the cursor', (tester) async {
    final repo = FakeWalletRepository()
      ..txnPages.add(WalletTxnPage(items: _many('a', 20), nextCursor: 'c1'))
      ..txnPages.add(WalletTxnPage(items: _many('b', 5), nextCursor: null));
    await _pump(tester, repo);
    await tester.drag(find.byType(ListView), const Offset(0, -4000));
    await tester.pumpAndSettle();
    expect(repo.txnRequests.last.cursor, 'c1');
    await tester.drag(find.byType(ListView), const Offset(0, -4000));
    await tester.pumpAndSettle();
    expect(find.text('+₦104'), findsOneWidget); // last row of page 2
  });

  testWidgets('a failed load-more keeps the list and shows an inline retry that works', (tester) async {
    final repo = FakeWalletRepository()
      ..txnPages.add(WalletTxnPage(items: _many('a', 20), nextCursor: 'c1'))
      ..txnPages.add(ApiException(status: 0, code: 'network', message: 'offline'))
      ..txnPages.add(WalletTxnPage(items: _many('b', 2), nextCursor: null));
    await _pump(tester, repo);
    await tester.drag(find.byType(ListView), const Offset(0, -4000));
    await tester.pumpAndSettle();
    expect(find.text('Couldn\'t load more. Tap to retry.'), findsOneWidget);
    expect(find.text('+₦100'), findsNothing); // scrolled away, but still in the list below
    await tester.tap(find.byKey(const Key('txn-load-more-retry')));
    await tester.pumpAndSettle();
    expect(find.text('Couldn\'t load more. Tap to retry.'), findsNothing);
    expect(repo.txnRequests.last.cursor, 'c1');
  });

  testWidgets('an empty ledger shows the empty state for the filter', (tester) async {
    final repo = FakeWalletRepository(); // default: empty page
    await _pump(tester, repo);
    expect(find.text('No transactions here.'), findsOneWidget);
  });

  testWidgets('a failed first load shows a retry that refetches', (tester) async {
    final repo = FakeWalletRepository()
      ..txnPages.add(ApiException(status: 0, code: 'network', message: 'offline'))
      ..txnPages.add(WalletTxnPage(items: [walletTxnFixture('a', amount: 777)], nextCursor: null));
    await _pump(tester, repo);
    expect(find.text("Couldn't load your wallet."), findsOneWidget);
    await tester.tap(find.byKey(const Key('txn-retry')));
    await tester.pumpAndSettle();
    expect(find.text('+₦777'), findsOneWidget);
  });

  testWidgets('pull to refresh refetches the first page', (tester) async {
    final repo = FakeWalletRepository()
      ..txnPages.add(WalletTxnPage(items: [walletTxnFixture('a', amount: 111)], nextCursor: null))
      ..txnPages.add(WalletTxnPage(items: [walletTxnFixture('z', amount: 999)], nextCursor: null));
    await _pump(tester, repo);
    await tester.fling(find.byType(ListView), const Offset(0, 400), 1000);
    await tester.pumpAndSettle();
    expect(find.text('+₦999'), findsOneWidget);
  });

  testWidgets('pending and failed rows show a status; debits use a true minus', (tester) async {
    final repo = FakeWalletRepository()
      ..txnPages.add(WalletTxnPage(items: [
        walletTxnFixture('a', amount: -1000, type: 'withdrawal_request', category: 'withdrawal', status: 'pending'),
        walletTxnFixture('b', amount: -500, type: 'withdrawal_request', category: 'withdrawal', status: 'failed'),
      ], nextCursor: null));
    await _pump(tester, repo);
    expect(find.text('−₦1,000'), findsOneWidget);
    expect(find.text('Pending'), findsOneWidget);
    expect(find.text('Failed'), findsOneWidget);
  });

  for (final locale in const [Locale('fr'), Locale('pcm')]) {
    testWidgets('fits at 320px in ${locale.languageCode}', (tester) async {
      final repo = FakeWalletRepository()..txnPages.add(WalletTxnPage(items: _many('a', 6), nextCursor: null));
      await _pump(tester, repo, locale: locale, width: 320);
      expect(tester.takeException(), isNull);
    });
  }
}
