import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/api/messages_models.dart';
import '../../core/realtime/realtime_hub.dart';
import '../../core/utils/idempotency_key.dart';
import 'inbox_providers.dart';
import 'messages_repository.dart';
import 'thread_window.dart';

/// The clock the thread logic reads (the 30 s media-refresh limit, the optimistic edit stamp). Overridable so
/// tests control time.
final dmClockProvider = Provider<DateTime Function()>((_) => DateTime.now);

/// Runs operations for one thread strictly in submission order (send, edit, unsend, forward, markRead), while
/// different threads run independently. An error in one operation never poisons the chain behind it.
class ThreadActionQueue {
  final _tails = <String, Future<void>>{};

  Future<T> run<T>(String threadId, Future<T> Function() op) {
    final done = Completer<T>();
    final previous = _tails[threadId] ?? Future<void>.value();
    late Future<void> tail;
    tail = previous.then((_) async {
      try {
        done.complete(await op());
      } catch (e, s) {
        done.completeError(e, s);
      }
    }).whenComplete(() {
      if (identical(_tails[threadId], tail)) _tails.remove(threadId);
    });
    _tails[threadId] = tail;
    return done.future;
  }
}

final threadActionQueueProvider = Provider<ThreadActionQueue>((_) => ThreadActionQueue());

/// The thread the player is looking at right now (set by the visible conversation while the app is resumed).
/// Push banners for it are suppressed. Only the owner of the current value can clear it.
class OpenThread extends Notifier<String?> {
  @override
  String? build() => null;

  void open(String threadId) => state = threadId;

  void close(String threadId) {
    if (state == threadId) state = null;
  }
}

final openThreadIdProvider = NotifierProvider<OpenThread, String?>(OpenThread.new);

/// In-memory text draft per thread. Deliberately not autoDispose: it survives the screen being popped (not a
/// process kill, Ruling 9).
class ThreadDraftNotifier extends Notifier<String> {
  ThreadDraftNotifier(this.threadId);
  final String threadId;

  @override
  String build() => '';

  void set(String text) => state = text;
}

final threadDraftProvider = NotifierProvider.family<ThreadDraftNotifier, String, String>(ThreadDraftNotifier.new);

final threadHeaderProvider = FutureProvider.autoDispose.family<ThreadHeader, String>((ref, threadId) async {
  final viewer = await ref.watch(dmViewerIdProvider.future);
  if (viewer == null) throw StateError('signed out');
  return ref.watch(messagesRepositoryProvider).thread(threadId);
});

const _mediaRefreshGap = Duration(seconds: 30);

class ThreadNotifier extends AsyncNotifier<ThreadView> {
  ThreadNotifier(this.threadId);

  final String threadId;

  /// The error of the last edit/unsend/forward that returned false, for the screen's copy.
  Object? lastActionError;

  // loadOlder and the refreshes all rewrite the window, so they never overlap: a refresh that arrives
  // mid-flight is queued and runs once the other finishes (Phase 4 lesson 5).
  bool _inFlight = false;
  bool _refreshQueued = false;
  bool _eventDuringFirstLoad = false;
  bool _markReadQueued = false;
  String _viewerId = '';
  int _localSeq = 0;
  DateTime? _lastMediaRefresh;

  @override
  Future<ThreadView> build() async {
    _eventDuringFirstLoad = false;
    final viewer = await ref.watch(dmViewerIdProvider.future);
    if (viewer == null) return ThreadView.empty;
    _viewerId = viewer;
    ref.listen(dmNudgeProvider, (_, next) {
      if (next is! AsyncData<RealtimeSignal>) return;
      if (state.value == null) {
        _eventDuringFirstLoad = true;
      } else {
        unawaited(_onSignal(next.value.kind));
      }
    });
    final page = await ref.read(messagesRepositoryProvider).messages(threadId);
    if (_eventDuringFirstLoad) {
      _eventDuringFirstLoad = false;
      Future<void>(refreshInPlace); // after this build's state lands
    }
    return ThreadView(messages: page.messages, nextBefore: page.nextBefore);
  }

  Set<String> _incomingIds() => {
        for (final m in state.value?.messages ?? const <DmMessage>[])
          if (!m.isMine(_viewerId)) m.id,
      };

  Future<void> _onSignal(RealtimeSignalKind kind) async {
    if (kind == RealtimeSignalKind.event) {
      final before = _incomingIds();
      await refreshInPlace();
      if (!ref.mounted) return;
      if (_incomingIds().difference(before).isNotEmpty) await ref.read(deliveredThrottleProvider).trigger();
    } else {
      await refreshWindow();
      if (!ref.mounted) return;
      await ref.read(deliveredThrottleProvider).trigger();
    }
  }

  // --- reads ---

