import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/core/api/api_client.dart';

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

ApiClient _client(_FakeAdapter a, {Future<String?> Function()? token}) => ApiClient.create(
    baseUrl: 'https://api.test', appVersion: '1.0.0', platform: 'android', accessToken: token ?? () async => 'tok', adapter: a);

_FakeAdapter _ok(Object? data) => _FakeAdapter((_) => _json(200, {'data': data}));

const _itemId = '11111111-1111-4111-8111-111111111111';

void main() {
  test('getStore reads the public catalogue and sends no bearer when signed out', () async {
    final a = _ok({'balance': null, 'items': <Object>[]});
    final c = await _client(a, token: () async => null).getStore();
    expect(a.requests.single.method, 'GET');
    expect(a.requests.single.uri.toString(), 'https://api.test/api/mobile/v1/store');
    expect(a.requests.single.headers.containsKey('Authorization'), isFalse);
    expect(c.balance, isNull);
  });

  test('getStore sends the bearer when signed in, so ownership and balance come back', () async {
    final a = _ok({'balance': 1250, 'items': <Object>[]});
    final c = await _client(a).getStore();
    expect(a.requests.single.headers['Authorization'], 'Bearer tok');
    expect(c.balance, 1250);
  });

  test('purchaseStoreItem posts to the item with the Idempotency-Key and parses the outcome', () async {
    final a = _ok({'balance': 350, 'itemId': _itemId});
    final r = await _client(a).purchaseStoreItem(_itemId, idempotencyKey: 'key-1');
    expect(a.requests.single.method, 'POST');
    expect(a.requests.single.uri.toString(), 'https://api.test/api/mobile/v1/store/$_itemId/purchase');
    expect(a.requests.single.headers['Idempotency-Key'], 'key-1');
    expect(r.balance, 350);
  });

  test('equip and unequip post to their own paths with no idempotency header', () async {
    final eq = _ok({'itemId': _itemId, 'category': 'avatar_border'});
    await _client(eq).equipStoreItem(_itemId);
    expect(eq.requests.single.uri.toString(), 'https://api.test/api/mobile/v1/store/$_itemId/equip');
    expect(eq.requests.single.headers.containsKey('Idempotency-Key'), isFalse);

    final un = _ok({'itemId': _itemId, 'category': 'avatar_border'});
    final out = await _client(un).unequipStoreItem(_itemId);
    expect(un.requests.single.uri.toString(), 'https://api.test/api/mobile/v1/store/$_itemId/unequip');
    expect(out.category, 'avatar_border');
  });

  test('an item id is path-encoded', () async {
    final a = _ok({'balance': 1, 'itemId': 'a b'});
    await _client(a).purchaseStoreItem('a b', idempotencyKey: 'k');
    expect(a.requests.single.uri.toString(), contains('/store/a%20b/purchase'));
  });

  test('insufficient_coins surfaces as an ApiException with that code', () async {
    final a = _FakeAdapter((_) => _json(422, {
          'error': {'code': 'insufficient_coins', 'message': 'Not enough SX Coins.'},
        }));
    await expectLater(
      _client(a).purchaseStoreItem(_itemId, idempotencyKey: 'k'),
      throwsA(isA<ApiException>().having((e) => e.code, 'code', 'insufficient_coins')),
    );
  });
}
