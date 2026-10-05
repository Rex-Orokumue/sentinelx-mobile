import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/core/api/messages_models.dart';
import 'package:sentinelx_mobile/core/providers.dart';
import 'package:sentinelx_mobile/core/realtime/realtime_hub.dart';
import 'package:sentinelx_mobile/features/messages/inbox_providers.dart';
import 'package:sentinelx_mobile/features/messages/messages_repository.dart';
import 'package:sentinelx_mobile/features/messages/thread_providers.dart';
import 'package:sentinelx_mobile/features/messages/thread_window.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../fakes/fake_messages_repository.dart';

class _Viewer extends Notifier<String?> {
  _Viewer(this.initial);
  final String? initial;

  @override
  String? build() => initial;
}

final _viewerProvider = NotifierProvider<_Viewer, String?>(() => _Viewer('me'));

const _t = 'thread-1';

DateTime _at(int i) => DateTime.utc(2026, 10, 5, 10).add(Duration(seconds: i));

List<DmMessage> _msgs(int n, {String sender = 'them'}) => [for (var i = n - 1; i >= 0; i--) dmMsg('m$i', sender: sender, at: _at(i))];

class _Rig {
  _Rig(this.repo, {String? viewer = 'me', DateTime Function()? now, this.threadId = _t}) {
    clock = now ?? DateTime.now;
    container = ProviderContainer(retry: (_, _) => null, overrides: [
      messagesRepositoryProvider.overrideWithValue(repo),
      _viewerProvider.overrideWith(() => _Viewer(viewer)),
      dmViewerIdProvider.overrideWith((ref) async => ref.watch(_viewerProvider)),
      dmNudgeProvider.overrideWith((ref) => nudges.stream),
      deliveredThrottleProvider.overrideWithValue(DeliveredThrottle(send: repo.markAllDelivered)),
      dmClockProvider.overrideWithValue(clock),
    ]);
    container.listen(provider, (_, _) {});
    container.listen(dmNudgeProvider, (_, _) {});
  }

  final FakeMessagesRepository repo;
  final String threadId;
  late final DateTime Function() clock;
  final nudges = StreamController<RealtimeSignal>.broadcast();
  late final ProviderContainer container;
  var _seq = 0;

  AsyncNotifierProvider<ThreadNotifier, ThreadView> get provider => threadProvider(threadId);
  ThreadNotifier get notifier => container.read(provider.notifier);
  ThreadView? get view => container.read(provider).value;
  Future<ThreadView> get loaded => container.read(provider.future);
  List<String> get ids => [for (final m in view!.messages) m.id];

  Future<void> nudge([RealtimeSignalKind kind = RealtimeSignalKind.event]) async {
    nudges.add(RealtimeSignal(++_seq, kind));
    await pumpEventQueue();
  }

  void dispose() {
    container.dispose();
    nudges.close();
  }
}

Future<_Rig> _ready(FakeMessagesRepository repo, {DateTime Function()? now}) async {
  final r = _Rig(repo, now: now);
  addTearDown(r.dispose);
  await r.loaded;
  return r;
}

