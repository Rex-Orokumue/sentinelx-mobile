import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/core/realtime/realtime_hub.dart';
import 'package:sentinelx_mobile/core/realtime/realtime_port.dart';
import 'package:sentinelx_mobile/features/notifications/notifications_providers.dart';

import '../../fakes/fake_realtime.dart';

void main() {
  test('the bell nudge opens a hub channel on player_notifications filtered to the viewer, and every event refreshes it',
      () async {
    final factory = FakeChannelFactory();
    final hub = RealtimeHub(factory: factory, lifecycle: FakeLifecycle());
    final container = ProviderContainer(retry: (_, _) => null, overrides: [
      realtimeHubProvider.overrideWithValue(hub),
      notificationsViewerIdProvider.overrideWith((ref) async => 'u1'),
    ]);
    addTearDown(container.dispose);

    final seen = <int>[];
    container.listen(notificationsRealtimeProvider, (_, next) {
      final v = next.asData?.value;
      if (v != null) seen.add(v);
    });
    await pumpEventQueue();

    final port = factory.created.single;
    final b = port.spec.bindings.single as PostgresBinding;
    expect(b.table, 'player_notifications');
    expect(b.filterColumn, 'player_id');
    expect(b.filterValue, 'u1');

    port.emitStatus(PortStatus.subscribed);
    port.emitEvent();
    await Future<void>.delayed(const Duration(milliseconds: 450));
    port.emitEvent();
    await Future<void>.delayed(const Duration(milliseconds: 450));
    expect(seen, [1, 2], reason: 'two separate events notify twice');
  });
}
