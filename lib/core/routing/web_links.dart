const _hosts = {'sentinelxesports.com.ng', 'www.sentinelxesports.com.ng'};
const _locales = {'en', 'fr', 'pcm'};

/// Web `link` values (push payloads, bell items, App Links) are web route paths. This is the single
/// place that turns one into an in-app go_router location. Extend the switch as each phase adds screens.
String? resolveWebLink(String input) {
  final uri = Uri.tryParse(input.trim());
  if (uri == null) return null;
  if (uri.hasAuthority && !_hosts.contains(uri.host)) return null;

  final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
  if (segments.isNotEmpty && _locales.contains(segments.first)) segments.removeAt(0);

  if (segments.isEmpty) return '/';
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
    case 'tv':
      return '/tv';
    case 'community':
      return '/community';
    case 'exchange':
      return '/exchange';
  }
  return null;
}
