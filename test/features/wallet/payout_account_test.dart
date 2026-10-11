import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/core/api/api_client.dart';
import 'package:sentinelx_mobile/core/errors/error_reporter.dart';
import 'package:sentinelx_mobile/core/providers.dart';
import 'package:sentinelx_mobile/features/wallet/payout_account_screen.dart';
import 'package:sentinelx_mobile/features/wallet/wallet_providers.dart';

import '../../fakes/fake_wallet_repository.dart';
import 'wallet_test_harness.dart';

const _number = '0123456789';

FakeWalletRepository _formRepo() => FakeWalletRepository()..overview = walletOverviewFixture(payout: null, kycVerified: false);

Future<void> _pump(WidgetTester tester, FakeWalletRepository repo, {Locale locale = const Locale('en'), double width = 375, List<String>? reported}) =>
    pumpWallet(
      tester,
      const PayoutAccountScreen(),
      repo: repo,
      locale: locale,
      width: width,
      overrides: [
        if (reported != null) errorReporterProvider.overrideWithValue(ErrorReporter((m, s, r) async => reported.add(m))),
      ],
    );

Future<void> _pickBank(WidgetTester tester, String code) async {
  await tester.tap(find.byKey(const Key('payout-bank')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(Key('bank-$code')));
  await tester.pumpAndSettle();
}

Future<void> _enterNumber(WidgetTester tester, String number) async {
  await tester.enterText(find.byKey(const Key('payout-number')), number);
  await tester.pump();
}

Future<void> _resolve(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('payout-resolve')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the bank picker lists banks, filters by search, and shows the choice', (tester) async {
    await _pump(tester, _formRepo());
    await tester.tap(find.byKey(const Key('payout-bank')));
    await tester.pumpAndSettle();
    expect(find.text('GTBank'), findsOneWidget);
    expect(find.text('Test Bank'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('payout-bank-search')), 'gt');
    await tester.pumpAndSettle();
    expect(find.text('GTBank'), findsOneWidget);
    expect(find.text('Test Bank'), findsNothing);
    await tester.tap(find.byKey(const Key('bank-058')));
    await tester.pumpAndSettle();
    expect(find.descendant(of: find.byKey(const Key('payout-bank')), matching: find.text('GTBank')), findsOneWidget);
  });

  testWidgets('the account number accepts at most 10 digits, digits only', (tester) async {
    await _pump(tester, _formRepo());
    await _enterNumber(tester, '01a2-3456789012');
    final field = tester.widget<TextField>(find.byKey(const Key('payout-number')));
    expect(field.controller!.text, '0123456789');
  });

  testWidgets('Check account needs a bank and exactly 10 digits', (tester) async {
    await _pump(tester, _formRepo());
    bool enabled() => tester.widget<OutlinedButton>(find.byKey(const Key('payout-resolve'))).onPressed != null;
    expect(enabled(), isFalse);
    await _pickBank(tester, '058');
    await _enterNumber(tester, '012345678');
    expect(enabled(), isFalse);
    await _enterNumber(tester, _number);
    expect(enabled(), isTrue);
  });

  testWidgets('resolving shows the account holder name and only then enables Save', (tester) async {
    final repo = _formRepo();
    await _pump(tester, repo);
    await _pickBank(tester, '058');
    await _enterNumber(tester, _number);
    bool canSave() => tester.widget<FilledButton>(find.byKey(const Key('payout-save'))).onPressed != null;
    expect(canSave(), isFalse);
    await _resolve(tester);
    expect(find.text('Account name: ADA OBI'), findsOneWidget);
    expect(repo.calls, contains('resolve:058:$_number'));
    expect(canSave(), isTrue);
  });

  testWidgets('changing the number or the bank after resolving clears the confirmed name', (tester) async {
    final repo = _formRepo();
    await _pump(tester, repo);
    await _pickBank(tester, '058');
    await _enterNumber(tester, _number);
    await _resolve(tester);
    await _enterNumber(tester, '0123456780');
    expect(find.byKey(const Key('payout-name')), findsNothing);
    await _resolve(tester);
    expect(find.byKey(const Key('payout-name')), findsOneWidget);
    await _pickBank(tester, '001');
    expect(find.byKey(const Key('payout-name')), findsNothing);
    expect(tester.widget<FilledButton>(find.byKey(const Key('payout-save'))).onPressed, isNull);
  });

  for (final c in const [
    ('account_unresolvable', 'We couldn\'t verify that account number. Check the details and try again.'),
    ('unknown_bank', 'We don\'t recognise that bank. Select your bank again.'),
    ('already_verified', 'A payout account is already saved. Remove it first to change it.'),
    ('payout_unavailable', 'Payout accounts are unavailable right now. Please try again.'),
    ('rate_limited', 'Too many attempts. Try again in 42 s.'),
  ]) {
    testWidgets('a failed resolve with ${c.$1} shows its localized copy', (tester) async {
      final repo = _formRepo()..resolveResult = ApiException(status: 422, code: c.$1, message: 'RAW SERVER MESSAGE', fields: const {'retryAfterSeconds': '42'});
      await _pump(tester, repo);
      await _pickBank(tester, '058');
      await _enterNumber(tester, _number);
      await _resolve(tester);
      expect(find.text(c.$2), findsOneWidget);
      expect(find.textContaining('RAW SERVER MESSAGE'), findsNothing);
      expect(find.byKey(const Key('payout-name')), findsNothing);
    });

    testWidgets('a failed save with ${c.$1} shows its localized copy and keeps the form', (tester) async {
      final repo = _formRepo()..setResult = ApiException(status: 422, code: c.$1, message: 'RAW SERVER MESSAGE', fields: const {'retryAfterSeconds': '42'});
      await _pump(tester, repo);
      await _pickBank(tester, '058');
      await _enterNumber(tester, _number);
      await _resolve(tester);
      await tester.tap(find.byKey(const Key('payout-save')));
      await tester.pumpAndSettle();
      expect(find.text(c.$2), findsOneWidget);
      expect(find.byKey(const Key('payout-number')), findsOneWidget);
    });
  }

  testWidgets('saving calls the API, clears the typed number, confirms, and refreshes the wallet', (tester) async {
    final repo = _formRepo();
    await _pump(tester, repo);
    final container = ProviderScope.containerOf(tester.element(find.byType(PayoutAccountScreen)));
    await _pickBank(tester, '058');
    await _enterNumber(tester, _number);
    await _resolve(tester);
    repo.overview = walletOverviewFixture(payout: testPayoutAccount); // the server now has the account
    await tester.tap(find.byKey(const Key('payout-save')));
    await tester.pumpAndSettle();
    expect(repo.calls, contains('set:058:$_number'));
    expect(find.text('Payout account saved.'), findsOneWidget);
    // saved view: masked only, the form and any 10-digit string are gone
    expect(find.byKey(const Key('payout-number')), findsNothing);
    expect(find.text('•••6789'), findsOneWidget);
    expect(find.textContaining(RegExp(r'\d{10}')), findsNothing);
    expect(container.read(walletOverviewProvider).requireValue!.payoutAccount, isNotNull);
    expect(repo.calls.where((c) => c == 'overview').length, 2);
  });

  testWidgets('a saved account shows masked details and Remove asks for confirmation before calling the API', (tester) async {
    final repo = FakeWalletRepository()..overview = walletOverviewFixture();
    await _pump(tester, repo);
    expect(find.text('GTBank'), findsOneWidget);
    expect(find.text('ADA OBI'), findsOneWidget);
    expect(find.text('•••6789'), findsOneWidget);
    expect(find.textContaining(RegExp(r'\d{10}')), findsNothing);

    await tester.tap(find.byKey(const Key('payout-remove')));
    await tester.pumpAndSettle();
    expect(find.text('Remove payout account?'), findsOneWidget);
    await tester.tap(find.byKey(const Key('payout-remove-cancel')));
    await tester.pumpAndSettle();
    expect(repo.calls, isNot(contains('remove')));

    repo.overview = walletOverviewFixture(payout: null, kycVerified: false);
    await tester.tap(find.byKey(const Key('payout-remove')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('payout-remove-confirm')));
    await tester.pumpAndSettle();
    expect(repo.calls, contains('remove'));
    expect(find.byKey(const Key('payout-number')), findsOneWidget); // back to the form
    expect(find.text('Payout account removed.'), findsOneWidget);
  });

  testWidgets('a failed remove shows localized copy and keeps the account', (tester) async {
    final repo = FakeWalletRepository()
      ..overview = walletOverviewFixture()
      ..removeResult = ApiException(status: 500, code: 'payout_remove_failed', message: 'RAW SERVER MESSAGE');
    await _pump(tester, repo);
    await tester.tap(find.byKey(const Key('payout-remove')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('payout-remove-confirm')));
    await tester.pumpAndSettle();
    expect(find.text('Something went wrong. Please try again.'), findsOneWidget);
    expect(find.text('•••6789'), findsOneWidget);
  });

  testWidgets('the typed account number never reaches the error reporter after a failure', (tester) async {
    final reported = <String>[];
    final repo = _formRepo()..resolveResult = ApiException(status: 0, code: 'network', message: 'offline');
    await _pump(tester, repo, reported: reported);
    await _pickBank(tester, '058');
    await _enterNumber(tester, _number);
    await _resolve(tester);
    expect(reported.where((m) => m.contains(_number)), isEmpty);
  });

  for (final locale in const [Locale('fr'), Locale('pcm')]) {
    testWidgets('form and resolved state fit at 320px in ${locale.languageCode}', (tester) async {
      final repo = _formRepo();
      await _pump(tester, repo, locale: locale, width: 320);
      expect(tester.takeException(), isNull);
      await _pickBank(tester, '058');
      await _enterNumber(tester, _number);
      await _resolve(tester);
      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('payout-name')), findsOneWidget);
    });
  }
}
