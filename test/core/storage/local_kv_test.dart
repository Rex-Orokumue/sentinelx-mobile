import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/core/storage/local_kv.dart';
import '../../fakes/fake_local_kv.dart';

void main() {
  test('device id is generated once, persisted and reused', () async {
    final kv = MemoryLocalKv();
    final c = ProviderContainer(overrides: [localKvProvider.overrideWith((ref) async => kv)]);
    addTearDown(c.dispose);
    final first = await c.read(chatDeviceIdProvider.future);
    expect(first.length, greaterThanOrEqualTo(8));
    expect(kv.values['chat.deviceId'], first);
    final c2 = ProviderContainer(overrides: [localKvProvider.overrideWith((ref) async => kv)]);
    addTearDown(c2.dispose);
    expect(await c2.read(chatDeviceIdProvider.future), first);
  });
  test('device id matches the server header pattern [A-Za-z0-9-]{8,64}', () async {
    final c = ProviderContainer(overrides: [localKvProvider.overrideWith((ref) async => MemoryLocalKv())]);
    addTearDown(c.dispose);
    expect(RegExp(r'^[A-Za-z0-9-]{8,64}$').hasMatch(await c.read(chatDeviceIdProvider.future)), isTrue);
  });
  test('when storage cannot write, a device id is still returned (in memory)', () async {
    final kv = MemoryLocalKv()..failWrites = true;
    final c = ProviderContainer(overrides: [localKvProvider.overrideWith((ref) async => kv)]);
    addTearDown(c.dispose);
    expect((await c.read(chatDeviceIdProvider.future)).isNotEmpty, isTrue);
  });
}
