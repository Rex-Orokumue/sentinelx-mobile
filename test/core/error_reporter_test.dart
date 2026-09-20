import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/core/errors/error_reporter.dart';

void main() {
  test('sends message, stack and route', () async {
    final sent = <List<String?>>[];
    final r = ErrorReporter((m, s, route) async => sent.add([m, s, route]));
    await r.report(StateError('boom'), StackTrace.fromString('trace'), route: '/x');
    expect(sent.single[0], contains('boom'));
    expect(sent.single[1], 'trace');
    expect(sent.single[2], '/x');
  });

  test('never throws even when the sender fails', () async {
    final r = ErrorReporter((m, s, route) async => throw Exception('network down'));
    await r.report(Exception('a'), null);
  });

  test('skips an immediately repeated identical message', () async {
    var n = 0;
    final r = ErrorReporter((m, s, route) async => n++);
    await r.report(Exception('same'), null);
    await r.report(Exception('same'), null);
    await r.report(Exception('different'), null);
    expect(n, 2);
  });

  test('caps reports per run', () async {
    var n = 0;
    final r = ErrorReporter((m, s, route) async => n++, maxReports: 3);
    for (var i = 0; i < 10; i++) {
      await r.report(Exception('e$i'), null);
    }
    expect(n, 3);
  });
}
