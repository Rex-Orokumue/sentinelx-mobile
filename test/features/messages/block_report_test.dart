import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/core/api/messages_models.dart';

import '../../fakes/fake_messages_repository.dart';
import '../../support/pump_conversation.dart';

FakeMessagesRepository _repo({ThreadHeader? header}) {
  final r = FakeMessagesRepository(inbox: [thread('t1')])
    ..headers['t1'] = header ?? _open()
    ..messagesByThread['t1'] = [
      dmMsg('theirs', body: 'their words', at: kNow.subtract(const Duration(minutes: 3))),
      dmMsg('mine', sender: 'me', body: 'my words', at: kNow.subtract(const Duration(minutes: 4))),
    ];
  return r;
}

ThreadHeader _open() => header('t1', name: 'Ada', otherId: 'ada-id');
ThreadHeader _blockedByMe() => header('t1', name: 'Ada', otherId: 'ada-id', blockedByMe: true);

Future<void> _menu(WidgetTester tester, String item) async {
  await tester.tap(find.byKey(const Key('dm-menu')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(Key(item)));
  await tester.pumpAndSettle();
}

void main() {
  group('block', () {
    testWidgets('asks for confirmation; cancelling does nothing', (tester) async {
      final repo = _repo();
      await pumpConversation(tester, repo);
      await _menu(tester, 'dm-menu-block');
      expect(find.text('Block Ada?'), findsOneWidget);
      await tester.tap(find.byKey(const Key('dm-block-cancel')));
      await tester.pumpAndSettle();
      expect(repo.blockCalls, isEmpty);
      expect(find.byKey(const Key('dm-composer')), findsOneWidget);
    });

    testWidgets('confirming blocks the other player once even on a double tap, and the composer becomes the blocked banner', (tester) async {
      final repo = _repo();
      await pumpConversation(tester, repo);
      await _menu(tester, 'dm-menu-block');
      repo.headers['t1'] = _blockedByMe(); // what the server reports once the block lands
      await tester.tap(find.byKey(const Key('dm-block-confirm')));
      await tester.tap(find.byKey(const Key('dm-block-confirm')), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(repo.blockCalls, ['ada-id']);
      expect(find.byKey(const Key('dm-composer')), findsNothing);
      expect(find.text('You blocked Ada'), findsOneWidget);
      expect(find.byKey(const Key('dm-unblock')), findsOneWidget);
    });

    testWidgets('blocked by them shows the cannot-message copy with no Unblock', (tester) async {
      await pumpConversation(tester, _repo(header: header('t1', name: 'Ada', blockedByThem: true)));
      expect(find.byKey(const Key('dm-blocked-banner')), findsOneWidget);
      expect(find.text("You can't message this player."), findsOneWidget);
      expect(find.byKey(const Key('dm-unblock')), findsNothing);
    });

    testWidgets('Unblock calls unblock and restores the composer', (tester) async {
      final repo = _repo(header: _blockedByMe());
      await pumpConversation(tester, repo);
      expect(find.byKey(const Key('dm-composer')), findsNothing);
      repo.headers['t1'] = _open();
      await tester.tap(find.byKey(const Key('dm-unblock')));
      await tester.pumpAndSettle();
      expect(repo.unblockCalls, ['ada-id']);
      expect(find.byKey(const Key('dm-composer')), findsOneWidget);
      expect(find.byKey(const Key('dm-blocked-banner')), findsNothing);
    });

    testWidgets('a block failure shows the mapped copy', (tester) async {
      final repo = _repo()..failures['block'] = apiError('action_failed', status: 500);
      await pumpConversation(tester, repo);
      await _menu(tester, 'dm-menu-block');
      await tester.tap(find.byKey(const Key('dm-block-confirm')));
      await tester.pumpAndSettle();
      expect(find.text("That didn't work. Please try again."), findsOneWidget);
      expect(find.byKey(const Key('dm-composer')), findsOneWidget);
    });

    testWidgets('a send rejected as blocked flips the banner once the header refetches', (tester) async {
      final repo = _repo()..failures['send'] = apiError('blocked', status: 403);
      await pumpConversation(tester, repo);
      repo.headers['t1'] = header('t1', name: 'Ada', blockedByThem: true);
      await tester.enterText(find.byKey(const Key('dm-input')), 'hello?');
      await tester.pump();
      await tester.tap(find.byKey(const Key('dm-send')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('dm-blocked-banner')), findsOneWidget);
      expect(find.byKey(const Key('dm-composer')), findsNothing);
    });
  });

  group('report', () {
    Future<void> openReport(WidgetTester tester) => _menu(tester, 'dm-menu-report');

    testWidgets('Submit is disabled for empty and for 1001 characters, enabled at 1 and at 1000', (tester) async {
      await pumpConversation(tester, _repo());
      await openReport(tester);
      bool enabled() => tester.widget<FilledButton>(find.byKey(const Key('dm-report-submit'))).onPressed != null;
      expect(enabled(), isFalse);
      await tester.enterText(find.byKey(const Key('dm-report-input')), 'x');
      await tester.pump();
      expect(enabled(), isTrue);
      await tester.enterText(find.byKey(const Key('dm-report-input')), 'x' * 1000);
      await tester.pump();
      expect(enabled(), isTrue);
      await tester.enterText(find.byKey(const Key('dm-report-input')), 'x' * 1001);
      await tester.pump();
      expect(enabled(), isFalse);
      await tester.enterText(find.byKey(const Key('dm-report-input')), '   ');
      await tester.pump();
      expect(enabled(), isFalse, reason: 'whitespace only is empty');
    });

    testWidgets('from the menu it reports the thread with no message id, then confirms', (tester) async {
      final repo = _repo();
      await pumpConversation(tester, repo);
      await openReport(tester);
      await tester.enterText(find.byKey(const Key('dm-report-input')), 'spamming me');
      await tester.pump();
      await tester.tap(find.byKey(const Key('dm-report-submit')));
      await tester.pumpAndSettle();
      expect(repo.reportCalls.single, (threadId: 't1', messageId: null, reason: 'spamming me'));
      expect(find.text("Thanks. We'll review your report."), findsOneWidget);
    });

    testWidgets("from a message's actions it passes that message id (theirs only)", (tester) async {
      final repo = _repo();
      await pumpConversation(tester, repo);
      await tester.longPress(find.byKey(const Key('dm-msg-theirs')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('dm-action-report')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('dm-report-input')), 'abuse');
      await tester.pump();
      await tester.tap(find.byKey(const Key('dm-report-submit')));
      await tester.pumpAndSettle();
      expect(repo.reportCalls.single.messageId, 'theirs');

      await tester.longPress(find.byKey(const Key('dm-msg-mine')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('dm-action-report')), findsNothing);
    });

    testWidgets('a failed report shows the mapped copy', (tester) async {
      final repo = _repo()..failures['report'] = apiError('validation');
      await pumpConversation(tester, repo);
      await openReport(tester);
      await tester.enterText(find.byKey(const Key('dm-report-input')), 'abuse');
      await tester.pump();
      await tester.tap(find.byKey(const Key('dm-report-submit')));
      await tester.pumpAndSettle();
      expect(find.text("That message isn't valid."), findsOneWidget);
    });
  });

  testWidgets('French smoke: menu, banner and confirm copy', (tester) async {
    await pumpConversation(tester, _repo(header: _blockedByMe()), locale: const Locale('fr'));
    expect(find.text('Vous avez bloqué Ada'), findsOneWidget);
    expect(find.text('Débloquer'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
