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

  test('maps a tournament web link (slug) to the in-app detail route, and /games to the games list', () {
    expect(resolveWebLink('https://sentinelxesports.com.ng/tournaments/fc-mobile-cup'), '/tournaments/fc-mobile-cup');
    expect(resolveWebLink('https://sentinelxesports.com.ng/fr/tournaments/fc-mobile-cup?paid=1'), '/tournaments/fc-mobile-cup');
    expect(resolveWebLink('https://sentinelxesports.com.ng/games'), '/games');
  });

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

  test('returns null for other hosts and for paths the app has no screen for yet', () {
    expect(resolveWebLink('https://evil.example/tournaments'), isNull);
    expect(resolveWebLink('https://sentinelxesports.com.ng/tournaments/some-slug/bracket'), isNull);
    expect(resolveWebLink('https://sentinelxesports.com.ng/tournaments/a/b/c'), isNull);
    expect(resolveWebLink('not a url at all ::'), isNull);
  });

  test('maps player web paths (with and without a locale), keeps usernames intact and is idempotent', () {
    expect(resolveWebLink('https://sentinelxesports.com.ng/players'), '/players');
    expect(resolveWebLink('https://sentinelxesports.com.ng/players/ada'), '/players/ada');
    expect(resolveWebLink('https://sentinelxesports.com.ng/fr/players/ada'), '/players/ada');
    expect(resolveWebLink('https://sentinelxesports.com.ng/players/ada/followers'), '/players/ada/followers');
    expect(resolveWebLink('https://sentinelxesports.com.ng/en/players/ada/following?x=1'), '/players/ada/following');
    expect(resolveWebLink('https://sentinelxesports.com.ng/players/a%20b'), '/players/a%20b');
    expect(resolveWebLink('https://sentinelxesports.com.ng/players/ada/unknown'), isNull);
    expect(resolveWebLink('https://evil.example/players/ada'), isNull);
    // idempotent: the router redirect must never loop
    for (final p in ['/players', '/players/ada', '/players/ada/followers', '/players/a%20b']) {
      expect(resolveWebLink(p), p);
    }
    // in-app paths of this phase pass through untouched (null = no redirect)
    expect(resolveWebLink('/account/progress'), isNull);
  });

  test('maps a match web link to the Match Centre, with and without a locale prefix', () {
    expect(resolveWebLink('https://sentinelxesports.com.ng/matches/abc'), '/matches/abc');
    expect(resolveWebLink('https://sentinelxesports.com.ng/fr/matches/abc?x=1'), '/matches/abc');
    expect(resolveWebLink('https://sentinelxesports.com.ng/matches'), isNull);
    // the bracket API needs an id, not the slug carried by this web path — never mapped
    expect(resolveWebLink('https://sentinelxesports.com.ng/tournaments/some-slug/bracket'), isNull);
  });
}