void main() {
  group('loading and paging', () {
    test('first page, then loadOlder appends the next page', () async {
      final repo = FakeMessagesRepository()..messagesByThread[_t] = _msgs(90);
      final r = await _ready(repo);
      expect(r.view!.messages, hasLength(40));
      expect(r.view!.hasOlder, isTrue);
      await r.notifier.loadOlder();
      expect(r.view!.messages, hasLength(80));
      await r.notifier.loadOlder();
      expect(r.view!.messages, hasLength(90));
      expect(r.view!.hasOlder, isFalse);
      await r.notifier.loadOlder();
      expect(repo.messagesCalls, hasLength(3), reason: 'nothing left to load');
    });

    test('a nudge refreshes in place without resetting older pages: 80 rows stay 80', () async {
      final repo = FakeMessagesRepository()..messagesByThread[_t] = _msgs(120);
      final r = await _ready(repo);
      await r.notifier.loadOlder();
      expect(r.view!.messages, hasLength(80));
      repo.messagesByThread[_t]!.insert(0, dmMsg('new', at: _at(500)));
      await r.nudge();
      expect(r.view!.messages, hasLength(81));
      expect(r.ids.first, 'new');
      expect(r.view!.nextBefore, '80', reason: 'the older cursor is not reset');
    });

    test('two consecutive nudges both refresh', () async {
      final repo = FakeMessagesRepository()..messagesByThread[_t] = _msgs(3);
      final r = await _ready(repo);
      repo.messagesByThread[_t]!.insert(0, dmMsg('a', at: _at(50)));
      await r.nudge();
      expect(r.ids.first, 'a');
      repo.messagesByThread[_t]!.insert(0, dmMsg('b', at: _at(60)));
      await r.nudge();
      expect(r.ids.first, 'b');
    });

    test('a nudge during loadOlder is queued and loses nothing', () async {
      final repo = FakeMessagesRepository()..messagesByThread[_t] = _msgs(100);
      final r = await _ready(repo);
      final gate = Completer<void>();
      repo.holds['messages'] = gate;
      final older = r.notifier.loadOlder();
      await pumpEventQueue();
      repo.messagesByThread[_t]!.insert(0, dmMsg('fresh', at: _at(500)));
      await r.nudge();
      gate.complete();
      await older;
      await pumpEventQueue();
      expect(r.ids.first, 'fresh');
      expect(r.ids.toSet().length, r.ids.length, reason: 'no duplicates');
      expect(r.ids, ['fresh', for (var i = 99; i >= 21; i--) 'm$i'], reason: 'one contiguous window, no hole');
      expect(r.view!.loadingOlder, isFalse);
    });

    test('a nudge during the first load is replayed after it', () async {
      final repo = FakeMessagesRepository()..messagesByThread[_t] = _msgs(3);
      final gate = Completer<void>();
      repo.holds['messages'] = gate;
      final r = _Rig(repo);
      addTearDown(r.dispose);
      await pumpEventQueue();
      repo.messagesByThread[_t]!.insert(0, dmMsg('inserted-meanwhile', at: _at(50)));
      await r.nudge();
      gate.complete();
      await r.loaded;
      await pumpEventQueue();
      expect(r.ids.first, 'inserted-meanwhile');
    });

    test('a failed refresh keeps the last good window', () async {
      final repo = FakeMessagesRepository()..messagesByThread[_t] = _msgs(3);
      final r = await _ready(repo);
      repo.failures['messages'] = networkError;
      await r.nudge();
      expect(r.ids, ['m2', 'm1', 'm0']);
      expect(r.container.read(r.provider).hasError, isFalse);
    });

    test('resumed and reconnected reconcile the window: more than a page of new messages leaves no hole', () async {
      final repo = FakeMessagesRepository()..messagesByThread[_t] = _msgs(5);
      final r = await _ready(repo);
      repo.messagesByThread[_t] = [for (var i = 59; i >= 0; i--) dmMsg('n$i', at: _at(300 + i)), ...repo.messagesByThread[_t]!];
      await r.nudge(RealtimeSignalKind.resumed);
      expect(r.view!.messages, hasLength(65));
      expect(r.ids.last, 'm0');
      expect(repo.markAllDeliveredCalls, 1, reason: 'resume stamps delivery through the throttle');
    });
  });

  group('sending', () {
    test('send shows a pending bubble before the future completes, then the server message', () async {
      final repo = FakeMessagesRepository()..messagesByThread[_t] = _msgs(2);
      final r = await _ready(repo);
      final gate = Completer<void>();
      repo.holds['send'] = gate;
      final done = r.notifier.send(const SendDraft(body: 'hello'));
      await pumpEventQueue();
      expect(r.view!.pending.single.status, PendingStatus.sending);
      expect(r.view!.pending.single.draft.body, 'hello');
      expect(r.view!.messages, hasLength(2));
      gate.complete();
      await done;
      expect(r.view!.pending, isEmpty);
      expect(r.view!.messages.first.id, 'srv-1');
      expect(r.view!.messages.first.body, 'hello');
      expect(r.view!.messages.first.senderId, 'me');
      expect(r.view!.messages.first.readAt, isNull);
    });

    test('a refresh that already returned the sent message before the send response arrives yields exactly one bubble', () async {
      final repo = FakeMessagesRepository()..messagesByThread[_t] = _msgs(2);
      final r = await _ready(repo);
      final gate = Completer<void>();
      repo.holds['send:after'] = gate;
      final done = r.notifier.send(const SendDraft(body: 'hello'));
      await pumpEventQueue();
      await r.nudge(); // the realtime refetch sees the committed message first
      expect(r.ids.where((id) => id == 'srv-1'), hasLength(1));
      gate.complete();
      await done;
      expect(r.ids.where((id) => id == 'srv-1'), hasLength(1));
      expect(r.view!.pending, isEmpty);
    });

    test('a failure leaves a failed bubble carrying the error', () async {
      final repo = FakeMessagesRepository()..messagesByThread[_t] = _msgs(1);
      final r = await _ready(repo);
      repo.failures['send'] = apiError('send_failed', status: 500);
      await r.notifier.send(const SendDraft(body: 'x'));
      final p = r.view!.pending.single;
      expect(p.status, PendingStatus.failed);
      expect((p.error as dynamic).code, 'send_failed');
      expect(p.canRetry, isTrue);
    });

    test('retry reuses the same idempotency key and the fake server creates one message', () async {
      final repo = FakeMessagesRepository()..messagesByThread[_t] = _msgs(1);
      final r = await _ready(repo);
      repo.failures['send'] = networkError;
      await r.notifier.send(const SendDraft(body: 'x'));
      final item = r.view!.pending.single;
      repo.failures.clear();
      await r.notifier.retry(item.localId);
      expect(repo.sendCalls, hasLength(2));
      expect(repo.sendCalls[0].key, repo.sendCalls[1].key);
      expect(repo.createdMessageCount, 1);
      expect(r.view!.pending, isEmpty);
    });

    test('an ambiguous failure (committed, then a network error) followed by retry shows one bubble', () async {
      final repo = FakeMessagesRepository()..messagesByThread[_t] = _msgs(1);
      final r = await _ready(repo);
      repo.sendFailsAfterCommit = networkError;
      await r.notifier.send(const SendDraft(body: 'x'));
      expect(r.view!.pending.single.status, PendingStatus.failed);
      await r.notifier.retry(r.view!.pending.single.localId);
      expect(repo.createdMessageCount, 1, reason: 'the retry replayed the first result');
      expect(r.ids.where((id) => id == 'srv-1'), hasLength(1));
      expect(r.view!.pending, isEmpty);
    });

    test('a double retry while in flight sends once', () async {
      final repo = FakeMessagesRepository()..messagesByThread[_t] = _msgs(1);
      final r = await _ready(repo);
      repo.failures['send'] = networkError;
      await r.notifier.send(const SendDraft(body: 'x'));
      final id = r.view!.pending.single.localId;
      repo.failures.clear();
      final gate = Completer<void>();
      repo.holds['send'] = gate;
      final first = r.notifier.retry(id);
      await pumpEventQueue();
      final second = r.notifier.retry(id);
      gate.complete();
      await Future.wait([first, second]);
      expect(repo.sendCalls, hasLength(2), reason: 'the original attempt plus exactly one retry');
    });

    test('a non-retryable code (blocked) fails without retry and invalidates the header', () async {
      final repo = FakeMessagesRepository()..messagesByThread[_t] = _msgs(1);
      final r = await _ready(repo);
      r.container.listen(threadHeaderProvider(_t), (_, _) {});
      await r.container.read(threadHeaderProvider(_t).future);
      expect(repo.threadCalls, hasLength(1));
      repo.failures['send'] = apiError('blocked', status: 403);
      repo.headers[_t] = header(_t, blockedByThem: true);
      await r.notifier.send(const SendDraft(body: 'x'));
      expect(r.view!.pending.single.canRetry, isFalse);
      await r.notifier.retry(r.view!.pending.single.localId);
      expect(repo.sendCalls, hasLength(1), reason: 'a non-retryable item is never resent');
      await pumpEventQueue();
      expect(repo.threadCalls, hasLength(2), reason: 'the header was refetched');
      expect((await r.container.read(threadHeaderProvider(_t).future)).blockedByThem, isTrue);
    });

    test('discard removes a failed item', () async {
      final repo = FakeMessagesRepository()..messagesByThread[_t] = _msgs(1);
      final r = await _ready(repo);
      repo.failures['send'] = networkError;
      await r.notifier.send(const SendDraft(body: 'x'));
      r.notifier.discard(r.view!.pending.single.localId);
      expect(r.view!.pending, isEmpty);
    });

    test('prepare runs before each attempt and its result is what is sent', () async {
      final repo = FakeMessagesRepository()..messagesByThread[_t] = _msgs(1);
      final r = await _ready(repo);
      var prepared = 0;
      await r.notifier.send(
        const SendDraft(body: null),
        prepare: (d) async {
          prepared++;
          return d.copyWith(imagePath: 'me/x.jpg');
        },
      );
      expect(prepared, 1);
      expect(repo.sendCalls.single.draft.imagePath, 'me/x.jpg');
    });
  });

  group('serialization', () {
    test('send then edit then unsend reach the repository in order even if the first is slow, and a failure does not stop the next', () async {
      final repo = FakeMessagesRepository()..messagesByThread[_t] = [dmMsg('mine', sender: 'me', at: _at(0)), ..._msgs(1).map((m) => m)];
      final r = await _ready(repo);
      final gate = Completer<void>();
      repo.holds['send'] = gate;
      repo.failures['edit'] = apiError('action_failed', status: 500);
      final s = r.notifier.send(const SendDraft(body: 'a'));
      final e = r.notifier.edit('mine', 'edited');
      final u = r.notifier.unsend('mine');
      await pumpEventQueue();
      expect(repo.opLog.where((o) => !o.startsWith('markRead')), hasLength(1), reason: 'only the send has started');
      gate.complete();
      await Future.wait([s, e, u]);
      final log = repo.opLog;
      expect(log.indexWhere((o) => o.startsWith('send')), lessThan(log.indexOf('edit:mine')));
      expect(log.indexOf('edit:mine'), lessThan(log.indexOf('unsend:mine')));
      expect(repo.unsendCalls, ['mine'], reason: 'the failed edit did not poison the chain');
    });

    test('two threads run independently: a slow op in A does not delay B', () async {
      final repo = FakeMessagesRepository()
        ..messagesByThread['A'] = _msgs(1)
        ..messagesByThread['B'] = _msgs(1);
      final r = _Rig(repo, threadId: 'A');
      addTearDown(r.dispose);
      await r.loaded;
      r.container.listen(threadProvider('B'), (_, _) {});
      await r.container.read(threadProvider('B').future);
      final b = r.container.read(threadProvider('B').notifier);
      final gate = Completer<void>();
      repo.holds['send'] = gate;
      final slow = r.notifier.send(const SendDraft(body: 'slow'));
      await pumpEventQueue();
      await b.send(const SendDraft(body: 'fast'));
      expect(repo.sendCalls.map((c) => c.threadId), ['A', 'B']);
      expect(r.container.read(threadProvider('B')).value!.pending, isEmpty, reason: 'B finished while A is still held');
      expect(r.view!.pending.single.status, PendingStatus.sending);
      gate.complete();
      await slow;
    });

    test('markRead called three times while one is queued issues at most two requests', () async {
      final repo = FakeMessagesRepository()..messagesByThread[_t] = _msgs(1);
      final r = await _ready(repo);
      final gate = Completer<void>();
      repo.holds['markRead'] = gate;
      final calls = [r.notifier.markRead(), r.notifier.markRead(), r.notifier.markRead()];
      await pumpEventQueue();
      gate.complete();
      await Future.wait(calls);
      expect(repo.markReadCalls.length, lessThanOrEqualTo(2));
      expect(repo.markReadCalls, isNotEmpty);
    });
  });

  group('optimistic edit and unsend', () {
    Future<_Rig> mine() async {
      final repo = FakeMessagesRepository()..messagesByThread[_t] = [dmMsg('mine', sender: 'me', body: 'original', at: _at(5)), ..._msgs(2)];
      return _ready(repo);
    }

    test('edit applies before the API answers and sticks on success', () async {
      final r = await mine();
      final gate = Completer<void>();
      r.repo.holds['edit'] = gate;
      final call = r.notifier.edit('mine', 'changed');
      await pumpEventQueue();
      expect(r.view!.messages.firstWhere((m) => m.id == 'mine').body, 'changed');
      expect(r.view!.messages.firstWhere((m) => m.id == 'mine').isEdited, isTrue);
      gate.complete();
      expect(await call, isTrue);
    });

    test('a failed edit reverts only that message', () async {
      final r = await mine();
      r.repo.failures['edit'] = apiError('action_failed', status: 500);
      expect(await r.notifier.edit('mine', 'changed'), isFalse);
      final m = r.view!.messages.firstWhere((m) => m.id == 'mine');
      expect(m.body, 'original');
      expect(m.isEdited, isFalse);
      expect(r.notifier.lastActionError, isA<Object>());
    });

    test('a failed edit does not clobber a refresh that already delivered the edit', () async {
      final r = await mine();
      final gate = Completer<void>();
      r.repo.holds['edit'] = gate;
      final call = r.notifier.edit('mine', 'server-version');
      await pumpEventQueue();
      // the server applied it and a realtime refresh landed first, then the response turned into an error
      r.repo.messagesByThread[_t]![0] = dmMsg('mine', sender: 'me', body: 'server-version', editedAt: _at(70), at: _at(5));
      await r.nudge();
      r.repo.failures['edit'] = networkError;
      gate.complete();
      await call;
      expect(r.view!.messages.firstWhere((m) => m.id == 'mine').body, 'server-version');
    });

    test('a 409 edit_window_closed reverts, returns false and records the error', () async {
      final r = await mine();
      r.repo.failures['edit'] = apiError('edit_window_closed', status: 409);
      expect(await r.notifier.edit('mine', 'late'), isFalse);
      expect(r.view!.messages.firstWhere((m) => m.id == 'mine').body, 'original');
      expect((r.notifier.lastActionError as dynamic).code, 'edit_window_closed');
    });

    test('unsend removes the content optimistically and a failure restores it', () async {
      final r = await mine();
      final gate = Completer<void>();
      r.repo.holds['unsend'] = gate;
      r.repo.failures['unsend'] = networkError;
      final call = r.notifier.unsend('mine');
      await pumpEventQueue();
      expect(r.view!.messages.firstWhere((m) => m.id == 'mine').kind, MessageKind.removed);
      gate.complete();
      expect(await call, isFalse);
      expect(r.view!.messages.firstWhere((m) => m.id == 'mine').body, 'original');
    });

    test('a successful unsend stays removed', () async {
      final r = await mine();
      expect(await r.notifier.unsend('mine'), isTrue);
      expect(r.view!.messages.firstWhere((m) => m.id == 'mine').kind, MessageKind.removed);
    });

    test('forward sends a fresh key and returns true; a failure returns false with the error recorded', () async {
      final r = await mine();
      expect(await r.notifier.forward('mine', 'other-thread'), isTrue);
      expect(r.repo.forwardCalls.single.toThreadId, 'other-thread');
      expect(r.repo.forwardCalls.single.key, isNotEmpty);
      r.repo.failures['forward'] = apiError('not_forwardable', status: 409);
      expect(await r.notifier.forward('mine', 'other-thread'), isFalse);
      expect((r.notifier.lastActionError as dynamic).code, 'not_forwardable');
      expect(r.repo.forwardCalls[0].key, isNot(r.repo.forwardCalls[1].key));
    });
  });

  group('lifecycle and viewer', () {
    test('mutators on a disposed notifier do nothing and do not throw', () async {
      final repo = FakeMessagesRepository()..messagesByThread[_t] = _msgs(3);
      final r = _Rig(repo);
      await r.loaded;
      final n = r.notifier;
      r.dispose();
      final calls = repo.messagesCalls.length;
      await n.loadOlder();
      await n.refreshInPlace();
      await n.refreshWindow();
      await n.send(const SendDraft(body: 'x'));
      expect(await n.edit('m0', 'x'), isFalse);
      expect(await n.unsend('m0'), isFalse);
      expect(await n.forward('m0', 't2'), isFalse);
      await n.markRead();
      n.discard('nope');
      expect(repo.messagesCalls, hasLength(calls));
      expect(repo.sendCalls, isEmpty);
    });

    test('a real refreshed Session (same user) does not refetch; a different user does', () async {
      final repo = FakeMessagesRepository()..messagesByThread[_t] = _msgs(3);
      final session = StreamController<Session?>.broadcast();
      addTearDown(session.close);
      var seq = 0;
      Session sessionFor(String id) => Session(
            accessToken: 'tok-$id-${seq++}',
            tokenType: 'bearer',
            user: User(id: id, appMetadata: const {}, userMetadata: const {}, aud: '', createdAt: ''),
          );
      final c = ProviderContainer(retry: (_, _) => null, overrides: [
        messagesRepositoryProvider.overrideWithValue(repo),
        sessionProvider.overrideWith((ref) => session.stream),
        dmNudgeProvider.overrideWith((ref) => const Stream<RealtimeSignal>.empty()),
        deliveredThrottleProvider.overrideWithValue(DeliveredThrottle(send: repo.markAllDelivered)),
      ]);
      addTearDown(c.dispose);
      c.listen(sessionProvider, (_, _) {});
      c.listen(threadProvider(_t), (_, _) {});
      await pumpEventQueue();
      session.add(sessionFor('u1'));
      await pumpEventQueue();
      expect(repo.messagesCalls, hasLength(1));
      session.add(sessionFor('u1'));
      await pumpEventQueue();
      expect(repo.messagesCalls, hasLength(1));
      session.add(sessionFor('u2'));
      await pumpEventQueue();
      expect(repo.messagesCalls, hasLength(2));
    });

    test('media refresh is rate-limited to one per 30 s; a resumed signal always refetches', () async {
      var now = DateTime.utc(2026, 10, 5, 12);
      final repo = FakeMessagesRepository()..messagesByThread[_t] = _msgs(2);
      final r = await _ready(repo, now: () => now);
      expect(repo.messagesCalls, hasLength(1));
      await r.notifier.requestMediaRefresh();
      await r.notifier.requestMediaRefresh();
      expect(repo.messagesCalls, hasLength(2), reason: 'the second is inside the window');
      now = now.add(const Duration(seconds: 29));
      await r.notifier.requestMediaRefresh();
      expect(repo.messagesCalls, hasLength(2));
      now = now.add(const Duration(seconds: 2));
      await r.notifier.requestMediaRefresh();
      expect(repo.messagesCalls, hasLength(3));
      await r.nudge(RealtimeSignalKind.resumed);
      expect(repo.messagesCalls, hasLength(4), reason: 'resume is not rate-limited');
    });

    test('openThreadIdProvider tracks the visible thread and only the owner clears it', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      expect(c.read(openThreadIdProvider), isNull);
      c.read(openThreadIdProvider.notifier).open('a');
      c.read(openThreadIdProvider.notifier).open('b');
      c.read(openThreadIdProvider.notifier).close('a');
      expect(c.read(openThreadIdProvider), 'b', reason: 'a stale screen cannot clear the newer one');
      c.read(openThreadIdProvider.notifier).close('b');
      expect(c.read(openThreadIdProvider), isNull);
    });

    test('the text draft survives the thread notifier being disposed', () async {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      c.read(threadDraftProvider(_t).notifier).set('half-typed');
      c.read(threadDraftProvider('other').notifier).set('elsewhere');
      expect(c.read(threadDraftProvider(_t)), 'half-typed');
      expect(c.read(threadDraftProvider('other')), 'elsewhere');
    });
  });

  group('ThreadActionQueue', () {
    test('runs ops for one thread in submission order and a throwing op does not poison the chain', () async {
      final q = ThreadActionQueue();
      final order = <int>[];
      final gate = Completer<void>();
      final a = q.run<int>('t', () async {
        await gate.future;
        order.add(1);
        return 1;
      });
      final b = q.run<int>('t', () async {
        order.add(2);
        throw StateError('boom');
      });
      final c = q.run<int>('t', () async {
        order.add(3);
        return 3;
      });
      gate.complete();
      await expectLater(b.then((_) => 'ok', onError: (Object _) => 'err'), completion('err'));
      expect(await a, 1);
      expect(await c, 3);
      expect(order, [1, 2, 3]);
    });
  });
}
