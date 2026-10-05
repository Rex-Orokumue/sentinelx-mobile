import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/core/api/messages_models.dart';
import 'package:sentinelx_mobile/features/messages/inbox_providers.dart';
import 'package:sentinelx_mobile/features/messages/messages_repository.dart';
import 'package:sentinelx_mobile/features/messages/request_view.dart';
import 'package:sentinelx_mobile/features/messages/thread_providers.dart';

import '../../fakes/fake_messages_repository.dart';
import '../../support/pump_conversation.dart';

DateTime _ago(Duration d) => kNow.subtract(d);

ThreadHeader _incoming() => header('t1', name: 'Quinn', otherId: 'quinn-id', requestState: RequestState.pending, direction: RequestDirection.incoming);
ThreadHeader _outgoing() => header('t1', name: 'Ada', otherId: 'ada-id', requestState: RequestState.pending, direction: RequestDirection.outgoing);

FakeMessagesRepository _repo(ThreadHeader h, {bool mineSent = false}) => FakeMessagesRepository(inbox: [thread('t1')])
  ..headers['t1'] = h
  ..messagesByThread['t1'] = [
    if (mineSent) dmMsg('first', sender: 'me', body: 'hello?', at: _ago(const Duration(minutes: 2))),
    if (!mineSent) dmMsg('theirs', body: 'hey, add me', at: _ago(const Duration(minutes: 2))),
  ];

