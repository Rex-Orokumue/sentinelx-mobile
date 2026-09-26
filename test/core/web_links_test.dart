import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/core/routing/web_links.dart';

void main() {
  test('maps the site root to standalone Home', () {
    expect(resolveWebLink('https://sentinelxesports.com.ng/'), '/');
    expect(resolveWebLink('/'), '/');
  });

  test(
    'maps the tournaments list to the Compete branch (no longer the site root)',
    () {
      expect(
        resolveWebLink('https://sentinelxesports.com.ng/tournaments'),
        '/tournaments',
      );
    },
  );

  test('maps tv, community and exchange to their branch roots', () {
    expect(resolveWebLink('https://sentinelxesports.com.ng/tv'), '/tv');
    expect(
      resolveWebLink('https://sentinelxesports.com.ng/community'),
      '/community',
    );
    expect(
      resolveWebLink('https://sentinelxesports.com.ng/exchange'),
      '/exchange',
    );
  });

  test('strips a locale prefix, query and fragment', () {
    expect(
      resolveWebLink('https://sentinelxesports.com.ng/fr/tournaments'),
      '/tournaments',
    );
    expect(
      resolveWebLink('https://sentinelxesports.com.ng/pcm/tournaments?x=1#y'),
      '/tournaments',
    );
    expect(resolveWebLink('https://sentinelxesports.com.ng/fr/'), '/');
  });

  test('accepts the www host and tolerates a trailing slash', () {
    expect(
      resolveWebLink('https://www.sentinelxesports.com.ng/tournaments/'),
      '/tournaments',
    );
  });

  test('maps progress pages and localized season detail links', () {
    expect(
      resolveWebLink('https://sentinelxesports.com.ng/rankings'),
      '/rankings',
    );
    expect(
      resolveWebLink('https://sentinelxesports.com.ng/seasons'),
      '/seasons',
    );
    expect(
      resolveWebLink('https://sentinelxesports.com.ng/fr/seasons/season-one'),
      '/seasons/season-one',
    );
    expect(
      resolveWebLink('https://sentinelxesports.com.ng/hall-of-fame'),
      '/hall-of-fame',
    );
  });

  test(
    'returns null for other hosts and for paths the app has no screen for yet',
    () {
      expect(resolveWebLink('https://evil.example/tournaments'), isNull);
      expect(
        resolveWebLink('https://sentinelxesports.com.ng/tournaments/some-slug'),
        isNull,
      );
      expect(resolveWebLink('not a url at all ::'), isNull);
    },
  );
}
