import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/core/api/messages_models.dart';

import '../../fakes/fake_messages_repository.dart';
import 'inbox_screen_test.dart' show pumpInbox;

void main() {
  testWidgets('the requests screen reads the requests box and marks each row as a request', (tester) async {
    final repo = FakeMessagesRepository(
      inbox: [thread('inbox-only')],
      requests: [
        thread('q1', name: 'Quinn', requestState: RequestState.pending, direction: RequestDirection.incoming),
        thread('q2', name: 'Quill', requestState: RequestState.pending, direction: RequestDirection.incoming),
      ],
      requestCount: 2,
    );
    await pumpInbox(tester, repo, location: '/messages/requests');
    expect(find.text('Message requests'), findsOneWidget);
    expect(find.byKey(const Key('dm-thread-q1')), findsOneWidget);
    expect(find.byKey(const Key('dm-request-chip-q1')), findsOneWidget);
    expect(find.byKey(const Key('dm-thread-inbox-only')), findsNothing);
    expect(repo.threadsCalls.every((c) => c.cursor == null && c.box.wire == 'requests'), isTrue);
  });

  testWidgets('an empty requests box shows its own empty state', (tester) async {
    await pumpInbox(tester, FakeMessagesRepository(), location: '/messages/requests');
    expect(find.text('No message requests.'), findsOneWidget);
  });

  testWidgets('tapping a request opens its thread', (tester) async {
    final repo = FakeMessagesRepository(requests: [thread('q1', requestState: RequestState.pending, direction: RequestDirection.incoming)], requestCount: 1);
    await pumpInbox(tester, repo, location: '/messages/requests');
    await tester.tap(find.byKey(const Key('dm-thread-q1')));
    await tester.pumpAndSettle();
    expect(find.text('THREAD q1'), findsOneWidget);
  });
}
