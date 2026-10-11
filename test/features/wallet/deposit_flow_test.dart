import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/core/api/api_client.dart';
import 'package:sentinelx_mobile/core/api/wallet_models.dart';
import 'package:sentinelx_mobile/features/compete/registration_flow.dart';
import 'package:sentinelx_mobile/features/wallet/deposit_screen.dart';
import 'package:sentinelx_mobile/features/wallet/wallet_providers.dart';

import '../../fakes/fake_wallet_repository.dart';
import 'wallet_test_harness.dart';

const _credited = DepositPoll(status: DepositStatus.confirmed, balance: 6000);
const _notYet = DepositPoll(status: DepositStatus.notSuccessful, balance: null);

Future<List<Duration>> _pump(
  WidgetTester tester,
  FakeWalletRepository repo, {
  Future<bool> Function(String)? paystack,
  Locale locale = const Locale('en'),
  double width = 375,
}) async {
  final delays = <Duration>[];
  await pumpWallet(
    tester,
    const DepositScreen(),
    repo: repo,
    paystack: paystack,
    locale: locale,
    width: width,
    overrides: [pollDelayProvider.overrideWithValue((d) async => delays.add(d))],
  );
  return delays;
}

Future<void> _enter(WidgetTester tester, String amount) async {
  await tester.enterText(find.byKey(const Key('deposit-amount')), amount);
  await tester.pump();
}

