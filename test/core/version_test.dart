import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/core/utils/version.dart';

void main() {
  test('orders dotted numeric versions', () {
    expect(compareVersions('1.0.0', '1.0.1'), -1);
    expect(compareVersions('1.2.0', '1.1.9'), 1);
    expect(compareVersions('2.0.0', '2.0.0'), 0);
  });
  test('compares numerically, not lexically', () => expect(compareVersions('1.10.0', '1.9.0'), 1));
  test('ignores the +build suffix', () => expect(compareVersions('1.0.0+45', '1.0.0'), 0));
  test('treats missing segments as zero', () {
    expect(compareVersions('1.0', '1.0.0'), 0);
    expect(compareVersions('1', '1.0.1'), -1);
  });
  test('treats an unparseable version as 0.0.0', () => expect(compareVersions('garbage', '0.0.1'), -1));
}
