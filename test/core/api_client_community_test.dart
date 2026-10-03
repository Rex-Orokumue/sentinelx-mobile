import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/core/api/api_client.dart';
import 'package:sentinelx_mobile/core/api/community_models.dart';

import '../support/community_fixtures.dart';

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

_FakeAdapter _ok(Object? data) => _FakeAdapter((_) => _json(200, {'data': data}));

void main() {
  test('getCommunityFeed hits the feed path with no query params by default, and sends both when paginated', () async {
    var a = _ok(feedPageJson());
    var page = await _client(a).getCommunityFeed();
    expect(a.requests.single.method, 'GET');
    expect(a.requests.single.uri.path, '/api/mobile/v1/community/feed');
    expect(a.requests.single.uri.queryParameters, isEmpty);
    expect(page.hasMore, isFalse);

    a = _ok(feedPageJson());
    page = await _client(a).getCommunityFeed(offset: 20, limit: 10);
    expect(a.requests.single.uri.path, '/api/mobile/v1/community/feed');
    expect(a.requests.single.uri.queryParameters, {'offset': '20', 'limit': '10'});
  });

  test('getCommunityPost and getCommunityPostComments hit the right paths', () async {
    var a = _ok({
      'post': postViewJson(id: 'p1'),
      'comments': [commentViewJson()],
    });
    final detail = await _client(a).getCommunityPost('p1');
    expect(a.requests.single.uri.path, '/api/mobile/v1/community/posts/p1');
    expect(detail.post.id, 'p1');
    expect(detail.comments.single.id, 'c1');

    a = _ok({
      'comments': [commentViewJson(id: 'c2')],
    });
    final comments = await _client(a).getCommunityPostComments('p1');
    expect(a.requests.single.uri.path, '/api/mobile/v1/community/posts/p1/comments');
    expect(comments.single.id, 'c2');
  });

  test('getCommunityStatuses hits the right path and unwraps the rings key', () async {
    final a = _ok({
      'rings': [statusRingJson(playerId: 'u1')],
    });
    final rings = await _client(a).getCommunityStatuses();
    expect(a.requests.single.uri.path, '/api/mobile/v1/community/statuses');
    expect(rings.single.playerId, 'u1');
  });

  test('getCommunityStatusViewers hits the right path and unwraps the viewers key', () async {
    final a = _ok({
      'viewers': [statusViewerJson(viewerId: 'u2')],
    });
    final viewers = await _client(a).getCommunityStatusViewers('s1');
    expect(a.requests.single.uri.path, '/api/mobile/v1/community/statuses/s1/viewers');
    expect(viewers.single.viewerId, 'u2');
  });

  test('getCommunityTopMembers hits the right path and unwraps the members key', () async {
    final a = _ok({
      'members': [topMemberJson(id: 'u1', rank: 1)],
    });
    final members = await _client(a).getCommunityTopMembers();
    expect(a.requests.single.uri.path, '/api/mobile/v1/community/top-members');
    expect(members.single.id, 'u1');
    expect(members.single.rank, 1);
  });

  test('getCommunityUpcomingEvents hits the right path and unwraps the events key', () async {
    final a = _ok({
      'events': [upcomingEventJson(id: 'e1')],
    });
    final events = await _client(a).getCommunityUpcomingEvents();
    expect(a.requests.single.uri.path, '/api/mobile/v1/community/upcoming-events');
    expect(events.single.id, 'e1');
  });

  test('getCommunityChallenges returns null for a null data envelope and the widget otherwise', () async {
    var a = _ok(null);
    final nullResult = await _client(a).getCommunityChallenges();
    expect(a.requests.single.uri.path, '/api/mobile/v1/community/challenges');
    expect(nullResult, isNull);

    a = _ok(challengesJson());
    final widget = await _client(a).getCommunityChallenges();
    expect(widget, isNotNull);
    expect(widget!.weekLabel, 'Week 39');
  });

  test('getCommunityBestPlay returns null for a null data envelope and the banner otherwise', () async {
    var a = _ok(null);
    final nullResult = await _client(a).getCommunityBestPlay();
    expect(a.requests.single.uri.path, '/api/mobile/v1/community/best-play');
    expect(nullResult, isNull);

    a = _ok(bestPlayJson());
    final banner = await _client(a).getCommunityBestPlay();
    expect(banner, isNotNull);
    expect(banner!.nominations.single.nominationId, 'n1');
  });

  test('getCommunityGallery sends neither param by default, both when paginated', () async {
    var a = _ok(galleryPageJson());
    await _client(a).getCommunityGallery();
    expect(a.requests.single.uri.path, '/api/mobile/v1/community/gallery');
    expect(a.requests.single.uri.queryParameters, isEmpty);

    a = _ok(galleryPageJson());
    await _client(a).getCommunityGallery(offset: 8, limit: 8);
    expect(a.requests.single.uri.queryParameters, {'offset': '8', 'limit': '8'});
  });

  test('postCommunityPost sends the Idempotency-Key header and body', () async {
    final a = _ok({'id': 'p9'});
    final id = await _client(a).postCommunityPost(content: 'hello', imageUrls: const ['https://x/a.png'], idempotencyKey: 'k1');
    final r = a.requests.single;
    expect(r.method, 'POST');
    expect(r.path, '/api/mobile/v1/community/posts');
    expect(r.headers['Idempotency-Key'], 'k1');
    expect(r.data, {'content': 'hello', 'imageUrls': ['https://x/a.png']});
    expect(id, 'p9');
  });

  test('putCommunityPostReaction sends body and header, and parses the reaction response', () async {
    final a = _ok({'reaction': 'crown'});
    final reaction = await _client(a).putCommunityPostReaction('p1', reaction: ReactionType.crown, idempotencyKey: 'k2');
    final r = a.requests.single;
    expect(r.method, 'PUT');
    expect(r.path, '/api/mobile/v1/community/posts/p1/reaction');
    expect(r.headers['Idempotency-Key'], 'k2');
    expect(r.data, {'reaction': 'crown'});
    expect(reaction, ReactionType.crown);
  });

  test('deleteCommunityPostReaction and postCommunityStatusView send no Idempotency-Key header', () async {
    var a = _ok(null);
    await _client(a).deleteCommunityPostReaction('p1');
    expect(a.requests.single.method, 'DELETE');
    expect(a.requests.single.path, '/api/mobile/v1/community/posts/p1/reaction');
    expect(a.requests.single.headers.containsKey('Idempotency-Key'), isFalse);

    a = _ok(null);
    await _client(a).postCommunityStatusView('s1');
    expect(a.requests.single.method, 'POST');
    expect(a.requests.single.path, '/api/mobile/v1/community/statuses/s1/view');
    expect(a.requests.single.headers.containsKey('Idempotency-Key'), isFalse);
  });

  test('postCommunityPostReport sends the note when given and omits the key entirely when not', () async {
    var a = _ok(null);
    await _client(a).postCommunityPostReport('p1', reasonCode: ReportReasonCode.hateSpeech, note: 'x', idempotencyKey: 'k3');
    var r = a.requests.single;
    expect(r.path, '/api/mobile/v1/community/posts/p1/report');
    expect(r.headers['Idempotency-Key'], 'k3');
    expect(r.data, {'reasonCode': 'hate_speech', 'note': 'x'});

    a = _ok(null);
    await _client(a).postCommunityPostReport('p1', reasonCode: ReportReasonCode.spam, idempotencyKey: 'k4');
    r = a.requests.single;
    expect(r.data, {'reasonCode': 'spam'});
    expect((r.data as Map).containsKey('note'), isFalse);
  });

  test('an error envelope from postCommunityPostBoost throws ApiException with code and status', () async {
    final a = _FakeAdapter((_) => _json(400, {
          'error': {'code': 'insufficient_coins', 'message': 'x'}
        }));
    await expectLater(
      _client(a).postCommunityPostBoost('p1', idempotencyKey: 'k5'),
      throwsA(isA<ApiException>().having((e) => e.code, 'code', 'insufficient_coins').having((e) => e.status, 'status', 400)),
    );
  });

  // The web handlers for these five read `ctx?.userId` (optional auth) to fill caller-specific
  // fields: myReaction, canDelete/canBoost, isSelf/hasUnseen, myVoteNominationId. Dropping the
  // bearer token silently turns every one of those into the anonymous answer.
  test('viewer-specific community reads send the bearer token', () async {
    final a = _FakeAdapter((_) => _json(200, {'data': <String, dynamic>{}}));
    final api = _client(a);
    Future<void> call(Future<Object?> f) async {
      try {
        await f;
      } catch (_) {/* shape is irrelevant here; only the request headers are under test */}
    }

    await call(api.getCommunityFeed());
    await call(api.getCommunityPost('p1'));
    await call(api.getCommunityPostComments('p1'));
    await call(api.getCommunityStatuses());
    await call(api.getCommunityBestPlay());
    expect(a.requests, hasLength(5));
    for (final r in a.requests) {
      expect(r.headers['Authorization'], 'Bearer tok', reason: r.uri.path);
    }
  });

  test('caller-independent community reads stay anonymous', () async {
    final a = _FakeAdapter((_) => _json(200, {'data': <String, dynamic>{}}));
    final api = _client(a);
    Future<void> call(Future<Object?> f) async {
      try {
        await f;
      } catch (_) {/* shape is irrelevant here */}
    }

    await call(api.getCommunityGallery());
    await call(api.getCommunityStats());
    await call(api.getCommunityTopMembers());
    await call(api.getCommunityUpcomingEvents());
    expect(a.requests, hasLength(4));
    for (final r in a.requests) {
      expect(r.headers.containsKey('Authorization'), isFalse, reason: r.uri.path);
    }
  });
}
