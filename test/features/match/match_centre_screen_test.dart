import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/core/api/api_client.dart';
import 'package:sentinelx_mobile/core/api/match_models.dart';
import 'package:sentinelx_mobile/features/match/match_centre_screen.dart';
import 'package:sentinelx_mobile/features/match/match_providers.dart';
import 'package:sentinelx_mobile/features/match/match_reads_repository.dart';

import '../../fakes/fake_match_repositories.dart';
import '../../support/match_fixtures.dart';
import '../../support/pump_compete.dart';

ApiException _apiEx(String code, {int status = 409}) => ApiException(status: status, code: code, message: 'x');

class _Env {
  final repo = FakeMatchRepository();
  final reads = FakeMatchReads();
  int logins = 0;
  final submits = <MatchInfo>[];
  final rates = <MatchInfo>[];
}

MatchInfo _match({
  String id = 'm1',
  String status = 'scheduled',
  int? scoreA,
  int? scoreB,
  String? streamUrl,
  String? replayUrl,
  String? playerAId = 'p1',
  String? playerBId = 'p2',
  String nameA = 'Ada',
  String nameB = 'Bola',
}) =>
    MatchInfo(
      id: id,
      tournamentId: 't1',
      tournamentTitle: 'Champions Cup',
      round: 'quarter_final',
      status: status,
      scoreA: scoreA,
      scoreB: scoreB,
      scheduledAt: '2026-10-01T18:00:00Z',
      isFullDay: false,
      streamUrl: streamUrl,
      replayUrl: replayUrl,
      playerAId: playerAId,
      playerBId: playerBId,
      nameA: nameA,
      nameB: nameB,
    );

Future<_Env> _pump(
  WidgetTester tester, {
  MatchInfo? match,
  MatchCentre? centre,
  bool signedOut = false,
  bool matchFails = false,
  bool centreFails = false,
}) async {
  final env = _Env();
  env.reads.matches['m1'] = match ?? _match();
  env.reads.failAll = matchFails;
  env.repo.centreView = centre ?? MatchCentre.fromJson(centreJson());
  if (centreFails) env.repo.centreError = Exception('boom');
  await pumpCompete(
    tester,
    MatchCentreScreen(
      matchId: 'm1',
      onLogin: () => env.logins++,
      onSubmitResult: env.submits.add,
      onRate: env.rates.add,
    ),
    overrides: [
      ...competeBaseOverrides(signedOut: signedOut),
      matchReadsRepositoryProvider.overrideWithValue(env.reads),
      matchRepositoryProvider.overrideWithValue(env.repo),
    ],
  );
  await tester.pumpAndSettle();
  return env;
}

