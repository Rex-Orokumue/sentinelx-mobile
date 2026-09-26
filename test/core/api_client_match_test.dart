import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/core/api/api_client.dart';

import '../support/match_fixtures.dart';

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

ResponseBody _json(int status, Object body) => ResponseBody.fromString(jsonEncode(body), status,
    headers: {Headers.contentTypeHeader: [Headers.jsonContentType]});

ApiClient _client(_FakeAdapter a) => ApiClient.create(
    baseUrl: 'https://api.test', appVersion: '1.0.0', platform: 'android', accessToken: () async => 'tok', adapter: a);

_FakeAdapter _ok(Object data) => _FakeAdapter((_) => _json(200, {'data': data}));

void main() {
  test('getTournamentBracket hits the right path', () async {
    final a = _ok(bracketJson());
    final b = await _client(a).getTournamentBracket('t1');
    expect(a.requests.single.method, 'GET');
    expect(a.requests.single.path, '/api/mobile/v1/tournaments/t1/bracket');
    expect(b.hasGroups, isTrue);
  });

  test('getTournamentStandings sends the stage query and unwraps rows', () async {
    final a = _ok({
      'rows': [
        {
          'entrantId': 'e1',
          'displayName': 'Ada',
          'played': 1,
          'totalPoints': 10,
          'totalKills': 2,
          'bestPlacement': 1,
          'lastRoundPlacement': 1,
          'rank': 1,
          'advancing': true,
          'unresolvedTieWith': <String>[],
        },
      ],
    });
    final rows = await _client(a).getTournamentStandings('t1', 's1');
    expect(a.requests.single.uri.path, '/api/mobile/v1/tournaments/t1/standings');
    expect(a.requests.single.uri.queryParameters['stage'], 's1');
    expect(rows.single.displayName, 'Ada');
  });

  test('getTournamentResults, getMatchCentre and getMeSummary hit the right paths', () async {
    var a = _ok({'champion': null, 'noWinner': false});
    await _client(a).getTournamentResults('t1');
    expect(a.requests.single.path, '/api/mobile/v1/tournaments/t1/results');
    a = _ok(centreJson());
    await _client(a).getMatchCentre('m1');
    expect(a.requests.single.path, '/api/mobile/v1/matches/m1/centre');
    a = _ok(summaryJson());
    await _client(a).getMeSummary();
    expect(a.requests.single.path, '/api/mobile/v1/me/summary');
  });

  test('getSquadLookup URL-encodes query parameters and unwraps the squad', () async {
    final a = _ok({
      'squad': {'id': 's1', 'name': 'Lions', 'memberCount': 1, 'teamSize': 4},
    });
    final s = await _client(a).getSquadLookup(tournamentId: 't 1', code: 'A&B');
    expect(a.requests.single.uri.path, '/api/mobile/v1/squads/lookup');
    expect(a.requests.single.uri.queryParameters, {'tournamentId': 't 1', 'code': 'A&B'});
    expect(a.requests.single.uri.toString(), isNot(contains('A&B')));
    expect(s.name, 'Lions');
  });

  test('postMatchCheckIn sends no Idempotency-Key', () async {
    final a = _ok({'success': true});
    await _client(a).postMatchCheckIn('m1');
    expect(a.requests.single.method, 'POST');
    expect(a.requests.single.path, '/api/mobile/v1/matches/m1/check-in');
    expect(a.requests.single.headers.containsKey('Idempotency-Key'), isFalse);
  });

  test('postMatchResult sends the header and body', () async {
    final a = _ok({'success': true});
    await _client(a).postMatchResult('m1', scoreA: 2, scoreB: 1, recordingUrl: 'https://y/x', screenshotPath: 'u/m1/1-a.png', idempotencyKey: 'k1');
    final r = a.requests.single;
    expect(r.path, '/api/mobile/v1/matches/m1/result');
    expect(r.headers['Idempotency-Key'], 'k1');
    expect(r.data, {'scoreA': 2, 'scoreB': 1, 'recordingUrl': 'https://y/x', 'screenshotPath': 'u/m1/1-a.png'});
  });

  test('rating, wager, lobby result and squad create send header and body', () async {
    var a = _ok({'success': true});
    await _client(a).postMatchRating('m1', stars: 4, idempotencyKey: 'k2');
    expect(a.requests.single.path, '/api/mobile/v1/matches/m1/rating');
    expect(a.requests.single.headers['Idempotency-Key'], 'k2');
    expect(a.requests.single.data, {'stars': 4});

    a = _ok({'success': true});
    await _client(a).postMatchWager('m1', pickPlayerId: 'p1', stakeCoins: 50, idempotencyKey: 'k3');
    expect(a.requests.single.path, '/api/mobile/v1/matches/m1/wager');
    expect(a.requests.single.headers['Idempotency-Key'], 'k3');
    expect(a.requests.single.data, {'pickPlayerId': 'p1', 'stakeCoins': 50});

    a = _ok({'success': true});
    await _client(a).postLobbyResult('l1', placement: 3, kills: 7, screenshotPath: 'u/l1/1-a.png', idempotencyKey: 'k4');
    expect(a.requests.single.path, '/api/mobile/v1/lobbies/l1/result');
    expect(a.requests.single.headers['Idempotency-Key'], 'k4');
    expect(a.requests.single.data, {'placement': 3, 'kills': 7, 'screenshotPath': 'u/l1/1-a.png'});

    a = _ok({'squadId': 's1', 'inviteCode': 'ABC'});
    final sq = await _client(a).postSquads(tournamentId: 't1', name: 'Lions', idempotencyKey: 'k5');
    expect(a.requests.single.path, '/api/mobile/v1/squads');
    expect(a.requests.single.headers['Idempotency-Key'], 'k5');
    expect(a.requests.single.data, {'tournamentId': 't1', 'name': 'Lions'});
    expect(sq.inviteCode, 'ABC');
  });

  test('an error envelope throws ApiException with code and status', () async {
    final a = _FakeAdapter((_) => _json(409, {
          'error': {'code': 'already_rated', 'message': 'x'}
        }));
    await expectLater(
      _client(a).postMatchRating('m1', stars: 5, idempotencyKey: 'k'),
      throwsA(isA<ApiException>().having((e) => e.code, 'code', 'already_rated').having((e) => e.status, 'status', 409)),
    );
  });
}
