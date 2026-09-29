import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/core/api/community_models.dart';
import 'package:sentinelx_mobile/features/community/community_providers.dart';
import 'package:sentinelx_mobile/features/community/status_tray.dart';

import '../../fakes/fake_community_repository.dart';
import '../../support/community_fixtures.dart';
import '../../support/pump_compete.dart';

StatusRing _ring({String playerId = 'u1', bool hasUnseen = true, bool isSelf = false}) =>
    StatusRing.fromJson(statusRingJson(playerId: playerId, hasUnseen: hasUnseen, isSelf: isSelf));

class _Capture {
  StatusRing? tappedRing;
  var addYoursTapped = false;
}

Future<_Capture> _pump(WidgetTester tester, {List<StatusRing> rings = const [], bool signedOut = false}) async {
  final capture = _Capture();
  final repo = FakeCommunityRepository(statusRings: rings);
  await pumpCompete(
    tester,
    StatusTray(
      onRingTap: (r) => capture.tappedRing = r,
      onAddYours: () => capture.addYoursTapped = true,
    ),
    overrides: [
      ...competeBaseOverrides(signedOut: signedOut),
      communityRepositoryProvider.overrideWithValue(repo),
    ],
  );
  await tester.pumpAndSettle();
  return capture;
}

void main() {
  testWidgets('empty rings list shows only the add-yours tile', (tester) async {
    await _pump(tester, rings: []);
    expect(find.text('Your story'), findsOneWidget);
    expect(find.byKey(const Key('status-add-yours')), findsOneWidget);
  });

  testWidgets('a ring with hasUnseen true gets the unseen key, hasUnseen false gets the seen key', (tester) async {
    final rings = [
      _ring(playerId: 'u1', hasUnseen: true),
      _ring(playerId: 'u2', hasUnseen: false),
    ];
    await _pump(tester, rings: rings);
    expect(find.byKey(const Key('status-ring-unseen-u1')), findsOneWidget);
    expect(find.byKey(const Key('status-ring-seen-u2')), findsOneWidget);
    expect(find.byKey(const Key('status-ring-seen-u1')), findsNothing);
    expect(find.byKey(const Key('status-ring-unseen-u2')), findsNothing);
  });

  testWidgets('tapping a ring calls onRingTap with that ring; tapping add-yours calls onAddYours', (tester) async {
    final ring = _ring(playerId: 'u1', hasUnseen: true);
    final capture = await _pump(tester, rings: [ring]);

    await tester.tap(find.byKey(const Key('status-ring-unseen-u1')));
    await tester.pumpAndSettle();
    expect(capture.tappedRing?.playerId, 'u1');
    expect(capture.addYoursTapped, isFalse);

    await tester.tap(find.byKey(const Key('status-add-yours')));
    await tester.pumpAndSettle();
    expect(capture.addYoursTapped, isTrue);
  });

  testWidgets('no rings at all renders without error (an empty tray is valid, not a failure)', (tester) async {
    await _pump(tester, rings: []);
    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('status-add-yours')), findsOneWidget);
  });

  testWidgets('the add-yours tile is present and tappable even when signed out', (tester) async {
    final capture = await _pump(tester, rings: [], signedOut: true);
    expect(find.byKey(const Key('status-add-yours')), findsOneWidget);

    await tester.tap(find.byKey(const Key('status-add-yours')));
    await tester.pumpAndSettle();
    expect(capture.addYoursTapped, isTrue);
  });
}
