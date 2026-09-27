import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/core/api/api_client.dart';
import 'package:sentinelx_mobile/features/match/match_providers.dart';
import 'package:sentinelx_mobile/features/match/match_reads_repository.dart';
import 'package:sentinelx_mobile/features/match/rating_sheet.dart';

import '../../fakes/fake_match_repositories.dart';
import '../../support/pump_compete.dart';

ApiException _apiEx(String code, {int status = 409}) => ApiException(status: status, code: code, message: 'x');

const _match = MatchInfo(
  id: 'm1',
  tournamentId: 't1',
  round: 'quarter_final',
  status: 'completed',
  isFullDay: false,
  nameA: 'Ada',
  nameB: 'Bola',
);

Future<FakeMatchRepository> _pump(WidgetTester tester) async {
  final repo = FakeMatchRepository();
  await pumpCompete(
    tester,
    Builder(builder: (context) {
      return ElevatedButton(onPressed: () => showRatingSheet(context, match: _match), child: const Text('open'));
    }),
    overrides: [...competeBaseOverrides(), matchRepositoryProvider.overrideWithValue(repo)],
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return repo;
}

void main() {
  testWidgets('submit is disabled until a star is chosen', (tester) async {
    await _pump(tester);
    final button = tester.widget<FilledButton>(find.byKey(const Key('rating-submit')));
    expect(button.onPressed, isNull);
  });

  testWidgets('choosing 4 stars and submitting rates once and closes with the thanks message', (tester) async {
    final repo = await _pump(tester);
    await tester.tap(find.byKey(const Key('star-4')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('rating-submit')));
    await tester.pumpAndSettle();
    expect(repo.ratingCalls.single.stars, 4);
    expect(find.text('Thanks for rating!'), findsOneWidget);
    expect(find.byKey(const Key('rating-submit')), findsNothing);
  });

  testWidgets('already_rated shows its copy and keeps the sheet open', (tester) async {
    final repo = await _pump(tester);
    repo.ratingResults.add(_apiEx('already_rated'));
    await tester.tap(find.byKey(const Key('star-5')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('rating-submit')));
    await tester.pumpAndSettle();
    expect(find.text("You've already rated this match."), findsOneWidget);
    expect(find.byKey(const Key('rating-submit')), findsOneWidget);
  });

  testWidgets('a network failure then retry reuses the key and the chosen star', (tester) async {
    final repo = await _pump(tester);
    repo.ratingResults.add(_apiEx('network', status: 0));
    await tester.tap(find.byKey(const Key('star-3')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('rating-submit')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('rating-submit')));
    await tester.pumpAndSettle();
    expect(repo.ratingCalls, hasLength(2));
    expect(repo.ratingCalls[1].stars, 3);
    expect(repo.ratingCalls[1].key, repo.ratingCalls[0].key);
  });

  testWidgets('a server error then retry uses a new key', (tester) async {
    final repo = await _pump(tester);
    repo.ratingResults.add(_apiEx('already_rated'));
    await tester.tap(find.byKey(const Key('star-2')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('rating-submit')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('rating-submit')));
    await tester.pumpAndSettle();
    expect(repo.ratingCalls[1].key, isNot(repo.ratingCalls[0].key));
  });

  testWidgets('busy disables close', (tester) async {
    final repo = await _pump(tester);
    repo.ratingGate = Future.delayed(const Duration(milliseconds: 200));
    await tester.tap(find.byKey(const Key('star-5')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('rating-submit')));
    await tester.pump();
    expect(find.byType(BottomSheet), findsOneWidget);
    await tester.pumpAndSettle();
  });
}
