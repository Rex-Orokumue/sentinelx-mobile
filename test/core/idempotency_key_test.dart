import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/core/utils/idempotency_key.dart';

void main() {
  final v4 = RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$');

  test('is a well-formed UUID v4', () {
    for (var i = 0; i < 50; i++) {
      expect(newIdempotencyKey(), matches(v4));
    }
  });

  test('two keys differ; a seeded generator is deterministic', () {
    expect(newIdempotencyKey(), isNot(newIdempotencyKey()));
    expect(newIdempotencyKey(Random(7)), newIdempotencyKey(Random(7)));
  });
}