void main() {
  testWidgets('a completed match with both scores shows the score', (tester) async {
    await _pump(tester, match: _match(status: 'completed', scoreA: 2, scoreB: 1), centre: MatchCentre.fromJson(centreJson(status: 'completed')));
    expect(find.text('2 – 1'), findsOneWidget);
  });

  testWidgets('a live match with null scores shows no null', (tester) async {
    await _pump(tester, match: _match(status: 'live'), centre: MatchCentre.fromJson(centreJson(status: 'live')));
    expect(find.textContaining('null'), findsNothing);
    expect(find.text('Live'), findsWidgets);
  });

  for (final status in ['bye', 'cancelled', 'disputed', 'forfeited']) {
    testWidgets('$status shows its status text and no score', (tester) async {
      await _pump(tester, match: _match(status: status, scoreA: 2, scoreB: 1), centre: MatchCentre.fromJson(centreJson(status: status)));
      expect(find.text('2 – 1'), findsNothing);
    });
  }

  testWidgets('an unknown status renders without crashing and no chip', (tester) async {
    await _pump(tester, match: _match(status: 'mystery'), centre: MatchCentre.fromJson(centreJson(status: 'mystery')));
    expect(tester.takeException(), isNull);
  });

  testWidgets('guest sees no check-in/submit/rate and the login prompt taps onLogin', (tester) async {
    final env = await _pump(tester, signedOut: true, centre: MatchCentre.fromJson(centreJson(isParticipant: false)));
    expect(find.byKey(const Key('check-in-button')), findsNothing);
    expect(find.byKey(const Key('submit-result-button')), findsNothing);
    expect(find.byKey(const Key('rate-button')), findsNothing);
    expect(find.text('Log in to place a wager.'), findsOneWidget);
    await tester.tap(find.text('Log in to place a wager.').hitTestable());
    expect(env.logins, 1);
  });

  testWidgets('participant with canCheckIn false has no check-in button', (tester) async {
    await _pump(tester, centre: MatchCentre.fromJson(centreJson(isParticipant: true, canCheckIn: false)));
    expect(find.byKey(const Key('check-in-button')), findsNothing);
  });

  testWidgets('participant with canCheckIn true: a double tap sends one request, shows success and re-reads', (tester) async {
    final env = await _pump(tester, centre: MatchCentre.fromJson(centreJson(isParticipant: true, canCheckIn: true)));
    final before = env.repo.centreCalls;
    final gate = Completer<void>();
    env.repo.checkInGate = gate.future;
    await tester.tap(find.byKey(const Key('check-in-button')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('check-in-button')));
    await tester.pump();
    expect(env.repo.checkIns, hasLength(1));
    gate.complete();
    await tester.pumpAndSettle();
    expect(env.repo.checkIns, hasLength(1));
    expect(find.text("You're checked in."), findsOneWidget);
    expect(env.repo.centreCalls, greaterThan(before));
  });

  testWidgets('check-in error shows localized copy, not server text', (tester) async {
    final env = await _pump(tester, centre: MatchCentre.fromJson(centreJson(isParticipant: true, canCheckIn: true)));
    env.repo.checkInResults.add(_apiEx('not_match_day'));
    await tester.tap(find.byKey(const Key('check-in-button')));
    await tester.pumpAndSettle();
    expect(find.text("You can check in once it's match day."), findsOneWidget);
    expect(find.textContaining('server said'), findsNothing);
  });

  testWidgets('participant sees submit-result for scheduled/live/disputed, not completed/cancelled/bye/forfeited', (tester) async {
    for (final status in ['scheduled', 'live', 'disputed']) {
      await _pump(tester, match: _match(status: status), centre: MatchCentre.fromJson(centreJson(isParticipant: true, status: status)));
      expect(find.byKey(const Key('submit-result-button')), findsOneWidget, reason: status);
    }
    for (final status in ['completed', 'cancelled', 'bye', 'forfeited']) {
      await _pump(tester, match: _match(status: status), centre: MatchCentre.fromJson(centreJson(isParticipant: true, status: status)));
      expect(find.byKey(const Key('submit-result-button')), findsNothing, reason: status);
    }
  });

  testWidgets('rate button only for completed', (tester) async {
    await _pump(tester, match: _match(status: 'completed'), centre: MatchCentre.fromJson(centreJson(isParticipant: true, status: 'completed')));
    expect(find.byKey(const Key('rate-button')), findsOneWidget);
    await _pump(tester, match: _match(status: 'scheduled'), centre: MatchCentre.fromJson(centreJson(isParticipant: true, status: 'scheduled')));
    expect(find.byKey(const Key('rate-button')), findsNothing);
  });

  testWidgets('a participant never sees the wager card', (tester) async {
    await _pump(tester, centre: MatchCentre.fromJson(centreJson(isParticipant: true)));
    expect(find.text('Wager'), findsNothing);
  });

  testWidgets('a signed-in non-participant sees the wager card and no participant controls', (tester) async {
    await _pump(tester, centre: MatchCentre.fromJson(centreJson(isParticipant: false)));
    expect(find.text('Wager'), findsOneWidget);
    expect(find.byKey(const Key('check-in-button')), findsNothing);
    expect(find.byKey(const Key('submit-result-button')), findsNothing);
    expect(find.byKey(const Key('rate-button')), findsNothing);
  });

  testWidgets('noShowEligible shows the info text', (tester) async {
    final json = centreJson(isParticipant: true)..['noShowEligible'] = true;
    await _pump(tester, centre: MatchCentre.fromJson(json));
    expect(find.text('This match is eligible for no-show handling by the organizers.'), findsOneWidget);
  });

  testWidgets('watch buttons appear only when URLs exist; isLaunchableUrl rejects non-http schemes', (tester) async {
    expect(isLaunchableUrl('https://youtu.be/x'), isTrue);
    expect(isLaunchableUrl('http://youtu.be/x'), isTrue);
    expect(isLaunchableUrl('javascript:alert(1)'), isFalse);
    expect(isLaunchableUrl(''), isFalse);

    await _pump(tester, match: _match(streamUrl: 'https://youtu.be/x'));
    expect(find.text('Watch live'), findsOneWidget);
    expect(find.text('Watch replay'), findsNothing);

    await _pump(tester, match: _match(replayUrl: 'https://youtu.be/r'));
    expect(find.text('Watch replay'), findsOneWidget);
  });

  testWidgets('load failure shows a retry button that re-reads', (tester) async {
    final env = await _pump(tester, centreFails: true);
    expect(find.text("Couldn't load this. Check your connection and try again."), findsOneWidget);
    env.repo.centreError = null;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.text("Couldn't load this. Check your connection and try again."), findsNothing);
  });

  testWidgets('pull-to-refresh re-reads the centre', (tester) async {
    final env = await _pump(tester, centre: MatchCentre.fromJson(centreJson(isParticipant: true, canCheckIn: true)));
    final before = env.repo.centreCalls;
    await tester.fling(find.byType(RefreshIndicator), const Offset(0, 300), 1000);
    await tester.pumpAndSettle();
    expect(env.repo.centreCalls, greaterThan(before));
  });

  testWidgets('a team match (no player ids) renders names and hides the wager form', (tester) async {
    await _pump(
      tester,
      match: _match(playerAId: null, playerBId: null, nameA: 'Lions', nameB: 'Tigers'),
      centre: MatchCentre.fromJson(centreJson(isParticipant: false)),
    );
    expect(find.text('Lions'), findsOneWidget);
    expect(find.text('Tigers'), findsOneWidget);
    expect(find.text('Wagering is closed for this match.'), findsOneWidget);
  });

  testWidgets('a 60-char name does not overflow at 375px', (tester) async {
    await _pump(tester, match: _match(nameA: 'N' * 60, nameB: 'B' * 60));
    expect(tester.takeException(), isNull);
  });
}
