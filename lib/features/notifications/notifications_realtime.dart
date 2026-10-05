import 'dart:async';

import '../../core/realtime/realtime_hub.dart';
import '../../core/realtime/realtime_port.dart';

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

/// Every insert/update/delete of this player's own notification rows, as a nudge stream. Backed by the
/// shared realtime hub (lifecycle-aware, reconnecting); reconnects and app resumes also nudge, so the bell
/// refetches after a gap.
Stream<void> notificationRowChanges(RealtimeHub hub, String userId) {
  late StreamController<void> controller;
  RealtimeHandle? handle;
  StreamSubscription<RealtimeSignal>? sub;
  controller = StreamController<void>.broadcast(
    onListen: () {
      handle = hub.open(RealtimeChannelSpec(
        topic: 'ntf-bell-$userId',
        bindings: [PostgresBinding(table: 'player_notifications', filterColumn: 'player_id', filterValue: userId)],
      ));
      sub = handle!.signals.listen((_) => controller.add(null));
    },
    onCancel: () async {
      await sub?.cancel();
      sub = null;
      await handle?.close();
      handle = null;
    },
  );
  return controller.stream;
}
