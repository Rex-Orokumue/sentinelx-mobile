import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/core/providers.dart';
import 'package:sentinelx_mobile/core/storage/local_kv.dart';
import 'package:sentinelx_mobile/features/guide/coach/coach_controller.dart';
import 'package:sentinelx_mobile/features/guide/coach/coach_registry.dart';
import 'package:sentinelx_mobile/features/guide/coach/coach_tours.dart';
import '../../../fakes/fake_local_kv.dart';

class _Registry extends CoachTargetRegistry {
  _Registry(this.present);
  final Set<String> present;
  @override Rect? rectFor(String id) => present.contains(id) ? const Rect.fromLTWH(10, 10, 50, 50) : null;
}

ProviderContainer _c(MemoryLocalKv kv, Set<String> present, {String? viewer = 'u1'}) {
  final c = ProviderContainer(overrides: [
    localKvProvider.overrideWith((ref) async => kv),
    viewerIdProvider.overrideWith((ref) async => viewer),
    coachRegistryProvider.overrideWithValue(_Registry(present)),
  ]);
  addTearDown(c.dispose);
  return c;
}

void main() {
  final allHome = homeTour.steps.map((s) => s.targetId).toSet();
  test('starts once, then never again after it is finished (per viewer)', () async {
    final kv = MemoryLocalKv();
    final c = _c(kv, allHome);
    await c.read(coachControllerProvider.notifier).maybeStart(homeTour);
    expect(c.read(coachControllerProvider).running, isTrue);
    c.read(coachControllerProvider.notifier).skip();
    await Future<void>.delayed(Duration.zero);
    expect(kv.values.keys.any((k) => k.startsWith('coach.u1.')), isTrue);
    await c.read(coachControllerProvider.notifier).maybeStart(homeTour);
    expect(c.read(coachControllerProvider).running, isFalse);
  });
  test('the seen flag is per viewer: another account still sees the tour', () async {
    final kv = MemoryLocalKv()..values['coach.u1.${homeTour.id}'] = '1';
    final c = _c(kv, allHome, viewer: 'u2');
    await c.read(coachControllerProvider.notifier).maybeStart(homeTour);
    expect(c.read(coachControllerProvider).running, isTrue);
  });
  test('signed-out visitors use the guest key', () async {
    final kv = MemoryLocalKv();
    final c = _c(kv, allHome, viewer: null);
    await c.read(coachControllerProvider.notifier).maybeStart(homeTour);
    c.read(coachControllerProvider.notifier).skip();
    await Future<void>.delayed(Duration.zero);
    expect(kv.values.keys.any((k) => k.startsWith('coach.guest.')), isTrue);
  });
  test('does not start when none of its targets are on screen (same-page only), and does not mark it seen', () async {
    final kv = MemoryLocalKv();
    final c = _c(kv, {});
    await c.read(coachControllerProvider.notifier).maybeStart(homeTour);
    expect(c.read(coachControllerProvider).running, isFalse);
    expect(kv.values, isEmpty);
  });
  test('skips steps whose target is missing and finishes after the last present one', () async {
    final present = {homeTour.steps.first.targetId, homeTour.steps.last.targetId};
    final c = _c(MemoryLocalKv(), present);
    final n = c.read(coachControllerProvider.notifier);
    await n.maybeStart(homeTour);
    expect(c.read(coachControllerProvider).running, isTrue);
    n.next();
    n.next();
    expect(c.read(coachControllerProvider).running, isFalse);
  });
  test('resetAll clears the flags so the tours run again', () async {
    final kv = MemoryLocalKv()..values['coach.u1.${homeTour.id}'] = '1'..values['coach.u1.${shellTour.id}'] = '1';
    final c = _c(kv, allHome);
    await c.read(coachControllerProvider.notifier).resetAll();
    expect(kv.values.keys.where((k) => k.startsWith('coach.u1.')), isEmpty);
  });
  test('a storage failure never blocks or crashes the tour', () async {
    final kv = MemoryLocalKv()..failWrites = true;
    final c = _c(kv, allHome);
    final n = c.read(coachControllerProvider.notifier);
    await n.maybeStart(homeTour);
    n.skip();
    expect(c.read(coachControllerProvider).running, isFalse);
  });
}
