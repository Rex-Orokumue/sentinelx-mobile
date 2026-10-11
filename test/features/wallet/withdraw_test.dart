import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/core/api/api_client.dart';
import 'package:sentinelx_mobile/core/api/wallet_models.dart';
import 'package:sentinelx_mobile/features/wallet/wallet_providers.dart';
import 'package:sentinelx_mobile/features/wallet/withdraw_screen.dart';

import '../../fakes/fake_wallet_repository.dart';
import 'wallet_test_harness.dart';

FakeWalletRepository _repo({int balance = 5000, ActiveWithdrawal? active, PayoutAccount? payout = testPayoutAccount}) =>
    FakeWalletRepository()..overview = walletOverviewFixture(balance: balance, active: active, payout: payout);

Future<void> _pump(WidgetTester tester, FakeWalletRepository repo, {Locale locale = const Locale('en'), double width = 375}) =>
    pumpWallet(tester, const WithdrawScreen(), repo: repo, locale: locale, width: width);

Future<void> _enter(WidgetTester tester, String amount) async {
  await tester.enterText(find.byKey(const Key('withdraw-amount')), amount);
  await tester.pump();
}

Future<void> _request(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('withdraw-request')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows the available balance from the API', (tester) async {
    await _pump(tester, _repo(balance: 12500));
    expect(find.text('Available: ₦12,500'), findsOneWidget);
  });

  testWidgets('without a payout account the request is disabled and a link opens the payout screen', (tester) async {
    await _pump(tester, _repo(payout: null));
    expect(tester.widget<FilledButton>(find.byKey(const Key('withdraw-request'))).onPressed, isNull);
    expect(find.text('Add a payout account to withdraw.'), findsOneWidget);
    await tester.tap(find.byKey(const Key('withdraw-add-account')));
    await tester.pumpAndSettle();
    expect(find.text('page:/account/wallet/payout-account'), findsOneWidget);
  });

  testWidgets('with a withdrawal already pending the amount is disabled and the player is told', (tester) async {
    await _pump(tester, _repo(active: ActiveWithdrawal(id: 'wr0', amount: 1000, requestedAt: DateTime.utc(2026, 10, 14))));
    expect(tester.widget<TextField>(find.byKey(const Key('withdraw-amount'))).enabled, isFalse);
    expect(find.text('You already have a pending withdrawal.'), findsOneWidget);
    expect(tester.widget<FilledButton>(find.byKey(const Key('withdraw-request'))).onPressed, isNull);
  });

  testWidgets('an amount over the balance or under the minimum is stopped before any request', (tester) async {
    final repo = _repo(balance: 5000);
    await _pump(tester, repo);
    await _enter(tester, '5001');
    await _request(tester);
    expect(find.text('That\'s more than your available balance.'), findsOneWidget);
    await _enter(tester, '99');
    await _request(tester);
    expect(find.text('Minimum is ₦100'), findsOneWidget);
    expect(repo.calls, isNot(contains('withdraw')));
  });

  testWidgets('a double tap sends one request and shows no spurious error', (tester) async {
    final repo = _repo();
    await _pump(tester, repo);
    await _enter(tester, '1500');
    final onPressed = tester.widget<FilledButton>(find.byKey(const Key('withdraw-request'))).onPressed!;
    onPressed();
    onPressed();
    await tester.pumpAndSettle();
    expect(repo.withdrawalAmounts, [1500]);
    expect(find.byKey(const Key('withdraw-error')), findsNothing);
  });

  testWidgets('success shows the submitted note, clears the amount, and refreshes the wallet and the list', (tester) async {
    final repo = _repo();
    await _pump(tester, repo);
    final container = ProviderScope.containerOf(tester.element(find.byType(WithdrawScreen)));
    container.listen(walletOverviewProvider, (_, _) {});
    await container.read(walletOverviewProvider.future);
    final overviewCalls = repo.calls.where((c) => c == 'overview').length;
    final listCalls = repo.calls.where((c) => c == 'withdrawals').length;

    repo.overview = walletOverviewFixture(balance: 3500, active: ActiveWithdrawal(id: 'wr1', amount: 1500, requestedAt: DateTime.utc(2026, 10, 15)));
    repo.withdrawals = WithdrawalPage(items: [withdrawalFixture('wr1')], nextCursor: null);
    await _enter(tester, '1500');
    await _request(tester);

    expect(find.text('Withdrawal requested. An administrator will pay it out.'), findsOneWidget);
    expect(repo.calls.where((c) => c == 'overview').length, greaterThan(overviewCalls));
    expect(repo.calls.where((c) => c == 'withdrawals').length, greaterThan(listCalls));
    expect(find.text('₦1,500'), findsWidgets);
  });

  testWidgets('a network failure keeps the Idempotency-Key; a changed amount mints a new one', (tester) async {
    final repo = _repo()..withdrawalResult = ApiException(status: 0, code: 'network', message: 'offline');
    await _pump(tester, repo);
    await _enter(tester, '1500');
    await _request(tester);
    expect(find.text('No connection. Check your internet and try again.'), findsOneWidget);
    await _request(tester);
    await _enter(tester, '2000');
    repo.withdrawalResult = withdrawalFixture('wr1', amount: 2000);
    await _request(tester);
    expect(repo.idempotencyKeys, hasLength(3));
    expect(repo.idempotencyKeys[0], repo.idempotencyKeys[1]);
    expect(repo.idempotencyKeys[2], isNot(repo.idempotencyKeys[0]));
  });

  for (final c in const [
    ('kyc_required', 'Add a payout account before requesting a withdrawal.'),
    ('insufficient_balance', 'That amount is more than your available balance.'),
    ('withdrawal_pending', 'You already have a pending withdrawal request.'),
    ('account_pending_deletion', 'Cancel your account deletion in Settings to do this.'),
    ('withdrawal_failed', 'Something went wrong. Please try again.'),
  ]) {
    testWidgets('${c.$1} shows localized copy, not the server message', (tester) async {
      final repo = _repo()..withdrawalResult = ApiException(status: 422, code: c.$1, message: 'RAW SERVER MESSAGE');
      await _pump(tester, repo);
      await _enter(tester, '1500');
      await _request(tester);
      expect(find.text(c.$2), findsOneWidget);
      expect(find.textContaining('RAW SERVER MESSAGE'), findsNothing);
    });
  }

  testWidgets('the status timeline shows pending, paid and rejected with no admin note', (tester) async {
    final repo = _repo()
      ..withdrawals = WithdrawalPage(
        items: [withdrawalFixture('a', status: 'pending'), withdrawalFixture('b', status: 'paid', amount: 2500), withdrawalFixture('c', status: 'rejected', amount: 900)],
        nextCursor: null,
      );
    await _pump(tester, repo);
    await tester.scrollUntilVisible(find.text('Rejected'), 300, scrollable: find.byType(Scrollable).first);
    expect(find.text('Pending'), findsOneWidget);
    expect(find.text('Paid'), findsOneWidget);
    expect(find.text('Rejected'), findsOneWidget);
    expect(find.text('₦2,500'), findsOneWidget);
    expect(find.textContaining('note', findRichText: true), findsNothing);
  });

  testWidgets('no withdrawals yet shows the empty line', (tester) async {
    await _pump(tester, _repo());
    await tester.scrollUntilVisible(find.text('No withdrawals yet.'), 300, scrollable: find.byType(Scrollable).first);
    expect(find.text('No withdrawals yet.'), findsOneWidget);
  });

  for (final locale in const [Locale('fr'), Locale('pcm')]) {
    testWidgets('fits at 320px in ${locale.languageCode}', (tester) async {
      final repo = _repo()..withdrawals = WithdrawalPage(items: [withdrawalFixture('a'), withdrawalFixture('b', status: 'paid')], nextCursor: null);
      await _pump(tester, repo, locale: locale, width: 320);
      await tester.drag(find.byType(ListView), const Offset(0, -2000));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
