import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/core/api/api_client.dart';
import 'package:sentinelx_mobile/core/api/match_models.dart';
import 'package:sentinelx_mobile/features/match/evidence.dart';
import 'package:sentinelx_mobile/features/match/lobby_result_screen.dart';
import 'package:sentinelx_mobile/features/match/match_providers.dart';

import '../../fakes/fake_evidence.dart';
import '../../fakes/fake_match_repositories.dart';
import '../../support/match_fixtures.dart';
import '../../support/pump_compete.dart';

ApiException _apiEx(String code, {int status = 409}) => ApiException(status: status, code: code, message: 'x');

PickedImage _img(String name) => PickedImage(name: name, bytes: Uint8List.fromList([1, 2, 3]));

class _Env {
  final repo = FakeMatchRepository();
  final uploader = FakeUploader();
  final picker = FakePicker();
}

Future<_Env> _pump(WidgetTester tester, {bool signedOut = false, NextLobby? lobby}) async {
  final env = _Env();
  await pumpCompete(
    tester,
    // A watcher keeps the autoDispose meSummaryProvider alive so the test can observe the
    // post-submit `ref.invalidate(meSummaryProvider)` actually re-reading the summary.
    Consumer(builder: (context, ref, _) {
      ref.watch(meSummaryProvider);
      return LobbyResultScreen(lobbyId: 'l1', lobby: lobby);
    }),
    overrides: [
      ...competeBaseOverrides(signedOut: signedOut),
      matchRepositoryProvider.overrideWithValue(env.repo),
      evidenceUploaderProvider.overrideWithValue(env.uploader),
      imagePickerProvider.overrideWithValue(env.picker),
    ],
  );
  await tester.pumpAndSettle();
  return env;
}

Future<void> _fillValid(WidgetTester tester, _Env env, {String placement = '3', String kills = '7'}) async {
  env.picker.queue.add(_img('a.png'));
  await tester.tap(find.byKey(const Key('pick-screenshot')));
  await tester.pumpAndSettle();
  await tester.enterText(find.byKey(const Key('placement')), placement);
  await tester.enterText(find.byKey(const Key('kills')), kills);
}

Future<void> _submit(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('submit-result')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('invalid placement blocks with zero I/O', (tester) async {
    final env = await _pump(tester);
    env.picker.queue.add(_img('a.png'));
    await tester.tap(find.byKey(const Key('pick-screenshot')));
    await tester.pumpAndSettle();
    for (final bad in ['0', '101']) {
      await tester.enterText(find.byKey(const Key('placement')), bad);
      await tester.enterText(find.byKey(const Key('kills')), '1');
      await _submit(tester);
      expect(find.text('Enter a whole number from 1 to 100.'), findsWidgets, reason: bad);
    }
    expect(env.uploader.calls, isEmpty);
    expect(env.repo.lobbyCalls, isEmpty);
  });

  testWidgets('invalid kills blocks with zero I/O', (tester) async {
    final env = await _pump(tester);
    env.picker.queue.add(_img('a.png'));
    await tester.tap(find.byKey(const Key('pick-screenshot')));
    await tester.pumpAndSettle();
    for (final bad in ['-1', '101']) {
      await tester.enterText(find.byKey(const Key('placement')), '3');
      await tester.enterText(find.byKey(const Key('kills')), bad);
      await _submit(tester);
      expect(find.text('Enter a whole number from 0 to 100.'), findsWidgets, reason: bad);
    }
    expect(env.uploader.calls, isEmpty);
    expect(env.repo.lobbyCalls, isEmpty);
  });

  testWidgets('happy path sends placement, kills, path and a key; shows the confirmation', (tester) async {
    final env = await _pump(tester);
    await _fillValid(tester, env);
    await _submit(tester);
    expect(env.uploader.calls, hasLength(1));
    expect(env.repo.lobbyCalls.single.placement, 3);
    expect(env.repo.lobbyCalls.single.kills, 7);
    expect(env.repo.lobbyCalls.single.key, isNotEmpty);
    expect(find.text('Result submitted — awaiting confirmation.'), findsOneWidget);
  });

  testWidgets('server error then retry: one upload, a new key', (tester) async {
    final env = await _pump(tester);
    env.repo.lobbyResults.add(_apiEx('lobby_confirmed'));
    await _fillValid(tester, env);
    await _submit(tester);
    expect(find.text('This lobby is confirmed and can no longer be edited.'), findsOneWidget);
    await _submit(tester);
    expect(env.uploader.calls, hasLength(1));
    expect(env.repo.lobbyCalls, hasLength(2));
    expect(env.repo.lobbyCalls[1].key, isNot(env.repo.lobbyCalls[0].key));
  });

  testWidgets('network error then retry: same key, one upload', (tester) async {
    final env = await _pump(tester);
    env.repo.lobbyResults.add(_apiEx('network', status: 0));
    await _fillValid(tester, env);
    await _submit(tester);
    await _submit(tester);
    expect(env.uploader.calls, hasLength(1));
    expect(env.repo.lobbyCalls[1].key, env.repo.lobbyCalls[0].key);
  });

  testWidgets('upload failure shows its message and never calls the repo', (tester) async {
    final env = await _pump(tester);
    env.uploader.failWith = Exception('down');
    await _fillValid(tester, env);
    await _submit(tester);
    expect(find.text('Screenshot upload failed. Please try again.'), findsOneWidget);
    expect(env.repo.lobbyCalls, isEmpty);
  });

  testWidgets('a double tap sends one request', (tester) async {
    final env = await _pump(tester);
    await _fillValid(tester, env);
    env.repo.lobbyGate = Future.delayed(const Duration(milliseconds: 200));
    await tester.tap(find.byKey(const Key('submit-result')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('submit-result')));
    await tester.pump();
    expect(env.repo.lobbyCalls, hasLength(1));
    await tester.pumpAndSettle();
  });

  testWidgets('not_in_lobby shows its localized copy', (tester) async {
    final env = await _pump(tester);
    env.repo.lobbyResults.add(_apiEx('not_in_lobby'));
    await _fillValid(tester, env);
    await _submit(tester);
    expect(find.text("You're not in this lobby."), findsOneWidget);
  });

  testWidgets('the header shows the lobby label when given, and renders without it', (tester) async {
    await _pump(tester, lobby: NextLobby.fromJson(nextLobbyJson()));
    expect(find.textContaining('Round 2'), findsOneWidget);
    await _pump(tester);
    expect(find.text('Lobby result'), findsOneWidget);
  });

  testWidgets('success invalidates the dashboard summary', (tester) async {
    final env = await _pump(tester);
    await _fillValid(tester, env);
    await _submit(tester);
    expect(env.repo.summaryCalls, greaterThan(0));
  });

  testWidgets('signed out shows a login message and no form', (tester) async {
    await _pump(tester, signedOut: true);
    expect(find.byKey(const Key('placement')), findsNothing);
    expect(find.byKey(const Key('submit-result')), findsNothing);
  });
}
