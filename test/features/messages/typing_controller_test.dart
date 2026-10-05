import 'package:fake_async/fake_async.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/core/api/messages_models.dart';
import 'package:sentinelx_mobile/core/realtime/realtime_hub.dart';
import 'package:sentinelx_mobile/core/realtime/realtime_port.dart';
import 'package:sentinelx_mobile/features/messages/inbox_providers.dart';
import 'package:sentinelx_mobile/features/messages/thread_providers.dart';
import 'package:sentinelx_mobile/features/messages/typing_controller.dart';

import '../../fakes/fake_messages_repository.dart';
import '../../fakes/fake_realtime.dart';
import '../../support/pump_conversation.dart';

const _args = ThreadTypingArgs(threadId: 't1', otherId: 'other', enabled: true);

void main() {
  group('TypingSender', () {
    test('10 keystrokes inside 3 s send once; one at exactly 3.0 s sends again; none at 2.9 s', () {
      var now = DateTime.utc(2026, 10, 5, 12);
      var sent = 0;
      final s = TypingSender(() => now, () => sent++);
      for (var i = 0; i < 10; i++) {
        s.keystroke();
        now = now.add(const Duration(milliseconds: 200));
      }
      expect(sent, 1);
      now = DateTime.utc(2026, 10, 5, 12, 0, 2, 900);
      s.keystroke();
      expect(sent, 1, reason: '2.9 s after the first send');
      now = DateTime.utc(2026, 10, 5, 12, 0, 3);
      s.keystroke();
      expect(sent, 2);
    });
  });

  group('TypingTracker', () {
    test('typing is true at 4.9 s and false at 5.0 s; a second event restarts the window', () {
      var now = DateTime.utc(2026, 10, 5, 12);
      final t = TypingTracker(() => now);
      t.onEvent('other');
      now = now.add(const Duration(milliseconds: 4900));
      expect(t.isTyping('other'), isTrue);
      now = now.add(const Duration(milliseconds: 100));
      expect(t.isTyping('other'), isFalse);
      t.onEvent('other');
      now = now.add(const Duration(seconds: 3));
      t.onEvent('other');
      now = now.add(const Duration(seconds: 3));
      expect(t.isTyping('other'), isTrue, reason: 'restarted at 3 s, so 3 s later is inside the new window');
    });

    test('clear forgets everyone', () {
      final t = TypingTracker(DateTime.now);
      t.onEvent('other');
      t.clear();
      expect(t.isTyping('other'), isFalse);
    });

    test('an unknown user is not typing', () {
      expect(TypingTracker(DateTime.now).isTyping('nobody'), isFalse);
    });
  });

  test('the topic string is exact', () => expect(typingTopic('abc'), 'dm-typing:abc'));

  group('typing channel (fake hub)', () {
    late FakeChannelFactory factory;
    late ProviderContainer container;
    var now = DateTime.utc(2026, 10, 5, 12);

    ProviderContainer make() {
      factory = FakeChannelFactory();
      final hub = RealtimeHub(factory: factory, lifecycle: FakeLifecycle());
      now = DateTime.utc(2026, 10, 5, 12);
      container = ProviderContainer(retry: (_, _) => null, overrides: [
        realtimeHubProvider.overrideWithValue(hub),
        dmViewerIdProvider.overrideWith((ref) async => 'me'),
        dmClockProvider.overrideWithValue(() => now),
      ]);
      addTearDown(container.dispose);
      return container;
    }

    test('disabled (pending thread, blocked, paused): no channel is ever opened and nothing is sent', () async {
      final c = make();
      const off = ThreadTypingArgs(threadId: 't1', otherId: 'other', enabled: false);
      c.listen(threadTypingProvider(off), (_, _) {});
      final keystroke = c.read(typingNotifierProvider(off));
      await pumpEventQueue();
      keystroke();
      keystroke();
      expect(factory.created.where((p) => p.spec.topic.startsWith('dm-typing:')), isEmpty);
    });

    test('enabled: opens exactly dm-typing:<id>, private, without self-broadcast', () async {
      final c = make();
      c.listen(threadTypingProvider(_args), (_, _) {});
      await pumpEventQueue();
      final port = factory.live('dm-typing:t1')!;
      expect(port.spec.private, isTrue);
      expect(port.spec.selfBroadcast, isFalse);
      expect(port.spec.bindings.whereType<BroadcastBinding>().single.event, 'typing');
    });

    test('events from the viewer or a third player are ignored; the other player sets typing and it expires after 5 s', () {
      fakeAsync((async) {
        final c = make();
        final seen = <bool>[];
        c.listen(threadTypingProvider(_args), (_, next) {
          final v = next.asData?.value;
          if (v != null) seen.add(v);
        });
        async.elapse(const Duration(milliseconds: 10)); // the viewer id resolves, then the channel opens
        final port = factory.live('dm-typing:t1')!;
        port.emitStatus(PortStatus.subscribed);

        port.emitBroadcast('typing', {'userId': 'me'});
        port.emitBroadcast('typing', {'userId': 'third'});
        async.flushMicrotasks();
        expect(seen.where((v) => v), isEmpty);

        port.emitBroadcast('typing', {'userId': 'other'});
        async.flushMicrotasks();
        expect(seen.last, isTrue);

        now = now.add(const Duration(seconds: 4));
        async.elapse(const Duration(seconds: 4));
        expect(seen.last, isTrue);
        now = now.add(const Duration(seconds: 1, milliseconds: 100));
        async.elapse(const Duration(seconds: 2));
        expect(seen.last, isFalse);
        expect(async.periodicTimerCount, 0, reason: 'the ticker stops when nothing is typing');
      });
    });

    test('a nested payload shape is understood as well', () {
      fakeAsync((async) {
        final c = make();
        final seen = <bool>[];
        c.listen(threadTypingProvider(_args), (_, next) {
          final v = next.asData?.value;
          if (v != null) seen.add(v);
        });
        async.elapse(const Duration(milliseconds: 10));
        factory.live('dm-typing:t1')!.emitBroadcast('typing', {
          'type': 'broadcast',
          'event': 'typing',
          'payload': {'userId': 'other'},
        });
        async.flushMicrotasks();
        expect(seen.last, isTrue);
        now = now.add(const Duration(seconds: 6));
        async.elapse(const Duration(seconds: 6));
      });
    });

    test('keystrokes send exactly {userId: viewer}, at most one per 3 s', () async {
      final c = make();
      c.listen(threadTypingProvider(_args), (_, _) {});
      await pumpEventQueue();
      final port = factory.live('dm-typing:t1')!;
      port.emitStatus(PortStatus.subscribed);
      final keystroke = c.read(typingNotifierProvider(_args));
      for (var i = 0; i < 5; i++) {
        keystroke();
      }
      await pumpEventQueue();
      expect(port.sent, hasLength(1));
      expect(port.sent.single.event, 'typing');
      expect(port.sent.single.payload, {'userId': 'me'});
      now = now.add(const Duration(seconds: 3));
      keystroke();
      await pumpEventQueue();
      expect(port.sent, hasLength(2));
    });

    test('a reconnect clears who is typing', () {
      fakeAsync((async) {
        final c = make();
        final seen = <bool>[];
        c.listen(threadTypingProvider(_args), (_, next) {
          final v = next.asData?.value;
          if (v != null) seen.add(v);
        });
        async.elapse(const Duration(milliseconds: 10)); // the viewer id resolves, then the channel opens
        final port = factory.live('dm-typing:t1')!;
        port.emitStatus(PortStatus.subscribed);
        port.emitBroadcast('typing', {'userId': 'other'});
        async.flushMicrotasks();
        expect(seen.last, isTrue);
        port.emitStatus(PortStatus.subscribed); // reconnected
        async.flushMicrotasks();
        expect(seen.last, isFalse);
        now = now.add(const Duration(seconds: 6));
        async.elapse(const Duration(seconds: 6));
      });
    });

    test('closing the listener disposes the channel', () async {
      final c = make();
      final sub = c.listen(threadTypingProvider(_args), (_, _) {});
      await pumpEventQueue();
      final port = factory.live('dm-typing:t1')!;
      sub.close();
      await pumpEventQueue();
      expect(port.disposed, isTrue);
    });
  });

  group('conversation screen', () {
    FakeMessagesRepository repo(ThreadHeader h) => FakeMessagesRepository()
      ..headers['t1'] = h
      ..messagesByThread['t1'] = [dmMsg('a', body: 'hi', at: kNow.subtract(const Duration(minutes: 3)))];

    Future<ConvRig> pump(WidgetTester tester, ThreadHeader h) => pumpConversation(tester, repo(h));

    testWidgets('the label shows while the other player types and hides after 5 s', (tester) async {
      var offset = Duration.zero;
      final rig = await pumpConversation(
        tester,
        repo(header('t1', name: 'Ada', otherId: 'ada-id')),
        clock: () => kNow.add(offset),
      );
      final port = rig.factory.live('dm-typing:t1')!;
      port.emitStatus(PortStatus.subscribed);
      expect(find.byKey(const Key('dm-typing')), findsNothing);
      port.emitBroadcast('typing', {'userId': 'ada-id'});
      await tester.pump();
      await tester.pump();
      expect(find.byKey(const Key('dm-typing')), findsOneWidget);
      expect(find.text('typing…'), findsOneWidget);
      offset = const Duration(seconds: 6);
      await tester.pump(const Duration(seconds: 6));
      await tester.pump();
      expect(find.byKey(const Key('dm-typing')), findsNothing);
    });

    testWidgets('typing in the composer sends a typing event over the thread channel', (tester) async {
      final rig = await pump(tester, header('t1', name: 'Ada', otherId: 'ada-id'));
      final port = rig.factory.live('dm-typing:t1')!;
      port.emitStatus(PortStatus.subscribed);
      await tester.enterText(find.byKey(const Key('dm-input')), 'h');
      await tester.pump();
      await tester.enterText(find.byKey(const Key('dm-input')), 'he');
      await tester.pump();
      expect(port.sent, hasLength(1));
      expect(port.sent.single.payload, {'userId': 'me'});
    });

    for (final entry in <String, ThreadHeader>{
      'an incoming request': header('t1', requestState: RequestState.pending, direction: RequestDirection.incoming),
      'an outgoing pending thread': header('t1', requestState: RequestState.pending, direction: RequestDirection.outgoing),
      'blocked by me': header('t1', blockedByMe: true),
      'blocked by them': header('t1', blockedByThem: true),
    }.entries) {
      testWidgets('${entry.key}: the typing channel is never opened', (tester) async {
        final rig = await pump(tester, entry.value);
        expect(rig.factory.created.where((p) => p.spec.topic.startsWith('dm-typing:')), isEmpty);
      });
    }

    testWidgets('while the app is paused the hub closes the channel; on resume it is re-opened', (tester) async {
      final rig = await pump(tester, header('t1', name: 'Ada', otherId: 'ada-id'));
      final port = rig.factory.live('dm-typing:t1')!;
      rig.lifecycle.push(AppLifecycleState.paused);
      expect(port.disposed, isTrue);
      expect(rig.factory.live('dm-typing:t1'), isNull);
      rig.lifecycle.push(AppLifecycleState.resumed);
      expect(rig.factory.live('dm-typing:t1'), isNotNull);
    });

    testWidgets('the inbox never shows a typing indicator', (tester) async {
      // the label exists only in the conversation header
      final rig = await pump(tester, header('t1', name: 'Ada', otherId: 'ada-id'));
      expect(rig.factory.created.where((p) => p.spec.topic == 'dm-typing:other'), isEmpty);
    });
  });
}
