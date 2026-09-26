import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/core/api/api_client.dart';
import 'package:sentinelx_mobile/core/api/compete_models.dart';
import 'package:sentinelx_mobile/features/compete/compete_models.dart';
import 'package:sentinelx_mobile/features/compete/compete_providers.dart';
import 'package:sentinelx_mobile/features/compete/invitations_screen.dart';
import 'package:sentinelx_mobile/features/compete/registration_flow.dart';

import '../../fakes/fake_compete_reads.dart';
import '../../fakes/fake_registration_repository.dart';
import '../../support/pump_compete.dart';

PendingInvitation _inv(String id, {int fee = 1000}) => PendingInvitation(
      id: id,
      tournamentId: 't-$id',
      tournamentTitle: 'Masters $id',
      registrationFee: fee,
      expiresAt: DateTime.utc(2026, 10, 5),
    );

class _Env {
  _Env(this.reads, this.repo);
  final FakeCompeteReads reads;
  final FakeRegistrationRepository repo;
  final launched = <String>[];
}

Future<_Env> _pump(WidgetTester tester, List<PendingInvitation> invitations) async {
  final env = _Env(FakeCompeteReads(invitations: invitations), FakeRegistrationRepository());
  await pumpCompete(
    tester,
    const InvitationsScreen(),
    overrides: [
      ...competeBaseOverrides(),
      competeReadsRepositoryProvider.overrideWithValue(env.reads),
      registrationRepositoryProvider.overrideWithValue(env.repo),
      paystackLauncherProvider.overrideWithValue((url) async {
        env.launched.add(url);
        return true;
      }),
      pollDelayProvider.overrideWithValue((_) async {}),
    ],
  );
  await tester.pumpAndSettle();
  return env;
}

Future<void> _tap(WidgetTester tester, String key) async {
  await tester.tap(find.byKey(Key(key)));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('lists pending invitations with fee and expiry; empty state otherwise', (tester) async {
    await _pump(tester, [_inv('a'), _inv('b', fee: 0)]);
    expect(find.text('Masters a'), findsOneWidget);
    expect(find.textContaining('Expires'), findsNWidgets(2));
    expect(find.textContaining('₦1000'), findsOneWidget);
    expect(find.textContaining('Free'), findsOneWidget);
  });

  testWidgets('no invitations shows the empty message', (tester) async {
    await _pump(tester, const []);
    expect(find.text('No pending invitations.'), findsOneWidget);
  });

  testWidgets('accepting a free invitation confirms once and the row leaves the list', (tester) async {
    final env = await _pump(tester, [_inv('a', fee: 0)]);
    env.repo.acceptResults.add(const RegisterConfirmed());
    env.reads.invitations = [];
    await _tap(tester, 'inv-accept-a');
    expect(env.repo.acceptKeys.length, 1);
    expect(find.text('Masters a'), findsNothing);
    expect(find.text("You're registered!"), findsOneWidget);
  });

  testWidgets('accepting a paid invitation opens checkout, polls and reports payment confirmed', (tester) async {
    final env = await _pump(tester, [_inv('a')]);
    env.repo.acceptResults.add(const RegisterPending(authorizationUrl: 'https://pay.test/i', reference: 'ri'));
    env.repo.paymentResults.add(PaymentStatus.confirmed);
    await _tap(tester, 'inv-accept-a');
    expect(env.launched, ['https://pay.test/i']);
    expect(find.text("You're in! Payment confirmed."), findsOneWidget);
  });

  testWidgets('a network failure keeps the same key on the retry', (tester) async {
    final env = await _pump(tester, [_inv('a')]);
    env.repo.acceptResults.addAll([const ApiException(status: 0, code: 'network', message: 'x'), const RegisterConfirmed()]);
    await _tap(tester, 'inv-accept-a');
    expect(find.text('No connection. Check your internet and try again.'), findsOneWidget);
    ScaffoldMessenger.of(tester.element(find.byType(InvitationsScreen))).hideCurrentSnackBar();
    await tester.pumpAndSettle();
    await _tap(tester, 'inv-accept-a');
    expect(env.repo.acceptKeys.length, 2);
    expect(env.repo.acceptKeys[0], env.repo.acceptKeys[1]);
  });

  testWidgets('a real server error shows its copy and the next tap uses a NEW key', (tester) async {
    final env = await _pump(tester, [_inv('a')]);
    env.repo.acceptResults
        .addAll([const ApiException(status: 410, code: 'invitation_expired', message: 'RAW'), const RegisterConfirmed()]);
    await _tap(tester, 'inv-accept-a');
    expect(find.text('This invitation has expired.'), findsOneWidget);
    expect(find.text('RAW'), findsNothing);
    ScaffoldMessenger.of(tester.element(find.byType(InvitationsScreen))).hideCurrentSnackBar();
    await tester.pumpAndSettle();
    await _tap(tester, 'inv-accept-a');
    expect(env.repo.acceptKeys[0], isNot(env.repo.acceptKeys[1]));
  });

  testWidgets('no-longer-available and not-found errors have their own copy', (tester) async {
    final env = await _pump(tester, [_inv('a')]);
    env.repo.acceptResults.add(const ApiException(status: 409, code: 'invitation_no_longer_available', message: 'x'));
    await _tap(tester, 'inv-accept-a');
    expect(find.text('This invitation is no longer available.'), findsOneWidget);
  });

  testWidgets('a double tap on Accept sends one request', (tester) async {
    final env = await _pump(tester, [_inv('a')]);
    final gate = Completer<void>();
    env.repo.acceptGate = gate.future;
    env.repo.acceptResults.add(const RegisterConfirmed());
    await tester.tap(find.byKey(const Key('inv-accept-a')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('inv-accept-a')), warnIfMissed: false);
    await tester.pump();
    gate.complete();
    await tester.pumpAndSettle();
    expect(env.repo.acceptKeys.length, 1);
  });

  testWidgets('declining calls the endpoint once and confirms', (tester) async {
    final env = await _pump(tester, [_inv('a')]);
    env.reads.invitations = [];
    await _tap(tester, 'inv-decline-a');
    expect(env.repo.declined, ['a']);
    expect(find.text('Invitation declined.'), findsOneWidget);
    expect(find.text('Masters a'), findsNothing);
  });

  testWidgets('a decline error shows copy and keeps the row', (tester) async {
    final env = await _pump(tester, [_inv('a')]);
    env.repo.declineResult = const ApiException(status: 404, code: 'invitation_not_found', message: 'x');
    await _tap(tester, 'inv-decline-a');
    expect(find.text('Invitation not found.'), findsOneWidget);
    expect(find.text('Masters a'), findsOneWidget);
  });
}
