import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/core/api/api_client.dart';
import 'package:sentinelx_mobile/core/api/store_models.dart';
import 'package:sentinelx_mobile/features/store/store_screen.dart';

import '../../fakes/fake_store_repository.dart';
import 'store_test_harness.dart';

StoreCatalogue _cat({int? balance = 1000, bool owned = false, bool equipped = false}) => StoreCatalogue(balance: balance, items: [
      storeItemFixture('i1', name: 'Bronze Frame', price: 150, owned: owned, equipped: equipped),
      storeItemFixture('i2', slug: 'avatar_border_gold_crown', name: 'Gold Crown', price: 1200,
          previewUrl: 'https://sentinelxesports.com.ng/coin-items/gold-crown.webp'),
      storeItemFixture('i3', slug: 'avatar_border_purple_glow', name: 'Purple Glow', price: 300,
          previewUrl: 'https://sentinelxesports.com.ng/coin-items/purple-glow.webp'),
    ]);

Future<FakeStoreRepository> _open(WidgetTester tester, {StoreCatalogue? catalogue, String id = 'i1', String? viewer = 'u1', Locale locale = const Locale('en'), double width = 375}) async {
  final repo = FakeStoreRepository()..catalogueResult = catalogue ?? _cat();
  await pumpStore(tester, const StoreScreen(), repo: repo, viewer: viewer, locale: locale, width: width);
  await tester.tap(find.byKey(Key('store-item-$id')));
  await tester.pumpAndSettle();
  return repo;
}

