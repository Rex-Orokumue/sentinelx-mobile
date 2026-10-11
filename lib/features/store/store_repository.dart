import '../../core/api/api_client.dart';
import '../../core/api/store_models.dart';

/// The store's only data source: the `/api/mobile/v1/store/**` operations. Screens never touch Supabase tables,
/// so ownership, price and balance can never disagree with the website.
abstract class StoreRepository {
  Future<StoreCatalogue> catalogue();
  Future<PurchaseOutcome> purchase(String itemId, {required String idempotencyKey});
  Future<EquipOutcome> equip(String itemId);
  Future<EquipOutcome> unequip(String itemId);
}

class ApiStoreRepository implements StoreRepository {
  ApiStoreRepository(this._api);

  final ApiClient _api;

  @override
  Future<StoreCatalogue> catalogue() => _api.getStore();

  @override
  Future<PurchaseOutcome> purchase(String itemId, {required String idempotencyKey}) =>
      _api.purchaseStoreItem(itemId, idempotencyKey: idempotencyKey);

  @override
  Future<EquipOutcome> equip(String itemId) => _api.equipStoreItem(itemId);

  @override
  Future<EquipOutcome> unequip(String itemId) => _api.unequipStoreItem(itemId);
}