  Future<void> loadOlder() async {
    if (!ref.mounted) return;
    final current = state.value;
    if (current == null || current.nextBefore == null || _inFlight) return;
    final repo = ref.read(messagesRepositoryProvider);
    _inFlight = true;
    state = AsyncData(current.copyWith(loadingOlder: true));
    try {
      final page = await repo.messages(threadId, before: current.nextBefore);
      if (!ref.mounted) return;
      final base = state.value ?? current;
      state = AsyncData(base.copyWith(messages: appendOlder(base.messages, page), nextBefore: page.nextBefore, loadingOlder: false));
    } catch (_) {
      if (!ref.mounted) return;
      state = AsyncData((state.value ?? current).copyWith(loadingOlder: false));
    } finally {
      _inFlight = false;
      _drainQueue();
    }
  }

  /// Realtime nudge. Walks to older pages until it overlaps the loaded window (so a burst of more than a page
  /// leaves no hole); never resets the cursor for older pages already loaded and never drops pending items.
  Future<void> refreshInPlace() => _reconcile();

  /// Resume, reconnect, or a media URL error: same reconcile, kept as its own name at the call sites.
  Future<void> refreshWindow() => _reconcile();

  /// Called by a bubble whose signed media URL failed. At most one refetch per 30 s (signed URLs last ~1 h).
  Future<void> requestMediaRefresh() async {
    if (!ref.mounted) return;
    final now = ref.read(dmClockProvider)();
    final last = _lastMediaRefresh;
    if (last != null && now.difference(last) < _mediaRefreshGap) return;
    _lastMediaRefresh = now;
    await _reconcile();
  }

