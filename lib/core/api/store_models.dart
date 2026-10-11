/// Response models for the `/store/**` operations. Prices, balances and ownership are server-owned; the app only
/// displays them. SX Coins are earned, never bought, so there is no money field anywhere in the store.
class StoreItem {
  const StoreItem({
    required this.id,
    required this.slug,
    required this.name,
    required this.description,
    required this.category,
    required this.priceCoins,
    required this.previewUrl,
    required this.owned,
    required this.equipped,
  });

  factory StoreItem.fromJson(Map<String, dynamic> j) => StoreItem(
        id: j['id'] as String,
        slug: j['slug'] as String,
        name: j['name'] as String,
        description: j['description'] as String?,
        category: j['category'] as String,
        priceCoins: (j['priceCoins'] as num).toInt(),
        previewUrl: j['previewUrl'] as String,
        owned: j['owned'] as bool,
        equipped: j['equipped'] as bool,
      );

  final String id;
  final String slug;
  final String name;
  final String? description;

  /// `avatar_border`, `bubble_skin`, `profile_theme` or `username_colour`.
  final String category;
  final int priceCoins;

  /// Absolute URL of the preview (the app prefers its bundled copy, matched by file name).
  final String previewUrl;
  final bool owned;
  final bool equipped;

  StoreItem copyWith({bool? owned, bool? equipped}) => StoreItem(
        id: id,
        slug: slug,
        name: name,
        description: description,
        category: category,
        priceCoins: priceCoins,
        previewUrl: previewUrl,
        owned: owned ?? this.owned,
        equipped: equipped ?? this.equipped,
      );
}

class StoreCatalogue {
  const StoreCatalogue({required this.balance, required this.items});

  factory StoreCatalogue.fromJson(Map<String, dynamic> j) => StoreCatalogue(
        balance: (j['balance'] as num?)?.toInt(),
        items: [for (final i in j['items'] as List<dynamic>) StoreItem.fromJson(i as Map<String, dynamic>)],
      );

  /// Null when signed out.
  final int? balance;
  final List<StoreItem> items;
}

class PurchaseOutcome {
  const PurchaseOutcome({required this.balance, required this.itemId});

  factory PurchaseOutcome.fromJson(Map<String, dynamic> j) =>
      PurchaseOutcome(balance: (j['balance'] as num).toInt(), itemId: j['itemId'] as String);

  final int balance;
  final String itemId;
}

class EquipOutcome {
  const EquipOutcome({required this.itemId, required this.category});

  factory EquipOutcome.fromJson(Map<String, dynamic> j) =>
      EquipOutcome(itemId: j['itemId'] as String, category: j['category'] as String);

  final String itemId;
  final String category;
}
