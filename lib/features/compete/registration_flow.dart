import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/api/compete_models.dart';
import '../../core/utils/idempotency_key.dart';
import 'compete_providers.dart';
import 'payment_poller.dart';

enum FlowPhase { idle, submitting, awaitingPayment, confirming, confirmed, waitlisted, notConfirmed, cancelled, failed }

class FlowState {
  const FlowState({this.phase = FlowPhase.idle, this.errorCode, this.fieldErrors = const {}});

  final FlowPhase phase;
  final String? errorCode;
  final Map<String, String> fieldErrors;

  bool get needsUsername => errorCode == 'needs_username';
  bool get busy => phase == FlowPhase.submitting || phase == FlowPhase.awaitingPayment || phase == FlowPhase.confirming;
}

/// Opens Paystack checkout. Completes `true` when the page reached the callback URL, `false` when the
/// user closed the window first. Supplied by the app shell; tests override it.
typedef PaystackLauncher = Future<bool> Function(String authorizationUrl);

final paystackLauncherProvider =
    Provider<PaystackLauncher>((ref) => throw UnimplementedError('Override paystackLauncherProvider'));

/// Overridden in tests so polling does not really wait.
final pollDelayProvider = Provider<PollDelay>((ref) => (d) => Future<void>.delayed(d));

/// Family argument: the tournament id — the registration state of that tournament is refreshed on
/// success. Invitation accepts pass the invitation's tournament id too.
final registrationFlowProvider =
    NotifierProvider.autoDispose.family<RegistrationFlow, FlowState, String>(RegistrationFlow.new);

class RegistrationFlow extends Notifier<FlowState> {
  RegistrationFlow(this.tournamentId);
  final String tournamentId;

  String? _key;

  @override
  FlowState build() => const FlowState();

  String get currentKey => _key ??= newIdempotencyKey();

  void reset() {
    _key = null;
    state = const FlowState();
  }

  Future<void> submitRegister(RegistrationDetails details, {int coinsUsed = 0}) => _run(() async {
        final key = currentKey;
        return ref.read(registrationRepositoryProvider).register(
              tournamentId,
              details: details,
              coinsUsed: coinsUsed,
              idempotencyKey: key,
            );
      });

  Future<void> submitInvitationAccept(String invitationId) => _run(() async {
        final key = currentKey;
        return ref.read(registrationRepositoryProvider).acceptInvitation(invitationId, idempotencyKey: key);
      });

  Future<void> submitWaitlist(RegistrationDetails details) async {
    if (state.busy) return;
    state = const FlowState(phase: FlowPhase.submitting);
    try {
      await ref.read(registrationRepositoryProvider).joinWaitlist(tournamentId, details: details);
      if (!ref.mounted) return;
      state = const FlowState(phase: FlowPhase.waitlisted);
      ref.invalidate(registrationStateProvider(tournamentId));
    } catch (e) {
      if (!ref.mounted) return;
      state = _failure(e);
    }
  }

  Future<void> _run(Future<RegisterOutcome> Function() call) async {
    if (state.busy) return;
    state = const FlowState(phase: FlowPhase.submitting);
    final RegisterOutcome outcome;
    try {
      outcome = await call();
    } catch (e) {
      if (!ref.mounted) return;
      // Same key only when the request may not have been processed; every real response, error or
      // not, is stored server-side under the key and would be replayed.
      final keepKey = e is! ApiException || e.code == 'network' || e.code == 'idempotency_in_progress';
      if (!keepKey) _key = null;
      state = _failure(e);
      return;
    }
    if (!ref.mounted) return;
    _key = null; // the attempt got an answer; a later manual restart is a new attempt

    switch (outcome) {
      case RegisterConfirmed():
        _finishConfirmed();
      case RegisterPending(:final authorizationUrl, :final reference):
        await _pay(authorizationUrl, reference);
    }
  }

  Future<void> _pay(String url, String reference) async {
    state = const FlowState(phase: FlowPhase.awaitingPayment);
    final repo = ref.read(registrationRepositoryProvider);
    final reachedCallback = await ref.read(paystackLauncherProvider)(url);
    if (!ref.mounted) return;

    if (!reachedCallback) {
      // Closed early: they may still have paid. One check, no polling.
      PaymentStatus? status;
      try {
        status = await repo.paymentStatus(reference);
      } catch (_) {}
      if (!ref.mounted) return;
      if (status != null && status.isPaid) {
        _finishConfirmed();
      } else {
        state = const FlowState(phase: FlowPhase.cancelled);
      }
      return;
    }

    state = const FlowState(phase: FlowPhase.confirming);
    final result = await pollPayment(() => repo.paymentStatus(reference), delay: ref.read(pollDelayProvider));
    if (!ref.mounted) return;
    if (result == PollResult.paid) {
      _finishConfirmed();
    } else {
      state = const FlowState(phase: FlowPhase.notConfirmed);
      ref.invalidate(registrationStateProvider(tournamentId));
    }
  }

  void _finishConfirmed() {
    state = const FlowState(phase: FlowPhase.confirmed);
    ref.invalidate(registrationStateProvider(tournamentId));
  }

  FlowState _failure(Object e) {
    if (e is ApiException) {
      final code = e.isUnauthorized ? 'unauthorized' : e.code;
      return FlowState(phase: FlowPhase.failed, errorCode: code, fieldErrors: e.fields);
    }
    return const FlowState(phase: FlowPhase.failed, errorCode: 'network');
  }
}