void main() {
  group('incoming request (preview-only)', () {
    testWidgets('no composer, three actions, and no markRead over 60 s or after a nudge', (tester) async {
      final repo = _repo(_incoming());
      final rig = await pumpConversation(tester, repo);
      expect(find.byKey(const Key('dm-composer')), findsNothing);
      expect(find.byKey(const Key('dm-accept')), findsOneWidget);
      expect(find.byKey(const Key('dm-decline')), findsOneWidget);
      expect(find.byKey(const Key('dm-block-report')), findsOneWidget);
      expect(find.text('Quinn wants to message you'), findsOneWidget);
      expect(find.text('hey, add me'), findsOneWidget, reason: 'the message is readable');
      await tester.pump(const Duration(seconds: 60));
      repo.messagesByThread['t1']!.insert(0, dmMsg('more', body: 'still there?', at: _ago(const Duration(minutes: 1))));
      await rig.nudge(tester);
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
      expect(find.text('still there?'), findsOneWidget);
      expect(repo.markReadCalls, isEmpty);
      expect(repo.markAllDeliveredCalls, 0, reason: 'a pending request stamps nothing, delivered included');
    });

    testWidgets('Accept calls accept once (even on a double tap), then the composer appears and markRead fires once', (tester) async {
      final repo = _repo(_incoming());
      await pumpConversation(tester, repo);
      repo.headers['t1'] = header('t1', name: 'Quinn', otherId: 'quinn-id'); // accepted now
      await tester.tap(find.byKey(const Key('dm-accept')));
      await tester.tap(find.byKey(const Key('dm-accept')), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(repo.acceptCalls, ['t1']);
      expect(find.byKey(const Key('dm-composer')), findsOneWidget);
      expect(find.byKey(const Key('dm-incoming-request')), findsNothing);
      expect(repo.markReadCalls, ['t1']);
    });

    testWidgets('Decline calls decline and leaves the thread', (tester) async {
      final repo = _repo(_incoming());
      final rig = await pumpConversation(tester, repo);
      rig.router.go('/');
      await tester.pumpAndSettle();
      rig.router.push<void>('/messages/t1').ignore();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('dm-decline')));
      await tester.pumpAndSettle();
      expect(repo.declineCalls, ['t1']);
      expect(find.text('HOME'), findsOneWidget);
    });

    testWidgets('Block and report runs the block flow and then opens the report sheet', (tester) async {
      final repo = _repo(_incoming());
      await pumpConversation(tester, repo);
      await tester.tap(find.byKey(const Key('dm-block-report')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('dm-block-confirm')));
      await tester.pumpAndSettle();
      expect(repo.blockCalls, ['quinn-id']);
      expect(find.byKey(const Key('dm-report-input')), findsOneWidget);
    });

    testWidgets('the request count in the inbox drops after Accept', (tester) async {
      final repo = _repo(_incoming())..requestCount = 1;
      final rig = await pumpConversation(tester, repo);
      rig.container.listen(inboxProvider, (_, _) {});
      await rig.container.read(inboxProvider.future);
      expect(rig.container.read(inboxProvider).value!.requestCount, 1);
      repo.requestCount = 0;
      repo.headers['t1'] = header('t1', name: 'Quinn', otherId: 'quinn-id');
      await tester.tap(find.byKey(const Key('dm-accept')));
      await tester.pumpAndSettle();
      expect(rig.container.read(inboxProvider).value!.requestCount, 0);
    });
  });

  group('outgoing request (waiting)', () {
    testWidgets('the composer is text only: no sticker or photo buttons', (tester) async {
      await pumpConversation(tester, _repo(_outgoing()));
      expect(find.byKey(const Key('dm-input')), findsOneWidget);
      expect(find.byKey(const Key('dm-sticker-button')), findsNothing);
      expect(find.byKey(const Key('dm-photo-button')), findsNothing);
    });

    testWidgets('after the first message the composer is replaced by the waiting banner', (tester) async {
      final repo = _repo(_outgoing());
      await pumpConversation(tester, repo);
      await tester.enterText(find.byKey(const Key('dm-input')), 'hi Ada');
      await tester.pump();
      await tester.tap(find.byKey(const Key('dm-send')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('dm-composer')), findsNothing);
      expect(find.text('Waiting for Ada to accept'), findsOneWidget);
    });

    testWidgets('a forced second send is refused with the request-limit copy and a Discard-only bubble', (tester) async {
      final repo = _repo(_outgoing(), mineSent: true)..failures['send'] = apiError('request_pending_limit', status: 409);
      final rig = await pumpConversation(tester, repo);
      await rig.container.read(threadProvider('t1').notifier).send(const SendDraft(body: 'again'));
      await tester.pumpAndSettle();
      expect(find.text('You can send one message until they accept your request.'), findsOneWidget);
      expect(find.byKey(const Key('dm-retry-local-0')), findsNothing);
      expect(find.byKey(const Key('dm-discard-local-0')), findsOneWidget);
    });

    testWidgets('the poll asks every 25 s while visible, and the composer returns with all buttons once accepted', (tester) async {
      final repo = _repo(_outgoing(), mineSent: true);
      await pumpConversation(tester, repo);
      expect(find.byKey(const Key('dm-waiting-banner')), findsOneWidget);
      final base = repo.threadCalls.length;
      await tester.pump(const Duration(seconds: 24));
      expect(repo.threadCalls.length, base);
      await tester.pump(const Duration(seconds: 2));
      await tester.pump();
      expect(repo.threadCalls.length, base + 1);
      repo.headers['t1'] = header('t1', name: 'Ada', otherId: 'ada-id'); // accepted
      await tester.pump(const Duration(seconds: 25));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('dm-composer')), findsOneWidget);
      expect(find.byKey(const Key('dm-sticker-button')), findsOneWidget);
      final after = repo.threadCalls.length;
      await tester.pump(const Duration(seconds: 100));
      expect(repo.threadCalls.length, after, reason: 'the poll stops the moment the state leaves outgoing-pending');
    });

    testWidgets('the poll does not run while the app is paused, and refetches on resume', (tester) async {
      final repo = _repo(_outgoing(), mineSent: true);
      await pumpConversation(tester, repo);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      final base = repo.threadCalls.length;
      await tester.pump(const Duration(seconds: 120));
      expect(repo.threadCalls.length, base);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(repo.threadCalls.length, greaterThan(base));
    });

    testWidgets('the poll stops after the screen is popped', (tester) async {
      final repo = _repo(_outgoing(), mineSent: true);
      final rig = await pumpConversation(tester, repo);
      rig.router.go('/');
      await tester.pumpAndSettle();
      final base = repo.threadCalls.length;
      await tester.pump(const Duration(seconds: 120));
      expect(repo.threadCalls.length, base);
    });

    testWidgets('an accepted thread never polls', (tester) async {
      final repo = _repo(header('t1', name: 'Ada'), mineSent: true);
      await pumpConversation(tester, repo);
      final base = repo.threadCalls.length;
      await tester.pump(const Duration(seconds: 120));
      expect(repo.threadCalls.length, base);
    });

    testWidgets('a poll that finds blockedByThem shows the same text as a block, and no "declined" word', (tester) async {
      final repo = _repo(_outgoing(), mineSent: true);
      await pumpConversation(tester, repo);
      repo.headers['t1'] = header('t1', name: 'Ada', blockedByThem: true);
      await tester.pump(const Duration(seconds: 26));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('dm-blocked-banner')), findsOneWidget);
      expect(find.text("You can't message this player."), findsOneWidget);
      expect(find.textContaining(RegExp('declin', caseSensitive: false)), findsNothing);
    });
  });

  group('state mapping', () {
    testWidgets('an unknown request state renders as accepted', (tester) async {
      final repo = _repo(header('t1', name: 'Ada', requestState: RequestState.unknown));
      await pumpConversation(tester, repo);
      expect(find.byKey(const Key('dm-composer')), findsOneWidget);
    });

    testWidgets('a declined request renders as blocked-by-them', (tester) async {
      final repo = _repo(header('t1', name: 'Ada', requestState: RequestState.declined));
      await pumpConversation(tester, repo);
      expect(find.byKey(const Key('dm-blocked-banner')), findsOneWidget);
      expect(find.text("You can't message this player."), findsOneWidget);
    });

    test('threadModeFor covers every combination', () {
      expect(threadModeFor(header('t')), ThreadMode.open);
      expect(threadModeFor(header('t', requestState: RequestState.unknown)), ThreadMode.open);
      expect(threadModeFor(header('t', blockedByMe: true)), ThreadMode.blocked);
      expect(threadModeFor(header('t', blockedByThem: true)), ThreadMode.blocked);
      expect(threadModeFor(header('t', requestState: RequestState.declined)), ThreadMode.blocked);
      expect(threadModeFor(_incoming()), ThreadMode.incomingRequest);
      expect(threadModeFor(_outgoing()), ThreadMode.outgoingRequest);
      expect(threadModeFor(header('t', requestState: RequestState.pending)), ThreadMode.open, reason: 'pending with no direction: nothing to wait for');
    });
  });

  test('no string a player can reach from the request screens says "declined" (en and fr)', () {
    for (final lang in ['en', 'fr']) {
      final arb = jsonDecode(File('lib/core/l10n/app_$lang.arb').readAsStringSync()) as Map<String, dynamic>;
      for (final e in arb.entries) {
        if (!e.key.startsWith('dm') || e.value is! String) continue;
        expect((e.value as String).toLowerCase(), isNot(contains('declined')), reason: '$lang ${e.key}');
        expect((e.value as String).toLowerCase(), isNot(matches(RegExp(r'refus(é|ée|és|ées)\b'))), reason: '$lang ${e.key}');
      }
    }
  });
}
