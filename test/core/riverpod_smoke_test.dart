import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final _failing = FutureProvider.autoDispose<int>((ref) async => throw Exception('boom'));

void main() {
  testWidgets('a failing FutureProvider surfaces its error at once when retry is disabled', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        retry: (_, _) => null,
        child: MaterialApp(
          home: Consumer(
            builder: (context, ref, _) => ref.watch(_failing).when(
                  data: (v) => Text('$v'),
                  loading: () => const Text('loading'),
                  error: (e, _) => const Text('error'),
                ),
          ),
        ),
      ),
    );
    expect(find.text('loading'), findsOneWidget);
    await tester.pump();
    expect(find.text('error'), findsOneWidget);
  });
}
