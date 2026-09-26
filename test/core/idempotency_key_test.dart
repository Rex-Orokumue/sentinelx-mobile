import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/core/utils/idempotency_key.dart';

void main() {
  test('is a v4 UUID and differs between calls', () {
    final re = RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$');
    final a = newIdempotencyKey();
    expect(re.hasMatch(a), isTrue);
    expect(newIdempotencyKey(), isNot(a));
  });

  test('is deterministic for a seeded Random', () {
    expect(newIdempotencyKey(Random(1)), newIdempotencyKey(Random(1)));
  });
}
