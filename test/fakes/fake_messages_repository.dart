import 'dart:async';

import 'package:sentinelx_mobile/core/api/api_client.dart';
import 'package:sentinelx_mobile/core/api/messages_models.dart';
import 'package:sentinelx_mobile/features/messages/messages_repository.dart';

ThreadSummary thread(
  String id, {
  int unread = 0,
  DateTime? at,
  PreviewKind kind = PreviewKind.text,
  String? text,
  String? stickerId,
  RequestState requestState = RequestState.accepted,
  RequestDirection? direction,
  String? name,
  String? username = 'rex',
  String? avatarUrl,
  String? otherId,
}) =>
    ThreadSummary(
      threadId: id,
      other: OtherPlayer(id: otherId ?? 'p-$id', name: name ?? 'Player $id', username: username, avatarUrl: avatarUrl),
      preview: ThreadPreview(kind: kind, text: text ?? (kind == PreviewKind.text ? 'hello $id' : null), stickerId: stickerId),
      lastMessageAt: at ?? DateTime.utc(2026, 10, 5, 10),
      unread: unread,
      requestState: requestState,
      direction: direction,
    );

DmMessage dmMsg(
  String id, {
  String sender = 'them',
  String? body,
  String? imageUrl,
  String? stickerId,
  String? audioUrl,
  int? audioSeconds,
  DateTime? at,
  DateTime? deliveredAt,
  DateTime? readAt,
  DateTime? editedAt,
  DateTime? deletedAt,
  bool forwarded = false,
  ReplyPreview? replyTo,
}) =>
    DmMessage(
      id: id,
      senderId: sender,
      createdAt: at ?? DateTime.utc(2026, 10, 5, 10),
      body: body ?? (imageUrl == null && stickerId == null && audioUrl == null && deletedAt == null ? 'text $id' : null),
      imageUrl: imageUrl,
      stickerId: stickerId,
      audioUrl: audioUrl,
      audioDurationSeconds: audioSeconds,
      forwarded: forwarded,
      deliveredAt: deliveredAt,
      readAt: readAt,
      editedAt: editedAt,
      deletedAt: deletedAt,
      replyTo: replyTo,
    );

ThreadHeader header(
  String id, {
  bool blockedByMe = false,
  bool blockedByThem = false,
  RequestState requestState = RequestState.accepted,
  RequestDirection? direction,
  String? name,
  String? username = 'rex',
  String? otherId,
}) =>
    ThreadHeader(
      threadId: id,
      other: OtherPlayer(id: otherId ?? 'p-$id', name: name ?? 'Player $id', username: username),
      blockedByMe: blockedByMe,
      blockedByThem: blockedByThem,
      requestState: requestState,
      direction: direction,
    );

/// In-memory [MessagesRepository]. Lists are newest first; cursors are positional indexes. Any operation can be
/// held in flight (`holds[op]`, consumed by the next call) or made to fail (`failures[op]`, persistent until
/// removed). `send` and `forward` replay by idempotency key like the real server.
class FakeMessagesRepository implements MessagesRepository {
  FakeMessagesRepository({List<ThreadSummary>? inbox, List<ThreadSummary>? requests, this.requestCount = 0})
      : inbox = inbox ?? [],
        requests = requests ?? [];

  String viewerId = 'me';
  List<ThreadSummary> inbox;
  List<ThreadSummary> requests;
  int requestCount;
  int threadPageSize = 20;
  int messagePageSize = 40;
  final headers = <String, ThreadHeader>{};
  final messagesByThread = <String, List<DmMessage>>{};

  final holds = <String, Completer<void>>{};
  final failures = <String, Object>{};

  /// Thrown by `send` AFTER the message was committed (and stored by key): the ambiguous-timeout case.
  Object? sendFailsAfterCommit;

  // --- call logs ---
  final threadsCalls = <({InboxBox box, String? cursor})>[];
  final threadCalls = <String>[];
  final messagesCalls = <({String threadId, String? before})>[];
  final startCalls = <String>[];
  final sendCalls = <({String threadId, SendDraft draft, String key})>[];
  final editCalls = <({String messageId, String body})>[];
  final unsendCalls = <String>[];
  final forwardCalls = <({String messageId, String toThreadId, String key})>[];
  final markReadCalls = <String>[];
  int markAllDeliveredCalls = 0;
  final blockCalls = <String>[];
  final unblockCalls = <String>[];
  final reportCalls = <({String threadId, String? messageId, String reason})>[];
  final acceptCalls = <String>[];
  final declineCalls = <String>[];

  /// Ordered log of every mutating call, for serialization assertions: 'send:KEY', 'edit:ID', ...
  final opLog = <String>[];

  int _serverMessages = 0;
  final _sentByKey = <String, ({String messageId, DateTime createdAt})>{};
  final _forwardedByKey = <String, String>{};

  /// Messages the fake server created through `send`, in creation order.
  int get createdMessageCount => _serverMessages;

  Future<void> _enter(String op) async {
    final h = holds.remove(op);
    if (h != null) await h.future;
    final f = failures[op];
    if (f != null) throw f;
  }

  List<DmMessage> _list(String threadId) => messagesByThread.putIfAbsent(threadId, () => []);

