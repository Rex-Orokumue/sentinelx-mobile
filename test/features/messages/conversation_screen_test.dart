import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/core/api/messages_models.dart';
import 'package:sentinelx_mobile/features/messages/composer.dart';
import 'package:sentinelx_mobile/features/messages/thread_providers.dart';

import '../../fakes/fake_messages_repository.dart';
import '../../support/pump_conversation.dart';

DateTime _ago(Duration d) => kNow.subtract(d);

FakeMessagesRepository _repo(List<DmMessage> msgs, {ThreadHeader? header}) {
  final r = FakeMessagesRepository()..messagesByThread['t1'] = msgs;
  if (header != null) r.headers['t1'] = header;
  return r;
}

Finder _semLabel(String label) => find.byWidgetPredicate((w) => w is Semantics && w.properties.label == label);

void main() {
  testWidgets('messages render newest at the bottom with date separators', (tester) async {
    final repo = _repo([
      dmMsg('new', body: 'newest text', at: _ago(const Duration(minutes: 1))),
      dmMsg('old', body: 'older text', at: _ago(const Duration(hours: 26))),
    ]);
    await pumpConversation(tester, repo);
    expect(tester.getTopLeft(find.text('newest text')).dy, greaterThan(tester.getTopLeft(find.text('older text')).dy));
    expect(find.text('Today'), findsOneWidget);
    expect(find.text('Yesterday'), findsOneWidget);
  });

  testWidgets('removed, unknown, forwarded, edited and reply-to-removed bubbles render without throwing', (tester) async {
    final repo = _repo([
      dmMsg('removed', deletedAt: _ago(const Duration(minutes: 1)), at: _ago(const Duration(minutes: 2))),
      DmMessage(id: 'unknown', senderId: 'them', createdAt: _ago(const Duration(minutes: 3))),
      dmMsg('fwd', body: 'forwarded body', forwarded: true, at: _ago(const Duration(minutes: 4))),
      dmMsg('edited', sender: 'me', body: 'edited body', editedAt: _ago(const Duration(minutes: 1)), at: _ago(const Duration(minutes: 5))),
      dmMsg('reply', body: 'reply body', replyTo: const ReplyPreview(id: 'gone', senderName: null, removed: true), at: _ago(const Duration(minutes: 6))),
      dmMsg('badsticker', stickerId: 'bogus', at: _ago(const Duration(minutes: 7))),
    ]);
    await pumpConversation(tester, repo);
    expect(find.text('Message removed'), findsOneWidget);
    expect(find.text('Unsupported message'), findsOneWidget);
    expect(find.text('Forwarded'), findsOneWidget);
    expect(find.text('edited'), findsOneWidget);
    expect(find.text('Original message removed'), findsOneWidget);
    expect(find.byKey(const Key('dm-sticker-unknown')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ticks: sent, delivered, read on mine; none on theirs; labels differ per state', (tester) async {
    final at = _ago(const Duration(minutes: 1));
    final repo = _repo([
      dmMsg('read', sender: 'me', body: 'a', at: at, deliveredAt: at, readAt: at),
      dmMsg('delivered', sender: 'me', body: 'b', at: at, deliveredAt: at),
      dmMsg('sent', sender: 'me', body: 'c', at: at),
      dmMsg('theirs', sender: 'them', body: 'd', at: at),
    ]);
    await pumpConversation(tester, repo);
    expect(find.byKey(const Key('dm-receipt-read')), findsOneWidget);
    expect(find.byKey(const Key('dm-receipt-delivered')), findsOneWidget);
    expect(find.byKey(const Key('dm-receipt-sent')), findsOneWidget);
    expect(find.byKey(const Key('dm-receipt-theirs')), findsNothing);
    expect(_semLabel('Read'), findsOneWidget);
    expect(_semLabel('Delivered'), findsOneWidget);
    expect(_semLabel('Sent'), findsOneWidget);
    expect(tester.widget<Icon>(find.byKey(const Key('dm-receipt-sent'))).icon, Icons.done);
    expect(tester.widget<Icon>(find.byKey(const Key('dm-receipt-read'))).icon, Icons.done_all);
  });

  testWidgets('long unbroken text and a very long name do not overflow at 375x800', (tester) async {
    final repo = _repo(
      [dmMsg('a', body: 'x' * 600, at: _ago(const Duration(minutes: 1))), dmMsg('b', sender: 'me', body: 'word ' * 150, at: _ago(const Duration(minutes: 2)))],
      header: header('t1', name: 'N' * 150),
    );
    await pumpConversation(tester, repo);
    expect(tester.takeException(), isNull);
  });

  group('sending', () {
    testWidgets('a pending bubble shows at once, then the confirmed message replaces it', (tester) async {
      final repo = _repo([dmMsg('a', body: 'hi', at: _ago(const Duration(minutes: 5)))]);
      await pumpConversation(tester, repo);
      final gate = Completer<void>();
      repo.holds['send'] = gate;
      await tester.enterText(find.byKey(const Key('dm-input')), 'hello there');
      await tester.pump();
      await tester.tap(find.byKey(const Key('dm-send')));
      await tester.pump();
      expect(find.byKey(const Key('dm-pending-local-0')), findsOneWidget);
      expect(find.text('hello there'), findsOneWidget);
      gate.complete();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('dm-pending-local-0')), findsNothing);
      expect(find.byKey(const Key('dm-msg-srv-1')), findsOneWidget);
      expect(find.text('hello there'), findsOneWidget);
    });

    testWidgets('double-tapping Send creates one pending item and one request', (tester) async {
      final repo = _repo([dmMsg('a', body: 'hi', at: _ago(const Duration(minutes: 5)))]);
      await pumpConversation(tester, repo);
      repo.holds['send'] = Completer<void>();
      await tester.enterText(find.byKey(const Key('dm-input')), 'once');
      await tester.pump();
      await tester.tap(find.byKey(const Key('dm-send')));
      await tester.tap(find.byKey(const Key('dm-send')), warnIfMissed: false);
      await tester.pump();
      expect(find.byKey(const Key('dm-pending-local-0')), findsOneWidget);
      expect(find.byKey(const Key('dm-pending-local-1')), findsNothing);
      expect(repo.sendCalls, hasLength(1));
    });

    testWidgets('a failed send shows Retry; tapping it twice quickly sends once more with the same key', (tester) async {
      final repo = _repo([dmMsg('a', body: 'hi', at: _ago(const Duration(minutes: 5)))]);
      await pumpConversation(tester, repo);
      repo.failures['send'] = networkError;
      await tester.enterText(find.byKey(const Key('dm-input')), 'flaky');
      await tester.pump();
      await tester.tap(find.byKey(const Key('dm-send')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('dm-retry-local-0')), findsOneWidget);
      repo.failures.clear();
      repo.holds['send'] = Completer<void>();
      await tester.tap(find.byKey(const Key('dm-retry-local-0')));
      await tester.tap(find.byKey(const Key('dm-retry-local-0')), warnIfMissed: false);
      await tester.pump();
      expect(repo.sendCalls, hasLength(2));
      expect(repo.sendCalls[0].key, repo.sendCalls[1].key);
    });

    testWidgets('a non-retryable failure hides Retry and keeps Discard', (tester) async {
      final repo = _repo([dmMsg('a', body: 'hi', at: _ago(const Duration(minutes: 5)))]);
      await pumpConversation(tester, repo);
      repo.failures['send'] = apiError('request_pending_limit', status: 409);
      await tester.enterText(find.byKey(const Key('dm-input')), 'second');
      await tester.pump();
      await tester.tap(find.byKey(const Key('dm-send')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('dm-retry-local-0')), findsNothing);
      expect(find.byKey(const Key('dm-discard-local-0')), findsOneWidget);
      expect(find.text('You can send one message until they accept your request.'), findsOneWidget);
      await tester.tap(find.byKey(const Key('dm-discard-local-0')));
      await tester.pump();
      expect(find.byKey(const Key('dm-pending-local-0')), findsNothing);
    });

    testWidgets('the reply flow sets replyToId, shows the quote on the bubble and clears after send', (tester) async {
      final repo = _repo([dmMsg('orig', body: 'original words', at: _ago(const Duration(minutes: 5)))]);
      await pumpConversation(tester, repo);
      await tester.longPress(find.byKey(const Key('dm-msg-orig')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('dm-action-reply')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('dm-reply-bar')), findsOneWidget);
      await tester.enterText(find.byKey(const Key('dm-input')), 'my answer');
      await tester.pump();
      await tester.tap(find.byKey(const Key('dm-send')));
      await tester.pumpAndSettle();
      expect(repo.sendCalls.single.draft.replyToId, 'orig');
      expect(find.byKey(const Key('dm-reply-bar')), findsNothing);
    });

    testWidgets('the 2000-character limit is enforced and the counter appears near it', (tester) async {
      await pumpConversation(tester, _repo([dmMsg('a', body: 'hi', at: _ago(const Duration(minutes: 5)))]));
      await tester.enterText(find.byKey(const Key('dm-input')), 'x' * 2100);
      await tester.pump();
      await tester.pump();
      expect(tester.widget<TextField>(find.byKey(const Key('dm-input'))).controller!.text.length, kMaxMessageChars);
      expect(find.byKey(const Key('dm-counter')), findsOneWidget);
    });

    testWidgets('a draft survives pop and re-push', (tester) async {
      final repo = _repo([dmMsg('a', body: 'hi', at: _ago(const Duration(minutes: 5)))]);
      final rig = await pumpConversation(tester, repo);
      await tester.enterText(find.byKey(const Key('dm-input')), 'half typed');
      await tester.pump();
      rig.router.go('/');
      await tester.pumpAndSettle();
      rig.router.go('/messages/t1');
      await tester.pumpAndSettle();
      expect(find.text('half typed'), findsOneWidget);
    });
  });

  group('edit, unsend and copy', () {
    Future<ConvRig> pumpMine(WidgetTester tester, {Duration age = const Duration(minutes: 5), FakeMessagesRepository? repo}) {
      final r = repo ?? _repo([dmMsg('mine', sender: 'me', body: 'my words', at: _ago(age))]);
      return pumpConversation(tester, r);
    }

    testWidgets('Edit and Unsend appear on my text message at 9:59 and are gone at 10:01', (tester) async {
      await pumpMine(tester, age: const Duration(minutes: 9, seconds: 59));
      await tester.longPress(find.byKey(const Key('dm-msg-mine')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('dm-action-edit')), findsOneWidget);
      expect(find.byKey(const Key('dm-action-unsend')), findsOneWidget);

      await pumpMine(tester, age: const Duration(minutes: 10, seconds: 1));
      await tester.longPress(find.byKey(const Key('dm-msg-mine')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('dm-action-edit')), findsNothing);
      expect(find.byKey(const Key('dm-action-unsend')), findsNothing);
      expect(find.byKey(const Key('dm-action-reply')), findsOneWidget);
    });

    testWidgets('never on their messages, on removed ones, and Edit never on a sticker', (tester) async {
      final repo = _repo([
        dmMsg('theirs', body: 'their words', at: _ago(const Duration(minutes: 1))),
        dmMsg('gone', sender: 'me', deletedAt: _ago(const Duration(minutes: 1)), at: _ago(const Duration(minutes: 2))),
        dmMsg('sticker', sender: 'me', stickerId: 'gg', at: _ago(const Duration(minutes: 3))),
      ]);
      await pumpConversation(tester, repo);
      await tester.longPress(find.byKey(const Key('dm-msg-theirs')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('dm-action-edit')), findsNothing);
      expect(find.byKey(const Key('dm-action-unsend')), findsNothing);
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      await tester.longPress(find.byKey(const Key('dm-msg-gone')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('dm-action-reply')), findsNothing, reason: 'a removed message offers nothing');
      await tester.longPress(find.byKey(const Key('dm-msg-sticker')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('dm-action-edit')), findsNothing);
      expect(find.byKey(const Key('dm-action-unsend')), findsOneWidget);
    });

    testWidgets('edit through the bar saves via the API', (tester) async {
      final repo = _repo([dmMsg('mine', sender: 'me', body: 'my words', at: _ago(const Duration(minutes: 5)))]);
      await pumpMine(tester, repo: repo);
      await tester.longPress(find.byKey(const Key('dm-msg-mine')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('dm-action-edit')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('dm-edit-bar')), findsOneWidget);
      await tester.enterText(find.byKey(const Key('dm-input')), 'better words');
      await tester.pump();
      await tester.tap(find.byKey(const Key('dm-edit-save')));
      await tester.pumpAndSettle();
      expect(repo.editCalls.single, (messageId: 'mine', body: 'better words'));
      expect(find.text('better words'), findsOneWidget);
      expect(find.byKey(const Key('dm-edit-bar')), findsNothing);
    });

    testWidgets('a 409 from edit hides the controls and shows the window copy', (tester) async {
      final repo = _repo([dmMsg('mine', sender: 'me', body: 'my words', at: _ago(const Duration(minutes: 5)))]);
      await pumpMine(tester, repo: repo);
      repo.failures['edit'] = apiError('edit_window_closed', status: 409);
      await tester.longPress(find.byKey(const Key('dm-msg-mine')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('dm-action-edit')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('dm-input')), 'too late');
      await tester.pump();
      await tester.tap(find.byKey(const Key('dm-edit-save')));
      await tester.pumpAndSettle();
      expect(find.text('You can only edit or unsend a message within 10 minutes of sending it.'), findsOneWidget);
      expect(find.text('my words'), findsOneWidget, reason: 'reverted');
      await tester.longPress(find.byKey(const Key('dm-msg-mine')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('dm-action-edit')), findsNothing);
      expect(find.byKey(const Key('dm-action-unsend')), findsNothing);
    });

    testWidgets('Unsend turns the bubble into a removed one', (tester) async {
      final repo = _repo([dmMsg('mine', sender: 'me', body: 'my words', at: _ago(const Duration(minutes: 5)))]);
      await pumpMine(tester, repo: repo);
      await tester.longPress(find.byKey(const Key('dm-msg-mine')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('dm-action-unsend')));
      await tester.pumpAndSettle();
      expect(repo.unsendCalls, ['mine']);
      expect(find.text('Message removed'), findsOneWidget);
    });

    testWidgets('Copy puts the text on the clipboard', (tester) async {
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') copied = (call.arguments as Map)['text'] as String?;
        return null;
      });
      addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
      await pumpConversation(tester, _repo([dmMsg('theirs', body: 'copy me', at: _ago(const Duration(minutes: 1)))]));
      await tester.longPress(find.byKey(const Key('dm-msg-theirs')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('dm-action-copy')));
      await tester.pumpAndSettle();
      expect(copied, 'copy me');
    });
  });

  group('lifecycle', () {
    testWidgets('markRead on open and again when a new incoming message arrives while visible', (tester) async {
      final repo = _repo([dmMsg('a', body: 'hi', at: _ago(const Duration(minutes: 5)))]);
      final rig = await pumpConversation(tester, repo);
      expect(repo.markReadCalls, ['t1']);
      repo.messagesByThread['t1']!.insert(0, dmMsg('b', body: 'new one', at: _ago(const Duration(minutes: 1))));
      await rig.nudge(tester);
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
      expect(find.text('new one'), findsOneWidget);
      expect(repo.markReadCalls, ['t1', 't1']);
    });

    testWidgets('no markRead while the app is paused; the open-thread id is set while visible and cleared on pop', (tester) async {
      final repo = _repo([dmMsg('a', body: 'hi', at: _ago(const Duration(minutes: 5)))]);
      final rig = await pumpConversation(tester, repo);
      expect(rig.container.read(openThreadIdProvider), 't1');
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      expect(rig.container.read(openThreadIdProvider), isNull);
      final before = repo.markReadCalls.length;
      repo.messagesByThread['t1']!.insert(0, dmMsg('b', body: 'while paused', at: _ago(const Duration(minutes: 1))));
      await rig.nudge(tester);
      await tester.pump(const Duration(milliseconds: 500));
      expect(repo.markReadCalls.length, before, reason: 'a hidden app stamps nothing');
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(rig.container.read(openThreadIdProvider), 't1');
      rig.router.go('/');
      await tester.pumpAndSettle();
      expect(rig.container.read(openThreadIdProvider), isNull);
    });

    testWidgets('scrolled up, a new message shows the pill and does not move the scroll offset', (tester) async {
      final msgs = [for (var i = 60; i >= 0; i--) dmMsg('m$i', body: 'message number $i', at: _ago(Duration(minutes: 10 + (60 - i))).subtract(Duration.zero))];
      final repo = _repo(msgs);
      final rig = await pumpConversation(tester, repo);
      await tester.drag(find.byKey(const Key('dm-list')), const Offset(0, 400));
      await tester.pumpAndSettle();
      final controller = tester.widget<ListView>(find.byKey(const Key('dm-list'))).controller!;
      final offset = controller.offset;
      expect(offset, greaterThan(80));
      repo.messagesByThread['t1']!.insert(0, dmMsg('fresh', body: 'fresh arrival', at: _ago(const Duration(minutes: 1))));
      await rig.nudge(tester);
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();
      expect(find.byKey(const Key('dm-new-pill')), findsOneWidget);
      expect(controller.offset, offset);
    });

    testWidgets('loadOlder fires once when the list is scrolled near the top', (tester) async {
      final msgs = [for (var i = 99; i >= 0; i--) dmMsg('m$i', body: 'message $i', at: _ago(Duration(minutes: 10 + (99 - i))))];
      final repo = _repo(msgs);
      await pumpConversation(tester, repo);
      expect(repo.messagesCalls, hasLength(1));
      await tester.drag(find.byKey(const Key('dm-list')), const Offset(0, 5000));
      await tester.pumpAndSettle();
      expect(repo.messagesCalls.where((c) => c.before == '40'), hasLength(1));
    });
  });

  group('states', () {
    testWidgets('the first load failing shows an error with a working retry', (tester) async {
      final repo = _repo([dmMsg('a', body: 'hi', at: _ago(const Duration(minutes: 5)))])..failures['messages'] = networkError;
      await pumpConversation(tester, repo);
      expect(find.byKey(const Key('dm-retry')), findsOneWidget);
      repo.failures.clear();
      await tester.tap(find.byKey(const Key('dm-retry')));
      await tester.pumpAndSettle();
      expect(find.text('hi'), findsOneWidget);
    });

    testWidgets('a 404 thread shows the conversation-not-found state', (tester) async {
      final repo = _repo(const [])
        ..failures['messages'] = apiError('not_found', status: 404)
        ..failures['thread'] = apiError('not_found', status: 404);
      await pumpConversation(tester, repo);
      expect(find.byKey(const Key('dm-not-found')), findsOneWidget);
    });

    testWidgets('the header shows the other player and opens their profile', (tester) async {
      final repo = _repo([dmMsg('a', body: 'hi', at: _ago(const Duration(minutes: 5)))], header: header('t1', name: 'Ada', username: 'ada'));
      await pumpConversation(tester, repo);
      expect(find.text('Ada'), findsOneWidget);
      await tester.tap(find.byKey(const Key('dm-header')));
      await tester.pumpAndSettle();
      expect(find.text('PLAYER ada'), findsOneWidget);
    });

    testWidgets('a blocked thread replaces the composer with the banner', (tester) async {
      final repo = _repo([dmMsg('a', body: 'hi', at: _ago(const Duration(minutes: 5)))], header: header('t1', blockedByThem: true));
      await pumpConversation(tester, repo);
      expect(find.byKey(const Key('dm-composer')), findsNothing);
      expect(find.byKey(const Key('dm-blocked-banner')), findsOneWidget);
    });

    testWidgets('French smoke: composer hint, day label and action copy', (tester) async {
      final repo = _repo([dmMsg('m', sender: 'me', body: 'salut', at: _ago(const Duration(minutes: 5)))]);
      await pumpConversation(tester, repo, locale: const Locale('fr'));
      expect(find.text("Aujourd'hui"), findsOneWidget);
      await tester.longPress(find.byKey(const Key('dm-msg-m')));
      await tester.pumpAndSettle();
      expect(find.text('Répondre'), findsOneWidget);
      expect(find.text('Modifier'), findsOneWidget);
    });
  });
}
