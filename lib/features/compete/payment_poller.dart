import '../../core/api/compete_models.dart';

enum PollResult { paid, notConfirmed }

typedef PollDelay = Future<void> Function(Duration d);

const List<Duration> defaultBackoff = [
  Duration(seconds: 1),
  Duration(seconds: 2),
  Duration(seconds: 3),
  Duration(seconds: 5),
  Duration(seconds: 5),
  Duration(seconds: 8),
  Duration(seconds: 8),
  Duration(seconds: 13),
  Duration(seconds: 15),
];

Future<void> _realDelay(Duration d) => Future<void>.delayed(d);

/// Polls `GET /payments/{reference}` (via [check]) until paid or the ~60 s [budget] of waiting is spent.
/// The Paystack webhook is the source of truth; this only decides what the UI may say.
///
/// The budget is wall-clock: each check is capped at [checkTimeout], and elapsed time is the larger
/// of the waited delays and the real clock, so a slow network cannot hold the poll open for minutes.
Future<PollResult> pollPayment(
  Future<PaymentStatus> Function() check, {
  PollDelay delay = _realDelay,
  Duration budget = const Duration(seconds: 60),
  Duration checkTimeout = const Duration(seconds: 15),
  List<Duration> backoff = defaultBackoff,
}) async {
  final clock = Stopwatch()..start();
  var spent = Duration.zero;
  var i = 0;
  while (true) {
    try {
      if ((await check().timeout(checkTimeout)).isPaid) return PollResult.paid;
    } catch (_) {
      // Transient failure or timeout: keep polling within the budget.
    }
    final next = backoff[i < backoff.length ? i : backoff.length - 1];
    final elapsed = clock.elapsed > spent ? clock.elapsed : spent;
    if (elapsed + next > budget) return PollResult.notConfirmed;
    await delay(next);
    spent += next;
    i++;
  }
}
