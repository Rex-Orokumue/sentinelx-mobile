import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/core/api/api_client.dart';
import 'package:sentinelx_mobile/core/api/compete_models.dart';
import 'package:sentinelx_mobile/features/compete/compete_providers.dart';
import 'package:sentinelx_mobile/features/compete/registration_flow.dart';

import '../../fakes/fake_registration_repository.dart';

const _details = RegistrationDetails(displayName: 'Ada', whatsapp: '+2348012345678', clubName: 'FC Ada', agreedToRules: true);
const _pending = RegisterPending(authorizationUrl: 'https://pay.test/a', reference: 'ref-1');

ApiException _err(int status, String code, {Map<String, String> fields = const {}}) =>
    ApiException(status: status, code: code, message: 'x', fields: fields);

class _Rig {
  _Rig({bool launcherReturns = true}) : repo = FakeRegistrationRepository() {
    container = ProviderContainer(retry: (_, _) => null, overrides: [
      registrationRepositoryProvider.overrideWithValue(repo),
      paystackLauncherProvider.overrideWithValue((url) async {
        launched.add(url);
        return launcherReturns;
      }),
      pollDelayProvider.overrideWithValue((_) async {}),
    ]);
    // autoDispose provider: keep it alive for the whole test, like a mounted screen would.
    container.listen(registrationFlowProvider('t1'), (_, _) {});
  }
  final FakeRegistrationRepository repo;
  late final ProviderContainer container;
  final launched = <String>[];
  RegistrationFlow get flow => container.read(registrationFlowProvider('t1').notifier);
  FlowState get state => container.read(registrationFlowProvider('t1'));
}

