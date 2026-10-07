import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/core/api/account_models.dart';
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
ApiClient _client(_FakeAdapter a) =>
    ApiClient.create(baseUrl: 'https://api.test', appVersion: '1.0.0', platform: 'android', accessToken: () async => 'tok', adapter: a);
_FakeAdapter _ok(Object? data) => _FakeAdapter((_) => _json(200, {'data': data}));

void main() {
  test('getMyAccount: GET /me/account with the bearer, parsed', () async {
    final a = _ok({
      'deletion': null,
      'signIn': {'email': 'a@b.com', 'pendingEmail': null, 'passwordIdentity': true, 'google': false},
      'phone': null,
      'locale': 'en',
    });
    final acct = await _client(a).getMyAccount();
    expect(a.requests.single.method, 'GET');
    expect(a.requests.single.uri.path, '/api/mobile/v1/me/account');
    expect(a.requests.single.headers['Authorization'], 'Bearer tok');
    expect(acct.signIn.email, 'a@b.com');
  });

  test('postAccountDeletion sends the literal DELETE', () async {
    final a = _ok({'requestedAt': '2026-10-07T00:00:00.000Z', 'dueAt': '2026-10-22T00:00:00.000Z'});
    final t = await _client(a).postAccountDeletion();
    expect(a.requests.single.method, 'POST');
    expect(a.requests.single.uri.path, '/api/mobile/v1/me/deletion');
    expect(a.requests.single.data, {'confirm': 'DELETE'});
    expect(t.dueAt, DateTime.utc(2026, 10, 22));
  });

  test('deleteAccountDeletion: DELETE /me/deletion', () async {
    final a = _ok({'ok': true});
    await _client(a).deleteAccountDeletion();
    expect(a.requests.single.method, 'DELETE');
    expect(a.requests.single.uri.path, '/api/mobile/v1/me/deletion');
  });

  test('postAccountDeletionExecute sends the typed username', () async {
    final a = _ok({'ok': true});
    await _client(a).postAccountDeletionExecute('Rex');
    expect(a.requests.single.uri.path, '/api/mobile/v1/me/deletion/execute');
    expect(a.requests.single.data, {'username': 'Rex'});
  });

  test('postPhoneCode and postPhoneConfirm', () async {
    final a = _ok({'expiresAt': '2026-10-07T10:10:00.000Z', 'resendAt': '2026-10-07T10:01:00.000Z'});
    final ticket = await _client(a).postPhoneCode('08012345678');
    expect(a.requests.single.uri.path, '/api/mobile/v1/me/phone/code');
    expect(a.requests.single.data, {'phone': '08012345678'});
    expect(ticket.resendAt, DateTime.utc(2026, 10, 7, 10, 1));

    final b = _ok({'verifiedAt': '2026-10-07T10:02:00.000Z'});
    final at = await _client(b).postPhoneConfirm('123456');
    expect(b.requests.single.uri.path, '/api/mobile/v1/me/phone/confirm');
    expect(b.requests.single.data, {'code': '123456'});
    expect(at, DateTime.utc(2026, 10, 7, 10, 2));
  });

  test('postMyEmail returns sentTo', () async {
    final a = _ok({'sentTo': 'n@b.com'});
    final sentTo = await _client(a).postMyEmail(email: 'N@b.com', password: 'pw');
    expect(a.requests.single.uri.path, '/api/mobile/v1/me/email');
    expect(a.requests.single.data, {'email': 'N@b.com', 'password': 'pw'});
    expect(sentTo, 'n@b.com');
  });

  test('deleteGoogleIdentity sends the password in a DELETE body', () async {
    final a = _ok({'ok': true});
    await _client(a).deleteGoogleIdentity('pw');
    expect(a.requests.single.method, 'DELETE');
    expect(a.requests.single.uri.path, '/api/mobile/v1/me/identities/google');
    expect(a.requests.single.data, {'password': 'pw'});
  });

  test('putMyLocale', () async {
    final a = _ok({'locale': 'pcm'});
    expect(await _client(a).putMyLocale('pcm'), 'pcm');
    expect(a.requests.single.method, 'PUT');
    expect(a.requests.single.uri.path, '/api/mobile/v1/me/locale');
    expect(a.requests.single.data, {'locale': 'pcm'});
  });

  test('error envelopes surface code, fields and details', () async {
    final a = _FakeAdapter((_) => _json(409, {
          'error': {
            'code': 'deletion_blocked',
            'message': 'blocked',
            'details': {'blockers': [{'code': 'wallet_balance', 'amount': 5}]},
          },
        }));
    try {
      await _client(a).postAccountDeletion();
      fail('expected ApiException');
    } on ApiException catch (e) {
      expect(e.status, 409);
      expect(e.code, 'deletion_blocked');
      expect(DeletionBlocker.listFrom(e.details).single.code, 'wallet_balance');
    }
  });

  test('a 429 carries retryAfterSeconds in fields', () async {
    final a = _FakeAdapter((_) => _json(429, {'error': {'code': 'phone_cooldown', 'message': 'wait', 'fields': {'retryAfterSeconds': '40'}}}));
    try {
      await _client(a).postPhoneCode('08012345678');
      fail('expected ApiException');
    } on ApiException catch (e) {
      expect(e.fields['retryAfterSeconds'], '40');
    }
  });
}
