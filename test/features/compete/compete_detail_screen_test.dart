import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/core/api/compete_models.dart';
import 'package:sentinelx_mobile/core/api/match_models.dart';
import 'package:sentinelx_mobile/features/compete/compete_detail_screen.dart';
import 'package:sentinelx_mobile/features/compete/compete_models.dart';
import 'package:sentinelx_mobile/features/compete/compete_providers.dart';
import 'package:sentinelx_mobile/features/compete/registration_flow.dart';
import 'package:sentinelx_mobile/features/match/match_providers.dart';

import '../../fakes/fake_compete_reads.dart';
import '../../fakes/fake_match_repositories.dart';
import '../../fakes/fake_registration_repository.dart';
import '../../support/compete_fixtures.dart';
import '../../support/pump_compete.dart';

class _Env {
  _Env(this.reads, this.repo);
  final FakeCompeteReads reads;
  final FakeRegistrationRepository repo;
  final matchRepo = FakeMatchRepository();
  int logins = 0;
  int invitations = 0;
  final brackets = <String>[];
}

RegistrationState _state(RegView v, {bool waiver = false, int fee = 500}) => RegistrationState(
      view: v,
      feeNaira: fee,
      hasWaiver: waiver,
      coinDiscountEligible: false,
      agreementRequired: true,
    );

Future<_Env> _pump(
  WidgetTester tester, {
  Object? state,
  Map<String, dynamic>? row,
  String? pendingReference,
  bool signedOut = false,
  bool readsFail = false,
  String tournamentId = 't1',
  TournamentResults? results,
  bool resultsFail = false,
}) async {
  final reads = FakeCompeteReads(
    tournaments: [CompeteTournament.fromJson(row ?? tournamentRow())],
    pendingReference: pendingReference,
    failAll: readsFail,
  );
  final repo = FakeRegistrationRepository()..stateResult = state ?? _state(RegView.canRegister);
  final env = _Env(reads, repo);
  if (results != null) env.matchRepo.resultsView = results;
  if (resultsFail) env.matchRepo.resultsError = Exception('boom');
  await pumpCompete(
    tester,
    CompeteDetailScreen(
      tournamentId: tournamentId,
      onViewBracket: env.brackets.add,
      onLogin: () => env.logins++,
      onNeedsUsername: () {},
      onViewInvitations: () => env.invitations++,
    ),
    overrides: [
      ...competeBaseOverrides(signedOut: signedOut),
      competeReadsRepositoryProvider.overrideWithValue(reads),
      registrationRepositoryProvider.overrideWithValue(repo),
      matchRepositoryProvider.overrideWithValue(env.matchRepo),
      paystackLauncherProvider.overrideWithValue((_) async => true),
      pollDelayProvider.overrideWithValue((_) async {}),
    ],
  );
  await tester.pumpAndSettle();
  return env;
}

