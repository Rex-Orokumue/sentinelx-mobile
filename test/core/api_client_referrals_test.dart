import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/core/api/api_client.dart';

class _Adapter implements HttpClientAdapter {
  RequestOptions? request;

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    request = options;
    return ResponseBody.fromString(jsonEncode({'data': {
      'username': 'owner', 'shareUrl': 'https://sentinelxesports.com.ng/signup?ref=owner',
      'totalReferrals': 1, 'convertedCount': 1, 'totalCoinsEarned': 500,
      'nextMilestone': {'count': 5, 'bonusCoins': 500},
      'invited': [{'id': 'r1', 'name': 'Friend', 'avatarUrl': null, 'tier': 'recruit', 'frameUrl': null,
        'status': 'converted', 'date': '2026-10-10T00:00:00Z', 'coinsAwarded': 250}],
      'milestoneHistory': [{'id': 'm1', 'description': 'First Recruit', 'coins': 250, 'date': '2026-10-10T00:00:00Z'}],
    }}), 200, headers: {Headers.contentTypeHeader: [Headers.jsonContentType]});
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  test('getMyReferrals uses the owner endpoint and parses the panel', () async {
    final adapter = _Adapter();
    final client = ApiClient.create(baseUrl: 'https://api.test', appVersion: '1.0.0', platform: 'android', accessToken: () async => 'tok', adapter: adapter);
    final overview = await client.getMyReferrals();
    expect(adapter.request?.uri.path, '/api/mobile/v1/me/referrals');
    expect(adapter.request?.method, 'GET');
    expect(adapter.request?.headers['Authorization'], 'Bearer tok');
    expect(overview.totalCoinsEarned, 500);
    expect(overview.invited.single.status, 'converted');
    expect(overview.nextMilestone?.count, 5);
    expect(overview.milestoneHistory.single.coins, 250);
  });
}
