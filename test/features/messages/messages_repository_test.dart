import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/core/api/api_client.dart';
import 'package:sentinelx_mobile/core/api/messages_models.dart';
import 'package:sentinelx_mobile/features/messages/messages_repository.dart';

class _Api implements ApiClient {
  final calls = <String>[];

  @override
  Future<ThreadsPage> getMessageThreads({String? cursor, String box = 'inbox'}) async {
    calls.add('threads:$box:$cursor');
    return const ThreadsPage(threads: []);
  }

  @override
  Future<MessagesPage> getThreadMessages(String threadId, {String? before}) async {
    calls.add('messages:$threadId:$before');
    return const MessagesPage(messages: []);
  }

  @override
  Future<({String messageId, DateTime createdAt})> sendMessage(
    String threadId, {
    String? body,
    String? imagePath,
    String? stickerId,
    String? audioPath,
    int? audioDurationSeconds,
    String? replyToId,
    required String idempotencyKey,
  }) async {
    calls.add('send:$threadId:$body:$imagePath:$stickerId:$audioPath:$audioDurationSeconds:$replyToId:$idempotencyKey');
    return (messageId: 'm', createdAt: DateTime.utc(2026));
  }

  @override
  Future<String> forwardMessage(String messageId, {required String toThreadId, required String idempotencyKey}) async {
    calls.add('forward:$messageId:$toThreadId:$idempotencyKey');
    return 'f';
  }

  @override
  Future<void> editMessage(String messageId, String body) async => calls.add('edit:$messageId:$body');

  @override
  Future<void> unsendMessage(String messageId) async => calls.add('unsend:$messageId');

  @override
  Future<void> markThreadRead(String threadId) async => calls.add('read:$threadId');

  @override
  Future<void> markAllDelivered() async => calls.add('delivered');

  @override
  Future<void> blockPlayer(String playerId) async => calls.add('block:$playerId');

  @override
  Future<void> unblockPlayer(String playerId) async => calls.add('unblock:$playerId');

  @override
  Future<void> reportThread(String threadId, {String? messageId, required String reason}) async =>
      calls.add('report:$threadId:$messageId:$reason');

  @override
  Future<void> acceptMessageRequest(String threadId) async => calls.add('accept:$threadId');

  @override
  Future<void> declineMessageRequest(String threadId) async => calls.add('decline:$threadId');

  @override
  Future<({String threadId, RequestState requestState})> startMessageThread(String recipientId) async {
    calls.add('start:$recipientId');
    return (threadId: 't', requestState: RequestState.accepted);
  }

  @override
  Future<ThreadHeader> getMessageThread(String threadId) async {
    calls.add('thread:$threadId');
    return ThreadHeader.fromJson({
      'threadId': threadId,
      'other': {'id': 'p', 'name': 'P'},
      'requestState': 'accepted',
    });
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('ApiMessagesRepository delegates every method to ApiClient with the same arguments', () async {
    final api = _Api();
    final repo = ApiMessagesRepository(api);

    await repo.threads(box: InboxBox.requests, cursor: 'c1');
    await repo.threads(box: InboxBox.inbox);
    await repo.thread('t1');
    await repo.messages('t1', before: 'b1');
    await repo.start('p1');
    await repo.send(
      't1',
      const SendDraft(body: 'hi', imagePath: 'u/i.jpg', stickerId: 'gg', audioPath: 'u/a.m4a', audioDurationSeconds: 7, replyToId: 'r1'),
      idempotencyKey: 'key-send',
    );
    await repo.edit('m1', 'new');
    await repo.unsend('m1');
    await repo.forward('m1', toThreadId: 't2', idempotencyKey: 'key-fwd');
    await repo.markRead('t1');
    await repo.markAllDelivered();
    await repo.block('p1');
    await repo.unblock('p1');
    await repo.report('t1', messageId: 'm1', reason: 'spam');
    await repo.accept('t1');
    await repo.decline('t1');

    expect(api.calls, [
      'threads:requests:c1',
      'threads:inbox:null',
      'thread:t1',
      'messages:t1:b1',
      'start:p1',
      'send:t1:hi:u/i.jpg:gg:u/a.m4a:7:r1:key-send',
      'edit:m1:new',
      'unsend:m1',
      'forward:m1:t2:key-fwd',
      'read:t1',
      'delivered',
      'block:p1',
      'unblock:p1',
      'report:t1:m1:spam',
      'accept:t1',
      'decline:t1',
    ]);
  });

  test('send and forward pass the caller-supplied key through unchanged', () async {
    final api = _Api();
    final repo = ApiMessagesRepository(api);
    await repo.send('t', const SendDraft(body: 'x'), idempotencyKey: 'same');
    await repo.send('t', const SendDraft(body: 'x'), idempotencyKey: 'same');
    expect(api.calls.where((c) => c.endsWith(':same')), hasLength(2));
  });
}
