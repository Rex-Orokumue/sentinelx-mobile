import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/core/api/models.dart';
import 'package:sentinelx_mobile/core/api/players_models.dart';
import 'package:sentinelx_mobile/core/l10n/gen/app_localizations.dart';
import 'package:sentinelx_mobile/core/providers.dart';
import 'package:sentinelx_mobile/features/progress/history_list_screen.dart';
import 'package:sentinelx_mobile/features/progress/progress_providers.dart';

import '../support/fake_players_repository.dart';
import '../support/fake_progress_repository.dart';

XpEvent _xp(int i, {String source = 'match_won'}) => XpEvent(id: 'x$i', xp: 10 + i, source: source, createdAt: '2026-09-0${(i % 9) + 1}T10:00:00+00:00');

HistoryPage<XpEvent> _page(List<XpEvent> items, String? next) => HistoryPage(items: items, nextCursor: next);

Widget _xpApp(FakeProgressRepository repo, {bool signedIn = true}) => ProviderScope(
      retry: (_, _) => null,
      overrides: [
        progressRepositoryProvider.overrideWithValue(repo),
        meProvider.overrideWith((ref) async => signedIn
            ? const MeResponse(id: 'me1', email: null, roles: [], isStaff: false, isAdmin: false, profile: null)
            : null),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: HistoryListScreen<XpEvent>(title: 'XP history', provider: xpHistoryProvider, rowBuilder: xpRow),
      ),
    );

void main() {
  testWidgets('loads the first page, then follows nextCursor exactly once per page and stops on the last', (tester) async {
    final repo = FakeProgressRepository()
      ..xpPager = (cursor) => switch (cursor) {
            null => _page([_xp(1), _xp(2), _xp(3)], 'c1'),
            'c1' => _page([_xp(4), _xp(5)], null),
            _ => throw StateError('unexpected cursor $cursor'),
          };
    await tester.pumpWidget(_xpApp(repo));
    await tester.pumpAndSettle();
    expect(repo.xpCursors, [null, 'c1']); // second page loaded automatically, third never requested
    expect(find.text('+11 XP'), findsOneWidget);
    expect(find.text('+15 XP'), findsOneWidget);
    expect(find.byKey(const Key('history-loading-more')), findsNothing);
  });

  testWidgets('a failed loadMore shows a retry tile and does NOT loop; tapping it retries the same cursor', (tester) async {
    var failSecondPage = true;
    final repo = FakeProgressRepository()
      ..xpPager = (cursor) {
        if (cursor == 'c1' && failSecondPage) throw apiError(0, 'network');
        return cursor == null ? _page([_xp(1), _xp(2)], 'c1') : _page([_xp(3)], null);
      };
    await tester.pumpWidget(_xpApp(repo));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('history-retry')), findsOneWidget);
    final callsAfterFailure = repo.xpCursors.length; // [null, 'c1']
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(repo.xpCursors.length, callsAfterFailure, reason: 'a failed page must not be re-requested automatically');
    failSecondPage = false;
    await tester.tap(find.byKey(const Key('history-retry')));
    await tester.pumpAndSettle();
    expect(repo.xpCursors.last, 'c1');
    expect(find.byKey(const Key('history-retry')), findsNothing);
    expect(find.text('+13 XP'), findsOneWidget);
  });

  testWidgets('an id repeated across pages is shown once', (tester) async {
    final repo = FakeProgressRepository()
      ..xpPager = (cursor) => cursor == null ? _page([_xp(1), _xp(2)], 'c1') : _page([_xp(2), _xp(3)], null);
    await tester.pumpWidget(_xpApp(repo));
    await tester.pumpAndSettle();
    expect(find.text('+12 XP'), findsOneWidget);
    expect(find.text('+13 XP'), findsOneWidget);
  });

  testWidgets('an unknown source code renders a humanized label, not blank', (tester) async {
    final repo = FakeProgressRepository()..xpPager = (_) => _page([_xp(1, source: 'referral_bonus_v2')], null);
    await tester.pumpWidget(_xpApp(repo));
    await tester.pumpAndSettle();
    expect(find.text('Referral bonus v2'), findsOneWidget);
  });

  testWidgets('empty history shows the empty state', (tester) async {
    final repo = FakeProgressRepository()..xpPager = (_) => _page(const [], null);
    await tester.pumpWidget(_xpApp(repo));
    await tester.pumpAndSettle();
    expect(find.text('No activity yet.'), findsOneWidget);
  });

  testWidgets('signed out: no request is made', (tester) async {
    final repo = FakeProgressRepository()..xpPager = (_) => _page([_xp(1)], null);
    await tester.pumpWidget(_xpApp(repo, signedIn: false));
    await tester.pumpAndSettle();
    expect(repo.xpCursors, isEmpty);
  });

  testWidgets('score rows show signed deltas; coin rows show a minus for spends and the resulting balance', (tester) async {
    final repo = FakeProgressRepository()
      ..scorePager = ((_) => HistoryPage(items: [
            SxScoreEvent.fromJson({'id': 's1', 'eventType': 'no_show', 'pointsDelta': -15, 'matchId': null, 'createdAt': '2026-09-01T10:00:00+00:00'}),
            SxScoreEvent.fromJson({'id': 's2', 'eventType': 'match_completed', 'pointsDelta': 8, 'matchId': 'm1', 'createdAt': '2026-09-02T10:00:00+00:00'}),
          ], nextCursor: null))
      ..coinPager = ((_) => HistoryPage(items: [
            CoinTransaction.fromJson({'id': 'c1', 'amount': -200, 'balanceAfter': 50, 'source': 'post_boost', 'description': 'Boosted a post', 'createdAt': '2026-09-01T10:00:00+00:00'}),
          ], nextCursor: null));
    Widget app(Widget home) => ProviderScope(
          retry: (_, _) => null,
          overrides: [
            progressRepositoryProvider.overrideWithValue(repo),
            meProvider.overrideWith((ref) async => const MeResponse(id: 'me1', email: null, roles: [], isStaff: false, isAdmin: false, profile: null)),
          ],
          child: MaterialApp(localizationsDelegates: AppLocalizations.localizationsDelegates, supportedLocales: AppLocalizations.supportedLocales, home: home),
        );
    await tester.pumpWidget(app(HistoryListScreen<SxScoreEvent>(title: 'Score', provider: scoreHistoryProvider, rowBuilder: scoreRow)));
    await tester.pumpAndSettle();
    expect(find.text('-15'), findsOneWidget);
    expect(find.text('+8'), findsOneWidget);
    expect(find.text('No-show'), findsOneWidget);
    await tester.pumpWidget(app(HistoryListScreen<CoinTransaction>(title: 'Coins', provider: coinHistoryProvider, rowBuilder: coinRow)));
    await tester.pumpAndSettle();
    expect(find.text('-200'), findsOneWidget);
    expect(find.text('Balance 50'), findsOneWidget);
    expect(find.text('Boosted a post'), findsOneWidget);
  });
}
