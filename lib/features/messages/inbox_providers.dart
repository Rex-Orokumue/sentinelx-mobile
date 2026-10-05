import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/messages_models.dart';
import '../../core/providers.dart';
import '../../core/realtime/realtime_hub.dart';
import '../../core/realtime/realtime_port.dart';
import 'messages_repository.dart';

/// The messages feature's name for the shared viewer id (`viewerIdProvider`, keyed on the user id so a token
/// refresh doesn't refetch).
final dmViewerIdProvider = viewerIdProvider;

final messagesRepositoryProvider = Provider<MessagesRepository>((ref) => ApiMessagesRepository(ref.watch(apiClientProvider)));

/// Nudges from `dm_messages` (unfiltered: RLS scopes the stream to the viewer's own threads), debounced 400 ms,
/// numbered. Silent until something changes; a reconnect or an app resume also nudges so windows refetch after a gap.
final dmNudgeProvider = StreamProvider.autoDispose<RealtimeSignal>((ref) {
  final viewer = ref.watch(dmViewerIdProvider).asData?.value;
  if (viewer == null) return const Stream.empty();
  final handle = ref.watch(realtimeHubProvider).open(
        const RealtimeChannelSpec(topic: 'dm-nudge', bindings: [PostgresBinding(table: 'dm_messages')]),
      );
  return debouncedSignals(handle.signals);
});

/// At most one `markAllDelivered` per [gap] (Ruling 11). Failures are swallowed and do not consume the window,
/// so the next trigger tries again.
class DeliveredThrottle {
  DeliveredThrottle({required Future<void> Function() send, DateTime Function()? now, this.gap = const Duration(seconds: 15)})
      : _send = send,
        _now = now ?? DateTime.now;

  final Future<void> Function() _send;
  final DateTime Function() _now;
  final Duration gap;
  DateTime? _last;

  Future<void> trigger() async {
    final last = _last;
    final now = _now();
    if (last != null && now.difference(last) < gap) return;
    try {
      await _send();
      _last = now;
    } catch (_) {
      // best effort: the sender just sees two ticks a little later
    }
  }
}

final deliveredThrottleProvider = Provider<DeliveredThrottle>(
  (ref) => DeliveredThrottle(send: () => ref.read(messagesRepositoryProvider).markAllDelivered()),
);

class InboxState {
  const InboxState({required this.threads, this.nextCursor, this.requestCount = 0, this.loadingMore = false});

  final List<ThreadSummary> threads;
  final String? nextCursor;
  final int requestCount;
  final bool loadingMore;

  static const empty = InboxState(threads: []);

  bool get hasMore => nextCursor != null;

  int get unreadTotal => threads.fold(0, (n, t) => n + t.unread);

  InboxState copyWith({List<ThreadSummary>? threads, Object? nextCursor = _keep, int? requestCount, bool? loadingMore}) => InboxState(
        threads: threads ?? this.threads,
        nextCursor: identical(nextCursor, _keep) ? this.nextCursor : nextCursor as String?,
        requestCount: requestCount ?? this.requestCount,
        loadingMore: loadingMore ?? this.loadingMore,
      );
}

const _keep = Object();

List<ThreadSummary> _dedupe(Iterable<ThreadSummary> rows, [Set<String>? seen]) {
  final out = <ThreadSummary>[];
  final s = seen ?? <String>{};
  for (final t in rows) {
    if (s.add(t.threadId)) out.add(t);
  }
  return out;
}

class InboxNotifier extends AsyncNotifier<InboxState> {
  InboxNotifier(this.box);

  final InboxBox box;

  // loadMore, refresh and refreshInPlace all rewrite the list, so they never overlap: one that arrives
  // mid-flight is queued and runs once the other finishes (Phase 4 lesson 5).
  bool _inFlight = false;
  bool _refreshQueued = false;

  // A nudge that fired while the very first page was still loading: there was no list to refresh yet, and
  // that page may have been read before the change.
  bool _eventDuringFirstLoad = false;

