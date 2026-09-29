import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/core/api/community_models.dart';
import 'package:sentinelx_mobile/features/community/community_providers.dart';
import 'package:sentinelx_mobile/features/community/status_viewers_screen.dart';

import '../../fakes/fake_community_repository.dart';
import '../../support/community_fixtures.dart';
import '../../support/pump_compete.dart';

Future<FakeCommunityRepository> _pump(
  WidgetTester tester, {
  FakeCommunityRepository? repo,
  String statusId = 's1',
  bool settle = true,
}) async {
  final fake = repo ?? FakeCommunityRepository();
  await pumpCompete(
    tester,
    StatusViewersScreen(statusId: statusId),
    overrides: [
      ...competeBaseOverrides(),
      communityRepositoryProvider.overrideWithValue(fake),
    ],
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
  return fake;
}

void main() {
  testWidgets('shows a loading indicator while statusViewers is in flight', (tester) async {
    final repo = FakeCommunityRepository()..statusViewersGate = Completer<void>();
    await _pump(tester, repo: repo, settle: false);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    repo.statusViewersGate!.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('shows an error state when statusViewers throws', (tester) async {
    final repo = FakeCommunityRepository()..statusViewersError = Exception('boom');
    await _pump(tester, repo: repo);
    expect(find.text('Something went wrong. Please try again.'), findsOneWidget);
  });

  testWidgets('shows the list of StatusViewers on success', (tester) async {
    final repo = FakeCommunityRepository(statusViewersList: [
      StatusViewer.fromJson(statusViewerJson(viewerId: 'v1', name: 'Ada')),
      StatusViewer.fromJson(statusViewerJson(viewerId: 'v2', name: 'Bola')),
    ]);
    await _pump(tester, repo: repo);
    expect(find.text('Ada'), findsOneWidget);
    expect(find.text('Bola'), findsOneWidget);
    expect(find.byKey(const Key('status-viewer-v1')), findsOneWidget);
    expect(find.byKey(const Key('status-viewer-v2')), findsOneWidget);
  });

  testWidgets('empty viewers list shows the empty-state copy, not a blank screen', (tester) async {
    final repo = FakeCommunityRepository(statusViewersList: const []);
    await _pump(tester, repo: repo);
    expect(find.text('No one has viewed this yet.'), findsOneWidget);
  });

  testWidgets('renders correctly given any statusId (reachability/authorization is server-enforced)', (tester) async {
    final repo = FakeCommunityRepository(statusViewersList: [
      StatusViewer.fromJson(statusViewerJson(viewerId: 'v1', name: 'Ada')),
    ]);
    await _pump(tester, repo: repo, statusId: 'some-other-status');
    expect(repo.calls, contains('statusViewers:some-other-status'));
    expect(find.text('Ada'), findsOneWidget);
  });
}
