import '../../core/api/api_client.dart';
import '../../core/api/messages_models.dart';

enum InboxBox {
  inbox('inbox'),
  requests('requests');

  const InboxBox(this.wire);
  final String wire;
}

/// What the composer hands the repository. Exactly the fields the `sendMessage` contract accepts; null fields
/// are omitted from the request.
class SendDraft {
  const SendDraft({this.body, this.imagePath, this.stickerId, this.audioPath, this.audioDurationSeconds, this.replyToId});

  final String? body;
  final String? imagePath;
  final String? stickerId;
  final String? audioPath;
  final int? audioDurationSeconds;
  final String? replyToId;

  SendDraft copyWith({String? imagePath, String? audioPath}) => SendDraft(
        body: body,
        imagePath: imagePath ?? this.imagePath,
        stickerId: stickerId,
        audioPath: audioPath ?? this.audioPath,
        audioDurationSeconds: audioDurationSeconds,
        replyToId: replyToId,
      );
}

/// Everything the DM screens need. Every viewer-specific read and every write goes through [ApiClient]
/// (never PostgREST); realtime only nudges a refetch. Screens read this through `messagesRepositoryProvider`
/// and never construct it.
abstract class MessagesRepository {
  Future<ThreadsPage> threads({required InboxBox box, String? cursor});
  Future<ThreadHeader> thread(String threadId);
  Future<MessagesPage> messages(String threadId, {String? before});
  Future<({String threadId, RequestState requestState})> start(String recipientId);
  Future<({String messageId, DateTime createdAt})> send(String threadId, SendDraft draft, {required String idempotencyKey});
  Future<void> edit(String messageId, String body);
  Future<void> unsend(String messageId);
  Future<String> forward(String messageId, {required String toThreadId, required String idempotencyKey});
  Future<void> markRead(String threadId);
  Future<void> markAllDelivered();
  Future<void> block(String playerId);
  Future<void> unblock(String playerId);
  Future<void> report(String threadId, {String? messageId, required String reason});
  Future<void> accept(String threadId);
  Future<void> decline(String threadId);
}

class ApiMessagesRepository implements MessagesRepository {
  ApiMessagesRepository(this._api);

  final ApiClient _api;

  @override
  Future<ThreadsPage> threads({required InboxBox box, String? cursor}) => _api.getMessageThreads(cursor: cursor, box: box.wire);

  @override
  Future<ThreadHeader> thread(String threadId) => _api.getMessageThread(threadId);

  @override
  Future<MessagesPage> messages(String threadId, {String? before}) => _api.getThreadMessages(threadId, before: before);

  @override
  Future<({String threadId, RequestState requestState})> start(String recipientId) => _api.startMessageThread(recipientId);

  @override
  Future<({String messageId, DateTime createdAt})> send(String threadId, SendDraft draft, {required String idempotencyKey}) =>
      _api.sendMessage(
        threadId,
        body: draft.body,
        imagePath: draft.imagePath,
        stickerId: draft.stickerId,
        audioPath: draft.audioPath,
        audioDurationSeconds: draft.audioDurationSeconds,
        replyToId: draft.replyToId,
        idempotencyKey: idempotencyKey,
      );

  @override
  Future<void> edit(String messageId, String body) => _api.editMessage(messageId, body);

  @override
  Future<void> unsend(String messageId) => _api.unsendMessage(messageId);

  @override
  Future<String> forward(String messageId, {required String toThreadId, required String idempotencyKey}) =>
      _api.forwardMessage(messageId, toThreadId: toThreadId, idempotencyKey: idempotencyKey);

  @override
  Future<void> markRead(String threadId) => _api.markThreadRead(threadId);

  @override
  Future<void> markAllDelivered() => _api.markAllDelivered();

  @override
  Future<void> block(String playerId) => _api.blockPlayer(playerId);

  @override
  Future<void> unblock(String playerId) => _api.unblockPlayer(playerId);

  @override
  Future<void> report(String threadId, {String? messageId, required String reason}) =>
      _api.reportThread(threadId, messageId: messageId, reason: reason);

  @override
  Future<void> accept(String threadId) => _api.acceptMessageRequest(threadId);

  @override
  Future<void> decline(String threadId) => _api.declineMessageRequest(threadId);
}
