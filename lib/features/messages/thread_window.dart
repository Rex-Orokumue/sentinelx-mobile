import 'dart:typed_data';

import '../../core/api/api_client.dart';
import '../../core/api/messages_models.dart';
import 'messages_repository.dart';

enum PendingStatus { sending, failed }

/// Error codes after which resending the same message cannot succeed: Retry is hidden, only Discard remains.
const kNonRetryableCodes = {
  'blocked',
  'blocked_by_me',
  'messaging_restricted',
  'request_pending_limit',
  'request_media_not_allowed',
  'validation',
};

/// An outgoing message the server has not confirmed. [clientKey] is the idempotency key, generated once per
/// compose action and reused by every retry of it, so an ambiguous failure can never duplicate the message.
class PendingItem {
  const PendingItem({
    required this.clientKey,
    required this.localId,
    required this.draft,
    required this.status,
    required this.queuedAt,
    this.error,
    this.prepare,
    this.localImage,
  });

  final String clientKey;
  final String localId;
  final SendDraft draft;
  final PendingStatus status;
  final DateTime queuedAt;
  final Object? error;

  /// Optional step run before each send attempt (media upload). It must be idempotent: a retry calls it again.
  final Future<SendDraft> Function(SendDraft draft)? prepare;

  /// The sanitized photo bytes shown in the bubble while it uploads (never the remote URL).
  final Uint8List? localImage;

  bool get canRetry {
    final e = error;
    return !(e is ApiException && kNonRetryableCodes.contains(e.code));
  }

  PendingItem copyWith({PendingStatus? status, Object? error, bool clearError = false}) => PendingItem(
        clientKey: clientKey,
        localId: localId,
        draft: draft,
        status: status ?? this.status,
        queuedAt: queuedAt,
        error: clearError ? null : (error ?? this.error),
        prepare: prepare,
        localImage: localImage,
      );
}

class ThreadView {
  const ThreadView({this.messages = const [], this.nextBefore, this.pending = const [], this.loadingOlder = false});

  /// Server truth, newest first.
  final List<DmMessage> messages;
  final String? nextBefore;
  final List<PendingItem> pending;
  final bool loadingOlder;

  static const empty = ThreadView();

  bool get hasOlder => nextBefore != null;

  ThreadView copyWith({
    List<DmMessage>? messages,
    Object? nextBefore = _keep,
    List<PendingItem>? pending,
    bool? loadingOlder,
  }) =>
      ThreadView(
        messages: messages ?? this.messages,
        nextBefore: identical(nextBefore, _keep) ? this.nextBefore : nextBefore as String?,
        pending: pending ?? this.pending,
        loadingOlder: loadingOlder ?? this.loadingOlder,
      );
}

const _keep = Object();

class MergeResult {
  const MergeResult({required this.messages, required this.nextBefore, required this.droppedOld});

  final List<DmMessage> messages;
  final String? nextBefore;

  /// True when no overlap with the old window was found and the old window was replaced.
  final bool droppedOld;
}

/// Merges the newest [page] into [window] (both newest first): a row in the page replaces the loaded one by id,
/// new rows are inserted, older loaded rows are kept untouched, and a loaded row newer than the whole page
/// (a send that landed after the fetch) is kept. A loaded row inside the page's range that the server no longer
/// returns is dropped.
List<DmMessage> mergeNewestPage(List<DmMessage> window, MessagesPage page) {
  if (page.messages.isEmpty) return window;
  final pageIds = {for (final m in page.messages) m.id};
  final newest = page.messages.first.createdAt;
  final oldest = page.messages.last.createdAt;
  final newer = [for (final m in window) if (!pageIds.contains(m.id) && m.createdAt.isAfter(newest)) m];
  final older = [for (final m in window) if (!pageIds.contains(m.id) && !m.createdAt.isAfter(oldest) && !m.createdAt.isAfter(newest)) m];
  return [...newer, ...page.messages, ...older];
}

/// Brings [window] up to date after a gap (resume, reconnect, a media URL error, a nudge). Fetches the newest
/// page and keeps walking to older pages until a fetched page overlaps the loaded window by id, so more than
/// a page of new messages never leaves a hole. With no overlap within [maxPages] the old window is dropped and
/// replaced by what was fetched (with more to load).
Future<MergeResult> reconcileWindow({
  required List<DmMessage> window,
  required String? windowNextBefore,
  required Future<MessagesPage> Function(String? before) fetch,
  int maxPages = 10,
}) async {
  final first = await fetch(null);
  if (window.isEmpty) {
    return MergeResult(messages: first.messages, nextBefore: first.nextBefore, droppedOld: false);
  }
  final windowIds = {for (final m in window) m.id};
  final collected = [...first.messages];
  var cursor = first.nextBefore;
  var pages = 1;
  bool overlaps() => collected.any((m) => windowIds.contains(m.id));
  while (!overlaps() && cursor != null && pages < maxPages) {
    final next = await fetch(cursor);
    collected.addAll(next.messages);
    cursor = next.nextBefore;
    pages++;
  }
  if (overlaps()) {
    return MergeResult(
      messages: mergeNewestPage(window, MessagesPage(messages: collected, nextBefore: cursor)),
      nextBefore: windowNextBefore,
      droppedOld: false,
    );
  }
  return MergeResult(messages: collected, nextBefore: cursor, droppedOld: true);
}

/// Appends an older [page] below [window], skipping a message that slid across the page boundary.
List<DmMessage> appendOlder(List<DmMessage> window, MessagesPage page) {
  final seen = {for (final m in window) m.id};
  return [...window, for (final m in page.messages) if (seen.add(m.id)) m];
}

/// Replaces [message] by id, or inserts it in `createdAt` order (newest first).
List<DmMessage> upsertMessage(List<DmMessage> window, DmMessage message) {
  final i = window.indexWhere((m) => m.id == message.id);
  if (i >= 0) return [...window]..[i] = message;
  final at = window.indexWhere((m) => m.createdAt.isBefore(message.createdAt));
  return [...window]..insert(at < 0 ? window.length : at, message);
}
