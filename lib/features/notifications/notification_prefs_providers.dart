import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/notifications_models.dart';
import 'notifications_providers.dart';
import 'notifications_repository.dart';

/// A type is silenced when it has a live timed mute, or "always" was chosen (which the server stores as
/// `push[type] == false`, so the preference switch and the mute menu can never disagree).
bool isTypeSilenced(String type, {required NotificationPrefs? prefs, required NotificationMutes? mutes, required DateTime now}) {
  if (prefs?.push[type] == false) return true;
  return mutes?.isTypeMuted(type, now) ?? false;
}

/// The caller's effective notification preferences (the server resolves "absent = default", never Dart).
/// Null when signed out; rebuilds for a different user (login/logout/account switch) and not on a token
/// refresh, so one user's switches are never shown to another.
class NotificationPrefsNotifier extends AsyncNotifier<NotificationPrefs?> {
  // One in-flight patch per key at a time, in tap order, so responses can never arrive out of order.
  final _chains = <String, Future<void>>{};
  // Latest toggle number per key: a failure only reverts if nobody toggled the key again since.
  final _latest = <String, int>{};
  var _seq = 0;

  @override
  Future<NotificationPrefs?> build() async {
    final viewer = await ref.watch(notificationsViewerIdProvider.future);
    if (viewer == null) return null;
    return ref.read(notificationsRepositoryProvider).prefs();
  }

  /// Optimistic. On failure reverts only this key, and only if its value is still the one we set — a later
  /// toggle of the same key wins, and no other key is ever touched. On success the local value stands (the
  /// server body is not applied over what the user may have changed since).
  Future<bool> set(PrefSection section, String key, bool value) async {
    if (!ref.mounted) return false;
    final current = state.value;
    if (current == null) return false;
    final repo = ref.read(notificationsRepositoryProvider);
    final before = current.section(section)[key] ?? !value;
    state = AsyncData(current.withValue(section, key, value));

    final id = '${section.wire}.$key';
    final mine = _latest[id] = ++_seq;
    final previous = _chains[id] ?? Future<void>.value();
    final run = previous.then((_) => repo.patchPrefs(section, {key: value})).then((_) => true, onError: (Object _) => false);
    _chains[id] = run.then((_) {});
    final ok = await run;

    if (!ok && ref.mounted) {
      final now = state.value;
      if (now != null && _latest[id] == mine && now.section(section)[key] == value) {
        state = AsyncData(now.withValue(section, key, before));
      }
    }
    return ok;
  }
}

final notificationPrefsProvider =
    AsyncNotifierProvider.autoDispose<NotificationPrefsNotifier, NotificationPrefs?>(NotificationPrefsNotifier.new);
