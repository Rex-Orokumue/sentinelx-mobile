import 'package:sentinelx_mobile/core/storage/local_kv.dart';

class MemoryLocalKv implements LocalKv {
  final Map<String, String> values = {};
  bool failWrites = false;
  @override Future<String?> read(String key) async => values[key];
  @override Future<void> write(String key, String value) async {
    if (failWrites) throw StateError('write failed');
    values[key] = value;
  }
  @override Future<void> remove(String key) async => values.remove(key);
}
