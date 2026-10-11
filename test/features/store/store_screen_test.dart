import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/core/api/api_client.dart';
import 'package:sentinelx_mobile/core/api/store_models.dart';
import 'package:sentinelx_mobile/features/store/store_providers.dart';
import 'package:sentinelx_mobile/features/store/store_screen.dart';

import '../../fakes/fake_store_repository.dart';
import 'store_test_harness.dart';

StoreCatalogue _catalogue({int? balance = 1250}) => StoreCatalogue(balance: balance, items: [
      storeItemFixture('b1', slug: 'avatar_border_bronze', name: 'Bronze Frame', price: 150, owned: true, equipped: true),
      storeItemFixture('b2', slug: 'avatar_border_gold_crown', name: 'Gold Crown', price: 1200,
          previewUrl: 'https://sentinelxesports.com.ng/coin-items/gold-crown.webp'),
      storeItemFixture('k1', slug: 'bubble_neon_mascot', name: 'Neon Mascot', category: 'bubble_skin', price: 450, owned: true,
          previewUrl: 'https://sentinelxesports.com.ng/coin-items/bubble-mascot-neon.webp'),
      storeItemFixture('c1', slug: 'username_gold', name: 'Gold Name', category: 'username_colour', price: 150,
          previewUrl: 'https://sentinelxesports.com.ng/coin-items/username-gold.webp'),
    ]);

void main() {
  testWidgets('shows a progress indicator while loading', (tester) async {
    await pumpStore(
      tester,
      const StoreScreen(),
      repo: FakeStoreRepository(),
      settle: false,
      overrides: [storeCatalogueProvider.overrideWith((ref) => Completer<StoreCatalogue>().future)],
    );
    expect(find.byKey(const Key('store-loading')), findsOneWidget);
  });

  testWidgets('a failed load shows retry, and retry refetches', (tester) async {
    final repo = FakeStoreRepository()..catalogueResult = ApiException(status: 0, code: 'network', message: 'offline');
    await pumpStore(tester, const StoreScreen(), repo: repo);
    expect(find.text("Couldn't load the store."), findsOneWidget);
    repo.catalogueResult = _catalogue();
    await tester.tap(find.byKey(const Key('store-retry')));
    await tester.pumpAndSettle();
    expect(find.text('Bronze Frame'), findsOneWidget);
    expect(repo.calls.where((c) => c == 'catalogue'), hasLength(2));
  });

  testWidgets('the header shows the server balance and the coin disclaimer', (tester) async {
    final repo = FakeStoreRepository()..catalogueResult = _catalogue(balance: 1250);
    await pumpStore(tester, const StoreScreen(), repo: repo);
    expect(find.byKey(const Key('store-balance')), findsOneWidget);
    expect(find.text('1,250'), findsOneWidget);
    expect(find.text('SX Coins cannot be exchanged for cash. They are earned by competing and spent on the platform.'), findsOneWidget);
  });

  testWidgets('signed out: the catalogue shows, no balance is shown, the disclaimer stays', (tester) async {
    final repo = FakeStoreRepository()..catalogueResult = _catalogue(balance: null);
    await pumpStore(tester, const StoreScreen(), repo: repo, viewer: null);
    expect(find.text('Bronze Frame'), findsOneWidget);
    expect(find.byKey(const Key('store-balance')), findsNothing);
    expect(find.byKey(const Key('store-disclaimer')), findsOneWidget);
  });

  testWidgets('category chips filter the grid, starting on frames', (tester) async {
    final repo = FakeStoreRepository()..catalogueResult = _catalogue();
    await pumpStore(tester, const StoreScreen(), repo: repo);
    expect(find.text('Bronze Frame'), findsOneWidget);
    expect(find.text('Gold Crown'), findsOneWidget);
    expect(find.text('Neon Mascot'), findsNothing);
    await tester.ensureVisible(find.byKey(const Key('store-cat-bubble_skin')));
    await tester.tap(find.byKey(const Key('store-cat-bubble_skin')));
    await tester.pumpAndSettle();
    expect(find.text('Neon Mascot'), findsOneWidget);
    expect(find.text('Bronze Frame'), findsNothing);
    await tester.ensureVisible(find.byKey(const Key('store-cat-username_colour')));
    await tester.tap(find.byKey(const Key('store-cat-username_colour')));
    await tester.pumpAndSettle();
    expect(find.text('Gold Name'), findsOneWidget);
  });

  testWidgets('a category with no items shows the empty state', (tester) async {
    final repo = FakeStoreRepository()..catalogueResult = _catalogue();
    await pumpStore(tester, const StoreScreen(), repo: repo);
    await tester.ensureVisible(find.byKey(const Key('store-cat-profile_theme')));
    await tester.tap(find.byKey(const Key('store-cat-profile_theme')));
    await tester.pumpAndSettle();
    expect(find.text('Nothing here yet.'), findsOneWidget);
  });

  testWidgets('cards show price, owned/equipped badges, and the bundled preview art', (tester) async {
    final repo = FakeStoreRepository()..catalogueResult = _catalogue();
    await pumpStore(tester, const StoreScreen(), repo: repo);
    expect(find.text('1,200'), findsOneWidget); // Gold Crown price
    expect(find.descendant(of: find.byKey(const Key('store-item-b1')), matching: find.text('Equipped')), findsOneWidget);
    expect(find.descendant(of: find.byKey(const Key('store-item-b2')), matching: find.text('Owned')), findsNothing);
    final crown = tester.widget<Image>(find.descendant(of: find.byKey(const Key('store-item-b2')), matching: find.byType(Image)));
    expect(crown.image, isA<AssetImage>());
    expect((crown.image as AssetImage).assetName, 'assets/store/gold-crown.webp');
  });

  testWidgets('an owned but unequipped item shows Owned', (tester) async {
    final repo = FakeStoreRepository()
      ..catalogueResult = StoreCatalogue(balance: 10, items: [storeItemFixture('x', name: 'Mine', owned: true)]);
    await pumpStore(tester, const StoreScreen(), repo: repo);
    expect(find.descendant(of: find.byKey(const Key('store-item-x')), matching: find.text('Owned')), findsOneWidget);
  });

  testWidgets('pull to refresh refetches the catalogue', (tester) async {
    final repo = FakeStoreRepository()..catalogueResult = _catalogue();
    await pumpStore(tester, const StoreScreen(), repo: repo);
    repo.catalogueResult = StoreCatalogue(balance: 5, items: [storeItemFixture('z', name: 'Fresh Item')]);
    await tester.fling(find.byType(CustomScrollView), const Offset(0, 400), 1000);
    await tester.pumpAndSettle();
    expect(find.text('Fresh Item'), findsOneWidget);
  });

  for (final locale in const [Locale('fr'), Locale('pcm')]) {
    for (final width in const [320.0, 375.0]) {
      testWidgets('lays out without overflow at ${width.toInt()}px in ${locale.languageCode}', (tester) async {
        final repo = FakeStoreRepository()..catalogueResult = _catalogue(balance: 1250000);
        await pumpStore(tester, const StoreScreen(), repo: repo, locale: locale, width: width);
        expect(tester.takeException(), isNull);
        for (final c in ['bubble_skin', 'profile_theme', 'username_colour']) {
          await tester.ensureVisible(find.byKey(Key('store-cat-$c')));
          await tester.tap(find.byKey(Key('store-cat-$c')));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        }
      });
    }
  }
}
