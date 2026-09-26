import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/core/api/compete_models.dart';
import 'package:sentinelx_mobile/features/compete/payment_poller.dart';

void main() {
  final waited = <Duration>[];
  Future<void> fakeDelay(Duration d) async => waited.add(d);
  setUp(waited.clear);

  test('returns paid immediately when the first check confirms', () async {
    final r = await pollPayment(() async => PaymentStatus.confirmed, delay: fakeDelay);
    expect(r, PollResult.paid);
    expect(waited, isEmpty);
  });

  test('already_paid counts as paid', () async {
    expect(await pollPayment(() async => PaymentStatus.alreadyPaid, delay: fakeDelay), PollResult.paid);
  });

  test('keeps polling through not_successful then succeeds', () async {
    var n = 0;
    final r = await pollPayment(
      () async => ++n < 3 ? PaymentStatus.notSuccessful : PaymentStatus.confirmed,
      delay: fakeDelay,
    );
    expect(r, PollResult.paid);
    expect(n, 3);
    expect(waited.length, 2);
  });

  test('gives up as notConfirmed once the delay budget is spent, never reporting paid', () async {
    var n = 0;
    final r = await pollPayment(() async {
      n++;
      return PaymentStatus.notSuccessful;
    }, delay: fakeDelay);
    expect(r, PollResult.notConfirmed);
    final total = waited.fold<Duration>(Duration.zero, (a, b) => a + b);
    expect(total, lessThanOrEqualTo(const Duration(seconds: 60)));
    expect(n, waited.length + 1);
  });

  test('thrown errors (network blips) are retried, not fatal', () async {
    var n = 0;
    final r = await pollPayment(() async {
      if (++n < 3) throw Exception('offline');
      return PaymentStatus.confirmed;
    }, delay: fakeDelay);
    expect(r, PollResult.paid);
  });

  test('not_found for the whole budget is notConfirmed', () async {
    expect(await pollPayment(() async => PaymentStatus.notFound, delay: fakeDelay), PollResult.notConfirmed);
  });
}