  Future<void> _reconcile() async {
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
      final r = await reconcileWindow(
        window: current.messages,
        windowNextBefore: current.nextBefore,
        fetch: (before) => repo.messages(threadId, before: before),
      );
      if (!ref.mounted) return;
      final base = state.value ?? current;
      // Rows that changed while the fetch was in flight (a send that landed, an optimistic edit) are folded in.
      final List<DmMessage> merged;
      if (r.droppedOld) {
        final ids = {for (final m in r.messages) m.id};
        final newest = r.messages.isEmpty ? null : r.messages.first.createdAt;
        final newer = [
          for (final m in base.messages)
            if (!ids.contains(m.id) && newest != null && m.createdAt.isAfter(newest)) m,
        ];
        merged = [...newer, ...r.messages];
      } else {
        merged = mergeNewestPage(base.messages, MessagesPage(messages: r.messages));
      }
      state = AsyncData(base.copyWith(messages: merged, nextBefore: r.nextBefore, loadingOlder: false));
    } catch (_) {
      // keep the last good window
    } finally {
      _inFlight = false;
      _drainQueue();
    }
  }

  void _drainQueue() {
    if (_refreshQueued && ref.mounted) {
      _refreshQueued = false;
      unawaited(_reconcile());
    }
  }

  // --- sending ---

  List<PendingItem> get _pending => state.value?.pending ?? const [];

  void _setPending(List<PendingItem> items) {
    if (!ref.mounted) return;
    final s = state.value;
    if (s == null) return;
    state = AsyncData(s.copyWith(pending: items));
  }

  PendingItem? _item(String localId) {
    for (final p in _pending) {
      if (p.localId == localId) return p;
    }
    return null;
  }

  /// Optimistic: the bubble shows at once, then the send runs through the thread's serial queue with this
  /// item's idempotency key (generated once; every retry reuses it).
  Future<void> send(SendDraft draft, {Future<SendDraft> Function(SendDraft draft)? prepare, Uint8List? localImage}) async {
    if (!ref.mounted || state.value == null) return;
    final item = PendingItem(
      clientKey: newIdempotencyKey(),
      localId: 'local-${_localSeq++}',
      draft: draft,
      status: PendingStatus.sending,
      queuedAt: ref.read(dmClockProvider)(),
      prepare: prepare,
      localImage: localImage,
    );
    _setPending([..._pending, item]);
    await _attempt(item.localId);
  }

  /// Re-sends with the SAME key. A no-op while the item is already sending (double tap) or can never succeed.
  Future<void> retry(String localId) async {
    if (!ref.mounted) return;
    final item = _item(localId);
    if (item == null || item.status == PendingStatus.sending || !item.canRetry) return;
    _setPending([for (final p in _pending) p.localId == localId ? p.copyWith(status: PendingStatus.sending, clearError: true) : p]);
    await _attempt(localId);
  }

  void discard(String localId) {
    if (!ref.mounted) return;
    _setPending([for (final p in _pending) if (p.localId != localId) p]);
  }

  Future<void> _attempt(String localId) async {
    if (!ref.mounted) return;
    final repo = ref.read(messagesRepositoryProvider);
    final queue = ref.read(threadActionQueueProvider);
    final item = _item(localId);
    if (item == null) return;
    try {
      final sent = await queue.run(threadId, () async {
        var draft = item.draft;
        final prepare = item.prepare;
        if (prepare != null) draft = await prepare(draft);
        final result = await repo.send(threadId, draft, idempotencyKey: item.clientKey);
        return (draft: draft, result: result);
      });
      if (!ref.mounted) return;
      _onSent(localId, sent.draft, sent.result);
    } catch (e) {
      if (!ref.mounted) return;
      _onFailed(localId, e);
    }
  }

  void _onSent(String localId, SendDraft draft, ({String messageId, DateTime createdAt}) result) {
    final s = state.value;
    if (s == null) return;
    final already = s.messages.any((m) => m.id == result.messageId);
    // A refresh may have brought the server's own copy first: that one wins (it has signed URLs, receipts).
    final messages = already
        ? s.messages
        : upsertMessage(
            s.messages,
            DmMessage(
              id: result.messageId,
              senderId: _viewerId,
              createdAt: result.createdAt,
              body: draft.body,
              stickerId: draft.stickerId,
              // Signed URLs come only from the server: '' marks "media, URL not fetched yet" (the bubble shows
              // its placeholder) and the refetch below replaces it.
              imageUrl: draft.imagePath == null ? null : '',
              audioUrl: draft.audioPath == null ? null : '',
              audioDurationSeconds: draft.audioDurationSeconds,
            ),
          );
    state = AsyncData(s.copyWith(messages: messages, pending: [for (final p in s.pending) if (p.localId != localId) p]));
    if (!already && (draft.imagePath != null || draft.audioPath != null || draft.replyToId != null)) unawaited(_reconcile());
  }

  void _onFailed(String localId, Object error) {
    _setPending([for (final p in _pending) p.localId == localId ? p.copyWith(status: PendingStatus.failed, error: error) : p]);
    if (error is ApiException && (error.code == 'blocked' || error.code == 'blocked_by_me' || error.code.startsWith('request_'))) {
      ref.invalidate(threadHeaderProvider(threadId));
    }
  }

  // --- optimistic edit / unsend / forward ---

  DmMessage? _message(String id) {
    for (final m in state.value?.messages ?? const <DmMessage>[]) {
      if (m.id == id) return m;
    }
    return null;
  }

  void _put(DmMessage message) {
    final s = state.value;
    if (s == null || !ref.mounted) return;
    state = AsyncData(s.copyWith(messages: [for (final m in s.messages) m.id == message.id ? message : m]));
  }

  /// Applies [applied] now; on failure puts [original] back, but only if the message is still exactly the
  /// optimistic object (a refresh that already delivered the server's truth wins).
  Future<bool> _optimistic(String messageId, DmMessage applied, DmMessage original, Future<void> Function(MessagesRepository) call) async {
    final repo = ref.read(messagesRepositoryProvider);
    final queue = ref.read(threadActionQueueProvider);
    _put(applied);
    try {
      await queue.run(threadId, () => call(repo));
      return true;
    } catch (e) {
      lastActionError = e;
      if (ref.mounted && identical(_message(messageId), applied)) _put(original);
      return false;
    }
  }

  Future<bool> edit(String messageId, String body) async {
    if (!ref.mounted) return false;
    lastActionError = null;
    final original = _message(messageId);
    if (original == null) return false;
    final applied = original.copyWith(body: body, editedAt: ref.read(dmClockProvider)());
    return _optimistic(messageId, applied, original, (repo) => repo.edit(messageId, body));
  }

  Future<bool> unsend(String messageId) async {
    if (!ref.mounted) return false;
    lastActionError = null;
    final original = _message(messageId);
    if (original == null) return false;
    final applied = original.copyWith(clearContent: true, deletedAt: ref.read(dmClockProvider)());
    return _optimistic(messageId, applied, original, (repo) => repo.unsend(messageId));
  }

  Future<bool> forward(String messageId, String toThreadId) async {
    if (!ref.mounted) return false;
    lastActionError = null;
    final repo = ref.read(messagesRepositoryProvider);
    final queue = ref.read(threadActionQueueProvider);
    final key = newIdempotencyKey();
    try {
      await queue.run(threadId, () => repo.forward(messageId, toThreadId: toThreadId, idempotencyKey: key));
      return true;
    } catch (e) {
      lastActionError = e;
      return false;
    }
  }

  /// Coalesced: while one call is queued (not yet running) further calls are dropped, so a flurry of new
  /// messages costs at most one queued + one running request.
  Future<void> markRead() async {
    if (!ref.mounted || _markReadQueued) return;
    _markReadQueued = true;
    final repo = ref.read(messagesRepositoryProvider);
    final queue = ref.read(threadActionQueueProvider);
    try {
      await queue.run(threadId, () {
        _markReadQueued = false;
        return repo.markRead(threadId);
      });
    } catch (_) {
      // best effort; the next open or new message tries again
    } finally {
      _markReadQueued = false;
    }
  }
}

final threadProvider = AsyncNotifierProvider.autoDispose.family<ThreadNotifier, ThreadView, String>(ThreadNotifier.new);
