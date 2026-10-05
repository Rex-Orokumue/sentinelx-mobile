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

  test('a community post link resolves to the post, not the feed', () {
    const id = '3f2b8c1e-9d4a-4b7e-8a61-5c0d2e7f9a10';
    expect(resolveWebLink('https://sentinelxesports.com.ng/community/$id'), '/community/$id');
    expect(resolveWebLink('https://sentinelxesports.com.ng/fr/community/$id'), '/community/$id');
    expect(resolveWebLink('https://sentinelxesports.com.ng/community/${id.toUpperCase()}'), '/community/${id.toUpperCase()}');
    expect(resolveWebLink('/community/$id'), '/community/$id');
  });

  test('a web page under /community that is not a post lands on the community tab, not a broken post screen', () {
    expect(resolveWebLink('https://sentinelxesports.com.ng/community/rules'), '/community');
    expect(resolveWebLink('https://sentinelxesports.com.ng/en/community/guidelines'), '/community');
  });

  test('in-app community paths are left for the router (the redirect runs on every location)', () {
    expect(resolveWebLink('/community/compose'), isNull);
    expect(resolveWebLink('/community/statuses'), isNull);
    expect(resolveWebLink('/community/statuses/compose'), isNull);
    expect(resolveWebLink('/community/p1'), isNull);
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

  test('the web settings page maps to in-app notification settings (the test push url)', () {
    expect(resolveWebLink('/dashboard/settings'), '/account/notifications');
    expect(resolveWebLink('https://sentinelxesports.com.ng/en/dashboard/settings'), '/account/notifications');
    expect(resolveWebLink('https://sentinelxesports.com.ng/fr/dashboard/settings?x=1'), '/account/notifications');
  });

  test('web destinations the app has no screen for stay unmapped (a push tap then falls back to the bell)', () {
    expect(resolveWebLink('/dashboard/settings/extra'), isNull);
    expect(resolveWebLink('/dashboard/wallet'), isNull);
    expect(resolveWebLink('/messages/abc'), isNull);
    expect(resolveWebLink('/admin/matches/1/review'), isNull);
    expect(resolveWebLink('/exchange/abc'), isNull);
  });

  test('in-app notification paths pass through the redirect untouched (lesson 8)', () {
    expect(resolveWebLink('/notifications'), isNull);
    expect(resolveWebLink('/account/notifications'), isNull);
    expect(resolveWebLink('/account'), isNull);
  });

  group('messages links', () {
    const id = '3f2b8c1e-9d4a-4b7e-8a61-5c0d2e7f9a10';

    test('/messages maps to the inbox, with or without a locale prefix', () {
      expect(resolveWebLink('https://sentinelxesports.com.ng/messages'), '/messages');
      expect(resolveWebLink('https://sentinelxesports.com.ng/fr/messages'), '/messages');
    });

    test('a thread link maps to the conversation (lower-cased), locale stripped', () {
      expect(resolveWebLink('/messages/$id'), '/messages/$id');
      expect(resolveWebLink('https://sentinelxesports.com.ng/fr/messages/$id'), '/messages/$id');
      expect(resolveWebLink('https://sentinelxesports.com.ng/messages/${id.toUpperCase()}'), '/messages/$id');
    });

    test('in-app /messages/requests passes through the redirect untouched (lesson 9)', () {
      expect(resolveWebLink('/messages/requests'), isNull);
    });

    test('an external page under /messages that is not a thread lands on the inbox', () {
      expect(resolveWebLink('https://sentinelxesports.com.ng/messages/requests'), '/messages');
      expect(resolveWebLink('https://sentinelxesports.com.ng/messages/garbage'), '/messages');
    });

    test('anything deeper than a thread is unmapped', () {
      expect(resolveWebLink('/messages/$id/x'), isNull);
      expect(resolveWebLink('https://sentinelxesports.com.ng/messages/$id/x'), isNull);
    });
  });

  test('in-app guide paths are not swallowed by the redirect', () {
    expect(resolveWebLink('/guide'), isNull);
    expect(resolveWebLink('/guide/chat'), isNull);
  });
}
