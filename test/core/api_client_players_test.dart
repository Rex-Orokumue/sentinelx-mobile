import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/core/api/api_client.dart';

import '../support/players_fixtures.dart';

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

ApiClient _client(_FakeAdapter a, {String? token = 'tok'}) => ApiClient.create(
    baseUrl: 'https://api.test', appVersion: '1.2.3', platform: 'android', accessToken: () async => token, adapter: a);

void main() {
  test('searchPlayers sends q only when non-empty', () async {
    final adapter = _FakeAdapter((_) => _json(200, {'data': <Object>[]}));
    await _client(adapter).searchPlayers(q: 'ada');
    await _client(adapter).searchPlayers();
    expect(adapter.requests[0].uri.path, '/api/mobile/v1/players');
    expect(adapter.requests[0].uri.queryParameters, {'q': 'ada'});
    expect(adapter.requests[1].uri.queryParameters, isEmpty);
  });

  test('getPlayerProfile encodes the username and parses; 404 surfaces as ApiException', () async {
    final adapter = _FakeAdapter((o) => o.uri.path.endsWith('/nobody')
        ? _json(404, {'error': {'code': 'not_found', 'message': 'Not found.'}})
        : _json(200, {'data': profileJson()}));
    final api = _client(adapter);
    expect((await api.getPlayerProfile('ada')).player.username, 'ada');
    await expectLater(api.getPlayerProfile('nobody'), throwsA(isA<ApiException>().having((e) => e.status, 'status', 404)));
    await api.getPlayerProfile('a b/c');
    expect(adapter.requests.last.uri.path, '/api/mobile/v1/players/a%20b%2Fc');
  });

  test('followers/following hit their own paths and parse bare arrays', () async {
    final adapter = _FakeAdapter((_) => _json(200, {'data': [followEntryJson('u1', 'ada'), followEntryJson('u2', null)]}));
    final api = _client(adapter);
    final f = await api.getPlayerFollowers('ada');
    expect(f.map((e) => e.isDeleted), [false, true]);
    await api.getPlayerFollowing('ada');
    expect(adapter.requests.map((r) => r.uri.path), ['/api/mobile/v1/players/ada/followers', '/api/mobile/v1/players/ada/following']);
  });

  test('getMyFollows needs the bearer token', () async {
    final adapter = _FakeAdapter((_) => _json(200, {'data': {'followingIds': ['a'], 'followerIds': []}}));
    final sets = await _client(adapter).getMyFollows();
    expect(sets.followingIds, {'a'});
    expect(adapter.requests.single.headers['Authorization'], 'Bearer tok');
  });

  test('followPlayer sends PUT with the Idempotency-Key header; unfollow sends DELETE without one', () async {
    final adapter = _FakeAdapter((o) => o.method == 'PUT'
        ? _json(200, {'data': {'following': true, 'created': true}})
        : _json(200, {'data': {'following': false}}));
    final api = _client(adapter);
    final put = await api.followPlayer('ada', idempotencyKey: 'key-1');
    expect(put.created, isTrue);
    expect(adapter.requests[0].method, 'PUT');
    expect(adapter.requests[0].headers['Idempotency-Key'], 'key-1');
    final del = await api.unfollowPlayer('ada');
    expect(del.following, isFalse);
    expect(adapter.requests[1].method, 'DELETE');
    expect(adapter.requests[1].headers.containsKey('Idempotency-Key'), isFalse);
    expect(adapter.requests[1].uri.path, '/api/mobile/v1/players/ada/follow');
  });

  test('follow error codes reach the caller (self / blocked)', () async {
    final adapter = _FakeAdapter((_) => _json(403, {'error': {'code': 'follow_blocked', 'message': 'nope'}}));
    await expectLater(
      _client(adapter).followPlayer('ada', idempotencyKey: 'k'),
      throwsA(isA<ApiException>().having((e) => e.code, 'code', 'follow_blocked')),
    );
  });

  test('getMyProgress parses and history methods pass the cursor only when set', () async {
    final adapter = _FakeAdapter((o) {
      if (o.uri.path.endsWith('/me/progress')) {
        return _json(200, {'data': {'xp': 10, 'membershipTier': 'recruit', 'tierProgress': null, 'sxScore': 1, 'sentinelTier': null, 'coinBalance': 0, 'seasonStanding': null}});
      }
      return _json(200, {'data': {'items': <Object>[], 'nextCursor': null}});
    });
    final api = _client(adapter);
    expect((await api.getMyProgress()).xp, 10);
    await api.getMyXpEvents();
    await api.getMyXpEvents(cursor: 'abc_-=');
    await api.getMySxScoreEvents(cursor: 'c2');
    await api.getMyCoinTransactions();
    expect(adapter.requests[1].uri.queryParameters, isEmpty);
    expect(adapter.requests[2].uri.queryParameters, {'cursor': 'abc_-='});
    expect(adapter.requests[3].uri.path, '/api/mobile/v1/me/sx-score-events');
    expect(adapter.requests[4].uri.path, '/api/mobile/v1/me/coin-transactions');
  });
}
