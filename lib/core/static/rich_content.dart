final _tagPattern = RegExp(r'<[^>]+>');
final _liPattern = RegExp(r'<li>(.*?)</li>', dotAll: true);

/// Strips next-intl-style rich-text tags (`<email>x</email>`, `<link>x</link>`).
/// Their href targets live in web component code, not this JSON string, so
/// Phase 1 renders plain text rather than guessing a destination.
String stripRichTags(String raw) => raw.replaceAll(_tagPattern, '');

/// Extracts `<li>...</li>` fragment items (the web's `sNList`-shaped keys)
/// as plain strings, each itself stripped of any rich-text tags.
List<String> parseListFragment(String raw) =>
    _liPattern.allMatches(raw).map((m) => stripRichTags(m.group(1) ?? '')).toList();
