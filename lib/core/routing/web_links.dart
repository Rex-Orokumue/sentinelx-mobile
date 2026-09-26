const _hosts = {'sentinelxesports.com.ng', 'www.sentinelxesports.com.ng'};
const _locales = {'en', 'fr', 'pcm'};

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
  // Web tournament links carry the slug; the detail screen accepts an id or a slug.
  if (segments.length == 2 && segments.first == 'tournaments') {
    return '/tournaments/${Uri.encodeComponent(segments[1])}';
  }
  if (segments.length == 2 && segments.first == 'seasons') {
    return '/seasons/${segments[1]}';
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
  }
  return null;
}
