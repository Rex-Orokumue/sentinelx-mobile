import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/core/api/api_client.dart';

void main() {
  test('every operation the client uses exists in the pinned web contract (api/openapi.json)', () {
    final doc = jsonDecode(File('api/openapi.json').readAsStringSync()) as Map<String, dynamic>;
    final paths = doc['paths'] as Map<String, dynamic>;

    final published = <String, String>{}; // operationId -> 'method /path'
    paths.forEach((path, methods) {
      (methods as Map<String, dynamic>).forEach((method, op) {
        published[(op as Map<String, dynamic>)['operationId'] as String] = '$method $path';
      });
    });

    for (final entry in ApiClient.usedOperations.entries) {
      expect(published[entry.key], entry.value, reason: '${entry.key} drifted from the web contract — re-copy openapi/mobile-v1.json and fix ApiClient');
    }
  });
}
