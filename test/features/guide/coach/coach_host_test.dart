import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/core/l10n/gen/app_localizations.dart';
import 'package:sentinelx_mobile/core/providers.dart';
import 'package:sentinelx_mobile/core/storage/local_kv.dart';
import 'package:sentinelx_mobile/features/guide/coach/coach_host.dart';
import 'package:sentinelx_mobile/features/guide/coach/coach_registry.dart';
import 'package:sentinelx_mobile/features/guide/coach/coach_tours.dart';

import '../../../fakes/fake_local_kv.dart';

Widget _app(MemoryLocalKv kv) => ProviderScope(
      overrides: [
        localKvProvider.overrideWith((ref) async => kv),
        viewerIdProvider.overrideWith((ref) async => 'u1'),
        meProvider.overrideWith((ref) async => null),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: CoachHost(
          tour: homeTour,
          child: const Scaffold(
            body: Column(children: [
              CoachTarget(id: 'home.fixtures', child: SizedBox(width: 200, height: 60, child: Text('fixtures'))),
              CoachTarget(id: 'home.account', child: SizedBox(width: 200, height: 60, child: Text('account'))),
            ]),
          ),
        ),
      ),
    );

void main() {
  testWidgets('shows the first present step, Next advances, Done closes and marks it seen', (tester) async {
    final kv = MemoryLocalKv();
    await tester.pumpWidget(_app(kv));
    await tester.pumpAndSettle();
    expect(find.text('Your fixtures'), findsOneWidget);
    expect(find.text('1 of 2'), findsOneWidget);
    await tester.tap(find.byKey(const Key('coach-next')));
    await tester.pumpAndSettle();
    expect(find.text('Your account'), findsOneWidget); // the quest and guide steps have no target here: skipped
    expect(find.text('Done'), findsOneWidget);
    await tester.tap(find.byKey(const Key('coach-next')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('coach-next')), findsNothing);
    expect(kv.values['coach.u1.home'], '1');
  });

  testWidgets('Skip removes the overlay and writes the flag', (tester) async {
    final kv = MemoryLocalKv();
    await tester.pumpWidget(_app(kv));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('coach-skip')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('coach-next')), findsNothing);
    expect(kv.values['coach.u1.home'], '1');
  });

  testWidgets('the system back button dismisses it and marks it seen', (tester) async {
    final kv = MemoryLocalKv();
    await tester.pumpWidget(_app(kv));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('coach-next')), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('coach-next')), findsNothing);
    expect(kv.values['coach.u1.home'], '1');
  });

  testWidgets('does not reappear on a second pump with the same storage', (tester) async {
    final kv = MemoryLocalKv();
    await tester.pumpWidget(_app(kv));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('coach-skip')));
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(_app(kv));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('coach-next')), findsNothing);
  });
}
