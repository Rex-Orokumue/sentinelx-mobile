import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/core/api/messages_models.dart';
import 'package:sentinelx_mobile/core/providers.dart';
import 'package:sentinelx_mobile/core/realtime/realtime_hub.dart';
import 'package:sentinelx_mobile/features/messages/inbox_providers.dart';
import 'package:sentinelx_mobile/features/messages/messages_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../fakes/fake_messages_repository.dart';

class _Viewer extends Notifier<String?> {
  _Viewer(this.initial);
  final String? initial;

  @override
  String? build() => initial;
}

final _viewerProvider = NotifierProvider<_Viewer, String?>(() => _Viewer('u1'));

List<ThreadSummary> _threads(int n, {String prefix = 't', int unread = 0}) => [
      for (var i = 0; i < n; i++) thread('$prefix$i', unread: unread, at: DateTime.utc(2026, 10, 5, 10).subtract(Duration(minutes: i))),
    ];

class _Rig {
  _Rig(this.repo, {String? viewer = 'u1', this.box = InboxBox.inbox, DateTime Function()? now}) {
    throttle = DeliveredThrottle(send: repo.markAllDelivered, now: now ?? DateTime.now);
    container = ProviderContainer(retry: (_, _) => null, overrides: [
      messagesRepositoryProvider.overrideWithValue(repo),
      _viewerProvider.overrideWith(() => _Viewer(viewer)),
      dmViewerIdProvider.overrideWith((ref) async => ref.watch(_viewerProvider)),
      dmNudgeProvider.overrideWith((ref) => nudges.stream),
      deliveredThrottleProvider.overrideWithValue(throttle),
    ]);
    container.listen(provider, (_, _) {});
    container.listen(dmNudgeProvider, (_, _) {});
  }

  final FakeMessagesRepository repo;
  final InboxBox box;
  late final DeliveredThrottle throttle;
  final nudges = StreamController<RealtimeSignal>.broadcast();
  late final ProviderContainer container;
  var _seq = 0;

  AsyncNotifierProvider<InboxNotifier, InboxState> get provider => box == InboxBox.inbox ? inboxProvider : requestsInboxProvider;
  InboxNotifier get notifier => container.read(provider.notifier);
  InboxState? get state => container.read(provider).value;
  Future<InboxState> get loaded => container.read(provider.future);
  List<String> get ids => [for (final t in state!.threads) t.threadId];

  Future<void> nudge([RealtimeSignalKind kind = RealtimeSignalKind.event]) async {
    nudges.add(RealtimeSignal(++_seq, kind));
    await pumpEventQueue();
  }

  void dispose() {
    container.dispose();
    nudges.close();
  }
}