Future<void> _confirmBuy(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('store-buy')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('store-buy-confirm')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('opens a sheet with the name, description and price', (tester) async {
    await _open(tester);
    expect(find.byKey(const Key('store-sheet')), findsOneWidget);
    expect(find.descendant(of: find.byKey(const Key('store-sheet')), matching: find.text('Bronze Frame')), findsOneWidget);
    expect(find.text('A modest bronze ring.'), findsOneWidget);
    expect(find.descendant(of: find.byKey(const Key('store-sheet')), matching: find.text('150')), findsOneWidget);
  });

  testWidgets('Buy is enabled when the balance covers the price', (tester) async {
    await _open(tester);
    expect(tester.widget<FilledButton>(find.byKey(const Key('store-buy'))).onPressed, isNotNull);
    expect(find.byKey(const Key('store-need-more')), findsNothing);
  });

  testWidgets('Buy is disabled with how many more coins are needed when the balance is short', (tester) async {
    await _open(tester, id: 'i2', catalogue: _cat(balance: 1000));
    expect(tester.widget<FilledButton>(find.byKey(const Key('store-buy'))).onPressed, isNull);
    expect(find.text('You need 200 more coins.'), findsOneWidget);
  });

  testWidgets('cancelling the confirmation buys nothing', (tester) async {
    final repo = await _open(tester);
    await tester.tap(find.byKey(const Key('store-buy')));
    await tester.pumpAndSettle();
    expect(find.text('Buy Bronze Frame?'), findsOneWidget);
    expect(find.text('150 coins. You\'ll have 850 left.'), findsOneWidget);
    await tester.tap(find.byKey(const Key('store-buy-cancel')));
    await tester.pumpAndSettle();
    expect(repo.calls.where((c) => c.startsWith('purchase')), isEmpty);
  });

  testWidgets('a confirmed purchase refetches from the server and then offers Equip; nothing is assumed locally', (tester) async {
    final repo = await _open(tester);
    repo.catalogueResult = _cat(balance: 850, owned: true); // what the server says after the purchase
    await _confirmBuy(tester);
    expect(repo.calls, contains('purchase:i1'));
    expect(repo.calls.where((c) => c == 'catalogue').length, greaterThanOrEqualTo(2));
    expect(find.text('Bought! You can equip it now.'), findsOneWidget);
    expect(find.byKey(const Key('store-equip')), findsOneWidget);
    expect(find.byKey(const Key('store-buy')), findsNothing);
    expect(find.text('850'), findsWidgets); // the new balance, from the server
  });

  testWidgets('a double tap on Buy opens one confirmation and buys once', (tester) async {
    final repo = await _open(tester);
    final onPressed = tester.widget<FilledButton>(find.byKey(const Key('store-buy'))).onPressed!;
    onPressed();
    onPressed();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('store-buy-confirm')), findsOneWidget);
    await tester.tap(find.byKey(const Key('store-buy-confirm')));
    await tester.pumpAndSettle();
    expect(repo.calls.where((c) => c.startsWith('purchase')), hasLength(1));
    expect(find.byKey(const Key('store-error')), findsNothing);
  });

  testWidgets('a network failure keeps the Idempotency-Key for the retry; a different item uses a different key', (tester) async {
    final repo = await _open(tester);
    repo.purchaseResults
      ..add(ApiException(status: 0, code: 'network', message: 'offline'))
      ..add(const PurchaseOutcome(balance: 850, itemId: 'i1'));
    await _confirmBuy(tester);
    expect(find.text('No connection. Check your internet and try again.'), findsOneWidget);
    await _confirmBuy(tester); // retry the same item
    expect(repo.idempotencyKeys, hasLength(2));
    expect(repo.idempotencyKeys[0], repo.idempotencyKeys[1]);

    // another item, fresh sheet
    Navigator.of(tester.element(find.byKey(const Key('store-sheet')))).pop();
    await tester.pumpAndSettle();
    repo.catalogueResult = _cat(balance: 850, owned: true);
    await tester.tap(find.byKey(const Key('store-item-i3')));
    await tester.pumpAndSettle();
    await _confirmBuy(tester);
    expect(repo.idempotencyKeys, hasLength(3));
    expect(repo.idempotencyKeys[2], isNot(repo.idempotencyKeys[0]));
  });

  for (final c in const [
    ('insufficient_coins', 'Not enough SX Coins.'),
    ('item_unavailable', "This item isn't available any more."),
    ('store_unavailable', 'The store is unavailable right now. Please try again.'),
    ('account_pending_deletion', 'Cancel your account deletion in Settings to do this.'),
    ('not_found', 'That item no longer exists.'),
  ]) {
    testWidgets('${c.$1} shows localized copy, not the server message, and leaves the item buyable', (tester) async {
      final repo = await _open(tester);
      repo.purchaseResults.add(ApiException(status: 422, code: c.$1, message: 'RAW SERVER MESSAGE'));
      await _confirmBuy(tester);
      expect(find.text(c.$2), findsOneWidget);
      expect(find.textContaining('RAW SERVER MESSAGE'), findsNothing);
      expect(find.byKey(const Key('store-buy')), findsOneWidget);
    });
  }

  testWidgets('already_owned shows its copy and refetches so the item shows as owned', (tester) async {
    final repo = await _open(tester);
    repo.purchaseResults.add(ApiException(status: 409, code: 'already_owned', message: 'x'));
    repo.catalogueResult = _cat(owned: true);
    await _confirmBuy(tester);
    expect(find.text('You already own this item.'), findsOneWidget);
    expect(find.byKey(const Key('store-equip')), findsOneWidget);
  });

  testWidgets('Equip calls the server, refetches, and the item shows as equipped with Unequip', (tester) async {
    final repo = await _open(tester, catalogue: _cat(owned: true));
    repo.catalogueResult = _cat(owned: true, equipped: true);
    await tester.tap(find.byKey(const Key('store-equip')));
    await tester.pumpAndSettle();
    expect(repo.calls, contains('equip:i1'));
    expect(find.text('Equipped.'), findsOneWidget);
    expect(find.byKey(const Key('store-unequip')), findsOneWidget);
  });

  testWidgets('Unequip calls the server and the item goes back to Equip', (tester) async {
    final repo = await _open(tester, catalogue: _cat(owned: true, equipped: true));
    repo.catalogueResult = _cat(owned: true);
    await tester.tap(find.byKey(const Key('store-unequip')));
    await tester.pumpAndSettle();
    expect(repo.calls, contains('unequip:i1'));
    expect(find.text('Removed.'), findsOneWidget);
    expect(find.byKey(const Key('store-equip')), findsOneWidget);
  });

  testWidgets('a failed equip shows localized copy and the item stays as it was', (tester) async {
    final repo = await _open(tester, catalogue: _cat(owned: true));
    repo.equipResult = ApiException(status: 409, code: 'not_owned', message: 'RAW SERVER MESSAGE');
    await tester.tap(find.byKey(const Key('store-equip')));
    await tester.pumpAndSettle();
    expect(find.text("You don't own this item yet."), findsOneWidget);
    expect(find.textContaining('RAW SERVER MESSAGE'), findsNothing);
  });

  testWidgets('signed out: the sheet asks to log in instead of buying, and the button goes to the log-in screen', (tester) async {
    final repo = await _open(tester, viewer: null, catalogue: _cat(balance: null));
    expect(find.text('Log in to buy'), findsOneWidget);
    await tester.tap(find.byKey(const Key('store-buy')));
    await tester.pumpAndSettle();
    expect(find.text('page:/login'), findsOneWidget);
    expect(repo.calls.where((c) => c.startsWith('purchase')), isEmpty);
  });

  for (final locale in const [Locale('fr'), Locale('pcm')]) {
    testWidgets('the sheet and the confirmation fit at 320px in ${locale.languageCode}', (tester) async {
      await _open(tester, locale: locale, width: 320);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byKey(const Key('store-buy')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
