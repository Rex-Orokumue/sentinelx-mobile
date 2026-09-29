import 'dart:async';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/features/community/community_realtime.dart';

void main() {
  test('coalesces multiple rapid emissions across sources into one signal after the debounce window', () {
    fakeAsync((async) {
      final a = StreamController<int>();
      final b = StreamController<int>();
      var emitted = 0;
      final sub = debouncedChangeSignal([a.stream, b.stream]).listen((_) => emitted++);
      async.elapse(Duration.zero); // let the merge subscribe
      a.add(1);
      async.elapse(const Duration(milliseconds: 100));
      b.add(1);
      async.elapse(const Duration(milliseconds: 100));
      a.add(1);
      async.elapse(const Duration(milliseconds: 399));
      expect(emitted, 0, reason: 'still inside the debounce window since the last emission');
      async.elapse(const Duration(milliseconds: 1));
      expect(emitted, 1);
      sub.cancel();
      a.close();
      b.close();
    });
  });

  test('a second burst after the first signal fires produces a second signal', () {
    fakeAsync((async) {
      final a = StreamController<int>();
      var emitted = 0;
      final sub = debouncedChangeSignal([a.stream]).listen((_) => emitted++);
      async.elapse(Duration.zero);
      a.add(1);
      async.elapse(const Duration(milliseconds: 400));
      expect(emitted, 1);
      a.add(1);
      async.elapse(const Duration(milliseconds: 400));
      expect(emitted, 2);
      sub.cancel();
      a.close();
    });
  });

  test('cancelling the subscription tears down every source subscription and the timer', () {
    fakeAsync((async) {
      final a = StreamController<int>();
      var emitted = 0;
      final sub = debouncedChangeSignal([a.stream]).listen((_) => emitted++);
      async.elapse(Duration.zero);
      sub.cancel();
      a.add(1); // after cancel — must never schedule a late emission
      async.elapse(const Duration(seconds: 2));
      expect(emitted, 0);
      expect(a.hasListener, isFalse);
      a.close();
    });
  });
}
