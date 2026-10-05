import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/features/messages/stickers.dart';

import '../../fakes/fake_messages_repository.dart';
import '../../support/pump_conversation.dart';

DateTime _ago(Duration d) => kNow.subtract(d);

void main() {
  FakeMessagesRepository repo() => FakeMessagesRepository()..messagesByThread['t1'] = [dmMsg('a', body: 'hi', at: _ago(const Duration(minutes: 5)))];

  testWidgets('the picker shows 14 cells in the web order', (tester) async {
    await pumpConversation(tester, repo());
    await tester.tap(find.byKey(const Key('dm-sticker-button')));
    await tester.pumpAndSettle();
    final cells = [for (final s in kStickerPack) find.byKey(Key('dm-sticker-${s.id}'))];
    expect(cells.every((f) => f.evaluate().length == 1), isTrue);
    expect(cells, hasLength(14));
    final xs = [for (final f in cells) tester.getTopLeft(f)];
    // row-major order: y never decreases, and x increases within a row
    for (var i = 1; i < xs.length; i++) {
      expect(xs[i].dy > xs[i - 1].dy || (xs[i].dy == xs[i - 1].dy && xs[i].dx > xs[i - 1].dx), isTrue, reason: kStickerPack[i].id);
    }
  });

  testWidgets('tapping a sticker sends exactly one sticker draft with a key, and closes the sheet', (tester) async {
    final r = repo();
    await pumpConversation(tester, r);
    await tester.tap(find.byKey(const Key('dm-sticker-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('dm-sticker-goat')));
    await tester.tap(find.byKey(const Key('dm-sticker-goat')), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(r.sendCalls, hasLength(1));
    expect(r.sendCalls.single.draft.stickerId, 'goat');
    expect(r.sendCalls.single.draft.body, isNull);
    expect(r.sendCalls.single.key, isNotEmpty);
    expect(find.byKey(const Key('dm-sticker-goat')), findsNothing, reason: 'the sheet closed');
    expect(find.text('🐐'), findsOneWidget, reason: 'rendered as a sticker bubble');
  });

  testWidgets('a double tap on the same cell while the first send is in flight sends once', (tester) async {
    final r = repo();
    await pumpConversation(tester, r);
    await tester.tap(find.byKey(const Key('dm-sticker-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('dm-sticker-fire')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('dm-sticker-fire')), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(r.sendCalls, hasLength(1));
  });

  testWidgets('an unknown sticker id renders the placeholder and does not throw', (tester) async {
    final r = FakeMessagesRepository()..messagesByThread['t1'] = [dmMsg('x', stickerId: 'bogus', at: _ago(const Duration(minutes: 1)))];
    await pumpConversation(tester, r);
    expect(find.byKey(const Key('dm-sticker-unknown')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
