import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

/// Coalesces a burst of change events into one tick (matches the web's own 400 ms coalesce) and numbers
/// them. A counter, never `void`: `StreamProvider<void>` would notify listeners for the first event only,
/// because every `null` equals the last (Phase 4 lesson 2).
Stream<int> debouncedTicks(Stream<void> source, {Duration debounce = const Duration(milliseconds: 400)}) {
  late StreamController<int> controller;
  StreamSubscription<void>? sub;
  Timer? timer;
  var tick = 0;
  controller = StreamController<int>.broadcast(
    onListen: () {
      sub = source.listen((_) {
        timer?.cancel();
        timer = Timer(debounce, () {
          if (!controller.isClosed) controller.add(++tick);
        });
      });
    },
    onCancel: () {
      timer?.cancel();
      sub?.cancel();
      sub = null;
    },
  );
  return controller.stream;
}

/// Every insert/update/delete of this player's own notification rows. One disposable subscription per
/// screen (the general channel manager stays deferred to 5b, when DMs are the third consumer).
Stream<void> notificationRowChanges(SupabaseClient client, String userId) {
  late StreamController<void> controller;
  RealtimeChannel? channel;
  controller = StreamController<void>.broadcast(
    onListen: () {
      channel = client.channel('ntf-bell-$userId')
        ..onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'player_notifications',
          filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'player_id', value: userId),
          callback: (_) => controller.add(null),
        )
        ..subscribe();
    },
    onCancel: () async {
      final c = channel;
      channel = null;
      if (c != null) await client.removeChannel(c);
    },
  );
  return controller.stream;
}
