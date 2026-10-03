import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/notifications_models.dart';
import '../../core/providers.dart';
import 'notification_models.dart';
import 'notifications_realtime.dart';
import 'notifications_repository.dart';

const _pageSize = 20;

/// Who is looking: the signed-in user's id, or null when signed out. Everything caller-specific here
/// watches it, so login/logout/account switch refetches while a token refresh for the same user does not
/// (keyed on the user id, not the token). Same pattern as `communityViewerIdProvider`; consolidating the
/// two is deferred. Awaits the session's first value so a signed-in cold start doesn't fetch as a guest.
final notificationsViewerIdProvider =
    FutureProvider.autoDispose<String?>((ref) async => (await ref.watch(sessionProvider.future))?.user.id);

class BellState {
  const BellState({required this.items, required this.hasMore, this.loadingMore = false});

  final List<BellNotification> items;
  final bool hasMore, loadingMore;

  static const empty = BellState(items: [], hasMore: false);

  int get unreadCount => items.where((n) => !n.read).length;

  BellState copyWith({List<BellNotification>? items, bool? hasMore, bool? loadingMore}) =>
      BellState(items: items ?? this.items, hasMore: hasMore ?? this.hasMore, loadingMore: loadingMore ?? this.loadingMore);
}

class NotificationsNotifier extends AsyncNotifier<BellState> {
  // loadMore and refreshInPlace both rewrite the list, so they never overlap: a refresh that arrives
  // mid-flight is queued and runs once the other finishes (lesson 5).
  bool _inFlight = false;
  bool _refreshQueued = false;

  // Rows whose mark-read call is still in flight. A refresh that lands meanwhile re-reads them as unread
  // (the server has not processed the call yet); keep them read so the dot doesn't flicker back.
  final _pendingRead = <String>{};

  @override
  Future<BellState> build() async {
    final viewer = await ref.watch(notificationsViewerIdProvider.future);
    if (viewer == null) return BellState.empty;
    ref.listen(notificationsRealtimeProvider, (_, next) {
      if (next.hasValue) unawaited(refreshInPlace());
    });
    final items = await ref.read(notificationsRepositoryProvider).page(offset: 0, limit: _pageSize);
    return BellState(items: items, hasMore: items.length >= _pageSize);
  }

  List<BellNotification> _withPending(List<BellNotification> items) =>
      _pendingRead.isEmpty ? items : [for (final n in items) _pendingRead.contains(n.id) ? n.copyWith(read: true) : n];

  Future<void> loadMore() async {
    if (!ref.mounted) return;
    final current = state.value;
    if (current == null || !current.hasMore || _inFlight) return;
    final repo = ref.read(notificationsRepositoryProvider);
    _inFlight = true;
    state = AsyncData(current.copyWith(loadingMore: true));
    try {
      final page = await repo.page(offset: current.items.length, limit: _pageSize);
      if (!ref.mounted) return;
      final base = state.value ?? current;
      // A row can slide across the page boundary while the player scrolls (new rows push the list down),
      // so drop anything already shown rather than listing it twice.
      final seen = {for (final n in base.items) n.id};
      state = AsyncData(base.copyWith(
        items: [...base.items, ..._withPending(page.where((n) => !seen.contains(n.id)).toList())],
        hasMore: page.length >= _pageSize,
        loadingMore: false,
      ));
    } catch (_) {
      if (!ref.mounted) return;
      state = AsyncData((state.value ?? current).copyWith(loadingMore: false));
    } finally {
      _inFlight = false;
      if (_refreshQueued && ref.mounted) {
        _refreshQueued = false;
        unawaited(refreshInPlace());
      }
    }
  }

  /// Background refresh (realtime): re-reads the window that is already loaded, in place — pagination is
  /// never reset and a manual action in flight is never raced.
  Future<void> refreshInPlace() async {
    if (!ref.mounted) return;
    final current = state.value;
    if (current == null) return;
    if (_inFlight) {
      _refreshQueued = true;
      return;
    }
    final repo = ref.read(notificationsRepositoryProvider);
    _inFlight = true;
    try {
      final limit = math.max(current.items.length, _pageSize);
      final items = await repo.page(offset: 0, limit: limit);
      if (!ref.mounted) return;
      final base = state.value ?? current;
      state = AsyncData(base.copyWith(items: _withPending(items), hasMore: items.length >= limit, loadingMore: false));
    } catch (_) {
      // keep the last good list
    } finally {
      _inFlight = false;
      if (_refreshQueued && ref.mounted) {
        _refreshQueued = false;
        unawaited(refreshInPlace());
      }
    }
  }

  /// Pull-to-refresh: back to page one. Never throws; on failure the last good list stays and this
  /// returns false so the screen can say so.
  Future<bool> refresh() async {
    if (!ref.mounted) return false;
    final repo = ref.read(notificationsRepositoryProvider);
    try {
      final items = await repo.page(offset: 0, limit: _pageSize);
      if (!ref.mounted) return true;
      state = AsyncData(BellState(items: _withPending(items), hasMore: items.length >= _pageSize));
      return true;
    } catch (_) {
      return false;
    }
  }

  void _setRead(Set<String> ids, bool read) {
    if (!ref.mounted) return;
    final s = state.value;
    if (s == null) return;
    state = AsyncData(s.copyWith(items: [for (final n in s.items) ids.contains(n.id) ? n.copyWith(read: read) : n]));
  }

  /// Optimistic. Failure reverts only this row's read flag — never a snapshot of the whole list — so rows a
  /// refresh brought in meanwhile are left alone.
  Future<bool> markRead(String id) async {
    if (!ref.mounted) return false;
    final s = state.value;
    if (s == null) return false;
    final row = s.items.where((n) => n.id == id).firstOrNull;
    if (row == null || row.read) return true;
    final repo = ref.read(notificationsRepositoryProvider);
    _pendingRead.add(id);
    _setRead({id}, true);
    try {
      await repo.markRead(id);
      return true;
    } catch (_) {
      _pendingRead.remove(id);
      _setRead({id}, false);
      return false;
    } finally {
      _pendingRead.remove(id);
    }
  }

  Future<bool> markAllRead() async {
    if (!ref.mounted) return false;
    final s = state.value;
    if (s == null) return false;
    final flipped = {for (final n in s.items) if (!n.read) n.id};
    if (flipped.isEmpty) return true;
    final repo = ref.read(notificationsRepositoryProvider);
    _pendingRead.addAll(flipped);
    _setRead(flipped, true);
    try {
      await repo.markAllRead();
      return true;
    } catch (_) {
      _pendingRead.removeAll(flipped);
      _setRead(flipped, false);
      return false;
    } finally {
      _pendingRead.removeAll(flipped);
    }
  }
}

final notificationsProvider = AsyncNotifierProvider.autoDispose<NotificationsNotifier, BellState>(NotificationsNotifier.new);

/// Counts debounced change events on the caller's own rows. Starts silent (the screen already has its
/// first page); each event is a new number so every one notifies.
final notificationsRealtimeProvider = StreamProvider.autoDispose<int>((ref) {
  final viewer = ref.watch(notificationsViewerIdProvider).asData?.value;
  if (viewer == null) return const Stream.empty();
  return debouncedTicks(notificationRowChanges(ref.watch(supabaseClientProvider), viewer));
});

/// Timed mutes for the bell menu's mute/unmute labels. Null when signed out.
final notificationMutesProvider = FutureProvider.autoDispose<NotificationMutes?>((ref) async {
  final viewer = await ref.watch(notificationsViewerIdProvider.future);
  if (viewer == null) return null;
  return ref.watch(notificationsRepositoryProvider).mutes();
});
