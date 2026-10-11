import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/compete_models.dart';
import '../../core/api/wallet_models.dart';
import '../../core/utils/write_flow.dart';
import '../compete/payment_poller.dart';
import '../compete/registration_flow.dart';
import 'wallet_providers.dart';

enum DepositPhase { idle, starting, awaitingPayment, confirming, confirmed, mayArrive, failed }

class DepositState {
  const DepositState({
    this.phase = DepositPhase.idle,
    this.reference,
    this.fee,
    this.total,
    this.checkoutClosed = false,
    this.errorCode,
    this.fieldErrors = const {},
  });

  final DepositPhase phase;
  final String? reference;

  /// Both computed by the server when the deposit starts; the app never calculates the Paystack fee.
  final int? fee;
  final int? total;

  /// True when the player closed the checkout before reaching the callback (they may or may not have paid).
  final bool checkoutClosed;
  final String? errorCode;
  final Map<String, String> fieldErrors;

  bool get busy => phase == DepositPhase.starting || phase == DepositPhase.awaitingPayment || phase == DepositPhase.confirming;
}

final depositControllerProvider = NotifierProvider.autoDispose<DepositController, DepositState>(DepositController.new);

/// Start a Paystack top-up, open the checkout, then CONFIRM by asking the server: the WebView only signals "the
/// player finished or closed". The wallet is never shown as credited until the API says so.
class DepositController extends Notifier<DepositState> {
  static const _scope = 'wallet-deposit';

  @override
  DepositState build() {
    // Keep the idempotent write alive for the life of this controller (it is autoDispose and read, not watched).
    ref.listen(writeFlowProvider(_scope), (_, _) {});
    return const DepositState();
  }

  Future<void> start(int amount) async {
    if (state.busy) return;
    state = const DepositState(phase: DepositPhase.starting);

    DepositStart? started;
    final ok = await ref.read(writeFlowProvider(_scope).notifier).run(
      (key) async => started = await ref.read(walletRepositoryProvider).startWalletDeposit(amount, idempotencyKey: key),
      fingerprint: amount, // a changed amount must not replay the response stored for the old one
    );
    if (!ref.mounted) return;
    final deposit = started;
    if (!ok || deposit == null) {
      final failure = ref.read(writeFlowProvider(_scope));
      state = DepositState(phase: DepositPhase.failed, errorCode: failure.errorCode ?? 'network', fieldErrors: failure.fieldErrors);
      return;
    }

    state = DepositState(phase: DepositPhase.awaitingPayment, reference: deposit.reference, fee: deposit.fee, total: deposit.total);
    final reachedCallback = await ref.read(paystackLauncherProvider)(deposit.authorizationUrl);
    if (!ref.mounted) return;

    if (!reachedCallback) {
      // Closed early: they may still have paid. One check, no polling.
      final credited = await _checkOnce(deposit.reference);
      if (!ref.mounted) return;
      _settle(credited, deposit, closed: true);
      return;
    }

    state = DepositState(phase: DepositPhase.confirming, reference: deposit.reference, fee: deposit.fee, total: deposit.total);
    final result = await pollPayment(
      () async => (await _check(deposit.reference)) ? PaymentStatus.confirmed : PaymentStatus.notSuccessful,
      delay: ref.read(pollDelayProvider),
    );
    if (!ref.mounted) return;
    _settle(result == PollResult.paid, deposit);
  }

  /// One manual re-check of the deposit that is still unconfirmed. Never starts a new deposit.
  Future<void> recheck() async {
    final reference = state.reference;
    if (state.busy || state.phase != DepositPhase.mayArrive || reference == null) return;
    final previous = state;
    state = DepositState(phase: DepositPhase.confirming, reference: reference, fee: previous.fee, total: previous.total);
    final credited = await _checkOnce(reference);
    if (!ref.mounted) return;
    if (credited) {
      _confirmed(previous);
    } else {
      state = previous;
    }
  }

  void reset() => state = const DepositState();

  Future<bool> _checkOnce(String reference) async {
    try {
      return await _check(reference).timeout(const Duration(seconds: 15));
    } catch (_) {
      return false;
    }
  }

  Future<bool> _check(String reference) async => (await ref.read(walletRepositoryProvider).getWalletDeposit(reference)).credited;

  void _settle(bool credited, DepositStart deposit, {bool closed = false}) {
    final base = DepositState(phase: DepositPhase.mayArrive, reference: deposit.reference, fee: deposit.fee, total: deposit.total, checkoutClosed: closed);
    if (credited) {
      _confirmed(base);
    } else {
      state = base;
    }
  }

  void _confirmed(DepositState from) {
    state = DepositState(phase: DepositPhase.confirmed, reference: from.reference, fee: from.fee, total: from.total);
    ref.invalidate(walletOverviewProvider);
    ref.invalidate(walletTransactionsProvider);
  }
}
