import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/core/api/api_client.dart';
import 'package:sentinelx_mobile/core/api/chat_models.dart';

class _Adapter implements HttpClientAdapter {
  _Adapter(this.respond);
  final ResponseBody Function(RequestOptions) respond;
  RequestOptions? last;
  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<Uint8List>? s, Future<void>? c) async { last = o; return respond(o); }
  @override
  void close({bool force = false}) {}
}

ResponseBody _stream(List<String> chunks, {int status = 200}) => ResponseBody(
      Stream.fromIterable(chunks.map((c) => Uint8List.fromList(utf8.encode(c)))), status,
      headers: {Headers.contentTypeHeader: [status == 200 ? 'application/x-ndjson' : 'application/json']});

ApiClient _client(_Adapter a, {String? token}) =>
    ApiClient.create(baseUrl: 'https://x.test', appVersion: '1', platform: 'android', accessToken: () async => token, adapter: a);
const _msgs = [ChatTurnMessage('user', 'hi')];

void main() {
  test('lines split across network chunks are reassembled', () async {
    final a = _Adapter((_) => _stream(['{"t":"delta","te', 'xt":"hi"}\n{"t":"do', 'ne","persisted":false}\n']));
    final events = await _client(a).postChatMessage(messages: _msgs, clientTurnId: 't', locale: 'en').toList();
    expect(events.map((e) => e.runtimeType), [ChatDelta, ChatDone]);
  });
  test('a bad line and an unknown event are skipped', () async {
    final a = _Adapter((_) => _stream(['garbage\n{"t":"future"}\n{"t":"delta","text":"ok"}\n']));
    final events = await _client(a).postChatMessage(messages: _msgs, clientTurnId: 't', locale: 'en').toList();
    expect(events, hasLength(1));
  });
  test('a non-200 before the stream is an ApiException with code and fields', () async {
    final a = _Adapter((_) => _stream(['{"error":{"code":"chat_rate_limited","message":"x","fields":{"retryAfterSeconds":"42"}}}'], status: 429));
    expect(
      () => _client(a).postChatMessage(messages: _msgs, clientTurnId: 't', locale: 'en').toList(),
      throwsA(isA<ApiException>().having((e) => e.code, 'code', 'chat_rate_limited').having((e) => e.fields['retryAfterSeconds'], 'retry', '42')),
    );
  });
  test('sends the body, the device id header only when given, and the bearer only when signed in', () async {
    final a = _Adapter((_) => _stream(['{"t":"done","persisted":false}\n']));
    await _client(a).postChatMessage(messages: _msgs, clientTurnId: 'turn-1', locale: 'fr', deviceId: 'device-abc-123').toList();
    expect(a.last!.headers['X-Device-Id'], 'device-abc-123');
    expect(a.last!.headers.containsKey('Authorization'), isFalse);
    expect(a.last!.data, {'messages': [{'role': 'user', 'content': 'hi'}], 'clientTurnId': 'turn-1', 'locale': 'fr'});
    await _client(a, token: 'tok').postChatMessage(messages: _msgs, clientTurnId: 't', locale: 'en').toList();
    expect(a.last!.headers['Authorization'], 'Bearer tok');
    expect(a.last!.headers.containsKey('X-Device-Id'), isFalse);
  });
  test('a connection that drops mid-stream ends the stream without a terminal event (no throw)', () async {
    final a = _Adapter((_) => ResponseBody(Stream<Uint8List>.multi((c) { c.add(Uint8List.fromList(utf8.encode('{"t":"delta","text":"a"}\n'))); c.addError(const FormatException('socket closed')); c.close(); }), 200));
    final events = await _client(a).postChatMessage(messages: _msgs, clientTurnId: 't', locale: 'en').toList();
    expect(events.single, isA<ChatDelta>());
  });
}
