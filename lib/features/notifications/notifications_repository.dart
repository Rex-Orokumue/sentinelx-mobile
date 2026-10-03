import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/api/api_client.dart';
import '../../core/api/notifications_models.dart';
import '../../core/providers.dart';
import 'notification_models.dart';

/// Raw reads of the caller's own `player_notifications` rows. The one sanctioned direct-Supabase read in
/// this phase (spec §3.1): nothing here is computed in TypeScript, owner-RLS scopes it, and it shares the
/// realtime channel the badge already uses. Named columns only.
abstract class NotificationRowSource {
  Future<List<Map<String, dynamic>>> fetchPage({required String userId, required int offset, required int limit});
  Future<String?> newestUnreadIdForLink({required String userId, required String link});
}

class SupabaseNotificationRowSource implements NotificationRowSource {
  SupabaseNotificationRowSource(this._client);
  final SupabaseClient _client;

  static const _columns = 'id, type, title, body, link, read, created_at';

  @override
  Future<List<Map<String, dynamic>>> fetchPage({required String userId, required int offset, required int limit}) async {
    final rows = await _client
        .from('player_notifications')
        .select(_columns)
        .eq('player_id', userId)
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);
    return (rows as List<dynamic>).cast<Map<String, dynamic>>();
  }

  @override
  Future<String?> newestUnreadIdForLink({required String userId, required String link}) async {
    final rows = await _client
        .from('player_notifications')
        .select('id')
        .eq('player_id', userId)
        .eq('read', false)
        .eq('link', link)
        .order('created_at', ascending: false)
        .limit(1);
    final list = rows as List<dynamic>;
    return list.isEmpty ? null : (list.first as Map<String, dynamic>)['id'] as String?;
  }
}

/// Everything the bell, the settings screen and the tap router need. Reads of rows go through
/// [NotificationRowSource]; every write and every prefs/mutes read goes through [ApiClient].
abstract class NotificationsRepository {
  /// Newest first, the caller's own rows only.
  Future<List<BellNotification>> page({required int offset, required int limit});
  Future<void> markRead(String id);
  Future<int> markAllRead();

  /// Marks the newest unread own row whose `link` equals [link] read (a push tap carries the url, not the
  /// row id — Stage B Ruling 3). Best-effort: never throws, no-op when nothing matches.
  Future<void> markReadForLink(String link);

  Future<NotificationMutes> mutes();
  Future<void> muteType(String type, MuteDuration duration);
  Future<void> unmuteType(String type);
  Future<void> mutePost(String postId, MuteDuration duration);
  Future<void> unmutePost(String postId);

  Future<NotificationPrefs> prefs();
  Future<NotificationPrefs> patchPrefs(PrefSection section, Map<String, bool> values);
  Future<void> sendTestPush();
}

class ApiNotificationsRepository implements NotificationsRepository {
  ApiNotificationsRepository({required NotificationRowSource source, required ApiClient api, required String? Function() userId})
      : _source = source,
        _api = api,
        _userId = userId;

  final NotificationRowSource _source;
  final ApiClient _api;
  final String? Function() _userId;

  @override
  Future<List<BellNotification>> page({required int offset, required int limit}) async {
    final userId = _userId();
    if (userId == null) return const [];
    final rows = await _source.fetchPage(userId: userId, offset: offset, limit: limit);
    return [
      for (final r in rows)
        ?BellNotification.tryParse(r),
    ];
  }

  @override
  Future<void> markRead(String id) => _api.markNotificationRead(id);

  @override
  Future<int> markAllRead() => _api.markAllNotificationsRead();

  @override
  Future<void> markReadForLink(String link) async {
    final userId = _userId();
    if (userId == null) return;
    try {
      final id = await _source.newestUnreadIdForLink(userId: userId, link: link);
      if (id != null) await _api.markNotificationRead(id);
    } catch (_) {
      // best-effort: an unread dot that lingers until the bell is opened is harmless
    }
  }

  @override
  Future<NotificationMutes> mutes() => _api.getNotificationMutes();
  @override
  Future<void> muteType(String type, MuteDuration duration) => _api.muteNotificationType(type, duration);
  @override
  Future<void> unmuteType(String type) => _api.unmuteNotificationType(type);
  @override
  Future<void> mutePost(String postId, MuteDuration duration) => _api.muteNotificationPost(postId, duration);
  @override
  Future<void> unmutePost(String postId) => _api.unmuteNotificationPost(postId);

  @override
  Future<NotificationPrefs> prefs() => _api.getNotificationPrefs();
  @override
  Future<NotificationPrefs> patchPrefs(PrefSection section, Map<String, bool> values) => _api.patchNotificationPrefs(section, values);
  @override
  Future<void> sendTestPush() => _api.sendTestPush();
}

final notificationsRepositoryProvider = Provider<NotificationsRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return ApiNotificationsRepository(
    source: SupabaseNotificationRowSource(client),
    api: ref.watch(apiClientProvider),
    userId: () => client.auth.currentUser?.id,
  );
});
