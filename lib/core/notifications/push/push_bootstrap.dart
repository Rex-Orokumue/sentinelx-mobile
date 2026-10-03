import 'dart:async';
import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/gen/app_localizations.dart';
import '../../providers.dart';
import 'push_gateway.dart';
import 'push_models.dart';
import 'push_tap_router.dart';

AppLocalizations _channelStrings() {
  final code = PlatformDispatcher.instance.locale.languageCode;
  try {
    return lookupAppLocalizations(Locale(code));
  } catch (_) {
    return lookupAppLocalizations(const Locale('en'));
  }
}

/// Startup wiring for push, owned by app startup (listened to from main()). Never throws: a failing
/// gateway means push is off, not that the app fails to start.
///
/// - creates the five Android channels before any push can reference them;
/// - subscribes to background taps and foreground messages;
/// - reads the notification that launched the app (terminated state) and **queues** it until the session
///   and `/me` have settled, then routes it exactly once (or drops it if nobody is signed in).
final pushBootstrapProvider = Provider<void>((ref) {
  final gateway = ref.read(pushGatewayProvider);
  final tapRouter = ref.read(pushTapRouterProvider);
  final subs = <StreamSubscription<PushMessage>>[];
  var disposed = false;
  ref.onDispose(() {
    disposed = true;
    for (final s in subs) {
      s.cancel();
    }
  });

  Future<bool> settledSignedIn() async {
    try {
      // Riverpod 3 pauses a provider nobody listens to, so hold both open while we wait for them.
      final sessionSub = ref.listen(sessionProvider, (_, _) {});
      try {
        final session = await ref.read(sessionProvider.future);
        if (session == null) return false;
        final meSub = ref.listen(meProvider, (_, _) {});
        try {
          await ref.read(meProvider.future);
        } catch (_) {
          // /me failing must not strand the tap; the router's own gate decides what to show.
        } finally {
          meSub.close();
        }
        return true;
      } finally {
        sessionSub.close();
      }
    } catch (_) {
      return false;
    }
  }

  Future<void> run() async {
    try {
      if (!gateway.isAvailable) return;
      await gateway.createChannels(buildPushChannels(_channelStrings()));
      if (disposed) return;
      subs.add(gateway.onMessageOpened.listen(tapRouter.onTap, onError: (Object _) {}));
      subs.add(gateway.onForegroundMessage.listen(ref.read(foregroundPushProvider.notifier).show, onError: (Object _) {}));
      try {
        final initial = await gateway.getInitialMessage();
        if (initial != null) tapRouter.onTap(initial);
      } catch (_) {}
      final signedIn = await settledSignedIn();
      if (disposed) return;
      if (!signedIn) tapRouter.dropPending();
      tapRouter.markReady();
    } catch (_) {
      // push stays off; the app is unaffected
    }
  }

  unawaited(run());
});