void main() {
  test('zero-fee / waiver path: confirmed, no checkout opened', () async {
    final r = _Rig();
    addTearDown(r.container.dispose);
    r.repo.registerResults.add(const RegisterConfirmed());
    await r.flow.submitRegister(_details);
    expect(r.state.phase, FlowPhase.confirmed);
    expect(r.launched, isEmpty);
  });

  test('pending → checkout → poll paid → confirmed, coins forwarded', () async {
    final r = _Rig();
    addTearDown(r.container.dispose);
    r.repo.registerResults.add(_pending);
    r.repo.paymentResults.add(PaymentStatus.confirmed);
    await r.flow.submitRegister(_details, coinsUsed: 500);
    expect(r.launched, ['https://pay.test/a']);
    expect(r.repo.registerCoins, [500]);
    expect(r.repo.paymentChecks, ['ref-1']);
    expect(r.state.phase, FlowPhase.confirmed);
  });

  test('checkout returns but payment never confirms → notConfirmed, never confirmed', () async {
    final r = _Rig();
    addTearDown(r.container.dispose);
    r.repo.registerResults.add(_pending);
    r.repo.paymentResults.add(PaymentStatus.notSuccessful);
    await r.flow.submitRegister(_details);
    expect(r.state.phase, FlowPhase.notConfirmed);
  });

  test('user closes the checkout: one status check; unpaid → cancelled', () async {
    final r = _Rig(launcherReturns: false);
    addTearDown(r.container.dispose);
    r.repo.registerResults.add(_pending);
    r.repo.paymentResults.add(PaymentStatus.notSuccessful);
    await r.flow.submitRegister(_details);
    expect(r.state.phase, FlowPhase.cancelled);
    expect(r.repo.paymentChecks, ['ref-1']);
  });

  test('user closes the checkout but had already paid → confirmed', () async {
    final r = _Rig(launcherReturns: false);
    addTearDown(r.container.dispose);
    r.repo.registerResults.add(_pending);
    r.repo.paymentResults.add(PaymentStatus.alreadyPaid);
    await r.flow.submitRegister(_details);
    expect(r.state.phase, FlowPhase.confirmed);
  });

  group('Idempotency-Key policy', () {
    test('a network failure reuses the same key on retry', () async {
      final r = _Rig();
      addTearDown(r.container.dispose);
      r.repo.registerResults.addAll([_err(0, 'network'), const RegisterConfirmed()]);
      await r.flow.submitRegister(_details);
      expect(r.state.phase, FlowPhase.failed);
      expect(r.state.errorCode, 'network');
      await r.flow.submitRegister(_details);
      expect(r.repo.registerKeys.length, 2);
      expect(r.repo.registerKeys[0], r.repo.registerKeys[1]);
      expect(r.state.phase, FlowPhase.confirmed);
    });

    test('idempotency_in_progress (409) also reuses the key', () async {
      final r = _Rig();
      addTearDown(r.container.dispose);
      r.repo.registerResults.addAll([_err(409, 'idempotency_in_progress'), const RegisterConfirmed()]);
      await r.flow.submitRegister(_details);
      await r.flow.submitRegister(_details);
      expect(r.repo.registerKeys[0], r.repo.registerKeys[1]);
    });

    test('any other server error mints a NEW key for the next submit', () async {
      final r = _Rig();
      addTearDown(r.container.dispose);
      r.repo.registerResults.addAll([_err(409, 'tournament_full'), const RegisterConfirmed()]);
      await r.flow.submitRegister(_details);
      expect(r.state.errorCode, 'tournament_full');
      await r.flow.submitRegister(_details);
      expect(r.repo.registerKeys[0], isNot(r.repo.registerKeys[1]));
    });

    test('needs_username sets the flag and the resubmit uses a new key', () async {
      final r = _Rig();
      addTearDown(r.container.dispose);
      r.repo.registerResults.addAll([_err(400, 'needs_username'), const RegisterConfirmed()]);
      await r.flow.submitRegister(_details);
      expect(r.state.needsUsername, isTrue);
      await r.flow.submitRegister(_details);
      expect(r.repo.registerKeys[0], isNot(r.repo.registerKeys[1]));
    });

    test('a finished attempt does not leak its key into a later attempt', () async {
      final r = _Rig();
      addTearDown(r.container.dispose);
      r.repo.registerResults.addAll([const RegisterConfirmed(), const RegisterConfirmed()]);
      await r.flow.submitRegister(_details);
      r.flow.reset();
      await r.flow.submitRegister(_details);
      expect(r.repo.registerKeys[0], isNot(r.repo.registerKeys[1]));
    });
  });

  test('a second tap while the first request is in flight is ignored', () async {
    final r = _Rig();
    addTearDown(r.container.dispose);
    final gate = Completer<void>();
    r.repo.registerGate = gate.future;
    r.repo.registerResults.add(const RegisterConfirmed());
    final first = r.flow.submitRegister(_details);
    await Future<void>.delayed(Duration.zero);
    await r.flow.submitRegister(_details); // ignored
    gate.complete();
    await first;
    expect(r.repo.registerKeys.length, 1);
  });

  test('401 maps to the unauthorized code; field errors are kept', () async {
    final r = _Rig();
    addTearDown(r.container.dispose);
    r.repo.registerResults.add(_err(401, 'whatever'));
    await r.flow.submitRegister(_details);
    expect(r.state.errorCode, 'unauthorized');

    final r2 = _Rig();
    addTearDown(r2.container.dispose);
    r2.repo.registerResults.add(_err(400, 'validation_failed', fields: {'whatsapp': 'bad'}));
    await r2.flow.submitRegister(_details);
    expect(r2.state.fieldErrors, {'whatsapp': 'bad'});
  });

  test('a non-API exception becomes a network failure and keeps the key', () async {
    final r = _Rig();
    addTearDown(r.container.dispose);
    r.repo.registerResults.addAll([Exception('socket'), const RegisterConfirmed()]);
    await r.flow.submitRegister(_details);
    expect(r.state.errorCode, 'network');
    await r.flow.submitRegister(_details);
    expect(r.repo.registerKeys[0], r.repo.registerKeys[1]);
  });

  test('waitlist: success → waitlisted, no key involved; error → failed', () async {
    final r = _Rig();
    addTearDown(r.container.dispose);
    await r.flow.submitWaitlist(_details);
    expect(r.state.phase, FlowPhase.waitlisted);
    expect(r.repo.waitlistCalls.length, 1);
    r.flow.reset();
    r.repo.waitlistResult = _err(409, 'already_on_waitlist');
    await r.flow.submitWaitlist(_details);
    expect(r.state.errorCode, 'already_on_waitlist');
  });

  test('invitation accept uses the key policy and the same outcomes', () async {
    final r = _Rig();
    addTearDown(r.container.dispose);
    r.repo.acceptResults.addAll([_err(0, 'network'), const RegisterConfirmed()]);
    await r.flow.submitInvitationAccept('inv1');
    await r.flow.submitInvitationAccept('inv1');
    expect(r.repo.acceptKeys[0], r.repo.acceptKeys[1]);
    expect(r.state.phase, FlowPhase.confirmed);
  });
}
