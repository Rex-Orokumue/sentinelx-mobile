import 'package:app_links/app_links.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/email_link_handler.dart';
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
      case EmailLinkOutcome.verified:
        // Always true immediately after signup confirmation (username is
        // claimed AFTER confirmation, never before — design spec §4.1). A
        // Google sign-in or an already-onboarded email_change link lands on
        // Home instead via onLoggedIn/onSignedIn; this branch is specific to
        // the confirm-link flow.
        router.go('/onboarding/username');
      case EmailLinkOutcome.failed:
        router.go('/login');
    }
    return;
  }
  final resolved = resolveWebLink(uri.toString());
  if (resolved != null) router.go(resolved);
}

void listenForIncomingLinks({required GoRouter router, required GoTrueClient auth}) {
  final appLinks = AppLinks();
  appLinks.uriLinkStream.listen((uri) => handleIncomingLink(uri, router: router, auth: auth));
  appLinks.getInitialLink().then((uri) {
    if (uri != null) handleIncomingLink(uri, router: router, auth: auth);
  });
}
