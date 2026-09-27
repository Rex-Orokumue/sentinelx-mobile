import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/core/api/api_client.dart';
import 'package:sentinelx_mobile/core/api/match_models.dart';
import 'package:sentinelx_mobile/features/match/match_providers.dart';
import 'package:sentinelx_mobile/features/match/match_reads_repository.dart';
import 'package:sentinelx_mobile/features/match/wager_sheet.dart';

import '../../fakes/fake_match_repositories.dart';
import '../../support/match_fixtures.dart';
import '../../support/pump_compete.dart';

ApiException _apiEx(String code, {int status = 409}) => ApiException(status: status, code: code, message: 'x');

final _match = MatchInfo(
  id: 'm1',
  tournamentId: 't1',
  round: 'quarter_final',
  status: 'scheduled',
  scheduledAt: null,
  isFullDay: false,
  playerAId: 'p1',
  playerBId: 'p2',
  nameA: 'Ada',
  nameB: 'Bola',
);

Future<FakeMatchRepository> _pump(WidgetTester tester, {MatchCentre? centre}) async {
  final repo = FakeMatchRepository()..centreView = centre ?? MatchCentre.fromJson(centreJson());
  await pumpCompete(
    tester,
    Builder(builder: (context) {
      return ElevatedButton(
        onPressed: () => showWagerSheet(context, match: _match, centre: repo.centreView),
        child: const Text('open'),
      );
    }),
    overrides: [
      ...competeBaseOverrides(),
      matchRepositoryProvider.overrideWithValue(repo),
    ],
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return repo;
}

Future<void> _pick(WidgetTester tester, String name) async {
  await tester.tap(find.text(name));
  await tester.pump();
}

void main() {
  testWidgets('stake below min blocks the call and shows range copy', (tester) async {
    final repo = await _pump(tester);
    await _pick(tester, 'Ada');
    await tester.enterText(find.byKey(const Key('wager-stake')), '1');
    await tester.tap(find.text('Place wager'));
    await tester.pumpAndSettle();
    expect(find.text('Between 10 and 1000 coins.'), findsOneWidget);
    expect(repo.wagerCalls, isEmpty);
  });

  testWidgets('stake above max blocks the call', (tester) async {
    final repo = await _pump(tester);
    await _pick(tester, 'Ada');
    await tester.enterText(find.byKey(const Key('wager-stake')), '1001');
    await tester.tap(find.text('Place wager'));
    await tester.pumpAndSettle();
    expect(find.text('Between 10 and 1000 coins.'), findsOneWidget);
    expect(repo.wagerCalls, isEmpty);
  });

  testWidgets('non-numeric stake blocks the call', (tester) async {
    final repo = await _pump(tester);
    await _pick(tester, 'Ada');
    await tester.enterText(find.byKey(const Key('wager-stake')), 'abc');
    await tester.tap(find.text('Place wager'));
    await tester.pumpAndSettle();
    expect(find.text('Between 10 and 1000 coins.'), findsOneWidget);
    expect(repo.wagerCalls, isEmpty);
  });

  testWidgets('no pick blocks the call', (tester) async {
    final repo = await _pump(tester);
    await tester.enterText(find.byKey(const Key('wager-stake')), '50');
    await tester.tap(find.text('Place wager'));
    await tester.pumpAndSettle();
    expect(repo.wagerCalls, isEmpty);
  });

  testWidgets('a valid wager calls wager once, closes and shows Wager placed.', (tester) async {
    final repo = await _pump(tester);
    await _pick(tester, 'Ada');
    await tester.enterText(find.byKey(const Key('wager-stake')), '50');
    await tester.tap(find.text('Place wager'));
    await tester.pumpAndSettle();
    expect(repo.wagerCalls, hasLength(1));
    expect(repo.wagerCalls.single.pickPlayerId, 'p1');
    expect(repo.wagerCalls.single.stakeCoins, 50);
    expect(find.text('Wager placed.'), findsOneWidget);
    expect(find.text('Place wager'), findsNothing); // sheet closed
  });

  testWidgets('a network failure then a second tap reuses the same key', (tester) async {
    final repo = await _pump(tester);
    repo.wagerResults.add(_apiEx('network', status: 0));
    await _pick(tester, 'Ada');
    await tester.enterText(find.byKey(const Key('wager-stake')), '50');
    await tester.tap(find.text('Place wager'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Place wager'));
    await tester.pumpAndSettle();
    expect(repo.wagerCalls, hasLength(2));
    expect(repo.wagerCalls[1].key, repo.wagerCalls[0].key);
  });

  testWidgets('a network failure, then editing the stake before retrying mints a new key (the payload changed)', (tester) async {
    final repo = await _pump(tester);
    repo.wagerResults.add(_apiEx('network', status: 0));
    await _pick(tester, 'Ada');
    await tester.enterText(find.byKey(const Key('wager-stake')), '50');
    await tester.tap(find.text('Place wager'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('wager-stake')), '75');
    await tester.tap(find.text('Place wager'));
    await tester.pumpAndSettle();
    expect(repo.wagerCalls, hasLength(2));
    expect(repo.wagerCalls[1].stakeCoins, 75);
    expect(repo.wagerCalls[1].key, isNot(repo.wagerCalls[0].key));
  });

  testWidgets('insufficient_coins shows its copy and the next tap uses a new key', (tester) async {
    final repo = await _pump(tester);
    repo.wagerResults.add(_apiEx('insufficient_coins'));
    await _pick(tester, 'Ada');
    await tester.enterText(find.byKey(const Key('wager-stake')), '50');
    await tester.tap(find.text('Place wager'));
    await tester.pumpAndSettle();
    expect(find.text('Not enough SX Coins for this stake.'), findsOneWidget);
    await tester.tap(find.text('Place wager'));
    await tester.pumpAndSettle();
    expect(repo.wagerCalls[1].key, isNot(repo.wagerCalls[0].key));
  });

  testWidgets('window_closed shows its copy', (tester) async {
    final repo = await _pump(tester);
    repo.wagerResults.add(_apiEx('window_closed'));
    await _pick(tester, 'Ada');
    await tester.enterText(find.byKey(const Key('wager-stake')), '50');
    await tester.tap(find.text('Place wager'));
    await tester.pumpAndSettle();
    expect(find.text('Wagering is closed for this match.'), findsOneWidget);
  });

  testWidgets('an existing wager pre-fills pick and stake', (tester) async {
    await _pump(tester, centre: MatchCentre.fromJson(centreJson(myPick: 'p2', myStake: 75)));
    expect(find.text('75'), findsOneWidget);
    expect(find.text('Change wager'), findsOneWidget);
  });

  testWidgets('the sheet cannot be closed while busy', (tester) async {
    final repo = await _pump(tester);
    repo.wagerGate = Future.delayed(const Duration(milliseconds: 200));
    await _pick(tester, 'Ada');
    await tester.enterText(find.byKey(const Key('wager-stake')), '50');
    await tester.tap(find.text('Place wager'));
    await tester.pump();
    expect(find.text('Place wager'), findsOneWidget); // still open mid-flight
    await tester.pumpAndSettle();
  });

  testWidgets('the sheet cannot be dragged closed mid-flight (drag bypasses PopScope)', (tester) async {
    final repo = await _pump(tester);
    repo.wagerGate = Future.delayed(const Duration(milliseconds: 200));
    await _pick(tester, 'Ada');
    await tester.enterText(find.byKey(const Key('wager-stake')), '50');
    await tester.tap(find.text('Place wager'));
    await tester.pump();
    await tester.fling(find.byType(BottomSheet), const Offset(0, 400), 1000);
    await tester.pump();
    expect(find.text('Place wager'), findsOneWidget);
    await tester.pumpAndSettle();
  });
}
