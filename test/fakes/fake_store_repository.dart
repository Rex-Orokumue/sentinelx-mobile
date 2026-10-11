import 'package:sentinelx_mobile/core/api/store_models.dart';
import 'package:sentinelx_mobile/features/store/store_repository.dart';

StoreItem storeItemFixture(
  String id, {
  String slug = 'avatar_border_bronze',
  String name = 'Bronze Frame',
  String category = 'avatar_border',
  int price = 150,
  bool owned = false,
  bool equipped = false,
  String? description = 'A modest bronze ring.',
  String previewUrl = 'https://sentinelxesports.com.ng/coin-items/bronze-frame.webp',
}) =>
    StoreItem(
      id: id,
      slug: slug,
      name: name,
      description: description,
      category: category,
      priceCoins: price,
      previewUrl: previewUrl,
      owned: owned,
      equipped: equipped,
    );

/// In-memory [StoreRepository]. A result that is an Exception is thrown instead of returned.
class FakeStoreRepository implements StoreRepository {
  final calls = <String>[];
  final idempotencyKeys = <String>[];

  Object catalogueResult = StoreCatalogue(balance: 1000, items: [storeItemFixture('i1')]);

  /// Consumed one per call; when empty `purchaseDefault` is used.
  final purchaseResults = <Object>[];
  Object purchaseDefault = const PurchaseOutcome(balance: 850, itemId: 'i1');
  Object equipResult = const EquipOutcome(itemId: 'i1', category: 'avatar_border');
  Object unequipResult = const EquipOutcome(itemId: 'i1', category: 'avatar_border');

  T _out<T>(Object o) {
    if (o is Exception) throw o;
    return o as T;
  }

  @override
  Future<StoreCatalogue> catalogue() async {
    calls.add('catalogue');
    return _out(catalogueResult);
  }

  @override
  Future<PurchaseOutcome> purchase(String itemId, {required String idempotencyKey}) async {
    calls.add('purchase:$itemId');
    idempotencyKeys.add(idempotencyKey);
    return _out(purchaseResults.isEmpty ? purchaseDefault : purchaseResults.removeAt(0));
  }

  @override
  Future<EquipOutcome> equip(String itemId) async {
    calls.add('equip:$itemId');
    return _out(equipResult);
  }

  @override
  Future<EquipOutcome> unequip(String itemId) async {
    calls.add('unequip:$itemId');
    return _out(unequipResult);
  }
}
