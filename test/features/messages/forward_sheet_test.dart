import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fakes/fake_messages_repository.dart';
import '../../support/pump_conversation.dart';

DateTime _ago(Duration d) => kNow.subtract(d);

Future<void> _openForward(WidgetTester tester, String messageId) async {
  await tester.longPress(find.byKey(Key('dm-msg-$messageId')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('dm-action-forward')));
  await tester.pumpAndSettle();
}

FakeMessagesRepository _repo({List<dynamic> others = const ['t2', 't3']}) => FakeMessagesRepository(
      inbox: [thread('t1'), for (final o in others) thread(o as String)],
    )..messagesByThread['t1'] = [
        dmMsg('m1', body: 'forward me', at: _ago(const Duration(minutes: 5))),
        dmMsg('gone', deletedAt: _ago(const Duration(minutes: 1)), at: _ago(const Duration(minutes: 2))),
      ];

void main() {
  testWidgets('the sheet lists inbox threads except the current one', (tester) async {
    await pumpConversation(tester, _repo());
    await _openForward(tester, 'm1');
    expect(find.byKey(const Key('dm-forward-t2')), findsOneWidget);
    expect(find.byKey(const Key('dm-forward-t3')), findsOneWidget);
    expect(find.byKey(const Key('dm-forward-t1')), findsNothing);
  });

  testWidgets('with no other conversations the sheet shows its empty copy', (tester) async {
    await pumpConversation(tester, _repo(others: const []));
    await _openForward(tester, 'm1');
    expect(find.byKey(const Key('dm-forward-empty')), findsOneWidget);
  });

  testWidgets('choosing a thread forwards (messageId, toThreadId) with a key, closes the sheet and confirms', (tester) async {
    final repo = _repo();
    await pumpConversation(tester, repo);
    await _openForward(tester, 'm1');
    await tester.tap(find.byKey(const Key('dm-forward-t2')));
    await tester.pumpAndSettle();
    expect(repo.forwardCalls.single.messageId, 'm1');
    expect(repo.forwardCalls.single.toThreadId, 't2');
    expect(repo.forwardCalls.single.key, isNotEmpty);
    expect(find.byKey(const Key('dm-forward-t2')), findsNothing);
    expect(find.text('Message forwarded'), findsOneWidget);
  });

  testWidgets('a second tap while the first forward is in flight is ignored', (tester) async {
    final repo = _repo();
    await pumpConversation(tester, repo);
    await _openForward(tester, 'm1');
    final gate = Completer<void>();
    repo.holds['forward'] = gate;
    await tester.tap(find.byKey(const Key('dm-forward-t2')));
    await tester.tap(find.byKey(const Key('dm-forward-t3')), warnIfMissed: false);
    await tester.pump();
    gate.complete();
    await tester.pumpAndSettle();
    expect(repo.forwardCalls, hasLength(1));
  });

  testWidgets('not_forwardable shows its copy', (tester) async {
    final repo = _repo()..failures['forward'] = apiError('not_forwardable', status: 409);
    await pumpConversation(tester, repo);
    await _openForward(tester, 'm1');
    await tester.tap(find.byKey(const Key('dm-forward-t2')));
    await tester.pumpAndSettle();
    expect(find.text("This message can't be forwarded."), findsOneWidget);
  });

  testWidgets('request_media_not_allowed and blocked use their own copy', (tester) async {
    final repo = _repo()..failures['forward'] = apiError('request_media_not_allowed');
    await pumpConversation(tester, repo);
    await _openForward(tester, 'm1');
    await tester.tap(find.byKey(const Key('dm-forward-t2')));
    await tester.pumpAndSettle();
    expect(find.text('Photos, stickers and voice notes unlock once they accept your request.'), findsOneWidget);
  });

  testWidgets('Forward is hidden on removed messages', (tester) async {
    await pumpConversation(tester, _repo());
    await tester.longPress(find.byKey(const Key('dm-msg-gone')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('dm-action-forward')), findsNothing);
  });
}
