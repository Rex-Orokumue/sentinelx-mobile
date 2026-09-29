import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/core/api/community_models.dart';
import 'package:sentinelx_mobile/features/community/community_providers.dart';
import 'package:sentinelx_mobile/features/community/status_viewer_screen.dart';

import '../../fakes/fake_community_repository.dart';
import '../../support/community_fixtures.dart';
import '../../support/pump_compete.dart';

StatusRow _row({
  required String id,
  String? caption,
  String? imageUrl,
  String expiresAt = '2099-01-01T00:00:00Z',
}) =>
    StatusRow.fromJson(statusRowJson(id: id, imageUrl: imageUrl, caption: caption, expiresAt: expiresAt));

StatusRing _ring({
  required List<StatusRow> statuses,
  bool isSelf = false,
  String playerId = 'u1',
}) =>
    StatusRing.fromJson(statusRingJson(
      playerId: playerId,
      isSelf: isSelf,
      statuses: statuses.map((s) => statusRowJson(
            id: s.id,
            imageUrl: s.imageUrl,
            caption: s.caption,
            expiresAt: s.expiresAt,
          )).toList(),
    ));

class _Capture {
  final openedViewersFor = <String>[];
}

Future<_Capture> _pump(
  WidgetTester tester, {
  required StatusRing ring,
  FakeCommunityRepository? repo,
}) async {
  final capture = _Capture();
  await pumpCompete(
    tester,
    StatusViewerScreen(ring: ring, onOpenViewers: (id) => capture.openedViewersFor.add(id)),
    overrides: [
      ...competeBaseOverrides(),
      communityRepositoryProvider.overrideWithValue(repo ?? FakeCommunityRepository()),
    ],
  );
  await tester.pumpAndSettle();
  return capture;
}

void main() {
  testWidgets('renders the first status; right half advances, left half goes back; last-status right pops',
      (tester) async {
    final ring = _ring(statuses: [
      _row(id: 's1', caption: 'first'),
      _row(id: 's2', caption: 'second'),
    ]);
    await pumpCompete(
      tester,
      Builder(
        builder: (context) => TextButton(
          key: const Key('open'),
          onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
            builder: (_) => StatusViewerScreen(ring: ring, onOpenViewers: (_) {}),
          )),
          child: const Text('open'),
        ),
      ),
      overrides: [...competeBaseOverrides(), communityRepositoryProvider.overrideWithValue(FakeCommunityRepository())],
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('open')));
    await tester.pumpAndSettle();

    expect(find.text('first'), findsOneWidget);

    // Tap the right half to advance.
    await tester.tapAt(const Offset(300, 400));
    await tester.pumpAndSettle();
    expect(find.text('second'), findsOneWidget);
    expect(find.text('first'), findsNothing);

    // Tap the left half to go back.
    await tester.tapAt(const Offset(50, 400));
    await tester.pumpAndSettle();
    expect(find.text('first'), findsOneWidget);

    // Advance to the last status, then tap right again: closes the viewer (pop).
    await tester.tapAt(const Offset(300, 400));
    await tester.pumpAndSettle();
    expect(find.text('second'), findsOneWidget);
    await tester.tapAt(const Offset(300, 400));
    await tester.pumpAndSettle();
    expect(find.byType(StatusViewerScreen), findsNothing);
  });

  testWidgets('calls viewStatus exactly once per status shown, not re-called on back-then-forward', (tester) async {
    final ring = _ring(statuses: [
      _row(id: 's1', caption: 'first'),
      _row(id: 's2', caption: 'second'),
    ]);
    final repo = FakeCommunityRepository();
    await _pump(tester, ring: ring, repo: repo);

    expect(repo.calls.where((c) => c.startsWith('viewStatus:')).toList(), ['viewStatus:s1']);

    await tester.tapAt(const Offset(300, 400)); // advance to s2
    await tester.pumpAndSettle();
    expect(repo.calls.where((c) => c.startsWith('viewStatus:')).toList(), ['viewStatus:s1', 'viewStatus:s2']);

    await tester.tapAt(const Offset(50, 400)); // back to s1
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(300, 400)); // forward to s2 again
    await tester.pumpAndSettle();

    // Still exactly one call each — never re-called for a status already shown this session.
    expect(repo.calls.where((c) => c.startsWith('viewStatus:')).toList(), ['viewStatus:s1', 'viewStatus:s2']);
  });

  testWidgets('viewStatus throwing is swallowed silently: no error UI', (tester) async {
    final ring = _ring(statuses: [_row(id: 's1', caption: 'first')]);
    final repo = FakeCommunityRepository();
    repo.writeErrors['viewStatus'] = Exception('boom');
    await _pump(tester, ring: ring, repo: repo);

    expect(find.text('first'), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ring.isSelf true shows the viewers entry point; isSelf false shows none', (tester) async {
    final selfRing = _ring(statuses: [_row(id: 's1', caption: 'mine')], isSelf: true);
    final capture = await _pump(tester, ring: selfRing);
    expect(find.byKey(const Key('status-open-viewers')), findsOneWidget);

    await tester.tap(find.byKey(const Key('status-open-viewers')));
    await tester.pumpAndSettle();
    expect(capture.openedViewersFor, ['s1']);
  });

  testWidgets('ring.isSelf false shows no viewers entry point', (tester) async {
    final otherRing = _ring(statuses: [_row(id: 's1', caption: 'theirs')], isSelf: false);
    await _pump(tester, ring: otherRing);
    expect(find.byKey(const Key('status-open-viewers')), findsNothing);
  });

  testWidgets('an expired status is auto-advanced past without ever calling viewStatus for it', (tester) async {
    final ring = _ring(statuses: [
      _row(id: 's1', caption: 'first'),
      _row(id: 's2', caption: 'expired', expiresAt: '2000-01-01T00:00:00Z'),
      _row(id: 's3', caption: 'third'),
    ]);
    final repo = FakeCommunityRepository();
    await _pump(tester, ring: ring, repo: repo);
    expect(find.text('first'), findsOneWidget);

    // Advancing past s1 should skip the expired s2 entirely and land on s3.
    await tester.tapAt(const Offset(300, 400));
    await tester.pumpAndSettle();
    expect(find.text('third'), findsOneWidget);
    expect(find.text('expired'), findsNothing);
    expect(repo.calls.where((c) => c.startsWith('viewStatus:')).toList(), ['viewStatus:s1', 'viewStatus:s3']);
  });
}