  @override
  Future<InboxState> build() async {
    _eventDuringFirstLoad = false;
    final viewer = await ref.watch(dmViewerIdProvider.future);
    if (viewer == null) return InboxState.empty;
    ref.listen(dmNudgeProvider, (_, next) {
      if (next is! AsyncData<RealtimeSignal>) return;
      if (state.value == null) {
        _eventDuringFirstLoad = true;
      } else {
        unawaited(_onSignal(next.value.kind));
      }
    });
    final page = await ref.read(messagesRepositoryProvider).threads(box: box);
    if (_eventDuringFirstLoad) {
      _eventDuringFirstLoad = false;
      Future<void>(refreshInPlace); // after this build's state lands
    }
    return InboxState(threads: _dedupe(page.threads), nextCursor: page.nextCursor, requestCount: page.requestCount);
  }

  Future<void> _onSignal(RealtimeSignalKind kind) async {
    final before = state.value?.unreadTotal ?? 0;
    await refreshInPlace();
    if (!ref.mounted || box != InboxBox.inbox) return; // pending requests are never stamped delivered
    final after = state.value?.unreadTotal ?? 0;
    if (kind != RealtimeSignalKind.event || after > before) {
      await ref.read(deliveredThrottleProvider).trigger();
    }
  }

  Future<void> loadMore() async {
    if (!ref.mounted) return;
    final current = state.value;
    if (current == null || !current.hasMore || _inFlight) return;
    final repo = ref.read(messagesRepositoryProvider);
    _inFlight = true;
    state = AsyncData(current.copyWith(loadingMore: true));
    try {
      final page = await repo.threads(box: box, cursor: current.nextCursor);
      if (!ref.mounted) return;
      final base = state.value ?? current;
      // A thread can slide across the page boundary while the player scrolls, so drop anything already shown.
      final fresh = _dedupe(page.threads, {for (final t in base.threads) t.threadId});
      state = AsyncData(base.copyWith(
        threads: [...base.threads, ...fresh],
        nextCursor: page.nextCursor,
        requestCount: page.requestCount,
        loadingMore: false,
      ));
    } catch (_) {
      if (!ref.mounted) return;
      state = AsyncData((state.value ?? current).copyWith(loadingMore: false));
    } finally {
      _inFlight = false;
      _drainQueue();
    }
  }

  /// Background refresh (realtime): re-reads pages from the first cursor until it covers as many threads as are
  /// already loaded, in place. Pagination is never reset below the loaded window and a manual action in flight
  /// is never raced.
  Future<void> refreshInPlace() async {
    if (!ref.mounted) return;
    final current = state.value;
    if (current == null) return;
    if (_inFlight) {
      _refreshQueued = true;
      return;
    }
    final repo = ref.read(messagesRepositoryProvider);
    _inFlight = true;
    try {
      final target = math.max(current.threads.length, 1);
      final seen = <String>{};
      final all = <ThreadSummary>[];
      String? cursor;
      String? next;
      var requestCount = current.requestCount;
      do {
        final page = await repo.threads(box: box, cursor: cursor);
        all.addAll(_dedupe(page.threads, seen));
        next = page.nextCursor;
        requestCount = page.requestCount;
        cursor = next;
      } while (all.length < target && next != null);
      if (!ref.mounted) return;
      final base = state.value ?? current;
      state = AsyncData(base.copyWith(threads: all, nextCursor: next, requestCount: requestCount, loadingMore: false));
    } catch (_) {
      // keep the last good list
    } finally {
      _inFlight = false;
      _drainQueue();
    }
  }

  /// Pull-to-refresh: back to page one. Never throws; on failure the last good list stays and this returns
  /// false so the screen can say so.
  Future<bool> refresh() async {
    if (!ref.mounted) return false;
    if (_inFlight) {
      _refreshQueued = true;
      return true;
    }
    final repo = ref.read(messagesRepositoryProvider);
    _inFlight = true;
    try {
      final page = await repo.threads(box: box);
      if (!ref.mounted) return true;
      state = AsyncData(InboxState(threads: _dedupe(page.threads), nextCursor: page.nextCursor, requestCount: page.requestCount));
      return true;
    } catch (_) {
      return false;
    } finally {
      _inFlight = false;
      _drainQueue();
    }
  }

  void _drainQueue() {
    if (_refreshQueued && ref.mounted) {
      _refreshQueued = false;
      unawaited(refreshInPlace());
    }
  }
}

final inboxProvider = AsyncNotifierProvider.autoDispose<InboxNotifier, InboxState>(() => InboxNotifier(InboxBox.inbox));

final requestsInboxProvider = AsyncNotifierProvider.autoDispose<InboxNotifier, InboxState>(() => InboxNotifier(InboxBox.requests));
