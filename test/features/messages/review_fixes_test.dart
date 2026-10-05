import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/core/api/messages_models.dart';
import 'package:sentinelx_mobile/core/realtime/realtime_hub.dart';
import 'package:sentinelx_mobile/features/messages/conversation_screen.dart';
import 'package:sentinelx_mobile/features/messages/inbox_providers.dart';
import 'package:sentinelx_mobile/features/messages/messages_repository.dart';
import 'package:sentinelx_mobile/features/messages/thread_providers.dart';
import 'package:sentinelx_mobile/features/messages/thread_window.dart' show PendingStatus;
import 'package:sentinelx_mobile/features/messages/voice/voice_ports.dart';

import '../../fakes/fake_messages_repository.dart';
import '../../fakes/fake_voice.dart';
import '../../support/pump_conversation.dart';

DateTime _ago(Duration d) => kNow.subtract(d);

void main() {
  group('older history is not "new messages"', () {
    testWidgets('loading an older page while scrolled up shows no pill and does not mark read again', (tester) async {
      final msgs = [for (var i = 99; i >= 0; i--) dmMsg('m$i', body: 'message $i', at: _ago(Duration(minutes: 10 + (99 - i))))];
      final repo = FakeMessagesRepository()..messagesByThread['t1'] = msgs;
      await pumpConversation(tester, repo);
      final readsBefore = repo.markReadCalls.length;
      await tester.drag(find.byKey(const Key('dm-list')), const Offset(0, 5000));
      await tester.pumpAndSettle();
      expect(repo.messagesCalls.where((c) => c.before == '40'), hasLength(1), reason: 'the older page did load');
      expect(find.byKey(const Key('dm-new-pill')), findsNothing);
      expect(repo.markReadCalls.length, readsBefore);
    });

    testWidgets('a genuinely newer message while scrolled up still shows the pill', (tester) async {
      final msgs = [for (var i = 60; i >= 0; i--) dmMsg('m$i', body: 'message $i', at: _ago(Duration(minutes: 10 + (60 - i))))];
      final repo = FakeMessagesRepository()..messagesByThread['t1'] = msgs;
      final rig = await pumpConversation(tester, repo);
      await tester.drag(find.byKey(const Key('dm-list')), const Offset(0, 400));
      await tester.pumpAndSettle();
      repo.messagesByThread['t1']!.insert(0, dmMsg('fresh', body: 'fresh arrival', at: _ago(const Duration(minutes: 1))));
      await rig.nudge(tester);
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();
      expect(find.byKey(const Key('dm-new-pill')), findsOneWidget);
    });
  });

  testWidgets('recording does not rebuild the whole conversation on every timer tick', (tester) async {
    var screenRebuilds = 0;
    debugOnRebuildDirtyWidget = (Element e, bool builtOnce) {
      if (e.widget is ConversationScreen) screenRebuilds++;
    };
    addTearDown(() => debugOnRebuildDirtyWidget = null);
    final recorder = FakeVoiceRecorder();
    var offset = Duration.zero;
    final repo = FakeMessagesRepository()
      ..headers['t1'] = header('t1', name: 'Ada', otherId: 'ada-id')
      ..messagesByThread['t1'] = [dmMsg('a', body: 'hi', at: _ago(const Duration(minutes: 5)))];
    await pumpConversation(tester, repo, clock: () => kNow.add(offset), overrides: [
      voiceRecorderFactoryProvider.overrideWithValue(() => recorder),
      voiceTempDirProvider.overrideWithValue(() => Directory.systemTemp),
    ]);
    await tester.tap(find.byKey(const Key('dm-mic-button')));
    await tester.pump();
    await tester.pump();
    final before = screenRebuilds;
    for (var i = 0; i < 30; i++) {
      offset += const Duration(milliseconds: 100);
      recorder.emitLevel(0.5);
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(screenRebuilds - before, lessThanOrEqualTo(2), reason: 'timer ticks and amplitude levels belong to the voice panel only');
    await tester.tap(find.byKey(const Key('dm-voice-cancel')));
    await tester.pumpAndSettle();
  });

  group('leaving the screen mid-send does not lose the outcome', () {
    late FakeMessagesRepository repo;
    late ProviderContainer container;

    void make() {
      repo = FakeMessagesRepository()..messagesByThread['t1'] = [dmMsg('a', body: 'hi', at: _ago(const Duration(minutes: 5)))];
      container = ProviderContainer(retry: (_, _) => null, overrides: [
        messagesRepositoryProvider.overrideWithValue(repo),
        dmViewerIdProvider.overrideWith((ref) async => 'me'),
        dmNudgeProvider.overrideWith((ref) => const Stream<RealtimeSignal>.empty()),
        deliveredThrottleProvider.overrideWithValue(DeliveredThrottle(send: repo.markAllDelivered)),
      ]);
      addTearDown(container.dispose);
    }

    test('a send that fails after the screen is left keeps its failed bubble for when the thread reopens', () async {
      make();
      var sub = container.listen(threadProvider('t1'), (_, _) {});
      await container.read(threadProvider('t1').future);
      final gate = Completer<void>();
      repo.holds['send'] = gate;
      repo.failures['send'] = networkError;
      unawaited(container.read(threadProvider('t1').notifier).send(const SendDraft(body: 'hello')));
      await pumpEventQueue();
      sub.close(); // the player pressed Back during the send
      await pumpEventQueue();
      gate.complete();
      await pumpEventQueue();
      sub = container.listen(threadProvider('t1'), (_, _) {});
      final view = container.read(threadProvider('t1')).value!;
      expect(view.pending.single.status, PendingStatus.failed);
      expect(view.pending.single.draft.body, 'hello');
      expect(repo.messagesCalls, hasLength(1), reason: 'the state survived: no reload');
    });

    test('onDone still runs when a send succeeds after the screen was left, and the notifier is then released', () async {
      make();
      final sub = container.listen(threadProvider('t1'), (_, _) {});
      await container.read(threadProvider('t1').future);
      final gate = Completer<void>();
      repo.holds['send'] = gate;
      var done = 0;
      unawaited(container.read(threadProvider('t1').notifier).send(const SendDraft(body: 'hello'), onDone: () => done++));
      await pumpEventQueue();
      sub.close();
      await pumpEventQueue();
      expect(container.exists(threadProvider('t1')), isTrue, reason: 'kept alive while a message is unconfirmed');
      gate.complete();
      await pumpEventQueue();
      expect(done, 1);
      await pumpEventQueue();
      expect(container.exists(threadProvider('t1')), isFalse, reason: 'released once nothing is pending');
    });

    test('a thread with nothing pending is disposed as usual when left', () async {
      make();
      final sub = container.listen(threadProvider('t1'), (_, _) {});
      await container.read(threadProvider('t1').future);
      sub.close();
      await pumpEventQueue();
      expect(container.exists(threadProvider('t1')), isFalse);
    });
  });

  group('answering a request after leaving the thread still refreshes the inbox', () {
    ThreadHeader incoming() => header('t1', name: 'Quinn', otherId: 'q', requestState: RequestState.pending, direction: RequestDirection.incoming);

    FakeMessagesRepository repo() => FakeMessagesRepository(inbox: [thread('t1')])
      ..headers['t1'] = incoming()
      ..messagesByThread['t1'] = [dmMsg('m', body: 'hi', at: _ago(const Duration(minutes: 2)))];

    testWidgets('Decline completing after the screen was popped invalidates the inbox', (tester) async {
      final r = repo();
      final rig = await pumpConversation(tester, r);
      rig.container.listen(inboxProvider, (_, _) {});
      await rig.container.read(inboxProvider.future);
      final gate = Completer<void>();
      r.holds['decline'] = gate;
      await tester.tap(find.byKey(const Key('dm-decline')));
      await tester.pump();
      rig.router.go('/');
      await tester.pumpAndSettle();
      final before = r.threadsCalls.length;
      gate.complete();
      await tester.pumpAndSettle();
      expect(r.declineCalls, ['t1']);
      expect(r.threadsCalls.length, greaterThan(before), reason: 'the inbox was refetched even though the screen was gone');
    });

    testWidgets('Accept completing after the screen was popped invalidates the inbox', (tester) async {
      final r = repo();
      final rig = await pumpConversation(tester, r);
      rig.container.listen(inboxProvider, (_, _) {});
      await rig.container.read(inboxProvider.future);
      final gate = Completer<void>();
      r.holds['accept'] = gate;
      await tester.tap(find.byKey(const Key('dm-accept')));
      await tester.pump();
      rig.router.go('/');
      await tester.pumpAndSettle();
      final before = r.threadsCalls.length;
      gate.complete();
      await tester.pumpAndSettle();
      expect(r.acceptCalls, ['t1']);
      expect(r.threadsCalls.length, greaterThan(before));
    });
  });
}
