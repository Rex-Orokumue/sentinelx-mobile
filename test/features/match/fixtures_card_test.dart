import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/core/api/match_models.dart';
import 'package:sentinelx_mobile/features/match/fixtures_card.dart';
import 'package:sentinelx_mobile/features/match/match_providers.dart';

import '../../fakes/fake_match_repositories.dart';
import '../../support/match_fixtures.dart';
import '../../support/pump_compete.dart';

class _Env {
  final repo = FakeMatchRepository();
  final gone = <String>[];
  final opened = <(String, NextLobby)>[];
}

Future<_Env> _pump(
  WidgetTester tester, {
  MeSummary? summary,
  Object? error,
  bool signedOut = false,
}) async {
  final env = _Env();
  env.repo.summaryView = summary ?? MeSummary.fromJson(summaryJson());
  env.repo.summaryError = error;
  await pumpCompete(
    tester,
    FixturesCard(onGoTo: env.gone.add, onOpenLobby: (id, lobby) => env.opened.add((id, lobby))),
    overrides: [
      ...competeBaseOverrides(signedOut: signedOut),
      matchRepositoryProvider.overrideWithValue(env.repo),
    ],
  );
  await tester.pumpAndSettle();
  return env;
}

void main() {
  testWidgets('renders nothing when signed out', (tester) async {
    await _pump(tester, signedOut: true);
    expect(find.text('Your fixtures'), findsNothing);
  });

  testWidgets('renders nothing on a summary error, and no exception text', (tester) async {
    await _pump(tester, error: Exception('boom'));
    expect(find.text('Your fixtures'), findsNothing);
    expect(find.textContaining('Exception'), findsNothing);
  });

  testWidgets('renders nothing when the summary is entirely empty', (tester) async {
    await _pump(tester, summary: MeSummary.fromJson(summaryJson()));
    expect(find.text('Your fixtures'), findsNothing);
  });

  testWidgets('a next match renders and taps to /matches/<id>; a submit prompt shows when submittable', (tester) async {
    final env = await _pump(tester, summary: MeSummary.fromJson(summaryJson(nextMatch: nextMatchJson(id: 'm1'), hasSubmittableMatch: true)));
    expect(find.text('Your fixtures'), findsOneWidget);
    expect(find.text('Next match'), findsOneWidget);
    expect(find.text('You have a match awaiting your result.'), findsOneWidget);
    await tester.tap(find.byKey(const Key('next-match-tile')));
    expect(env.gone, ['/matches/m1']);
  });

  testWidgets('a next lobby not submitted taps to onOpenLobby', (tester) async {
    final env = await _pump(tester, summary: MeSummary.fromJson(summaryJson(nextLobby: nextLobbyJson(lobbyId: 'l1'))));
    expect(find.text('Next lobby'), findsOneWidget);
    expect(find.text('Room details are ready'), findsOneWidget);
    await tester.tap(find.byKey(const Key('next-lobby-tile')));
    expect(env.opened.single.$1, 'l1');
  });

  testWidgets('a submitted lobby shows the submitted text and is not tappable', (tester) async {
    final env = await _pump(tester, summary: MeSummary.fromJson(summaryJson(nextLobby: nextLobbyJson(lobbyId: 'l1', submitted: true))));
    expect(find.text('Result submitted'), findsOneWidget);
    await tester.tap(find.byKey(const Key('next-lobby-tile')));
    expect(env.opened, isEmpty);
  });

  testWidgets('qualified with and without awaiting; eliminated', (tester) async {
    await _pump(tester, summary: MeSummary.fromJson(summaryJson(banners: [
      {'kind': 'qualified', 'tournamentTitle': 'Cup', 'tournamentSlug': 'cup', 'round': 'semi_final', 'awaitingOpponent': true},
    ])));
    expect(find.text('You qualified in Cup (semi final).'), findsOneWidget);
    expect(find.text('Waiting for your opponent.'), findsOneWidget);

    await _pump(tester, summary: MeSummary.fromJson(summaryJson(banners: [
      {'kind': 'qualified', 'tournamentTitle': 'Cup', 'tournamentSlug': 'cup', 'round': 'final', 'awaitingOpponent': false},
    ])));
    expect(find.text('Waiting for your opponent.'), findsNothing);

    await _pump(tester, summary: MeSummary.fromJson(summaryJson(banners: [
      {'kind': 'eliminated', 'tournamentTitle': 'Cup', 'tournamentSlug': 'cup', 'round': 'quarter_final'},
    ])));
    expect(find.text('You were eliminated from Cup (quarter final).'), findsOneWidget);
  });

  testWidgets('a pending registration taps to /tournaments/<slug>; paid ones are not listed', (tester) async {
    final env = await _pump(tester, summary: MeSummary.fromJson(summaryJson(registrations: [
      {'id': 'r1', 'paymentStatus': 'pending', 'tournamentTitle': 'Cup', 'tournamentSlug': 'cup'},
      {'id': 'r2', 'paymentStatus': 'paid', 'tournamentTitle': 'Paid Cup', 'tournamentSlug': 'paid-cup'},
    ])));
    expect(find.text('Payment pending'), findsOneWidget);
    expect(find.text('Paid Cup'), findsNothing);
    await tester.tap(find.byKey(const Key('registration-r1')));
    expect(env.gone, ['/tournaments/cup']);
  });

  testWidgets('a null schedule shows To be announced', (tester) async {
    final json = nextMatchJson()..['scheduledAt'] = null;
    await _pump(tester, summary: MeSummary.fromJson(summaryJson(nextMatch: json)));
    expect(find.text('To be announced'), findsOneWidget);
  });

  testWidgets('a 60-char tournament title does not overflow at 375px', (tester) async {
    final json = nextMatchJson()..['tournamentTitle'] = 'T' * 60;
    await _pump(tester, summary: MeSummary.fromJson(summaryJson(nextMatch: json)));
    expect(tester.takeException(), isNull);
  });
}
