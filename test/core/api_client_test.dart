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
    ResponseBody.fromString(jsonEncode(body), status, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    });

ApiClient _client(_FakeAdapter adapter, {String? token = 'tok'}) => ApiClient.create(
      baseUrl: 'https://api.test',
      appVersion: '1.2.3',
      platform: 'android',
      accessToken: () async => token,
      adapter: adapter,
    );

const _configData = {
  'minSupportedAppVersion': '1.0.0',
  'latestAppVersion': '1.4.0',
  'maintenance': null,
  'siteUrl': 'https://sentinelxesports.com.ng',
  'coins': {'coinsPerNaira': 2, 'nairaPerCoin': 0.5, 'coinsPerEntry': 1000, 'coinsHalfEntry': 500},
  'enforcePhoneVerification': false,
  'whatsappCommunityUrl': null,
  'features': {'wagering': true},
};

void main() {
  test('getConfig unwraps the data envelope and parses RemoteConfig', () async {
    final adapter = _FakeAdapter((_) => _json(200, {'data': _configData}));
    final config = await _client(adapter).getConfig();
    expect(config.latestAppVersion, '1.4.0');
    expect(adapter.requests.single.uri.toString(), 'https://api.test/api/mobile/v1/config');
    expect(adapter.requests.single.method, 'GET');
  });

  test('sends the bearer token and app identity headers', () async {
    final adapter = _FakeAdapter((_) => _json(200, {'data': _configData}));
    await _client(adapter).getConfig();
    final h = adapter.requests.single.headers;
    expect(h['Authorization'], 'Bearer tok');
    expect(h['X-App-Version'], '1.2.3');
    expect(h['X-Platform'], 'android');
  });

  test('omits Authorization when signed out', () async {
    final adapter = _FakeAdapter((_) => _json(200, {'data': _configData}));
    await _client(adapter, token: null).getConfig();
    expect(adapter.requests.single.headers.containsKey('Authorization'), isFalse);
  });

  test('maps the error envelope to ApiException including field codes', () async {
    final adapter = _FakeAdapter((_) => _json(400, {
          'error': {
            'code': 'validation_failed',
            'message': 'Some fields are invalid.',
            'fields': {'token': 'too_small'},
          },
        }));
    await expectLater(
      _client(adapter).registerDevice(token: 'x', platform: 'android', appVersion: '1.0.0'),
      throwsA(isA<ApiException>()
          .having((e) => e.status, 'status', 400)
          .having((e) => e.code, 'code', 'validation_failed')
          .having((e) => e.fields, 'fields', {'token': 'too_small'})),
    );
  });

  test('flags 426 as update-required and 401 as unauthorized', () async {
    final a426 = _FakeAdapter((_) => _json(426, {'error': {'code': 'app_update_required', 'message': 'Update'}}));
    await expectLater(_client(a426).getMe(), throwsA(isA<ApiException>().having((e) => e.isUpdateRequired, 'upd', true)));
    final a401 = _FakeAdapter((_) => _json(401, {'error': {'code': 'unauthorized', 'message': 'Sign in'}}));
    await expectLater(_client(a401).getMe(), throwsA(isA<ApiException>().having((e) => e.isUnauthorized, 'unauth', true)));
  });

  test('a transport failure becomes ApiException(status 0, network)', () async {
    final adapter = _FakeAdapter((o) => throw DioException(requestOptions: o, type: DioExceptionType.connectionError));
    await expectLater(
      _client(adapter).getConfig(),
      throwsA(isA<ApiException>().having((e) => e.status, 'status', 0).having((e) => e.code, 'code', 'network')),
    );
  });

  test('getMe parses roles and the profile', () async {
    final adapter = _FakeAdapter((_) => _json(200, {
          'data': {
            'id': 'u1',
            'email': 'a@b.c',
            'roles': ['moderator'],
            'isStaff': true,
            'isAdmin': false,
            'profile': {
              'username': 'ada', 'displayName': 'Ada', 'avatarUrl': null, 'whatsappNumber': null, 'country': 'NG',
              'locale': 'en', 'membershipTier': 'guardian', 'kycVerified': false, 'deletionRequestedAt': null,
            },
          },
        }));
    final me = await _client(adapter).getMe();
    expect(me.isStaff, isTrue);
    expect(me.isAdmin, isFalse);
    expect(me.roles, ['moderator']);
    expect(me.profile?.username, 'ada');
  });

  test('postClientError sends the documented body', () async {
    final adapter = _FakeAdapter((_) => _json(200, {'data': {'ok': true}}));
    await _client(adapter).postClientError(
      message: 'boom', stack: 's', route: '/tournaments', platform: 'android', appVersion: '1.2.3', locale: 'en',
    );
    final req = adapter.requests.single;
    expect(req.method, 'POST');
    expect(req.uri.path, '/api/mobile/v1/errors');
    expect(req.data, {'message': 'boom', 'stack': 's', 'route': '/tournaments', 'platform': 'android', 'appVersion': '1.2.3', 'locale': 'en'});
  });

  test('unregisterDevice is a DELETE with the token in the body', () async {
    final adapter = _FakeAdapter((_) => _json(200, {'data': {'ok': true}}));
    await _client(adapter).unregisterDevice('t' * 30);
    final req = adapter.requests.single;
    expect(req.method, 'DELETE');
    expect(req.uri.path, '/api/mobile/v1/devices');
    expect(req.data, {'token': 't' * 30});
  });
}
