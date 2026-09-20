import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/core/routing/web_links.dart';

void main() {
  test('maps the tournaments list and site root to the in-app list screen', () {
    expect(resolveWebLink('https://sentinelxesports.com.ng/tournaments'), '/');
    expect(resolveWebLink('https://sentinelxesports.com.ng/'), '/');
    expect(resolveWebLink('/tournaments'), '/');
  });

  test('strips a locale prefix, query and fragment', () {
    expect(resolveWebLink('https://sentinelxesports.com.ng/fr/tournaments'), '/');
    expect(resolveWebLink('https://sentinelxesports.com.ng/pcm/tournaments?x=1#y'), '/');
  });

  test('accepts the www host and tolerates a trailing slash', () {
    expect(resolveWebLink('https://www.sentinelxesports.com.ng/tournaments/'), '/');
  });

  test('returns null for other hosts and for paths the app has no screen for yet', () {
    expect(resolveWebLink('https://evil.example/tournaments'), isNull);
    expect(resolveWebLink('https://sentinelxesports.com.ng/exchange'), isNull);
    expect(resolveWebLink('https://sentinelxesports.com.ng/tournaments/some-slug'), isNull);
    expect(resolveWebLink('not a url at all ::'), isNull);
  });
}
