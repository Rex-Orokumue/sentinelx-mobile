import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/core/realtime/realtime_hub.dart';
import 'package:sentinelx_mobile/features/messages/delivery_watcher.dart';
import 'package:sentinelx_mobile/features/messages/inbox_providers.dart';

import '../../fakes/fake_messages_repository.dart';

void main() {
  group('DeliveredThrottle trailing call', () {
    test('a trigger inside the 15 s gap is not dropped: it runs once when the gap ends', () {
      fakeAsync((async) {
        var now = DateTime.utc(2026, 10, 5, 12);
        var sent = 0;
        final t = DeliveredThrottle(send: () async => sent++, now: () => now);
        t.trigger();
        async.flushMicrotasks();
        expect(sent, 1);

        now = now.add(const Duration(seconds: 5));
        async.elapse(const Duration(seconds: 5));
        t.trigger();
        t.trigger();
        t.trigger();
        async.flushMicrotasks();
        expect(sent, 1, reason: 'still inside the window');

        now = now.add(const Duration(seconds: 10));
        async.elapse(const Duration(seconds: 10));
        async.flushMicrotasks();
        expect(sent, 2, reason: 'one trailing call, coalesced from three triggers');

        now = now.add(const Duration(minutes: 1));
        async.elapse(const Duration(minutes: 1));
        async.flushMicrotasks();
        expect(sent, 2, reason: 'nothing further was pending');
      });
    });

    test('no trailing call is scheduled when the gap had already passed', () {
      fakeAsync((async) {
        var now = DateTime.utc(2026, 10, 5, 12);
        var sent = 0;
        final t = DeliveredThrottle(send: () async => sent++, now: () => now);
        t.trigger();
        async.flushMicrotasks();
        now = now.add(const Duration(seconds: 20));
        t.trigger();
        async.flushMicrotasks();
        expect(sent, 2);
        expect(async.nonPeriodicTimerCount, 0);
      });
    });
  });

  group('app-wide delivery watcher (the receipt does not need a screen open)', () {
    late FakeMessagesRepository repo;
    late StreamController<RealtimeSignal> nudges;
    late ProviderContainer container;
    var now = DateTime.utc(2026, 10, 5, 12);
    var seq = 0;

    ProviderContainer make({String? viewer = 'me'}) {
      repo = FakeMessagesRepository();
      nudges = StreamController<RealtimeSignal>.broadcast();
      now = DateTime.utc(2026, 10, 5, 12);
      container = ProviderContainer(retry: (_, _) => null, overrides: [
        messagesRepositoryProvider.overrideWithValue(repo),
        dmViewerIdProvider.overrideWith((ref) async => viewer),
        dmNudgeProvider.overrideWith((ref) => nudges.stream),
        deliveredThrottleProvider.overrideWithValue(DeliveredThrottle(send: repo.markAllDelivered, now: () => now)),
      ]);
      container.listen(deliveryWatcherProvider, (_, _) {});
      container.listen(dmNudgeProvider, (_, _) {});
      addTearDown(() {
        container.dispose();
        nudges.close();
      });
      return container;
    }

    Future<void> signal(RealtimeSignalKind kind) async {
      nudges.add(RealtimeSignal(++seq, kind));
      await pumpEventQueue();
    }

    test('stamps once as soon as a signed-in app starts, with no screen open', () async {
      make();
      await pumpEventQueue();
      expect(repo.markAllDeliveredCalls, 1);
    });

    test('a signed-out app never stamps', () async {
      make(viewer: null);
      await pumpEventQueue();
      await signal(RealtimeSignalKind.event);
      expect(repo.markAllDeliveredCalls, 0);
    });

    test('a message arriving later stamps again once the throttle window has passed', () async {
      make();
      await pumpEventQueue();
      now = now.add(const Duration(seconds: 20));
      await signal(RealtimeSignalKind.event);
      expect(repo.markAllDeliveredCalls, 2);
    });

    test('resume and reconnect signals stamp too', () async {
      make();
      await pumpEventQueue();
      now = now.add(const Duration(seconds: 20));
      await signal(RealtimeSignalKind.resumed);
      now = now.add(const Duration(seconds: 20));
      await signal(RealtimeSignalKind.reconnected);
      expect(repo.markAllDeliveredCalls, 3);
    });
  });
}
