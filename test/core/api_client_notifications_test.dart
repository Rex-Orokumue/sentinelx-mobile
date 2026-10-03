import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/core/api/api_client.dart';
import 'package:sentinelx_mobile/core/api/notifications_models.dart';

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

Map<String, dynamic> _prefs() => {
      'push': {for (final k in kPushPrefKeys) k: true},
      'whatsapp': {for (final k in kWhatsappPrefKeys) k: true},
      'achievementSharing': {for (final k in kSharingPrefKeys) k: true},
    };

void _expectBearer(_FakeAdapter a) {
  // Lesson 1: viewer-specific calls must carry the bearer token (a public request strips it).
  expect(a.requests.single.headers['Authorization'], 'Bearer tok');
}

void main() {
  test('getNotificationPrefs: GET, bearer, parsed', () async {
    final a = _ok(_prefs());
    final p = await _client(a).getNotificationPrefs();
    expect(a.requests.single.method, 'GET');
    expect(a.requests.single.uri.path, '/api/mobile/v1/notifications/prefs');
    _expectBearer(a);
    expect(p.push, hasLength(17));
  });

  test('patchNotificationPrefs sends only the section and keys given', () async {
    final a = _ok(_prefs());
    await _client(a).patchNotificationPrefs(PrefSection.push, {'post_reaction': false});
    expect(a.requests.single.method, 'PATCH');
    expect(a.requests.single.uri.path, '/api/mobile/v1/notifications/prefs');
    expect(a.requests.single.data, {
      'push': {'post_reaction': false}
    });
    _expectBearer(a);
  });

  test('patchNotificationPrefs uses the camelCase wire name for achievement sharing', () async {
    final a = _ok(_prefs());
    await _client(a).patchNotificationPrefs(PrefSection.achievementSharing, {'social': true});
    expect(a.requests.single.data, {
      'achievementSharing': {'social': true}
    });
  });

  test('patchNotificationPrefs surfaces validation_failed fields', () async {
    final a = _FakeAdapter((_) => _json(400, {
          'error': {
            'code': 'validation_failed',
            'message': 'Some fields are invalid.',
            'fields': {'push.bogus': 'Unrecognized key'}
          }
        }));
    await expectLater(
      _client(a).patchNotificationPrefs(PrefSection.push, {'bogus': true}),
      throwsA(isA<ApiException>().having((e) => e.code, 'code', 'validation_failed').having((e) => e.fields, 'fields', {'push.bogus': 'Unrecognized key'})),
    );
  });

  test('getNotificationMutes: GET, bearer, parsed', () async {
    final a = _ok({
      'types': [
        {'type': 'post_reaction', 'mutedUntil': '2099-01-01T00:00:00.000Z'}
      ],
      'posts': <Object>[]
    });
    final m = await _client(a).getNotificationMutes();
    expect(a.requests.single.uri.path, '/api/mobile/v1/notifications/mutes');
    _expectBearer(a);
    expect(m.types.single.type, 'post_reaction');
  });

  test('mute type / post bodies are exact', () async {
    var a = _ok({'ok': true});
    await _client(a).muteNotificationType('post_reaction', MuteDuration.always);
    expect(a.requests.single.method, 'POST');
    expect(a.requests.single.uri.path, '/api/mobile/v1/notifications/mutes');
    expect(a.requests.single.data, {'scope': 'type', 'type': 'post_reaction', 'duration': 'always'});
    _expectBearer(a);

    a = _ok({'ok': true});
    await _client(a).muteNotificationPost('p1', MuteDuration.oneWeek);
    expect(a.requests.single.data, {'scope': 'post', 'postId': 'p1', 'duration': '1w'});
    expect(a.requests.single.headers.containsKey('Idempotency-Key'), isFalse);
  });

  test('unmute bodies carry no duration', () async {
    var a = _ok({'ok': true});
    await _client(a).unmuteNotificationType('post_reaction');
    expect(a.requests.single.method, 'DELETE');
    expect(a.requests.single.data, {'scope': 'type', 'type': 'post_reaction'});
    _expectBearer(a);

    a = _ok({'ok': true});
    await _client(a).unmuteNotificationPost('p1');
    expect(a.requests.single.data, {'scope': 'post', 'postId': 'p1'});
  });

  test('markNotificationRead posts to the encoded id path and 404 maps to not_found', () async {
    var a = _ok({'ok': true});
    await _client(a).markNotificationRead('a/b');
    expect(a.requests.single.method, 'POST');
    expect(a.requests.single.uri.toString(), contains('/notifications/a%2Fb/read'));
    _expectBearer(a);

    a = _FakeAdapter((_) => _json(404, {
          'error': {'code': 'not_found', 'message': 'Not found.'}
        }));
    await expectLater(_client(a).markNotificationRead('x'), throwsA(isA<ApiException>().having((e) => e.code, 'code', 'not_found')));
  });

  test('markAllNotificationsRead returns the updated count', () async {
    final a = _ok({'updated': 3});
    expect(await _client(a).markAllNotificationsRead(), 3);
    expect(a.requests.single.uri.path, '/api/mobile/v1/notifications/read-all');
    _expectBearer(a);
  });

  test('sendTestPush posts with the bearer token', () async {
    final a = _ok({'ok': true});
    await _client(a).sendTestPush();
    expect(a.requests.single.method, 'POST');
    expect(a.requests.single.uri.path, '/api/mobile/v1/notifications/test-push');
    _expectBearer(a);
  });
}
