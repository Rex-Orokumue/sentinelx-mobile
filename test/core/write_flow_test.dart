import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/core/api/api_client.dart';
import 'package:sentinelx_mobile/core/utils/write_flow.dart';

ApiException _err(int status, String code, {Map<String, String> fields = const {}}) =>
    ApiException(status: status, code: code, message: 'x', fields: fields);

class _Rig {
  _Rig() {
    container = ProviderContainer(retry: (_, _) => null);
    // autoDispose provider: keep it alive for the whole test, like a mounted screen would.
    container.listen(writeFlowProvider('s'), (_, _) {});
  }
  late final ProviderContainer container;
  final keys = <String>[];
  WriteFlow get flow => container.read(writeFlowProvider('s').notifier);
  WriteState get state => container.read(writeFlowProvider('s'));

  /// Runs one attempt; records the key; fails with [error] when given.
  Future<bool> attempt([Object? error]) => flow.run((key) async {
        keys.add(key);
        if (error != null) throw error;
      });

  /// Same, but carries a payload fingerprint (the value the caller is submitting this attempt).
  Future<bool> attemptWith(Object fingerprint, [Object? error]) => flow.run(
        (key) async {
          keys.add(key);
          if (error != null) throw error;
        },
        fingerprint: fingerprint,
      );
}

void main() {
  test('success → done, returns true; a later run after reset uses a different key', () async {
    final r = _Rig();
    addTearDown(r.container.dispose);
    expect(await r.attempt(), isTrue);
    expect(r.state.phase, WritePhase.done);
    r.flow.reset();
    expect(r.state.phase, WritePhase.idle);
    await r.attempt();
    expect(r.keys[1], isNot(r.keys[0]));
  });

  test('network failure keeps the key for the retry', () async {
    final r = _Rig();
    addTearDown(r.container.dispose);
    expect(await r.attempt(_err(0, 'network')), isFalse);
    expect(r.state.phase, WritePhase.failed);
    expect(r.state.errorCode, 'network');
    await r.attempt();
    expect(r.keys[1], r.keys[0]);
  });

  test('idempotency_in_progress and bad_response keep the key', () async {
    final r = _Rig();
    addTearDown(r.container.dispose);
    await r.attempt(_err(409, 'idempotency_in_progress'));
    await r.attempt(_err(504, 'bad_response'));
    await r.attempt();
    expect(r.keys.toSet().length, 1);
  });

  test('any other server error mints a new key for the next attempt', () async {
    for (final code in ['already_rated', 'insufficient_coins', 'window_closed', 'some_other_code']) {
      final r = _Rig();
      addTearDown(r.container.dispose);
      await r.attempt(_err(409, code));
      expect(r.state.errorCode, code);
      await r.attempt();
      expect(r.keys[1], isNot(r.keys[0]), reason: code);
    }
  });

  test('a non-ApiException is reported as network and keeps the key', () async {
    final r = _Rig();
    addTearDown(r.container.dispose);
    await r.attempt(Exception('x'));
    expect(r.state.phase, WritePhase.failed);
    expect(r.state.errorCode, 'network');
    await r.attempt();
    expect(r.keys[1], r.keys[0]);
  });

  test('401 surfaces as unauthorized', () async {
    final r = _Rig();
    addTearDown(r.container.dispose);
    await r.attempt(_err(401, 'whatever'));
    expect(r.state.errorCode, 'unauthorized');
  });

  test('field errors are copied from the ApiException', () async {
    final r = _Rig();
    addTearDown(r.container.dispose);
    await r.attempt(_err(400, 'validation_failed', fields: {'scoreA': 'bad'}));
    expect(r.state.fieldErrors, {'scoreA': 'bad'});
  });

  test('a second run while the first is in flight is ignored', () async {
    final r = _Rig();
    addTearDown(r.container.dispose);
    final gate = Completer<void>();
    var calls = 0;
    final first = r.flow.run((key) async {
      calls++;
      await gate.future;
    });
    expect(r.state.busy, isTrue);
    final second = await r.flow.run((key) async => calls++);
    expect(second, isFalse);
    gate.complete();
    expect(await first, isTrue);
    expect(calls, 1);
  });

  test('success clears the key: consecutive successes use different keys', () async {
    final r = _Rig();
    addTearDown(r.container.dispose);
    await r.attempt();
    await r.attempt();
    expect(r.keys[1], isNot(r.keys[0]));
  });

  test('a network failure keeps the key when the retried payload is unchanged', () async {
    final r = _Rig();
    addTearDown(r.container.dispose);
    await r.attemptWith('stake:50', _err(0, 'network'));
    await r.attemptWith('stake:50');
    expect(r.keys[1], r.keys[0]);
  });

  test('a network failure mints a new key when the retried payload changed', () async {
    final r = _Rig();
    addTearDown(r.container.dispose);
    await r.attemptWith('stake:50', _err(0, 'network'));
    await r.attemptWith('stake:75');
    expect(r.keys[1], isNot(r.keys[0]));
  });

  test('a bad_response failure also mints a new key when the payload changed on retry', () async {
    final r = _Rig();
    addTearDown(r.container.dispose);
    await r.attemptWith('stars:3', _err(504, 'bad_response'));
    await r.attemptWith('stars:4');
    expect(r.keys[1], isNot(r.keys[0]));
  });

  test('disposing the container mid-call does not throw when the call completes', () async {
    final r = _Rig();
    final gate = Completer<void>();
    final future = r.flow.run((key) => gate.future);
    r.container.dispose();
    gate.complete();
    await future;
    final r2 = _Rig();
    addTearDown(r2.container.dispose);
    final gate2 = Completer<void>();
    final failing = r2.flow.run((key) => gate2.future);
    r2.container.dispose();
    gate2.completeError(_err(0, 'network'));
    expect(await failing, isFalse);
  });
}
