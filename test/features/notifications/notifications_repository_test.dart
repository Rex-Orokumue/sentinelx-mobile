import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/core/api/api_client.dart';
import 'package:sentinelx_mobile/core/api/notifications_models.dart';
import 'package:sentinelx_mobile/features/notifications/notifications_repository.dart';

class _FakeSource implements NotificationRowSource {
  List<Map<String, dynamic>> rows = [];
  String? unreadIdForLink;
  Object? lookupError;
  final pageCalls = <({String userId, int offset, int limit})>[];
  final linkLookups = <({String userId, String link})>[];

  @override
  Future<List<Map<String, dynamic>>> fetchPage({required String userId, required int offset, required int limit}) async {
    pageCalls.add((userId: userId, offset: offset, limit: limit));
    return rows;
  }

  @override
  Future<String?> newestUnreadIdForLink({required String userId, required String link}) async {
    linkLookups.add((userId: userId, link: link));
    if (lookupError != null) throw lookupError!;
    return unreadIdForLink;
  }
}

class _FakeApi implements ApiClient {
  final read = <String>[];
  @override
  Future<void> markNotificationRead(String id) async => read.add(id);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Map<String, dynamic> _row(String id) =>
    {'id': id, 'type': 'match_assigned', 'title': 'T$id', 'body': 'B', 'link': '/matches/$id', 'read': false, 'created_at': '2026-10-03T10:00:00.000Z'};

void main() {
  test('page asks the source for the signed-in user and the requested window, in order', () async {
    final src = _FakeSource()..rows = [_row('a'), _row('b')];
    final repo = ApiNotificationsRepository(source: src, api: _FakeApi(), userId: () => 'u1');
    final page = await repo.page(offset: 20, limit: 20);
    expect(src.pageCalls.single, (userId: 'u1', offset: 20, limit: 20));
    expect(page.map((n) => n.id), ['a', 'b']);
  });

  test('signed out returns an empty page without querying', () async {
    final src = _FakeSource()..rows = [_row('a')];
    final repo = ApiNotificationsRepository(source: src, api: _FakeApi(), userId: () => null);
    expect(await repo.page(offset: 0, limit: 20), isEmpty);
    expect(src.pageCalls, isEmpty);
  });

  test('malformed rows are skipped, never fatal', () async {
    final src = _FakeSource()..rows = [_row('a'), {'title': 'no id'}, _row('c')];
    final repo = ApiNotificationsRepository(source: src, api: _FakeApi(), userId: () => 'u1');
    expect((await repo.page(offset: 0, limit: 20)).map((n) => n.id), ['a', 'c']);
  });

  test('markReadForLink marks the newest unread row for that link via the API', () async {
    final src = _FakeSource()..unreadIdForLink = 'n9';
    final api = _FakeApi();
    final repo = ApiNotificationsRepository(source: src, api: api, userId: () => 'u1');
    await repo.markReadForLink('/matches/m1');
    expect(src.linkLookups.single, (userId: 'u1', link: '/matches/m1'));
    expect(api.read, ['n9']);
  });

  test('markReadForLink with no matching unread row makes no API call', () async {
    final api = _FakeApi();
    final repo = ApiNotificationsRepository(source: _FakeSource(), api: api, userId: () => 'u1');
    await repo.markReadForLink('/matches/m1');
    expect(api.read, isEmpty);
  });

  test('markReadForLink swallows a lookup error (best-effort)', () async {
    final src = _FakeSource()..lookupError = StateError('rls');
    final api = _FakeApi();
    final repo = ApiNotificationsRepository(source: src, api: api, userId: () => 'u1');
    await expectLater(repo.markReadForLink('/matches/m1'), completes);
    expect(api.read, isEmpty);
  });

  test('markReadForLink signed out does nothing', () async {
    final src = _FakeSource()..unreadIdForLink = 'n9';
    final repo = ApiNotificationsRepository(source: src, api: _FakeApi(), userId: () => null);
    await repo.markReadForLink('/matches/m1');
    expect(src.linkLookups, isEmpty);
  });

  test('mute helpers pass straight through to the API client', () async {
    final calls = <String>[];
    final repo = ApiNotificationsRepository(source: _FakeSource(), api: _RecordingApi(calls), userId: () => 'u1');
    await repo.muteType('post_reaction', MuteDuration.always);
    await repo.unmuteType('post_reaction');
    await repo.mutePost('p1', MuteDuration.oneHour);
    await repo.unmutePost('p1');
    expect(calls, ['muteType post_reaction always', 'unmuteType post_reaction', 'mutePost p1 1h', 'unmutePost p1']);
  });
}

class _RecordingApi implements ApiClient {
  _RecordingApi(this.log);
  final List<String> log;
  @override
  Future<void> muteNotificationType(String type, MuteDuration d) async => log.add('muteType $type ${d.wire}');
  @override
  Future<void> unmuteNotificationType(String type) async => log.add('unmuteType $type');
  @override
  Future<void> muteNotificationPost(String postId, MuteDuration d) async => log.add('mutePost $postId ${d.wire}');
  @override
  Future<void> unmuteNotificationPost(String postId) async => log.add('unmutePost $postId');
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
