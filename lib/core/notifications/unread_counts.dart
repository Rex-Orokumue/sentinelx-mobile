import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../providers.dart';

Map<String, Object> countQuery({required String playerId, String? type}) => {
      'player_id': playerId,
      'read': false,
      'type': ?type,
    };

// Refetches the count on every insert/update to this player's notifications
// (never assumes no gap — same "refetch on reconnect" rule as the master
// spec's RealtimeManager). One disposable subscription per screen; the
// general-purpose channel manager is Phase 5's job once DMs/feed/bell give
// it three real consumers to design against.
Stream<int> unreadCount(SupabaseClient client, {required String userId, String? type}) async* {
  Future<int> fetch() async {
    var query = client.from('player_notifications').select('id').eq('player_id', userId).eq('read', false);
    if (type != null) query = query.eq('type', type);
    final rows = await query;
    return (rows as List).length;
  }

  yield await fetch();
  await for (final _ in client
      .from('player_notifications')
      .stream(primaryKey: ['id'])
      .eq('player_id', userId)) {
    yield await fetch();
  }
}

final unreadNotificationCountProvider = StreamProvider.autoDispose<int>((ref) {
  final me = ref.watch(meProvider).asData?.value;
  if (me == null) return const Stream.empty();
  return unreadCount(ref.watch(supabaseClientProvider), userId: me.id);
});

final unreadMessageCountProvider = StreamProvider.autoDispose<int>((ref) {
  final me = ref.watch(meProvider).asData?.value;
  if (me == null) return const Stream.empty();
  return unreadCount(ref.watch(supabaseClientProvider), userId: me.id, type: 'direct_message');
});
