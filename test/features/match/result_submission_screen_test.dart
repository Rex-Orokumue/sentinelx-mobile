import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/core/api/api_client.dart';
import 'package:sentinelx_mobile/features/match/evidence.dart';
import 'package:sentinelx_mobile/features/match/match_providers.dart';
import 'package:sentinelx_mobile/features/match/match_reads_repository.dart';
import 'package:sentinelx_mobile/features/match/result_submission_screen.dart';

import '../../fakes/fake_evidence.dart';
import '../../fakes/fake_match_repositories.dart';
import '../../support/pump_compete.dart';

ApiException _apiEx(String code, {int status = 409}) => ApiException(status: status, code: code, message: 'x');

const _match = MatchInfo(
  id: 'm1',
  tournamentId: 't1',
  round: 'quarter_final',
  status: 'scheduled',
  isFullDay: false,
  playerAId: 'p1',
  playerBId: 'p2',
  nameA: 'Ada',
  nameB: 'Bola',
);

PickedImage _img(String name) => PickedImage(name: name, bytes: Uint8List.fromList([1, 2, 3]));

class _Env {
  final repo = FakeMatchRepository();
  final uploader = FakeUploader();
  final picker = FakePicker();
}

Future<_Env> _pump(WidgetTester tester, {bool signedOut = false, MatchInfo match = _match}) async {
  final env = _Env();
  await pumpCompete(
    tester,
    ResultSubmissionScreen(match: match),
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

Future<void> _fillValid(WidgetTester tester, _Env env, {String a = '2', String b = '1'}) async {
  env.picker.queue.add(_img('a.png'));
  await tester.tap(find.byKey(const Key('pick-screenshot')));
  await tester.pumpAndSettle();
  await tester.enterText(find.byKey(const Key('score-a')), a);
  await tester.enterText(find.byKey(const Key('score-b')), b);
}

Future<void> _submit(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('submit-result')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('invalid scores block with zero I/O', (tester) async {
    final env = await _pump(tester);
    env.picker.queue.add(_img('a.png'));
    await tester.tap(find.byKey(const Key('pick-screenshot')));
    await tester.pumpAndSettle();
    for (final bad in ['-1', '100', 'abc', '']) {
      await tester.enterText(find.byKey(const Key('score-a')), bad);
      await tester.enterText(find.byKey(const Key('score-b')), '1');
      await _submit(tester);
      expect(find.text('Enter a whole number from 0 to 99.'), findsWidgets, reason: bad);
    }
    expect(env.uploader.calls, isEmpty);
    expect(env.repo.resultCalls, isEmpty);
  });

  testWidgets('missing screenshot blocks with the required message', (tester) async {
    final env = await _pump(tester);
    await tester.enterText(find.byKey(const Key('score-a')), '2');
    await tester.enterText(find.byKey(const Key('score-b')), '1');
    await _submit(tester);
    expect(find.text('A screenshot is required.'), findsOneWidget);
    expect(env.uploader.calls, isEmpty);
    expect(env.repo.resultCalls, isEmpty);
  });

  testWidgets('a cancelled picker leaves no image chosen', (tester) async {
    final env = await _pump(tester);
    env.picker.queue.add(null);
    await tester.tap(find.byKey(const Key('pick-screenshot')));
    await tester.pumpAndSettle();
    expect(find.text('Choose screenshot'), findsOneWidget);
  });

  testWidgets('happy path: uploads once, sends the scores, shows the confirmation with no score/won text', (tester) async {
    final env = await _pump(tester);
    await _fillValid(tester, env);
    await _submit(tester);
    expect(env.uploader.calls, hasLength(1));
    expect(env.repo.resultCalls.single.scoreA, 2);
    expect(env.repo.resultCalls.single.scoreB, 1);
    expect(find.text('Result submitted — awaiting confirmation.'), findsOneWidget);
    expect(find.text('2 – 1'), findsNothing);
    expect(find.textContaining('won'), findsNothing);
  });

  testWidgets('server error then retry: uploader called once, second attempt uses a new key', (tester) async {
    final env = await _pump(tester);
    env.repo.resultResults.add(_apiEx('submission_locked'));
    await _fillValid(tester, env);
    await _submit(tester);
    expect(find.text('Your submission is under review and can no longer be edited.'), findsOneWidget);
    await _submit(tester);
    expect(env.uploader.calls, hasLength(1));
    expect(env.repo.resultCalls, hasLength(2));
    expect(env.repo.resultCalls[1].key, isNot(env.repo.resultCalls[0].key));
  });

  testWidgets('network error then retry: same key, one upload', (tester) async {
    final env = await _pump(tester);
    env.repo.resultResults.add(_apiEx('network', status: 0));
    await _fillValid(tester, env);
    await _submit(tester);
    await _submit(tester);
    expect(env.uploader.calls, hasLength(1));
    expect(env.repo.resultCalls[1].key, env.repo.resultCalls[0].key);
  });

  testWidgets('upload failure shows the upload-failed message and never calls the repo', (tester) async {
    final env = await _pump(tester);
    env.uploader.failWith = Exception('storage down');
    await _fillValid(tester, env);
    await _submit(tester);
    expect(find.text('Screenshot upload failed. Please try again.'), findsOneWidget);
    expect(env.repo.resultCalls, isEmpty);
  });

  testWidgets('a double tap on submit sends one request', (tester) async {
    final env = await _pump(tester);
    await _fillValid(tester, env);
    env.repo.resultGate = Future.delayed(const Duration(milliseconds: 200));
    await tester.tap(find.byKey(const Key('submit-result')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('submit-result')));
    await tester.pump();
    expect(env.repo.resultCalls, hasLength(1));
    await tester.pumpAndSettle();
  });

  testWidgets('a 60-char name in the score labels does not overflow at 375px', (tester) async {
    const match = MatchInfo(
      id: 'm1',
      tournamentId: 't1',
      round: 'quarter_final',
      status: 'scheduled',
      isFullDay: false,
      playerAId: 'p1',
      playerBId: 'p2',
      nameA: 'NNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNN',
      nameB: 'BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
    );
    await _pump(tester, match: match);
    expect(tester.takeException(), isNull);
  });

  testWidgets('signed out shows a login message and no form', (tester) async {
    await _pump(tester, signedOut: true);
    expect(find.byKey(const Key('score-a')), findsNothing);
    expect(find.byKey(const Key('submit-result')), findsNothing);
  });

  testWidgets('a blank recording URL is trimmed and sent as an empty string', (tester) async {
    final env = await _pump(tester);
    await _fillValid(tester, env);
    await tester.enterText(find.byKey(const Key('recording-url')), '   ');
    await _submit(tester);
    expect(env.repo.resultCalls.single.recordingUrl, '');
  });
}