Future<void> _continue(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('deposit-continue')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('an amount below the minimum shows the minimum and makes no request', (tester) async {
    final repo = FakeWalletRepository();
    await _pump(tester, repo);
    await _enter(tester, '99');
    await _continue(tester);
    expect(find.text('Minimum is ₦100'), findsOneWidget);
    expect(repo.calls, isNot(contains('startDeposit')));
  });

  testWidgets('the amount field accepts digits only', (tester) async {
    await _pump(tester, FakeWalletRepository());
    await _enter(tester, '1a5.0,0');
    final field = tester.widget<TextField>(find.byKey(const Key('deposit-amount')));
    expect(field.controller!.text, '1500');
  });

  testWidgets('a double tap starts exactly one deposit', (tester) async {
    final gate = Completer<bool>();
    final repo = FakeWalletRepository();
    await _pump(tester, repo, paystack: (_) => gate.future);
    await _enter(tester, '5000');
    // Two taps delivered before the next frame: invoke the handler twice with no pump in between.
    final onPressed = tester.widget<FilledButton>(find.byKey(const Key('deposit-continue'))).onPressed!;
    onPressed();
    onPressed();
    await tester.pump();
    expect(repo.depositAmounts, [5000]);
    // the second tap must be ignored, not reported to the player as a failure
    expect(find.byKey(const Key('deposit-error')), findsNothing);
    expect(find.byKey(const Key('deposit-confirming')), findsOneWidget);
    gate.complete(true);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('deposit-error')), findsNothing);
  });

  testWidgets('the server fee and total are shown once the deposit starts, never computed locally', (tester) async {
    final gate = Completer<bool>();
    await _pump(tester, FakeWalletRepository(), paystack: (_) => gate.future);
    await _enter(tester, '5000');
    await tester.tap(find.byKey(const Key('deposit-continue')));
    await tester.pump();
    await tester.pump();
    expect(find.text('Paystack fee ₦175. You\'ll pay ₦5,175 in total.'), findsOneWidget);
    gate.complete(false);
    await tester.pumpAndSettle();
  });

  testWidgets('a network failure keeps the Idempotency-Key; a changed amount mints a new one', (tester) async {
    final repo = FakeWalletRepository()..depositStart = ApiException(status: 0, code: 'network', message: 'offline');
    await _pump(tester, repo);
    await _enter(tester, '5000');
    await _continue(tester);
    expect(find.text('No connection. Check your internet and try again.'), findsOneWidget);
    await _continue(tester); // same amount: retry with the same key
    await _enter(tester, '6000');
    repo.depositStart = const DepositStart(reference: 'r2', authorizationUrl: 'https://pay.test/y', amount: 6000, fee: 200, total: 6200);
    repo.depositPolls.add(_credited);
    await _continue(tester);
    expect(repo.idempotencyKeys, hasLength(3));
    expect(repo.idempotencyKeys[0], repo.idempotencyKeys[1]);
    expect(repo.idempotencyKeys[2], isNot(repo.idempotencyKeys[0]));
  });

  testWidgets('after checkout it confirms by polling, shows success, and refreshes the wallet', (tester) async {
    final repo = FakeWalletRepository()..depositPolls.addAll([_notYet, _credited]);
    final delays = await _pump(tester, repo);
    final container = ProviderScope.containerOf(tester.element(find.byType(DepositScreen)));
    container.listen(walletOverviewProvider, (_, _) {});
    await container.read(walletOverviewProvider.future);
    expect(repo.calls.where((c) => c == 'overview'), hasLength(1));

    await _enter(tester, '5000');
    await _continue(tester);

    expect(find.text('Payment confirmed. Your wallet has been credited.'), findsOneWidget);
    expect(find.byKey(const Key('deposit-done')), findsOneWidget);
    expect(repo.calls.where((c) => c == 'poll:r1'), hasLength(2));
    expect(delays, [const Duration(seconds: 1)]);
    await tester.pumpAndSettle();
    expect(repo.calls.where((c) => c == 'overview'), hasLength(2)); // invalidated -> refetched
  });

  testWidgets('a poll that never confirms stops after the backoff budget and offers Check again', (tester) async {
    final repo = FakeWalletRepository(); // every poll: not successful
    final delays = await _pump(tester, repo);
    await _enter(tester, '5000');
    await _continue(tester);

    expect(find.text('We haven\'t seen your payment yet. If you were charged, it will arrive shortly.'), findsOneWidget);
    expect(find.byKey(const Key('deposit-check-again')), findsOneWidget);
    final polls = repo.calls.where((c) => c == 'poll:r1').length;
    expect(polls, inInclusiveRange(5, 12)); // bounded, not endless
    expect(delays.fold<Duration>(Duration.zero, (a, b) => a + b), lessThanOrEqualTo(const Duration(seconds: 60)));

    repo.depositPolls.add(_credited);
    await tester.tap(find.byKey(const Key('deposit-check-again')));
    await tester.pumpAndSettle();
    expect(repo.calls.where((c) => c == 'poll:r1').length, polls + 1);
    expect(find.text('Payment confirmed. Your wallet has been credited.'), findsOneWidget);
  });

  testWidgets('closing the checkout checks once, leaves the deposit pending, and does not refresh the wallet', (tester) async {
    final repo = FakeWalletRepository(); // the single check: not successful
    await _pump(tester, repo, paystack: (_) async => false);
    final container = ProviderScope.containerOf(tester.element(find.byType(DepositScreen)));
    container.listen(walletOverviewProvider, (_, _) {});
    await container.read(walletOverviewProvider.future);

    await _enter(tester, '5000');
    await _continue(tester);

    expect(repo.calls.where((c) => c == 'poll:r1'), hasLength(1));
    expect(find.text('Payment window closed. If you paid, your balance will update shortly.'), findsOneWidget);
    expect(find.byKey(const Key('deposit-check-again')), findsOneWidget);
    expect(repo.calls.where((c) => c == 'overview'), hasLength(1));
  });

  testWidgets('closing the checkout after paying still confirms on the single check', (tester) async {
    final repo = FakeWalletRepository()..depositPolls.add(_credited);
    await _pump(tester, repo, paystack: (_) async => false);
    await _enter(tester, '5000');
    await _continue(tester);
    expect(find.text('Payment confirmed. Your wallet has been credited.'), findsOneWidget);
  });

  for (final c in const [
    ('rate_limited', 'Too many attempts. Try again in 42 s.'),
    ('account_pending_deletion', 'Cancel your account deletion in Settings to do this.'),
    ('email_required', 'Add an email to your account to pay.'),
    ('payment_unavailable', 'Payment couldn\'t be started. Please try again.'),
  ]) {
    testWidgets('${c.$1} shows localized copy, not the server message', (tester) async {
      final repo = FakeWalletRepository()
        ..depositStart = ApiException(status: 400, code: c.$1, message: 'RAW SERVER MESSAGE', fields: const {'retryAfterSeconds': '42'});
      await _pump(tester, repo);
      await _enter(tester, '5000');
      await _continue(tester);
      expect(find.text(c.$2), findsOneWidget);
      expect(find.textContaining('RAW SERVER MESSAGE'), findsNothing);
    });
  }

  for (final locale in const [Locale('fr'), Locale('pcm')]) {
    testWidgets('idle and confirmed states fit at 320px in ${locale.languageCode}', (tester) async {
      final repo = FakeWalletRepository()..depositPolls.add(_credited);
      await _pump(tester, repo, locale: locale, width: 320);
      expect(tester.takeException(), isNull);
      await _enter(tester, '5000');
      await _continue(tester);
      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('deposit-done')), findsOneWidget);
    });
  }
}
