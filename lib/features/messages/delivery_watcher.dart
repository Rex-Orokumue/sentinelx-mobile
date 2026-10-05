import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/realtime/realtime_hub.dart';
import 'inbox_providers.dart';

/// Marks incoming messages delivered while the app is simply open, with no inbox or conversation on screen:
/// once when a signed-in app starts, and on every DM nudge, reconnect and resume (through the throttle, whose
/// trailing call guarantees the last message in a burst is stamped too). Pending requests are skipped by the
/// server. Mounted app-wide from `main.dart`.
final deliveryWatcherProvider = Provider<void>((ref) {
  ref.listen(dmViewerIdProvider, (_, next) {
    if (next.asData?.value != null) unawaited(ref.read(deliveredThrottleProvider).trigger());
  }, fireImmediately: true);
  ref.listen(dmNudgeProvider, (_, next) {
    final signedIn = ref.read(dmViewerIdProvider).asData?.value != null;
    if (signedIn && next is AsyncData<RealtimeSignal>) unawaited(ref.read(deliveredThrottleProvider).trigger());
  });
});
