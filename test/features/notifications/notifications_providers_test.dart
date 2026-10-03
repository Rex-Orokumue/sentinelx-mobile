import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/core/api/notifications_models.dart';
import 'package:sentinelx_mobile/core/providers.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sentinelx_mobile/features/notifications/notification_models.dart';
import 'package:sentinelx_mobile/features/notifications/notifications_providers.dart';
import 'package:sentinelx_mobile/features/notifications/notifications_realtime.dart';
import 'package:sentinelx_mobile/features/notifications/notifications_repository.dart';

import '../../fakes/fake_notifications_repository.dart';

class _Viewer extends Notifier<String?> {
  _Viewer(this.initial);
  final String? initial;

  @override
  String? build() => initial;
  void set(String? v) => state = v;
}

final _viewerProvider = NotifierProvider<_Viewer, String?>(() => _Viewer('u1'));

List<BellNotification> _rows(int n, {String prefix = 'n'}) => [for (var i = 0; i < n; i++) bell('$prefix$i')];

class _Rig {
  _Rig(this.repo, {String? viewer = 'u1', Stream<int>? realtime}) : realtimeSource = realtime == null ? StreamController<int>.broadcast() : null {
    container = ProviderContainer(retry: (_, _) => null, overrides: [
      notificationsRepositoryProvider.overrideWithValue(repo),
      _viewerProvider.overrideWith(() => _Viewer(viewer)),
      notificationsViewerIdProvider.overrideWith((ref) async => ref.watch(_viewerProvider)),
      notificationsRealtimeProvider.overrideWith((ref) => realtime ?? realtimeSource!.stream),
    ]);
    // autoDispose providers: keep them alive like a mounted screen would.
    container.listen(notificationsProvider, (_, _) {});
    container.listen(notificationsRealtimeProvider, (_, _) {});
  }

  final FakeNotificationsRepository repo;
  final StreamController<int>? realtimeSource;
  late final ProviderContainer container;
  int _tick = 0;

  NotificationsNotifier get notifier => container.read(notificationsProvider.notifier);
  BellState? get state => container.read(notificationsProvider).value;
  Future<BellState> get loaded => container.read(notificationsProvider.future);

  Future<void> tick() async {
    realtimeSource!.add(++_tick);
    await pumpEventQueue();
  }

  void dispose() {
    container.dispose();
    realtimeSource?.close();
  }
}

