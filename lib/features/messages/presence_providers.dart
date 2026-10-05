import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/realtime/realtime_hub.dart';
import '../../core/realtime/realtime_port.dart';
import 'inbox_providers.dart';

/// The ids of other players currently online, from the `dm-online` presence channel (private; presence key =
/// the viewer's own id). Tracked while the app is resumed (the hub drops the channel on pause, so presence
/// leaves promptly), re-tracked after every rejoin. Each sync emits a NEW set so every change notifies.
/// Never used for typing.
final onlinePlayersProvider = StreamProvider.autoDispose<Set<String>>((ref) {
  final viewer = ref.watch(dmViewerIdProvider).asData?.value;
  if (viewer == null) return const Stream.empty();
  final controller = StreamController<Set<String>>();
  final handle = ref.watch(realtimeHubProvider).open(
        RealtimeChannelSpec(
          topic: 'dm-online',
          private: true,
          presenceKey: viewer,
          bindings: [
            PresenceBinding(
              key: viewer,
              trackPayload: {'online_at': DateTime.now().toUtc().toIso8601String()},
              // The viewer is announced but is never "someone else online".
              onSync: (keys) {
                if (!controller.isClosed) controller.add({for (final k in keys) if (k != viewer) k});
              },
            ),
          ],
        ),
      );
  final sub = handle.signals.listen((_) {});
  ref.onDispose(() {
    sub.cancel();
    handle.close();
    controller.close();
  });
  return controller.stream;
});

final isOnlineProvider = Provider.autoDispose.family<bool, String>(
  (ref, userId) => ref.watch(onlinePlayersProvider.select((a) => a.asData?.value.contains(userId) ?? false)),
);
