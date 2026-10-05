import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/core/realtime/realtime_hub.dart';
import 'package:sentinelx_mobile/core/realtime/realtime_port.dart';

import '../fakes/fake_realtime.dart';

const _spec = RealtimeChannelSpec(
  topic: 'dm-test',
  private: true,
  bindings: [PostgresBinding(table: 'dm_messages')],
);

void main() {
  late FakeChannelFactory factory;
  late FakeLifecycle lifecycle;
  late RealtimeHub hub;

  setUp(() {
    factory = FakeChannelFactory();
    lifecycle = FakeLifecycle();
    hub = RealtimeHub(factory: factory, lifecycle: lifecycle);
  });

  group('signals', () {
    test('two consecutive events deliver two signals with strictly increasing seq', () {
      final seen = <RealtimeSignal>[];
      final h = hub.open(_spec);
      final sub = h.signals.listen(seen.add);
      final port = factory.created.single..emitStatus(PortStatus.subscribed);
      port
        ..emitEvent()
        ..emitEvent();
      expect(seen.map((s) => s.kind), [RealtimeSignalKind.event, RealtimeSignalKind.event]);
      expect(seen[1].seq, greaterThan(seen[0].seq));
      sub.cancel();
    });

    test('the second subscribed status is a reconnected signal, the first is silent', () {
      final seen = <RealtimeSignal>[];
      final sub = hub.open(_spec).signals.listen(seen.add);
      final port = factory.created.single;
      port.emitStatus(PortStatus.subscribed);
      expect(seen, isEmpty);
      port.emitStatus(PortStatus.subscribed);
      expect(seen.single.kind, RealtimeSignalKind.reconnected);
      sub.cancel();
    });

    test('the spec reaches the factory unchanged', () {
      hub.open(_spec).signals.listen((_) {});
      expect(identical(factory.created.single.spec, _spec), isTrue);
      expect(factory.created.single.spec.topic, 'dm-test');
      expect(factory.created.single.spec.private, isTrue);
      expect(factory.created.single.spec.selfBroadcast, isFalse);
    });

    test('nothing is created until the first listen', () {
      final h = hub.open(_spec);
      expect(factory.created, isEmpty);
      final sub = h.signals.listen((_) {});
      expect(factory.created, hasLength(1));
      sub.cancel();
    });
  });

  group('failure and backoff', () {
    test('error re-creates the channel after 2 s, then 4 s on a second failure, and resets after subscribed', () {
      fakeAsync((async) {
        final sub = hub.open(_spec).signals.listen((_) {});
        factory.created.single.emitStatus(PortStatus.error);
        expect(factory.created.single.disposed, isTrue);

        async.elapse(const Duration(milliseconds: 1999));
        expect(factory.created, hasLength(1));
        async.elapse(const Duration(milliseconds: 2));
        expect(factory.created, hasLength(2));

        factory.created[1].emitStatus(PortStatus.timedOut);
        async.elapse(const Duration(milliseconds: 3999));
        expect(factory.created, hasLength(2));
        async.elapse(const Duration(milliseconds: 2));
        expect(factory.created, hasLength(3));

        factory.created[2].emitStatus(PortStatus.subscribed);
        factory.created[2].emitStatus(PortStatus.closed);
        async.elapse(const Duration(milliseconds: 1999));
        expect(factory.created, hasLength(3), reason: 'backoff reset only to 2 s, not yet elapsed');
        async.elapse(const Duration(milliseconds: 2));
        expect(factory.created, hasLength(4));
        sub.cancel();
      });
    });

    test('backoff is capped at 30 s', () {
      fakeAsync((async) {
        final sub = hub.open(_spec).signals.listen((_) {});
        var made = 1;
        for (var i = 0; i < 8; i++) {
          factory.created.last.emitStatus(PortStatus.error);
          async.elapse(const Duration(seconds: 30));
          expect(factory.created, hasLength(++made), reason: 'attempt $i re-created within 30 s');
        }
        sub.cancel();
      });
    });

    test('a channel re-created after an error reports reconnected on subscribed', () {
      fakeAsync((async) {
        final seen = <RealtimeSignal>[];
        final sub = hub.open(_spec).signals.listen(seen.add);
        factory.created.single.emitStatus(PortStatus.subscribed);
        factory.created.single.emitStatus(PortStatus.error);
        async.elapse(const Duration(seconds: 2));
        factory.created[1].emitStatus(PortStatus.subscribed);
        expect(seen.map((s) => s.kind), [RealtimeSignalKind.reconnected]);
        sub.cancel();
      });
    });
  });

  group('lifecycle', () {
    test('paused disposes the port; resumed re-creates it and emits resumed', () {
      final seen = <RealtimeSignal>[];
      final sub = hub.open(_spec).signals.listen(seen.add);
      factory.created.single.emitStatus(PortStatus.subscribed);

      lifecycle.push(AppLifecycleState.paused);
      expect(factory.created.single.disposed, isTrue);
      expect(factory.created, hasLength(1));

      lifecycle.push(AppLifecycleState.resumed);
      expect(factory.created, hasLength(2));
      expect(seen.last.kind, RealtimeSignalKind.resumed);
      sub.cancel();
    });

    test('hidden behaves like paused and inactive is ignored', () {
      final sub = hub.open(_spec).signals.listen((_) {});
      lifecycle.push(AppLifecycleState.inactive);
      expect(factory.created.single.disposed, isFalse);
      lifecycle.push(AppLifecycleState.hidden);
      expect(factory.created.single.disposed, isTrue);
      sub.cancel();
    });

    test('a pending retry timer does not re-create while paused', () {
      fakeAsync((async) {
        final sub = hub.open(_spec).signals.listen((_) {});
        factory.created.single.emitStatus(PortStatus.error);
        lifecycle.push(AppLifecycleState.paused);
        async.elapse(const Duration(seconds: 60));
        expect(factory.created, hasLength(1));
        sub.cancel();
      });
    });
  });

  group('closing', () {
    test('cancelling the stream disposes the port; a late subscribed callback emits nothing and does not throw', () async {
      final seen = <RealtimeSignal>[];
      final sub = hub.open(_spec).signals.listen(seen.add);
      final port = factory.created.single;
      port.emitStatus(PortStatus.subscribed);
      await sub.cancel();
      expect(port.disposed, isTrue);
      expect(() => port.emitStatus(PortStatus.subscribed), returnsNormally);
      expect(() => port.emitEvent(), returnsNormally);
      expect(seen, isEmpty);
    });

    test('close is idempotent', () async {
      final h = hub.open(_spec);
      h.signals.listen((_) {});
      await h.close();
      await h.close();
      expect(factory.created.single.disposed, isTrue);
    });

    test('a closed handle is not revived by resumed', () async {
      final h = hub.open(_spec);
      h.signals.listen((_) {});
      await h.close();
      lifecycle.push(AppLifecycleState.paused);
      lifecycle.push(AppLifecycleState.resumed);
      expect(factory.created, hasLength(1));
    });
  });

  group('send and track', () {
    test('send before subscribed is dropped without throwing; after subscribed it goes through', () async {
      final h = hub.open(_spec);
      final sub = h.signals.listen((_) {});
      final port = factory.created.single;
      await h.send('typing', {'userId': 'u'});
      expect(port.sent, isEmpty);
      port.emitStatus(PortStatus.subscribed);
      await h.send('typing', {'userId': 'u'});
      expect(port.sent.single.event, 'typing');
      expect(port.sent.single.payload, {'userId': 'u'});
      sub.cancel();
    });

    test('send after close or while the channel is down never throws', () async {
      final h = hub.open(_spec);
      final sub = h.signals.listen((_) {});
      factory.created.single.emitStatus(PortStatus.subscribed);
      factory.created.single.emitStatus(PortStatus.error);
      await h.send('x', {});
      await sub.cancel();
      await h.send('x', {});
    });

    test('presence payload is tracked on every subscribed, including after a reconnect', () {
      fakeAsync((async) {
        const spec = RealtimeChannelSpec(
          topic: 'dm-online',
          private: true,
          presenceKey: 'me',
          bindings: [PresenceBinding(key: 'me', onSync: _noop, trackPayload: {'online_at': 'now'})],
        );
        final sub = hub.open(spec).signals.listen((_) {});
        final first = factory.created.single;
        first.emitStatus(PortStatus.subscribed);
        expect(first.tracked, [
          {'online_at': 'now'},
        ]);
        first.emitStatus(PortStatus.error);
        async.elapse(const Duration(seconds: 2));
        factory.created[1].emitStatus(PortStatus.subscribed);
        expect(factory.created[1].tracked, hasLength(1));
        sub.cancel();
      });
    });
  });

  group('debouncedSignals', () {
    test('coalesces a burst of 5 events inside 400 ms into one signal and still emits a later burst', () {
      fakeAsync((async) {
        final src = StreamController<RealtimeSignal>.broadcast(sync: true);
        final out = <RealtimeSignal>[];
        final sub = debouncedSignals(src.stream).listen(out.add);
        for (var i = 1; i <= 5; i++) {
          src.add(RealtimeSignal(i, RealtimeSignalKind.event));
          async.elapse(const Duration(milliseconds: 50));
        }
        expect(out, isEmpty);
        async.elapse(const Duration(milliseconds: 400));
        expect(out, hasLength(1));

        src.add(const RealtimeSignal(6, RealtimeSignalKind.event));
        async.elapse(const Duration(milliseconds: 401));
        expect(out, hasLength(2));
        expect(out[1].seq, greaterThan(out[0].seq));
        sub.cancel();
      });
    });

    test('reconnected or resumed inside a burst of events wins', () {
      fakeAsync((async) {
        final src = StreamController<RealtimeSignal>.broadcast(sync: true);
        final out = <RealtimeSignal>[];
        final sub = debouncedSignals(src.stream).listen(out.add);
        src.add(const RealtimeSignal(1, RealtimeSignalKind.event));
        src.add(const RealtimeSignal(2, RealtimeSignalKind.reconnected));
        src.add(const RealtimeSignal(3, RealtimeSignalKind.event));
        async.elapse(const Duration(milliseconds: 401));
        expect(out.single.kind, RealtimeSignalKind.reconnected);

        src.add(const RealtimeSignal(4, RealtimeSignalKind.resumed));
        src.add(const RealtimeSignal(5, RealtimeSignalKind.event));
        async.elapse(const Duration(milliseconds: 401));
        expect(out.last.kind, RealtimeSignalKind.resumed);
        sub.cancel();
      });
    });
  });
}

void _noop(Set<String> _) {}