void main() {
  group('loading and paging', () {
    test('a full first page means there may be more; a short one means there is not', () async {
      var r = _Rig(FakeNotificationsRepository(rows: _rows(20)));
      addTearDown(r.dispose);
      expect((await r.loaded).hasMore, isTrue);
      expect(r.repo.pageCalls.single, (offset: 0, limit: 20));

      r = _Rig(FakeNotificationsRepository(rows: _rows(5)));
      addTearDown(r.dispose);
      final s = await r.loaded;
      expect(s.hasMore, isFalse);
      expect(s.items, hasLength(5));
    });

    test('loadMore appends the next page and drops rows already shown (a row can slide across the boundary)', () async {
      final repo = FakeNotificationsRepository(rows: _rows(30));
      final r = _Rig(repo);
      addTearDown(r.dispose);
      await r.loaded;
      // A new row arrives before the next page is read: page two now starts with a row page one showed.
      repo.store = [bell('fresh'), ...repo.store];
      await r.notifier.loadMore();
      expect(repo.pageCalls.last.offset, 20);
      expect(r.state!.items.map((n) => n.id).toSet().length, r.state!.items.length, reason: 'no duplicates');
      expect(r.state!.items, hasLength(30), reason: '20 shown + the 10 new ones; the boundary row n19 is not listed twice');
      expect(r.state!.hasMore, isFalse);
    });

    test('loadMore does nothing when there is no more or a load is already running', () async {
      final repo = FakeNotificationsRepository(rows: _rows(30));
      final r = _Rig(repo);
      addTearDown(r.dispose);
      await r.loaded;
      final gate = repo.holdNextPage = Completer<void>();
      final first = r.notifier.loadMore();
      await pumpEventQueue();
      await r.notifier.loadMore(); // ignored: one is in flight
      expect(repo.pageCalls.where((c) => c.offset == 20), hasLength(1));
      gate.complete();
      await first;
    });

    test('pull-to-refresh failure keeps the last good list and reports false', () async {
      final repo = FakeNotificationsRepository(rows: _rows(3));
      final r = _Rig(repo);
      addTearDown(r.dispose);
      await r.loaded;
      repo.pageFails = true;
      expect(await r.notifier.refresh(), isFalse);
      expect(r.state!.items, hasLength(3));
    });

    test('signed out: empty state and no query', () async {
      final repo = FakeNotificationsRepository(rows: _rows(3));
      final r = _Rig(repo, viewer: null);
      addTearDown(r.dispose);
      final s = await r.loaded;
      expect(s.items, isEmpty);
      expect(s.hasMore, isFalse);
      expect(repo.pageCalls, isEmpty);
    });

    test('account switch refetches for the new viewer (Review Focus 4)', () async {
      final repo = FakeNotificationsRepository(rows: _rows(3));
      final r = _Rig(repo);
      addTearDown(r.dispose);
      await r.loaded;
      expect(repo.pageCalls, hasLength(1));
      repo.store = [bell('b1')];
      r.container.read(_viewerProvider.notifier).set('u2');
      await pumpEventQueue();
      expect(repo.pageCalls, hasLength(2));
      expect(r.state!.items.map((n) => n.id), ['b1']);
    });
  });

  group('realtime refresh (lessons 2 and 5)', () {
    test('keeps the loaded window instead of resetting to page one, and shows the new row', () async {
      final repo = FakeNotificationsRepository(rows: _rows(45));
      final r = _Rig(repo);
      addTearDown(r.dispose);
      await r.loaded;
      await r.notifier.loadMore(); // 40 loaded
      expect(r.state!.items, hasLength(40));
      repo.store = [bell('new'), ...repo.store];
      await r.tick();
      expect(r.state!.items, hasLength(40));
      expect(r.state!.items.first.id, 'new');
      expect(repo.pageCalls.last, (offset: 0, limit: 40));
    });

    test('two consecutive events both refresh', () async {
      final repo = FakeNotificationsRepository(rows: _rows(3));
      final r = _Rig(repo);
      addTearDown(r.dispose);
      await r.loaded;
      repo.store = [bell('a'), ...repo.store];
      await r.tick();
      expect(r.state!.items.first.id, 'a');
      repo.store = [bell('b'), ...repo.store];
      await r.tick();
      expect(r.state!.items.first.id, 'b');
      expect(repo.pageCalls, hasLength(3));
    });

    test('an event during loadMore is queued, runs afterwards, and loses no row', () async {
      final repo = FakeNotificationsRepository(rows: _rows(30));
      final r = _Rig(repo);
      addTearDown(r.dispose);
      await r.loaded;
      final gate = repo.holdNextPage = Completer<void>();
      final more = r.notifier.loadMore();
      await pumpEventQueue();
      repo.store = [bell('new'), ...repo.store];
      await r.tick(); // arrives while loadMore is in flight
      gate.complete();
      await more;
      await pumpEventQueue();
      final ids = r.state!.items.map((n) => n.id).toList();
      expect(ids.first, 'new');
      expect(ids.toSet().length, ids.length, reason: 'no duplicates');
      // The queued refresh re-read the 30-row window: the new row is on top, the list was not reset to page
      // one, and the oldest row slid onto the next page (hasMore) rather than being lost.
      expect(ids, hasLength(30));
      expect(ids, containsAll(['new', 'n0', 'n28']));
      expect(r.state!.hasMore, isTrue);
    });
  });

  group('review fixes', () {
    test('pull-to-refresh during loadMore is coordinated: no rows go missing', () async {
      final repo = FakeNotificationsRepository(rows: _rows(45));
      final r = _Rig(repo);
      addTearDown(r.dispose);
      await r.loaded;
      await r.notifier.loadMore(); // 40 loaded
      final gate = repo.holdNextPage = Completer<void>();
      final more = r.notifier.loadMore(); // offset 40, held
      await pumpEventQueue();
      final refreshed = r.notifier.refresh(); // the user pulls to refresh meanwhile
      gate.complete();
      await Future.wait([more, refreshed]);
      await pumpEventQueue();
      final ids = r.state!.items.map((n) => n.id).toList();
      expect(ids.toSet().length, ids.length, reason: 'no duplicates');
      expect(ids, [for (var i = 0; i < ids.length; i++) 'n$i'], reason: 'a contiguous prefix: nothing between rows 20 and 39 is missing');
      expect(ids.length, greaterThanOrEqualTo(20));
    });

    test('a realtime event during the very first page load is not dropped', () async {
      final repo = FakeNotificationsRepository(rows: _rows(3));
      final gate = repo.holdNextPage = Completer<void>();
      final r = _Rig(repo);
      addTearDown(r.dispose);
      await pumpEventQueue(); // the notifier is now waiting on its first page
      repo.store = [bell('inserted-meanwhile'), ...repo.store];
      await r.tick();
      gate.complete();
      await r.loaded;
      await pumpEventQueue();
      expect(r.state!.items.first.id, 'inserted-meanwhile');
    });

    test('the real viewer provider: a token-refreshed Session for the same user does not refetch; a different user does', () async {
      final repo = FakeNotificationsRepository(rows: _rows(3));
      final session = StreamController<Session?>.broadcast();
      addTearDown(session.close);
      var seq = 0;
      Session sessionFor(String id) => Session(
            accessToken: 'tok-$id-${seq++}',
            tokenType: 'bearer',
            user: User(id: id, appMetadata: const {}, userMetadata: const {}, aud: '', createdAt: ''),
          );
      final c = ProviderContainer(retry: (_, _) => null, overrides: [
        notificationsRepositoryProvider.overrideWithValue(repo),
        sessionProvider.overrideWith((ref) => session.stream),
        notificationsRealtimeProvider.overrideWith((ref) => const Stream<int>.empty()),
      ]);
      addTearDown(c.dispose);
      c.listen(sessionProvider, (_, _) {});
      c.listen(notificationsProvider, (_, _) {});
      await pumpEventQueue();
      session.add(sessionFor('u1'));
      await pumpEventQueue();
      expect(repo.pageCalls, hasLength(1));
      session.add(sessionFor('u1')); // token refresh: same user, new Session
      await pumpEventQueue();
      expect(repo.pageCalls, hasLength(1), reason: 'keyed on the user id, not the token');
      session.add(sessionFor('u2'));
      await pumpEventQueue();
      expect(repo.pageCalls, hasLength(2));
    });
  });

  group('mark read', () {
    test('is optimistic: the row reads as read before the API answers', () async {
      final repo = FakeNotificationsRepository(rows: _rows(3))..holdMarkRead = Completer<void>();
      final r = _Rig(repo);
      addTearDown(r.dispose);
      await r.loaded;
      final call = r.notifier.markRead('n1');
      await pumpEventQueue();
      expect(r.state!.items.firstWhere((n) => n.id == 'n1').read, isTrue);
      repo.holdMarkRead!.complete();
      expect(await call, isTrue);
      expect(repo.markReadCalls, ['n1']);
    });

    test('an already-read or unknown row makes no API call', () async {
      final repo = FakeNotificationsRepository(rows: [bell('a', read: true)]);
      final r = _Rig(repo);
      addTearDown(r.dispose);
      await r.loaded;
      await r.notifier.markRead('a');
      await r.notifier.markRead('zzz');
      expect(repo.markReadCalls, isEmpty);
    });

    test('failure reverts only that row, and leaves rows a refresh brought in meanwhile alone', () async {
      final repo = FakeNotificationsRepository(rows: _rows(3))
        ..holdMarkRead = Completer<void>()
        ..markReadFails = true;
      final r = _Rig(repo);
      addTearDown(r.dispose);
      await r.loaded;
      final call = r.notifier.markRead('n1');
      await pumpEventQueue();
      repo.store = [bell('fresh'), ...repo.store]; // a refresh lands while the call is in flight
      await r.tick();
      expect(r.state!.items.firstWhere((n) => n.id == 'n1').read, isTrue, reason: 'in-flight optimistic read survives a refresh');
      repo.holdMarkRead!.complete();
      expect(await call, isFalse);
      expect(r.state!.items.firstWhere((n) => n.id == 'n1').read, isFalse);
      expect(r.state!.items.first.id, 'fresh', reason: 'the fresher list is not replaced by a tap-time snapshot');
      expect(r.state!.items.where((n) => n.id != 'n1').every((n) => !n.read), isTrue);
    });
  });

  group('mark all read', () {
    test('is optimistic for the loaded unread rows', () async {
      final repo = FakeNotificationsRepository(rows: [bell('a'), bell('b', read: true), bell('c')])..holdMarkAll = Completer<void>();
      final r = _Rig(repo);
      addTearDown(r.dispose);
      await r.loaded;
      final call = r.notifier.markAllRead();
      await pumpEventQueue();
      expect(r.state!.items.every((n) => n.read), isTrue);
      repo.holdMarkAll!.complete();
      expect(await call, isTrue);
      expect(repo.markAllCalls, 1);
    });

    test('failure reverts only the rows it flipped, not rows that were already read', () async {
      final repo = FakeNotificationsRepository(rows: [bell('a'), bell('b', read: true), bell('c')])..markAllFails = true;
      final r = _Rig(repo);
      addTearDown(r.dispose);
      await r.loaded;
      expect(await r.notifier.markAllRead(), isFalse);
      final byId = {for (final n in r.state!.items) n.id: n.read};
      expect(byId, {'a': false, 'b': true, 'c': false});
    });

    test('with nothing unread it makes no API call', () async {
      final repo = FakeNotificationsRepository(rows: [bell('a', read: true)]);
      final r = _Rig(repo);
      addTearDown(r.dispose);
      await r.loaded;
      await r.notifier.markAllRead();
      expect(repo.markAllCalls, 0);
    });
  });

  test('mutators on a disposed notifier do nothing and do not throw', () async {
    final repo = FakeNotificationsRepository(rows: _rows(3));
    final r = _Rig(repo);
    await r.loaded;
    final notifier = r.notifier;
    r.dispose();
    expect(await notifier.markRead('n1'), isFalse);
    expect(await notifier.markAllRead(), isFalse);
    await notifier.loadMore();
    await notifier.refreshInPlace();
    expect(repo.markReadCalls, isEmpty);
  });

  group('notificationsTicks (debounced, numbered)', () {
    test('a burst becomes one tick; the next burst is a different value', () {
      fakeAsync((async) {
        final source = StreamController<void>.broadcast();
        final seen = <int>[];
        debouncedTicks(source.stream, debounce: const Duration(milliseconds: 400)).listen(seen.add);
        source.add(null);
        source.add(null);
        async.elapse(const Duration(milliseconds: 399));
        expect(seen, isEmpty);
        async.elapse(const Duration(milliseconds: 2));
        expect(seen, [1]);
        source.add(null);
        async.elapse(const Duration(milliseconds: 401));
        expect(seen, [1, 2], reason: 'a counter, so Riverpod notifies for the second event too');
        source.close();
      });
    });
  });

  group('mutes provider', () {
    test('null when signed out, the server list when signed in', () async {
      final repo = FakeNotificationsRepository()
        ..mutesResult = NotificationMutes(types: [MutedType('post_reaction', DateTime.utc(2099))], posts: const []);
      var r = _Rig(repo);
      addTearDown(r.dispose);
      r.container.listen(notificationMutesProvider, (_, _) {});
      expect((await r.container.read(notificationMutesProvider.future))!.types.single.type, 'post_reaction');

      r = _Rig(repo, viewer: null);
      addTearDown(r.dispose);
      r.container.listen(notificationMutesProvider, (_, _) {});
      expect(await r.container.read(notificationMutesProvider.future), isNull);
    });
  });
}