void main() {
  group('paging', () {
    test('first page, hasMore, and the request count', () async {
      final repo = FakeMessagesRepository(inbox: _threads(25), requestCount: 3);
      final r = _Rig(repo);
      addTearDown(r.dispose);
      final s = await r.loaded;
      expect(s.threads, hasLength(20));
      expect(s.hasMore, isTrue);
      expect(s.requestCount, 3);
      expect(repo.threadsCalls.single, (box: InboxBox.inbox, cursor: null));
    });

    test('loadMore appends, de-dupes a thread that slid across the boundary, and stops at the end', () async {
      final repo = FakeMessagesRepository(inbox: _threads(25));
      final r = _Rig(repo);
      addTearDown(r.dispose);
      await r.loaded;
      // a new thread pushes everything down one slot: the old t19 now sits at index 20 (the next page).
      repo.inbox = [thread('new'), ...repo.inbox];
      await r.notifier.loadMore();
      expect(r.ids.where((id) => id == 't19'), hasLength(1));
      expect(r.state!.threads, hasLength(25));
      expect(r.state!.hasMore, isFalse);
      await r.notifier.loadMore();
      expect(repo.threadsCalls, hasLength(2), reason: 'no request once the cursor is exhausted');
    });
  });

  group('realtime nudges', () {
    test('a nudge re-reads the loaded window in place: 40 threads stay 40, re-ordered, request count updated', () async {
      final repo = FakeMessagesRepository(inbox: _threads(60));
      final r = _Rig(repo);
      addTearDown(r.dispose);
      await r.loaded;
      await r.notifier.loadMore();
      expect(r.state!.threads, hasLength(40));
      final callsBefore = repo.threadsCalls.length;

      repo.inbox = [..._threads(60).reversed.take(1), ..._threads(60).take(59)]; // t59 jumps to the top
      repo.requestCount = 4;
      await r.nudge();

      expect(r.state!.threads, hasLength(40), reason: 'not reset to page one');
      expect(r.ids.first, 't59');
      expect(r.state!.requestCount, 4);
      expect(r.state!.hasMore, isTrue);
      expect(repo.threadsCalls.skip(callsBefore).map((c) => c.cursor), [null, '20'], reason: 'walks the pages it had loaded');
    });

    test('two consecutive nudges both refresh', () async {
      final repo = FakeMessagesRepository(inbox: _threads(3));
      final r = _Rig(repo);
      addTearDown(r.dispose);
      await r.loaded;
      repo.inbox = [thread('a'), ...repo.inbox];
      await r.nudge();
      expect(r.ids.first, 'a');
      repo.inbox = [thread('b'), ...repo.inbox];
      await r.nudge();
      expect(r.ids.first, 'b');
    });

    test('a nudge during loadMore is queued, runs after, and loses no row', () async {
      final repo = FakeMessagesRepository(inbox: _threads(45));
      final r = _Rig(repo);
      addTearDown(r.dispose);
      await r.loaded;
      final gate = Completer<void>();
      repo.holds['threads'] = gate;
      final more = r.notifier.loadMore();
      await pumpEventQueue();
      repo.inbox = [thread('fresh'), ...repo.inbox];
      await r.nudge();
      gate.complete();
      await more;
      await pumpEventQueue();
      expect(r.ids.first, 'fresh');
      expect(r.ids.toSet().length, r.ids.length, reason: 'no duplicates');
      expect(r.ids, ['fresh', for (var i = 0; i < 39; i++) 't$i'], reason: 'one contiguous window, no hole; t39 is beyond it');
      expect(r.state!.hasMore, isTrue);
    });

    test('a nudge that fires during the first load is replayed once the page lands', () async {
      final gate = Completer<void>();
      final repo = FakeMessagesRepository(inbox: _threads(3))..holds['threads'] = gate;
      final r = _Rig(repo);
      addTearDown(r.dispose);
      await pumpEventQueue();
      repo.inbox = [thread('inserted-meanwhile'), ...repo.inbox];
      await r.nudge();
      gate.complete();
      await r.loaded;
      await pumpEventQueue();
      expect(r.ids.first, 'inserted-meanwhile');
    });

    test('a failed refresh keeps the last good list', () async {
      final repo = FakeMessagesRepository(inbox: _threads(3));
      final r = _Rig(repo);
      addTearDown(r.dispose);
      await r.loaded;
      repo.failures['threads'] = networkError;
      await r.nudge();
      expect(r.ids, ['t0', 't1', 't2']);
      expect(r.container.read(r.provider).hasError, isFalse);
    });

    test('refresh() returns false on failure and never throws; true on success', () async {
      final repo = FakeMessagesRepository(inbox: _threads(3));
      final r = _Rig(repo);
      addTearDown(r.dispose);
      await r.loaded;
      repo.failures['threads'] = networkError;
      expect(await r.notifier.refresh(), isFalse);
      expect(r.ids, hasLength(3));
      repo.failures.clear();
      repo.inbox = [thread('x')];
      expect(await r.notifier.refresh(), isTrue);
      expect(r.ids, ['x']);
    });
  });

  group('viewer', () {
    test('signed out: empty state and no request', () async {
      final repo = FakeMessagesRepository(inbox: _threads(3));
      final r = _Rig(repo, viewer: null);
      addTearDown(r.dispose);
      final s = await r.loaded;
      expect(s.threads, isEmpty);
      expect(repo.threadsCalls, isEmpty);
    });

    test('the real viewer provider: a token-refreshed Session does not refetch; a different user does and never shows user A', () async {
      final repo = FakeMessagesRepository(inbox: _threads(3));
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
      c.listen(inboxProvider, (_, _) {});
      await pumpEventQueue();
      session.add(sessionFor('u1'));
      await pumpEventQueue();
      expect(repo.threadsCalls, hasLength(1));
      session.add(sessionFor('u1'));
      await pumpEventQueue();
      expect(repo.threadsCalls, hasLength(1), reason: 'keyed on the user id, not the token');
      repo.inbox = [thread('userB-only')];
      session.add(sessionFor('u2'));
      await pumpEventQueue();
      expect(repo.threadsCalls, hasLength(2));
      expect([for (final t in c.read(inboxProvider).value!.threads) t.threadId], ['userB-only']);
    });

    test('mutators on a disposed notifier do nothing and do not throw', () async {
      final repo = FakeMessagesRepository(inbox: _threads(25));
      final r = _Rig(repo);
      await r.loaded;
      final notifier = r.notifier;
      r.dispose();
      final calls = repo.threadsCalls.length;
      await notifier.loadMore();
      await notifier.refreshInPlace();
      expect(await notifier.refresh(), isFalse);
      expect(repo.threadsCalls, hasLength(calls));
    });
  });

  group('markAllDelivered', () {
    test('the throttle lets one call through per 15 s', () async {
      var now = DateTime.utc(2026, 10, 5, 10);
      var sent = 0;
      final t = DeliveredThrottle(send: () async => sent++, now: () => now);
      await t.trigger();
      await t.trigger();
      now = now.add(const Duration(seconds: 14));
      await t.trigger();
      expect(sent, 1);
      now = now.add(const Duration(seconds: 2));
      await t.trigger();
      expect(sent, 2);
    });

    test('a failing send does not throw and does not burn the window', () async {
      var attempts = 0;
      final t = DeliveredThrottle(send: () async {
        attempts++;
        throw networkError;
      });
      await t.trigger();
      await t.trigger();
      expect(attempts, 2);
    });

    test('resumed and reconnected refetch the window and call markAllDelivered through the throttle', () async {
      final repo = FakeMessagesRepository(inbox: _threads(3));
      final r = _Rig(repo);
      addTearDown(r.dispose);
      await r.loaded;
      final before = repo.threadsCalls.length;
      await r.nudge(RealtimeSignalKind.resumed);
      await r.nudge(RealtimeSignalKind.reconnected);
      expect(repo.threadsCalls.length, greaterThan(before));
      expect(repo.markAllDeliveredCalls, 1, reason: 'second one falls inside the 15 s window');
    });

    test('an event that brings a new incoming message triggers it; one that does not (own messages) does not', () async {
      final repo = FakeMessagesRepository(inbox: _threads(3));
      final r = _Rig(repo);
      addTearDown(r.dispose);
      await r.loaded;
      await r.nudge(); // nothing new
      expect(repo.markAllDeliveredCalls, 0);
      repo.inbox = [thread('t0', unread: 1), ...repo.inbox.skip(1)];
      await r.nudge();
      expect(repo.markAllDeliveredCalls, 1);
    });

    test('the requests box never stamps delivery', () async {
      final repo = FakeMessagesRepository(requests: [thread('q0', unread: 1, requestState: RequestState.pending, direction: RequestDirection.incoming)]);
      final r = _Rig(repo, box: InboxBox.requests);
      addTearDown(r.dispose);
      await r.loaded;
      repo.requests = [thread('q0', unread: 3, requestState: RequestState.pending, direction: RequestDirection.incoming)];
      await r.nudge();
      await r.nudge(RealtimeSignalKind.resumed);
      expect(repo.markAllDeliveredCalls, 0);
      expect(repo.threadsCalls.every((c) => c.box == InboxBox.requests), isTrue);
    });
  });
}