void main() {
  final cases = <({String name, RegView view, String? text, bool cta, String? ctaLabel})>[
    (name: 'guest', view: RegView.guest, text: null, cta: true, ctaLabel: 'Log in to register'),
    (name: 'can_register', view: RegView.canRegister, text: null, cta: true, ctaLabel: 'Register'),
    (name: 'complete_payment', view: RegView.completePayment, text: null, cta: true, ctaLabel: 'Resume payment'),
    (name: 'registered', view: RegView.registered, text: "You're registered.", cta: false, ctaLabel: null),
    (name: 'waitlisted', view: RegView.waitlisted, text: "You're on the waitlist.", cta: false, ctaLabel: null),
    (name: 'full', view: RegView.full, text: 'This tournament is full.', cta: false, ctaLabel: null),
    (name: 'closed', view: RegView.closed, text: null, cta: true, ctaLabel: 'Join waitlist'),
    (name: 'ended', view: RegView.ended, text: 'This tournament has ended.', cta: false, ctaLabel: null),
    (name: 'invitation_only', view: RegView.invitationOnly, text: 'This tournament is invitation-only.', cta: false, ctaLabel: null),
  ];

  for (final c in cases) {
    testWidgets('view ${c.name} renders exactly its own call to action', (tester) async {
      await _pump(tester, state: _state(c.view));
      expect(find.byKey(const Key('reg-cta')).evaluate().isNotEmpty, c.cta);
      if (c.ctaLabel != null) {
        expect(find.descendant(of: find.byKey(const Key('reg-cta')), matching: find.text(c.ctaLabel!)), findsOneWidget);
      }
      if (c.text != null) expect(find.text(c.text!), findsOneWidget);
    });
  }

  testWidgets('full never offers the waitlist (the server rejects it until registration closes)', (tester) async {
    await _pump(tester, state: _state(RegView.full));
    expect(find.text('Join waitlist'), findsNothing);
  });

  testWidgets('invitation-only has no register button but links to invitations', (tester) async {
    final env = await _pump(tester, state: _state(RegView.invitationOnly));
    expect(find.text('Register'), findsNothing);
    await tester.ensureVisible(find.text('View my invitations'));
    await tester.tap(find.text('View my invitations'));
    expect(env.invitations, 1);
  });

  testWidgets('guest tap asks to log in and never registers', (tester) async {
    final env = await _pump(tester, state: _state(RegView.guest), signedOut: true);
    await tester.ensureVisible(find.byKey(const Key('reg-cta')));
    await tester.tap(find.byKey(const Key('reg-cta')));
    await tester.pumpAndSettle();
    expect(env.logins, 1);
    expect(env.repo.registerKeys, isEmpty);
  });

  testWidgets('can_register opens the registration sheet; a waiver is announced', (tester) async {
    await _pump(tester, state: _state(RegView.canRegister, waiver: true));
    expect(find.text('Free entry — waiver applied'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('reg-cta')));
    await tester.tap(find.byKey(const Key('reg-cta')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('reg-submit')), findsOneWidget);
  });

  testWidgets('closed opens the sheet in waitlist mode', (tester) async {
    await _pump(tester, state: _state(RegView.closed));
    await tester.ensureVisible(find.byKey(const Key('reg-cta')));
    await tester.tap(find.byKey(const Key('reg-cta')));
    await tester.pumpAndSettle();
    expect(find.descendant(of: find.byKey(const Key('reg-submit')), matching: find.text('Join waitlist')), findsOneWidget);
    expect(find.text("Don't use coins"), findsNothing);
  });

  group('resume payment', () {
    testWidgets('an already-paid pending reference refreshes state instead of opening the sheet', (tester) async {
      final env = await _pump(tester, state: _state(RegView.completePayment), pendingReference: 'r1');
      env.repo.paymentResults.add(PaymentStatus.confirmed);
      final before = env.repo.stateCalls;
      await tester.ensureVisible(find.byKey(const Key('reg-cta')));
      await tester.tap(find.byKey(const Key('reg-cta')));
      await tester.pumpAndSettle();
      expect(env.repo.paymentChecks, ['r1']);
      expect(find.byKey(const Key('reg-submit')), findsNothing);
      expect(env.repo.stateCalls, greaterThan(before));
    });

    testWidgets('an unpaid reference opens the sheet', (tester) async {
      final env = await _pump(tester, state: _state(RegView.completePayment), pendingReference: 'r1');
      env.repo.paymentResults.add(PaymentStatus.notSuccessful);
      await tester.ensureVisible(find.byKey(const Key('reg-cta')));
      await tester.tap(find.byKey(const Key('reg-cta')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('reg-submit')), findsOneWidget);
    });

    testWidgets('a failing status check still opens the sheet', (tester) async {
      final env = await _pump(tester, state: _state(RegView.completePayment), pendingReference: 'r1');
      env.repo.paymentResults.add(Exception('offline'));
      await tester.ensureVisible(find.byKey(const Key('reg-cta')));
      await tester.tap(find.byKey(const Key('reg-cta')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('reg-submit')), findsOneWidget);
    });

    testWidgets('no stored reference skips the check and opens the sheet', (tester) async {
      final env = await _pump(tester, state: _state(RegView.completePayment));
      await tester.ensureVisible(find.byKey(const Key('reg-cta')));
      await tester.tap(find.byKey(const Key('reg-cta')));
      await tester.pumpAndSettle();
      expect(env.repo.paymentChecks, isEmpty);
      expect(find.byKey(const Key('reg-submit')), findsOneWidget);
    });
  });

  testWidgets('a registration-state failure (or unknown view) keeps the tournament visible with a retry', (tester) async {
    await _pump(tester, state: const FormatException('Unknown registration view: x'));
    expect(find.text('FC Mobile Cup'), findsOneWidget);
    expect(find.byKey(const Key('reg-cta')), findsNothing);
    expect(find.text('Try again'), findsOneWidget);
    expect(find.textContaining('FormatException'), findsNothing);
  });

  testWidgets('a tournament load failure shows friendly copy', (tester) async {
    await _pump(tester, readsFail: true);
    expect(find.text("Couldn't load this. Check your connection and try again."), findsOneWidget);
    expect(find.textContaining('Exception'), findsNothing);
  });

  testWidgets('null rules, null max players and a zero fee render cleanly', (tester) async {
    await _pump(tester, row: tournamentRow(rules: null, maxPlayers: null, registrationFee: 0), state: _state(RegView.canRegister, fee: 0));
    expect(find.text('Rules'), findsNothing);
    expect(find.textContaining('players max'), findsNothing);
    expect(find.textContaining('Free'), findsWidgets);
  });

  testWidgets('shows rules and max players when present', (tester) async {
    await _pump(tester);
    expect(find.text('Rules'), findsOneWidget);
    expect(find.text('16 players max'), findsOneWidget);
  });

  testWidgets('the bracket button reports a tap', (tester) async {
    final env = await _pump(tester);
    await tester.ensureVisible(find.byKey(const Key('view-bracket-button')));
    await tester.tap(find.byKey(const Key('view-bracket-button')));
    expect(env.brackets, ['t1']);
  });

  testWidgets('opened by web slug, the bracket button still passes the resolved tournament id', (tester) async {
    final env = await _pump(tester, tournamentId: 'fc-mobile-cup');
    await tester.ensureVisible(find.byKey(const Key('view-bracket-button')));
    await tester.tap(find.byKey(const Key('view-bracket-button')));
    expect(env.brackets, ['t1']);
  });

  testWidgets('a 300-character description fits 375px without overflow', (tester) async {
    await _pump(tester, row: tournamentRow(description: 'D' * 300));
    expect(tester.takeException(), isNull);
  });

  testWidgets('a completed tournament with a champion shows the champion card', (tester) async {
    await _pump(
      tester,
      row: tournamentRow(status: 'completed'),
      results: TournamentResults.fromJson({
        'champion': {
          'tournamentId': 't1',
          'slug': 'fc-mobile-cup',
          'title': 'FC Mobile Cup',
          'tournamentType': 'open',
          'gameId': 'g1',
          'gameName': 'FC Mobile',
          'date': null,
          'prizePool': 8000,
          'champion': {'id': 'p1', 'name': 'Ada'},
          'runnerUp': {'id': 'p2', 'name': 'Bola'},
          'championAvatarUrl': null,
          'seasonName': null,
        },
        'noWinner': false,
      }),
    );
    expect(find.byKey(const Key('champion-card')), findsOneWidget);
    expect(find.descendant(of: find.byKey(const Key('champion-card')), matching: find.text('Ada')), findsOneWidget);
    expect(find.descendant(of: find.byKey(const Key('champion-card')), matching: find.textContaining('Bola')), findsOneWidget);
  });

  testWidgets('a completed tournament closed without a winner says so', (tester) async {
    await _pump(
      tester,
      row: tournamentRow(status: 'completed'),
      results: const TournamentResults(champion: null, noWinner: true),
    );
    expect(find.text('This tournament closed without a winner.'), findsOneWidget);
    expect(find.byKey(const Key('champion-card')), findsNothing);
  });

  testWidgets('a results failure never blocks the page', (tester) async {
    await _pump(tester, row: tournamentRow(status: 'completed'), resultsFail: true);
    expect(find.text('FC Mobile Cup'), findsOneWidget);
    expect(find.byKey(const Key('champion-card')), findsNothing);
    expect(find.textContaining('Exception'), findsNothing);
  });

  testWidgets('the results endpoint is not called for a tournament that is not completed', (tester) async {
    final env = await _pump(tester);
    expect(env.matchRepo.resultsCalls, 0);
  });
}
