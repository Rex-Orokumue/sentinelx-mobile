import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/core/api/api_client.dart';
import 'package:sentinelx_mobile/features/community/community_providers.dart';
import 'package:sentinelx_mobile/features/community/report_sheet.dart';

import '../../fakes/fake_community_repository.dart';
import '../../support/pump_compete.dart';

ApiException _apiEx(String code, {int status = 409}) => ApiException(status: status, code: code, message: 'RAW');

Future<FakeCommunityRepository> _pump(WidgetTester tester, {ReportTarget target = const ReportTarget.post('p1'), FakeCommunityRepository? repo}) async {
  final fake = repo ?? FakeCommunityRepository();
  await pumpCompete(
    tester,
    Builder(builder: (context) => ElevatedButton(onPressed: () => showReportSheet(context, target: target), child: const Text('open'))),
    size: const Size(375, 1600),
    overrides: [...competeBaseOverrides(), communityRepositoryProvider.overrideWithValue(fake)],
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return fake;
}

Future<void> _pick(WidgetTester tester, String wire) async {
  await tester.tap(find.byKey(Key('report-reason-$wire')));
  await tester.pumpAndSettle();
}

Future<void> _submit(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('report-submit')));
  await tester.pumpAndSettle();
}

List<String> _reports(FakeCommunityRepository repo) => repo.calls.where((c) => c.startsWith('report')).toList();

void main() {
  testWidgets('lists all seven reasons and keeps submit disabled until one is chosen', (tester) async {
    await _pump(tester);
    for (final label in [
      'Spam',
      'Harassment',
      'Hate speech',
      'Nudity or sexual content',
      'Violence',
      'Misinformation',
      'Other',
    ]) {
      expect(find.text(label), findsOneWidget);
    }
    expect(tester.widget<FilledButton>(find.byKey(const Key('report-submit'))).onPressed, isNull);
    await _pick(tester, 'spam');
    expect(tester.widget<FilledButton>(find.byKey(const Key('report-submit'))).onPressed, isNotNull);
  });

  testWidgets('a post target calls reportPost with the reason and a trimmed note', (tester) async {
    final repo = await _pump(tester);
    await _pick(tester, 'hate_speech');
    await tester.enterText(find.byKey(const Key('report-note')), '  rude  ');
    await _submit(tester);
    final call = _reports(repo).single;
    expect(call, startsWith('reportPost:p1:hate_speech:rude:'));
  });

  testWidgets('an empty note is sent as null', (tester) async {
    final repo = await _pump(tester);
    await _pick(tester, 'spam');
    await tester.enterText(find.byKey(const Key('report-note')), '   ');
    await _submit(tester);
    expect(_reports(repo).single, startsWith('reportPost:p1:spam:null:'));
  });

  testWidgets('a comment target calls reportComment instead', (tester) async {
    final repo = await _pump(tester, target: const ReportTarget.comment('c9'));
    await _pick(tester, 'violence');
    await _submit(tester);
    expect(_reports(repo).single, startsWith('reportComment:c9:violence:null:'));
  });

  testWidgets('success shows the thank-you copy and closes the sheet', (tester) async {
    await _pump(tester);
    await _pick(tester, 'spam');
    await _submit(tester);
    expect(find.text('Report submitted. Thank you.'), findsOneWidget);
    expect(find.text('Report content'), findsNothing);
  });

  testWidgets('already_reported shows its own copy and keeps the sheet open', (tester) async {
    final repo = FakeCommunityRepository();
    repo.writeErrors['reportPost'] = _apiEx('already_reported');
    await _pump(tester, repo: repo);
    await _pick(tester, 'spam');
    await _submit(tester);
    expect(find.text("You've already reported this."), findsOneWidget);
    expect(find.text('RAW'), findsNothing);
    expect(find.text('Report content'), findsOneWidget);
  });

  testWidgets('a retry of an unchanged report reuses the key; a changed reason mints a new one', (tester) async {
    final repo = FakeCommunityRepository();
    repo.writeErrors['reportPost'] = const ApiException(status: 0, code: 'network', message: 'x');
    await _pump(tester, repo: repo);
    await _pick(tester, 'spam');
    await _submit(tester);

    repo.writeErrors['reportPost'] = const ApiException(status: 0, code: 'network', message: 'x');
    await _submit(tester);

    repo.writeErrors['reportPost'] = const ApiException(status: 0, code: 'network', message: 'x');
    await _pick(tester, 'harassment');
    await _submit(tester);

    final keys = _reports(repo).map((c) => c.split(':').last).toList();
    expect(keys, hasLength(3));
    expect(keys[1], keys[0], reason: 'same payload, request may not have landed: same key');
    expect(keys[2], isNot(keys[0]), reason: 'changed reason must not replay the old response');
  });

  testWidgets('the sheet cannot be closed mid-flight', (tester) async {
    final repo = FakeCommunityRepository();
    await _pump(tester, repo: repo);
    await _pick(tester, 'spam');
    final gate = Completer<void>();
    repo.reportGate = gate;
    await tester.tap(find.byKey(const Key('report-submit')));
    await tester.pump();
    expect(tester.widget<FilledButton>(find.byKey(const Key('report-submit'))).onPressed, isNull);
    gate.complete();
    await tester.pumpAndSettle();
  });
}
