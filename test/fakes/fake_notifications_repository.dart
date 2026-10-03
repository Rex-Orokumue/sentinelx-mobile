import 'dart:async';

import 'package:sentinelx_mobile/core/api/notifications_models.dart';
import 'package:sentinelx_mobile/features/notifications/notification_models.dart';
import 'package:sentinelx_mobile/features/notifications/notifications_repository.dart';

BellNotification bell(
  String id, {
  String type = 'match_assigned',
  String? link,
  bool read = false,
  DateTime? at,
}) =>
    BellNotification(
      id: id,
      type: type,
      title: 'Title $id',
      body: 'Body $id',
      link: link,
      read: read,
      createdAt: at ?? DateTime.utc(2026, 10, 3, 10),
    );

/// In-memory [NotificationsRepository]. `store` is newest first; `page` slices it like the real query.
class FakeNotificationsRepository implements NotificationsRepository {
  FakeNotificationsRepository({List<BellNotification>? rows}) : store = rows ?? [];

  List<BellNotification> store;

  final pageCalls = <({int offset, int limit})>[];
  final markReadCalls = <String>[];
  int markAllCalls = 0;
  final readForLink = <String>[];
  final muteCalls = <String>[];
  int testPushCalls = 0;

  /// The next `page` call waits on this (then clears it): holds a load in flight.
  Completer<void>? holdNextPage;
  Completer<void>? holdMarkRead;
  Completer<void>? holdMarkAll;
  bool pageFails = false;
  bool markReadFails = false;
  bool markAllFails = false;
  Object? testPushError;
  Completer<void>? holdTestPush;

  NotificationMutes mutesResult = NotificationMutes.empty;
  late NotificationPrefs prefsResult = const NotificationPrefs(push: {}, whatsapp: {}, achievementSharing: {});
  final patchCalls = <({PrefSection section, Map<String, bool> values})>[];
  Completer<void>? holdPatch;
  final failPatchKeys = <String>{};

  /// The next N patch calls fail, whatever the key.
  int failNextPatches = 0;

  @override
  Future<List<BellNotification>> page({required int offset, required int limit}) async {
    pageCalls.add((offset: offset, limit: limit));
    // The query reads the table when it is issued; a held call only delays the response (so rows inserted
    // while it is in flight are NOT in it - the realistic case the realtime refresh has to cover).
    final failing = pageFails;
    final result = offset >= store.length ? const <BellNotification>[] : store.sublist(offset, (offset + limit).clamp(0, store.length));
    final gate = holdNextPage;
    if (gate != null) {
      holdNextPage = null;
      await gate.future;
    }
    if (failing || pageFails) throw StateError('page failed');
    return result;
  }

  @override
  Future<void> markRead(String id) async {
    markReadCalls.add(id);
    if (holdMarkRead != null) await holdMarkRead!.future;
    if (markReadFails) throw StateError('mark read failed');
    store = [for (final n in store) n.id == id ? n.copyWith(read: true) : n];
  }

  @override
  Future<int> markAllRead() async {
    markAllCalls++;
    if (holdMarkAll != null) await holdMarkAll!.future;
    if (markAllFails) throw StateError('mark all failed');
    final n = store.where((r) => !r.read).length;
    store = [for (final r in store) r.copyWith(read: true)];
    return n;
  }

  @override
  Future<void> markReadForLink(String link) async => readForLink.add(link);

  @override
  Future<NotificationMutes> mutes() async => mutesResult;
  @override
  Future<void> muteType(String type, MuteDuration d) async => muteCalls.add('muteType $type ${d.wire}');
  @override
  Future<void> unmuteType(String type) async => muteCalls.add('unmuteType $type');
  @override
  Future<void> mutePost(String postId, MuteDuration d) async => muteCalls.add('mutePost $postId ${d.wire}');
  @override
  Future<void> unmutePost(String postId) async => muteCalls.add('unmutePost $postId');

  @override
  Future<NotificationPrefs> prefs() async => prefsResult;

  @override
  Future<NotificationPrefs> patchPrefs(PrefSection section, Map<String, bool> values) async {
    patchCalls.add((section: section, values: values));
    if (holdPatch != null) await holdPatch!.future;
    if (failNextPatches > 0) {
      failNextPatches--;
      throw StateError('patch failed');
    }
    if (values.keys.any(failPatchKeys.contains)) throw StateError('patch failed');
    for (final e in values.entries) {
      prefsResult = prefsResult.withValue(section, e.key, e.value);
    }
    return prefsResult;
  }

  @override
  Future<void> sendTestPush() async {
    testPushCalls++;
    if (holdTestPush != null) await holdTestPush!.future;
    if (testPushError != null) throw testPushError!;
  }
}
