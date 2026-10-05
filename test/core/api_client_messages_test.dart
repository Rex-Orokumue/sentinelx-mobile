import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/core/api/api_client.dart';
import 'package:sentinelx_mobile/core/api/messages_models.dart';

class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.respond);
  final ResponseBody Function(RequestOptions options) respond;
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    requests.add(options);
    return respond(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _json(int status, Object body) =>
    ResponseBody.fromString(jsonEncode(body), status, headers: {Headers.contentTypeHeader: [Headers.jsonContentType]});

ApiClient _client(_FakeAdapter a) => ApiClient.create(
    baseUrl: 'https://api.test', appVersion: '1.0.0', platform: 'android', accessToken: () async => 'tok', adapter: a);

_FakeAdapter _ok(Object? data) => _FakeAdapter((_) => _json(200, {'data': data}));

const _okBody = {'ok': true};

Map<String, dynamic> _threadRow() => {
      'threadId': 't1',
      'other': {'id': 'p1', 'name': 'Rex', 'username': 'rex', 'avatarUrl': null},
      'preview': {'kind': 'text', 'text': 'hi', 'stickerId': null},
      'lastMessageAt': '2026-10-05T10:00:00.000Z',
      'unread': 1,
      'requestState': 'accepted',
      'direction': null,
    };

Map<String, dynamic> _msgRow() => {
      'id': 'm1',
      'senderId': 'p1',
      'body': 'yo',
      'imageUrl': null,
      'stickerId': null,
      'audioUrl': null,
      'audioDurationSeconds': null,
      'forwarded': false,
      'createdAt': '2026-10-05T10:00:00.000Z',
      'deliveredAt': null,
      'readAt': null,
      'editedAt': null,
      'deletedAt': null,
      'replyTo': null,
    };

void main() {
  const base = '/api/mobile/v1/messages';

  group('getMessageThreads', () {
    test('GET, bearer token, default box, parsed', () async {
      final a = _ok({
        'threads': [_threadRow()],
        'nextCursor': 'c2',
        'requestCount': 2,
      });
      final page = await _client(a).getMessageThreads();
      final r = a.requests.single;
      expect(r.method, 'GET');
      expect(r.uri.path, '$base/threads');
      expect(r.headers['Authorization'], 'Bearer tok');
      expect(r.headers.containsKey('Idempotency-Key'), isFalse);
      expect(r.uri.queryParameters, {'box': 'inbox'});
      expect(page.threads.single.threadId, 't1');
      expect(page.nextCursor, 'c2');
      expect(page.requestCount, 2);
    });

    test('cursor only when non-null, URL-encoded; box=requests', () async {
      final a = _ok({'threads': [], 'nextCursor': null, 'requestCount': 0});
      await _client(a).getMessageThreads(cursor: 'a b/c+d', box: 'requests');
      expect(a.requests.single.uri.queryParameters, {'box': 'requests', 'cursor': 'a b/c+d'});
      expect(a.requests.single.uri.query, contains('%2F'));
      expect(a.requests.single.uri.query, contains('%2Bd'));
      expect(a.requests.single.uri.query, isNot(contains('/')));
    });
  });

  group('getMessageThread', () {
    test('GET with bearer, encodes the id, parsed', () async {
      final a = _ok({
        'threadId': 't 1',
        'other': {'id': 'p1', 'name': 'Rex', 'username': null, 'avatarUrl': null},
        'blockedByMe': true,
        'blockedByThem': false,
        'requestState': 'pending',
        'direction': 'outgoing',
      });
      final h = await _client(a).getMessageThread('t 1');
      final r = a.requests.single;
      expect(r.method, 'GET');
      expect(r.uri.path, '$base/threads/t%201');
      expect(r.headers['Authorization'], 'Bearer tok');
      expect(h.blockedByMe, isTrue);
      expect(h.requestState, RequestState.pending);
      expect(h.direction, RequestDirection.outgoing);
    });
  });

  group('getThreadMessages', () {
    test('GET with bearer, no before by default', () async {
      final a = _ok({
        'messages': [_msgRow()],
        'nextBefore': 'b1',
      });
      final page = await _client(a).getThreadMessages('t1');
      final r = a.requests.single;
      expect(r.method, 'GET');
      expect(r.uri.path, '$base/threads/t1/messages');
      expect(r.headers['Authorization'], 'Bearer tok');
      expect(r.uri.queryParameters, isEmpty);
      expect(page.messages.single.id, 'm1');
      expect(page.nextBefore, 'b1');
    });

    test('before is sent and URL-encoded when given', () async {
      final a = _ok({'messages': [], 'nextBefore': null});
      await _client(a).getThreadMessages('t1', before: '2026-10-05T10:00:00+00:00');
      expect(a.requests.single.uri.queryParameters, {'before': '2026-10-05T10:00:00+00:00'});
      expect(a.requests.single.uri.query, contains('%2B'));
    });
  });

  group('startMessageThread', () {
    test('POST recipientId, returns thread id and state', () async {
      final a = _ok({'threadId': 't9', 'requestState': 'pending'});
      final r = await _client(a).startMessageThread('p1');
      final req = a.requests.single;
      expect(req.method, 'POST');
      expect(req.uri.path, '$base/threads');
      expect(req.data, {'recipientId': 'p1'});
      expect(req.headers['Authorization'], 'Bearer tok');
      expect(req.headers.containsKey('Idempotency-Key'), isFalse);
      expect(r.threadId, 't9');
      expect(r.requestState, RequestState.pending);
    });
  });

  group('sendMessage', () {
    test('POST with body only: null fields omitted, Idempotency-Key and bearer present', () async {
      final a = _ok({'messageId': 'm9', 'createdAt': '2026-10-05T10:00:00.000Z'});
      final r = await _client(a).sendMessage('t1', body: 'hello', idempotencyKey: 'key-1');
      final req = a.requests.single;
      expect(req.method, 'POST');
      expect(req.uri.path, '$base/threads/t1/messages');
      expect(req.data, {'body': 'hello'});
      expect(req.headers['Idempotency-Key'], 'key-1');
      expect(req.headers['Authorization'], 'Bearer tok');
      expect(r.messageId, 'm9');
      expect(r.createdAt.toUtc(), DateTime.utc(2026, 10, 5, 10));
    });

    test('voice: audioDurationSeconds is an int, reply id included', () async {
      final a = _ok({'messageId': 'm9', 'createdAt': '2026-10-05T10:00:00.000Z'});
      await _client(a).sendMessage('t1',
          audioPath: 'u/x.m4a', audioDurationSeconds: 7, replyToId: 'r1', idempotencyKey: 'k');
      final data = a.requests.single.data as Map;
      expect(data, {'audioPath': 'u/x.m4a', 'audioDurationSeconds': 7, 'replyToId': 'r1'});
      expect(data['audioDurationSeconds'], isA<int>());
    });

    test('image and sticker fields', () async {
      final a = _ok({'messageId': 'm9', 'createdAt': '2026-10-05T10:00:00.000Z'});
      await _client(a).sendMessage('t1', imagePath: 'u/i.jpg', stickerId: 'gg', idempotencyKey: 'k');
      expect(a.requests.single.data, {'imagePath': 'u/i.jpg', 'stickerId': 'gg'});
    });

    test('a 409 request_pending_limit surfaces its code', () async {
      final a = _FakeAdapter((_) => _json(409, {
            'error': {'code': 'request_pending_limit', 'message': 'nope'}
          }));
      await expectLater(
        _client(a).sendMessage('t1', body: 'x', idempotencyKey: 'k'),
        throwsA(isA<ApiException>().having((e) => e.code, 'code', 'request_pending_limit')),
      );
    });

    test('a 403 blocked surfaces its code', () async {
      final a = _FakeAdapter((_) => _json(403, {
            'error': {'code': 'blocked', 'message': 'nope'}
          }));
      await expectLater(
        _client(a).sendMessage('t1', body: 'x', idempotencyKey: 'k'),
        throwsA(isA<ApiException>().having((e) => e.code, 'code', 'blocked').having((e) => e.status, 'status', 403)),
      );
    });

    test('a 200 body without data is bad_response', () async {
      final a = _FakeAdapter((_) => _json(200, {'nope': 1}));
      await expectLater(
        _client(a).sendMessage('t1', body: 'x', idempotencyKey: 'k'),
        throwsA(isA<ApiException>().having((e) => e.code, 'code', 'bad_response')),
      );
    });
  });

  group('editMessage / unsendMessage', () {
    test('PATCH with body, bearer, no idempotency key', () async {
      final a = _ok(_okBody);
      await _client(a).editMessage('m1', 'new text');
      final r = a.requests.single;
      expect(r.method, 'PATCH');
      expect(r.uri.path, '$base/m1');
      expect(r.data, {'body': 'new text'});
      expect(r.headers['Authorization'], 'Bearer tok');
      expect(r.headers.containsKey('Idempotency-Key'), isFalse);
    });

    test('edit_window_closed 409 surfaces its code', () async {
      final a = _FakeAdapter((_) => _json(409, {
            'error': {'code': 'edit_window_closed', 'message': 'late'}
          }));
      await expectLater(
        _client(a).editMessage('m1', 'x'),
        throwsA(isA<ApiException>().having((e) => e.code, 'code', 'edit_window_closed')),
      );
    });

    test('DELETE unsend', () async {
      final a = _ok(_okBody);
      await _client(a).unsendMessage('m1');
      final r = a.requests.single;
      expect(r.method, 'DELETE');
      expect(r.uri.path, '$base/m1');
      expect(r.headers['Authorization'], 'Bearer tok');
      expect(r.headers.containsKey('Idempotency-Key'), isFalse);
    });
  });

  group('forwardMessage', () {
    test('POST toThreadId with Idempotency-Key, returns the new message id', () async {
      final a = _ok({'messageId': 'm10'});
      final id = await _client(a).forwardMessage('m1', toThreadId: 't2', idempotencyKey: 'fk');
      final r = a.requests.single;
      expect(r.method, 'POST');
      expect(r.uri.path, '$base/m1/forward');
      expect(r.data, {'toThreadId': 't2'});
      expect(r.headers['Idempotency-Key'], 'fk');
      expect(r.headers['Authorization'], 'Bearer tok');
      expect(id, 'm10');
    });
  });

  group('state-changing calls without a key', () {
    Future<RequestOptions> run(Future<void> Function(ApiClient c) call) async {
      final a = _ok(_okBody);
      await call(_client(a));
      return a.requests.single;
    }

    void common(RequestOptions r, String method, String path) {
      expect(r.method, method);
      expect(r.uri.path, path);
      expect(r.headers['Authorization'], 'Bearer tok');
      expect(r.headers.containsKey('Idempotency-Key'), isFalse);
    }

    test('markThreadRead', () async => common(await run((c) => c.markThreadRead('t1')), 'POST', '$base/threads/t1/read'));
    test('markAllDelivered', () async => common(await run((c) => c.markAllDelivered()), 'POST', '$base/delivered'));
    test('blockPlayer', () async => common(await run((c) => c.blockPlayer('p1')), 'PUT', '$base/blocks/p1'));
    test('unblockPlayer', () async => common(await run((c) => c.unblockPlayer('p1')), 'DELETE', '$base/blocks/p1'));
    test('acceptMessageRequest',
        () async => common(await run((c) => c.acceptMessageRequest('t1')), 'POST', '$base/threads/t1/accept'));
    test('declineMessageRequest',
        () async => common(await run((c) => c.declineMessageRequest('t1')), 'POST', '$base/threads/t1/decline'));

    test('reportThread sends reason, messageId only when given', () async {
      var r = await run((c) => c.reportThread('t1', reason: 'spam'));
      common(r, 'POST', '$base/threads/t1/report');
      expect(r.data, {'reason': 'spam'});
      r = await run((c) => c.reportThread('t1', reason: 'spam', messageId: 'm1'));
      expect(r.data, {'reason': 'spam', 'messageId': 'm1'});
    });
  });

  test('usedOperations lists all 15 messages operations', () {
    const ids = [
      'getMessageThreads',
      'getMessageThread',
      'getThreadMessages',
      'startMessageThread',
      'sendMessage',
      'editMessage',
      'unsendMessage',
      'forwardMessage',
      'markThreadRead',
      'markAllDelivered',
      'blockPlayer',
      'unblockPlayer',
      'reportThread',
      'acceptMessageRequest',
      'declineMessageRequest',
    ];
    for (final id in ids) {
      expect(ApiClient.usedOperations.containsKey(id), isTrue, reason: id);
    }
  });
}
