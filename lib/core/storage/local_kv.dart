import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/idempotency_key.dart';

/// Small per-install key/value store (coach-mark flags, anonymous chat device id). Never holds anything secret.
abstract class LocalKv {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> remove(String key);
}

class PrefsLocalKv implements LocalKv {
  PrefsLocalKv(this._prefs);
  final SharedPreferences _prefs;
  @override Future<String?> read(String key) async => _prefs.getString(key);
  @override Future<void> write(String key, String value) async => _prefs.setString(key, value);
  @override Future<void> remove(String key) async => _prefs.remove(key);
}

final localKvProvider = FutureProvider<LocalKv>((ref) async => PrefsLocalKv(await SharedPreferences.getInstance()));

/// Random per-install id sent as `X-Device-Id` on signed-out chat. Spoofable on purpose-built clients, so the
/// server only uses it to add a rate-limit bucket, never to raise a limit.
final chatDeviceIdProvider = FutureProvider<String>((ref) async {
  const key = 'chat.deviceId';
  try {
    final kv = await ref.watch(localKvProvider.future);
    final existing = await kv.read(key);
    if (existing != null && RegExp(r'^[A-Za-z0-9-]{8,64}$').hasMatch(existing)) return existing;
    final fresh = newIdempotencyKey();
    await kv.write(key, fresh);
    return fresh;
  } catch (_) {
    return newIdempotencyKey(); // storage unavailable: a per-run id still works
  }
});
