import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../router/app_router.dart';
import '../auth/email_link_handler.dart';
import '../providers.dart';
import 'web_links.dart';

const _locales = {'en', 'fr', 'pcm'};

bool isAuthConfirmPath(Uri uri) {
  final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
  if (segments.isNotEmpty && _locales.contains(segments.first)) segments.removeAt(0);
  return segments.join('/') == 'auth/confirm';
}

// The single place an incoming URI (App Link tap, cold-start deep link) is
// decided between two paths: /auth/confirm needs verifyOtp run against it
// first (Task 7); everything else is a plain in-app navigation resolved by
// resolveWebLink. Both end in the same router.go(...).
Future<void> handleIncomingLink(Uri uri, {required GoRouter router, required GoTrueClient auth}) async {
  if (isAuthConfirmPath(uri)) {
    final result = await handleEmailLink(uri, auth: auth);
    switch (result.outcome) {
      case EmailLinkOutcome.recovery:
        router.go('/reset-password');
      case EmailLinkOutcome.signupConfirmed:
        // Username is claimed AFTER confirmation, never before (design spec
        // §4.1) — always true immediately after a signup link, so go there
        // directly rather than via Home (the router's global auth redirect
        // in app_router.dart would reach the same place after a load flash).
        router.go('/onboarding/username');
      case EmailLinkOutcome.emailChanged:
      case EmailLinkOutcome.invited:
      case EmailLinkOutcome.magicLink:
        // Not a new signup — go Home and let the router's global
        // auth/onboarding redirect (evaluateAuthRedirect) decide whether
        // this account still needs onboarding.
        router.go('/');
      case EmailLinkOutcome.failed:
        router.go('/login');
    }
    return;
  }
  final resolved = resolveWebLink(uri.toString());
  if (resolved != null) router.go(resolved);
}

/// Owns the App Links subscription for the app's lifetime (constructed once
/// via incomingLinkListenerProvider) instead of a fire-and-forget
/// `.listen(...)` with no retained subscription, and reports failures
/// instead of letting them become an unhandled Future error.
class IncomingLinkListener {
  IncomingLinkListener({required GoRouter router, required GoTrueClient auth, required this.onError}) {
    final appLinks = AppLinks();
    _subscription = appLinks.uriLinkStream.listen(
      (uri) => _handle(uri, router, auth),
      onError: (Object error, StackTrace stack) => onError(error, stack),
    );
    _handleInitialLink(appLinks, router, auth);
  }

  final void Function(Object error, StackTrace stack) onError;
  late final StreamSubscription<Uri> _subscription;

  Future<void> _handleInitialLink(AppLinks appLinks, GoRouter router, GoTrueClient auth) async {
    try {
      final uri = await appLinks.getInitialLink();
      if (uri != null) _handle(uri, router, auth);
    } catch (error, stack) {
      onError(error, stack);
    }
  }

  Future<void> _handle(Uri uri, GoRouter router, GoTrueClient auth) async {
    try {
      await handleIncomingLink(uri, router: router, auth: auth);
    } catch (error, stack) {
      onError(error, stack);
    }
  }

  void dispose() => _subscription.cancel();
}

final incomingLinkListenerProvider = Provider<IncomingLinkListener>((ref) {
  final reporter = ref.watch(errorReporterProvider);
  final listener = IncomingLinkListener(
    router: ref.watch(routerProvider),
    auth: ref.watch(supabaseClientProvider).auth,
    onError: (error, stack) => reporter.report(error, stack, route: 'incoming-link'),
  );
  ref.onDispose(listener.dispose);
  return listener;
});