  @override
  Future<ThreadsPage> threads({required InboxBox box, String? cursor}) async {
    threadsCalls.add((box: box, cursor: cursor));
    await _enter('threads');
    final all = box == InboxBox.inbox ? inbox : requests;
    final start = cursor == null ? 0 : int.parse(cursor);
    final end = (start + threadPageSize).clamp(0, all.length);
    return ThreadsPage(
      threads: all.sublist(start.clamp(0, all.length), end),
      nextCursor: end < all.length ? '$end' : null,
      requestCount: requestCount,
    );
  }

  @override
  Future<ThreadHeader> thread(String threadId) async {
    threadCalls.add(threadId);
    await _enter('thread');
    return headers[threadId] ?? header(threadId);
  }

  @override
  Future<MessagesPage> messages(String threadId, {String? before}) async {
    messagesCalls.add((threadId: threadId, before: before));
    await _enter('messages');
    final all = _list(threadId);
    final start = before == null ? 0 : int.parse(before);
    final end = (start + messagePageSize).clamp(0, all.length);
    return MessagesPage(
      messages: all.sublist(start.clamp(0, all.length), end),
      nextBefore: end < all.length ? '$end' : null,
    );
  }

  @override
  Future<({String threadId, RequestState requestState})> start(String recipientId) async {
    startCalls.add(recipientId);
    await _enter('start');
    return (threadId: 'thread-$recipientId', requestState: RequestState.accepted);
  }

  @override
  Future<({String messageId, DateTime createdAt})> send(String threadId, SendDraft draft, {required String idempotencyKey}) async {
    sendCalls.add((threadId: threadId, draft: draft, key: idempotencyKey));
    opLog.add('send:$idempotencyKey');
    await _enter('send');
    var result = _sentByKey[idempotencyKey];
    if (result == null) {
      final id = 'srv-${++_serverMessages}';
      final at = DateTime.utc(2026, 10, 5, 12).add(Duration(seconds: _serverMessages));
      result = (messageId: id, createdAt: at);
      _sentByKey[idempotencyKey] = result;
      _list(threadId).insert(
        0,
        DmMessage(
          id: id,
          senderId: viewerId,
          createdAt: at,
          body: draft.body,
          stickerId: draft.stickerId,
          imageUrl: draft.imagePath == null ? null : 'https://signed.test/${draft.imagePath}',
          audioUrl: draft.audioPath == null ? null : 'https://signed.test/${draft.audioPath}',
          audioDurationSeconds: draft.audioDurationSeconds,
        ),
      );
    }
    final afterCommit = holds.remove('send:after');
    if (afterCommit != null) await afterCommit.future; // committed, response not delivered yet
    final late = sendFailsAfterCommit;
    if (late != null) {
      sendFailsAfterCommit = null;
      throw late;
    }
    return result;
  }

  void _replace(String messageId, DmMessage Function(DmMessage) f) {
    for (final list in messagesByThread.values) {
      final i = list.indexWhere((m) => m.id == messageId);
      if (i >= 0) list[i] = f(list[i]);
    }
  }

  @override
  Future<void> edit(String messageId, String body) async {
    editCalls.add((messageId: messageId, body: body));
    opLog.add('edit:$messageId');
    await _enter('edit');
    _replace(messageId, (m) => m.copyWith(body: body, editedAt: DateTime.utc(2026, 10, 5, 13)));
  }

  @override
  Future<void> unsend(String messageId) async {
    unsendCalls.add(messageId);
    opLog.add('unsend:$messageId');
    await _enter('unsend');
    _replace(messageId, (m) => m.copyWith(clearContent: true, deletedAt: DateTime.utc(2026, 10, 5, 13)));
  }

  @override
  Future<String> forward(String messageId, {required String toThreadId, required String idempotencyKey}) async {
    forwardCalls.add((messageId: messageId, toThreadId: toThreadId, key: idempotencyKey));
    opLog.add('forward:$idempotencyKey');
    await _enter('forward');
    return _forwardedByKey.putIfAbsent(idempotencyKey, () => 'fwd-${++_serverMessages}');
  }

  @override
  Future<void> markRead(String threadId) async {
    markReadCalls.add(threadId);
    opLog.add('markRead:$threadId');
    await _enter('markRead');
  }

  @override
  Future<void> markAllDelivered() async {
    markAllDeliveredCalls++;
    await _enter('markAllDelivered');
  }

  @override
  Future<void> block(String playerId) async {
    blockCalls.add(playerId);
    await _enter('block');
  }

  @override
  Future<void> unblock(String playerId) async {
    unblockCalls.add(playerId);
    await _enter('unblock');
  }

  @override
  Future<void> report(String threadId, {String? messageId, required String reason}) async {
    reportCalls.add((threadId: threadId, messageId: messageId, reason: reason));
    await _enter('report');
  }

  @override
  Future<void> accept(String threadId) async {
    acceptCalls.add(threadId);
    await _enter('accept');
  }

  @override
  Future<void> decline(String threadId) async {
    declineCalls.add(threadId);
    await _enter('decline');
  }
}

ApiException apiError(String code, {int status = 400}) => ApiException(status: status, code: code, message: 'server text');

const networkError = ApiException(status: 0, code: 'network', message: 'Network error');
