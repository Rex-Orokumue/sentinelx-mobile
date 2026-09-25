import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/core/api/models.dart';
import 'package:sentinelx_mobile/core/l10n/gen/app_localizations.dart';
import 'package:sentinelx_mobile/core/providers.dart';
import 'package:sentinelx_mobile/features/progress/my_progress_screen.dart';
import 'package:sentinelx_mobile/features/progress/progress_providers.dart';

import '../support/fake_players_repository.dart';
import '../support/fake_progress_repository.dart';

Widget _app(FakeProgressRepository repo, {bool signedIn = true, void Function(String)? onGoTo, VoidCallback? onLogIn}) => ProviderScope(
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
        home: MyProgressScreen(onGoTo: onGoTo ?? (_) {}, onLogIn: onLogIn ?? () {}),
      ),
    );

void main() {
  testWidgets('shows XP with progress to the next tier, SX Score, coins and the season card', (tester) async {
    await tester.pumpWidget(_app(FakeProgressRepository()));
    await tester.pumpAndSettle();
    expect(find.text('Guardian'), findsWidgets);
    expect(find.text('500 / 4000 XP to Elite'), findsOneWidget);
    expect(find.text('1234'), findsWidgets);
    expect(find.text('Rank #7'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
  });

  testWidgets('max tier shows the max-tier message and no progress bar', (tester) async {
    await tester.pumpWidget(_app(FakeProgressRepository()..progressData = progressJson(maxTier: true)));
    await tester.pumpAndSettle();
    expect(find.text('Max tier reached'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNothing);
  });

  testWidgets('no active season shows the empty season card; an unranked player shows Unranked', (tester) async {
    await tester.pumpWidget(_app(FakeProgressRepository()..progressData = progressJson(withSeason: false)));
    await tester.pumpAndSettle();
    expect(find.text('No active season.'), findsOneWidget);
    final unranked = progressJson();
    (unranked['seasonStanding'] as Map<String, dynamic>)['rank'] = null;
    await tester.pumpWidget(_app(FakeProgressRepository()..progressData = unranked));
    await tester.pumpAndSettle();
    expect(find.text('Unranked'), findsWidgets);
  });

  testWidgets('signed out: login prompt, login callback, and NO /me/progress request', (tester) async {
    final repo = FakeProgressRepository();
    var login = 0;
    await tester.pumpWidget(_app(repo, signedIn: false, onLogIn: () => login++));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('progress-signin')), findsOneWidget);
    await tester.tap(find.byKey(const Key('progress-login')));
    expect(login, 1);
    expect(repo.progressCalls, 0);
  });

  testWidgets('history tiles navigate to the three history routes', (tester) async {
    final visited = <String>[];
    await tester.pumpWidget(_app(FakeProgressRepository(), onGoTo: visited.add));
    await tester.pumpAndSettle();
    for (final k in ['progress-link-xp', 'progress-link-score', 'progress-link-coins']) {
      await tester.scrollUntilVisible(find.byKey(Key(k)), 200, scrollable: find.byType(Scrollable).first); // lazy list
      await tester.tap(find.byKey(Key(k)));
    }
    expect(visited, ['/account/progress/xp', '/account/progress/score', '/account/progress/coins']);
  });

  testWidgets('a failed load shows the retry message, not a stack trace', (tester) async {
    await tester.pumpWidget(_app(FakeProgressRepository()..progressError = apiError(500, 'internal')));
    await tester.pumpAndSettle();
    expect(find.text("Couldn't load. Tap to retry."), findsOneWidget);
  });
}
