import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../providers.dart';

/// Fires POST /session/start exactly once per signed-in user id, regardless
/// of how many times the underlying Supabase Session object changes (token
/// refresh, duplicate initial-session emissions — each is a new Session
/// instance, so watching sessionProvider directly re-fires on every one of
/// them). Owned by app startup (see incomingLinkListenerProvider for the
/// sibling pattern), not any particular screen — a signed-in user reaches this
/// exactly once no matter which screen they land on first.
class SessionLifecycle {
  SessionLifecycle(Ref ref) : _ref = ref {
    _sub = ref.listen<AsyncValue<Session?>>(sessionProvider, _onSessionChange, fireImmediately: true);
  }

  final Ref _ref;
  String? _startedForUserId;
  late final ProviderSubscription<AsyncValue<Session?>> _sub;

  void _onSessionChange(AsyncValue<Session?>? previous, AsyncValue<Session?> next) {
    final userId = next.asData?.value?.user.id;
    if (userId == null) {
      _startedForUserId = null;
      return;
    }
    if (_startedForUserId == userId) return;
    _startedForUserId = userId;
    _start(userId);
  }

  Future<void> _start(String userId) async {
    try {
      await _ref.read(apiClientProvider).postSessionStart();
    } catch (_) {
      // A failed session/start must not crash startup or block navigation —
      // clear the guard so the next auth-state event (e.g. the next token
      // refresh) retries rather than giving up on this user id forever.
      if (_startedForUserId == userId) _startedForUserId = null;
    }
  }

  void dispose() => _sub.close();
}

final sessionLifecycleProvider = Provider<SessionLifecycle>((ref) {
  final lifecycle = SessionLifecycle(ref);
  ref.onDispose(lifecycle.dispose);
  return lifecycle;
});
