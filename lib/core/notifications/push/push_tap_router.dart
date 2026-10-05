import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../features/notifications/notifications_repository.dart';
import '../../../router/app_router.dart';
import '../../routing/web_links.dart';
import 'push_models.dart';

/// Where a tapped push goes: the in-app screen for its web `url`, or the bell when there is no url or the
/// app has no screen for it yet (spec §3.7) — a tap must never silently do nothing.
final _uuid = RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$', caseSensitive: false);

String destinationFor(PushMessage m) {
  // A DM routes from its thread id; only without one does it fall back to url resolution (below).
  final thread = m.threadId;
  if (m.type == 'direct_message' && thread != null && _uuid.hasMatch(thread)) return '/messages/${thread.toLowerCase()}';
  final url = m.url?.trim();
  // A blank url must not reach resolveWebLink: it would resolve to Home, not the bell.
  if (url == null || url.isEmpty) return '/notifications';
  return resolveWebLink(url) ?? '/notifications';
}

/// Tab roots and Home are switched to (`go`); anything deeper stacks over whatever the player is looking at
/// (`push`) so Back returns there, and is skipped when it is already the current location (no duplicate page).
void pushNavigate(GoRouter router, String location) {
  if (location == '/' || tabRootLocations.contains(location)) {
    router.go(location);
    return;
  }
  // The top page's location (a pushed page does not change the configuration's own uri).
  final matches = router.routerDelegate.currentConfiguration;
  if (matches.isNotEmpty && matches.last.matchedLocation == Uri.parse(location).path) return;
  router.push<void>(location).ignore();
}

/// Navigates to an in-app location. A provider so tests record locations instead of building a router.
final pushNavigatorProvider = Provider<void Function(String location)>(
  (ref) => (location) => pushNavigate(ref.read(routerProvider), location),
);

/// Routes push taps. A tap can fire before the Supabase session has restored (cold start from a killed
/// app); routing then would bounce through the login/onboarding gate and lose the destination, so taps are
/// queued until [markReady] and only the latest queued one is kept.
class PushTapRouter {
  PushTapRouter(this._ref);

  final Ref _ref;
  PushMessage? _pending;
  bool _ready = false;

  void onTap(PushMessage m) {
    if (!_ready) {
      _pending = m;
      return;
    }
    _route(m);
  }

  /// The session and `/me` have settled with a signed-in user. Flushes the queued tap, once.
  void markReady() {
    if (_ready) return;
    _ready = true;
    final pending = _pending;
    _pending = null;
    if (pending != null) _route(pending);
  }

  /// Signed out when the app settled: there is nothing to open, so forget the queued tap.
  void dropPending() => _pending = null;

  void _route(PushMessage m) {
    _ref.read(pushNavigatorProvider)(destinationFor(m));
    final url = m.url?.trim();
    if (url != null && url.isNotEmpty) unawaited(_markRead(url));
  }

  // The push carries the url, not the row id (Stage B Ruling 3): look the row up by link. Best-effort.
  Future<void> _markRead(String url) async {
    try {
      await _ref.read(notificationsRepositoryProvider).markReadForLink(url);
    } catch (_) {}
  }
}

final pushTapRouterProvider = Provider<PushTapRouter>((ref) => PushTapRouter(ref));

/// The foreground banner's current message (null when none). Auto-dismisses after 5 seconds.
class ForegroundPushController extends Notifier<PushMessage?> {
  Timer? _timer;

  @override
  PushMessage? build() {
    ref.onDispose(() => _timer?.cancel());
    return null;
  }

  void show(PushMessage m) {
    _timer?.cancel();
    state = m;
    _timer = Timer(const Duration(seconds: 5), dismiss);
  }

  void dismiss() {
    _timer?.cancel();
    _timer = null;
    if (ref.mounted) state = null;
  }
}

final foregroundPushProvider = NotifierProvider<ForegroundPushController, PushMessage?>(ForegroundPushController.new);
