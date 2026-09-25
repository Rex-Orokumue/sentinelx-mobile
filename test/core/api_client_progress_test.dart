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

ApiClient _client(_FakeAdapter a, {String? token = 'tok'}) => ApiClient.create(
    baseUrl: 'https://api.test', appVersion: '1.2.3', platform: 'android', accessToken: () async => token, adapter: a);

const _emptyPage = {
  'scope': {'game': 'dls', 'region': null, 'metric': 'wins'}, 'rows': [],
  'page': {'page': 2, 'totalPages': 2, 'total': 11, 'perPage': 10}, 'games': [], 'regions': [],
  'stats': {'playersRanked': 11, 'gamesIncluded': 1, 'totalMatches': 5, 'prizesAwarded': 0},
  'highlights': {'topScore': null, 'topTitles': null, 'topWinRate': null, 'topStreak': null, 'topStreakValue': 0},
};

void main() {
  test('getRankings sends only the set query params', () async {
    final adapter = _FakeAdapter((_) => _json(200, {'data': _emptyPage}));
    final page = await _client(adapter).getRankings(game: 'dls', page: 2);
    expect(page.scope.metric, 'wins');
    final uri = adapter.requests.single.uri;
    expect(uri.path, '/api/mobile/v1/rankings');
    expect(uri.queryParameters, {'game': 'dls', 'page': '2'});
  });

  test('getRankingsMe hits /rankings/me with the bearer token', () async {
    final adapter = _FakeAdapter((_) => _json(200, {'data': {'row': null}}));
    final me = await _client(adapter).getRankingsMe(region: 'NG');
    expect(me.row, isNull);
    expect(adapter.requests.single.uri.path, '/api/mobile/v1/rankings/me');
    expect(adapter.requests.single.headers['Authorization'], 'Bearer tok');
  });

  test('getSeasons and getSeasonDetail use the documented paths', () async {
    final adapter = _FakeAdapter((o) => o.uri.path.endsWith('/seasons')
        ? _json(200, {'data': {'seasons': [{'id': 's1', 'slug': 'season-1', 'name': 'Season 1', 'startDate': '2026-08-01', 'endDate': '2026-10-31'}]}})
        : _json(404, {'error': {'code': 'not_found', 'message': 'Not found.'}}));
    final api = _client(adapter);
    expect((await api.getSeasons()).single.slug, 'season-1');
    await expectLater(api.getSeasonDetail('nope'), throwsA(isA<ApiException>().having((e) => e.status, 'status', 404)));
    expect(adapter.requests.last.uri.path, '/api/mobile/v1/seasons/nope');
  });

  test('getHallOfFame passes the optional game filter', () async {
    final adapter = _FakeAdapter((_) => _json(200, {'data': {
      'games': [], 'selectedGame': 'dls',
      'awards': {'mvp': null, 'goldenBoot': [], 'categories': []},
      'champions': {'championsCup': [], 'masters': [], 'communityClub': [], 'open': []}, 'bronze': [],
    }}));
    final h = await _client(adapter).getHallOfFame(game: 'dls');
    expect(h.selectedGame, 'dls');
    expect(adapter.requests.single.uri.queryParameters, {'game': 'dls'});
  });
}
