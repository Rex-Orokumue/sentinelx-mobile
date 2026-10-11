const _hosts = {'sentinelxesports.com.ng', 'www.sentinelxesports.com.ng'};
const _locales = {'en', 'fr', 'pcm'};
final _postId = RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$', caseSensitive: false);

/// Web `link` values (push payloads, bell items, App Links) are web route paths. This is the single
/// place that turns one into an in-app go_router location. Extend the switch as each phase adds screens.
String? resolveWebLink(String input) {
  final uri = Uri.tryParse(input.trim());
  if (uri == null) return null;
  if (uri.hasAuthority && !_hosts.contains(uri.host)) return null;

  final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
  if (segments.isNotEmpty && _locales.contains(segments.first)) {
    segments.removeAt(0);
  }

  if (segments.isEmpty) return '/';
  if (segments.length == 1 && segments.first == 'signup') {
    final ref = uri.queryParameters['ref'];
    return ref == null ? '/signup' : '/signup?ref=${Uri.encodeQueryComponent(ref)}';
  }
  // Web tournament links carry the slug; the detail screen accepts an id or a slug.
  if (segments.length == 2 && segments.first == 'tournaments') {
    return '/tournaments/${Uri.encodeComponent(segments[1])}';
  }
  if (segments.length == 2 && segments.first == 'seasons') {
    return '/seasons/${segments[1]}';
  }
  if (segments.length == 2 && segments.first == 'community') {
    // Web post pages are /community/<post uuid>. This also runs as the router's redirect on every
    // in-app location, so a non-post path such as /community/compose must pass through untouched
    // (null), while an *external* web page under /community (e.g. /community/rules) has no screen
    // and lands on the community tab rather than a "couldn't load" post.
    if (_postId.hasMatch(segments[1])) return '/community/${segments[1]}';
    return uri.hasAuthority ? '/community' : null;
  }
  if (segments.first == 'messages') {
    if (segments.length == 1) return '/messages';
    if (segments.length == 2) {
      // Web thread pages are /messages/<thread uuid>. Like /community, this runs as the redirect on every
      // in-app location: /messages/requests (an in-app path) must pass through untouched (null), while an
      // external page that is not a thread lands on the inbox.
      if (_postId.hasMatch(segments[1])) return '/messages/${segments[1].toLowerCase()}';
      return uri.hasAuthority ? '/messages' : null;
    }
    return null;
  }
  if (segments.length == 2 && segments.first == 'matches') {
    return '/matches/${Uri.encodeComponent(segments[1])}';
  }
  if (segments.first == 'players') {
    if (segments.length == 1) return '/players';
    final username = Uri.encodeComponent(segments[1]);
    if (segments.length == 2) return '/players/$username';
    if (segments.length == 3 && (segments[2] == 'followers' || segments[2] == 'following')) {
      return '/players/$username/${segments[2]}';
    }
    return null;
  }
  switch (segments.join('/')) {
    case 'tournaments':
      return '/tournaments';
    case 'games':
      return '/games';
    case 'tv':
      return '/tv';
    case 'community':
      return '/community';
    case 'exchange':
      return '/exchange';
    case 'rankings':
      return '/rankings';
    case 'seasons':
      return '/seasons';
    case 'hall-of-fame':
      return '/hall-of-fame';
    case 'dashboard/referrals':
      return '/account/referrals';
    case 'store':
      return '/account/store';
    // The Paystack return path (/api/paystack/callback) is deliberately NOT mapped: the in-app checkout
    // WebView intercepts it and the app confirms the deposit through the API instead.
    case 'dashboard/wallet':
      return '/account/wallet';
    case 'dashboard/wallet/deposit':
      return '/account/wallet/deposit';
    case 'dashboard/wallet/withdraw':
      return '/account/wallet/withdraw';
    case 'dashboard/wallet/transactions':
      return '/account/wallet/transactions';
    case 'dashboard/wallet/payment-methods':
      return '/account/wallet/payout-account';
    // The web settings page (the test push's url) holds the notification preferences; the app's
    // equivalent is Settings -> Notifications.
    case 'dashboard/settings':
      return '/account/notifications';
  }
  return null;
}

/// The five bottom-tab roots. Reaching one is a tab switch (`go`), not a screen stacked on top (`push`):
/// a pushed tab page keeps the tab bar but has no Back control to return with.
const tabRootLocations = {'/tournaments', '/tv', '/community', '/exchange', '/account'};
