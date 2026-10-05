import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/core/api/api_client.dart';
import 'package:sentinelx_mobile/core/api/models.dart';

class _Adapter implements HttpClientAdapter {
  _Adapter(this.body);
  final Map<String, Object?> body;
  RequestOptions? last;
  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<Uint8List>? s, Future<void>? c) async {
    last = o;
    return ResponseBody.fromString(jsonEncode(body), 200, headers: {Headers.contentTypeHeader: ['application/json']});
  }

  @override
  void close({bool force = false}) {}
}

ApiClient _client(_Adapter a) =>
    ApiClient.create(baseUrl: 'https://x.test', appVersion: '1', platform: 'android', accessToken: () async => 't', adapter: a);

Map<String, Object?> _profile([Map<String, Object?> extra = const {}]) => {
      'username': 'ada', 'displayName': 'Ada', 'avatarUrl': null, 'whatsappNumber': null, 'country': 'NG',
      'locale': 'en', 'membershipTier': 'guardian', 'kycVerified': false, 'deletionRequestedAt': null,
      'profileCompletedAt': null, 'consentWhatsappUpdates': false, 'gameInterests': <String>[], ...extra,
    };

void main() {
  test('MeProfile.bubbleSkinUrl: present, absent and null all parse', () {
    expect(MeProfile.fromJson(_profile({'bubbleSkinUrl': '/mascot/skin.png'})).bubbleSkinUrl, '/mascot/skin.png');
    expect(MeProfile.fromJson(_profile()).bubbleSkinUrl, isNull);
    expect(MeProfile.fromJson(_profile({'bubbleSkinUrl': null})).bubbleSkinUrl, isNull);
  });

  test('getGuideQuests hits GET /guide/quests and parses', () async {
    final a = _Adapter({'data': {'quests': []}});
    expect((await _client(a).getGuideQuests()).quests, isEmpty);
    expect([a.last!.method, a.last!.path], ['GET', '/api/mobile/v1/guide/quests']);
  });

  test('postGuideBadge sends the quest id and parses the claim', () async {
    final a = _Adapter({'data': {'claimed': true, 'alreadyClaimed': false, 'xp': 100, 'coins': 50}});
    final c = await _client(a).postGuideBadge();
    expect([a.last!.method, a.last!.path, a.last!.data], ['POST', '/api/mobile/v1/guide/badge', {'quest': 'battle_ready'}]);
    expect([c.alreadyClaimed, c.xp, c.coins], [false, 100, 50]);
  });

  test('getChatHistory sends before/limit; deleteChatHistory is DELETE', () async {
    final a = _Adapter({'data': {'messages': [], 'nextBefore': null}});
    await _client(a).getChatHistory(before: 'cur', limit: 20);
    expect(a.last!.uri.queryParameters, {'before': 'cur', 'limit': '20'});
    expect(a.last!.uri.path, '/api/mobile/v1/chat/history');
    final d = _Adapter({'data': {'ok': true}});
    await _client(d).deleteChatHistory();
    expect([d.last!.method, d.last!.path], ['DELETE', '/api/mobile/v1/chat/history']);
  });
}
