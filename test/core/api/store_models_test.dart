import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/core/api/models.dart';
import 'package:sentinelx_mobile/core/api/store_models.dart';

Map<String, dynamic> _item({bool owned = false, bool equipped = false, String? description = 'A frame'}) => {
      'id': 'i1',
      'slug': 'avatar_border_bronze',
      'name': 'Bronze Frame',
      'description': description,
      'category': 'avatar_border',
      'priceCoins': 150,
      'previewUrl': 'https://sentinelxesports.com.ng/coin-items/bronze-frame.webp',
      'owned': owned,
      'equipped': equipped,
    };

void main() {
  group('StoreCatalogue.fromJson', () {
    test('parses a signed-out catalogue: null balance, nothing owned', () {
      final c = StoreCatalogue.fromJson({
        'balance': null,
        'items': [_item(description: null)],
      });
      expect(c.balance, isNull);
      expect(c.items.single.description, isNull);
      expect(c.items.single.priceCoins, 150);
      expect(c.items.single.owned, isFalse);
    });

    test('parses a signed-in catalogue with owned and equipped flags', () {
      final c = StoreCatalogue.fromJson({
        'balance': 1250,
        'items': [_item(owned: true, equipped: true)],
      });
      expect(c.balance, 1250);
      expect(c.items.single.owned, isTrue);
      expect(c.items.single.equipped, isTrue);
      expect(c.items.single.previewUrl, endsWith('bronze-frame.webp'));
    });

    test('an item without a price fails loudly instead of showing a free item', () {
      final bad = _item()..remove('priceCoins');
      expect(() => StoreItem.fromJson(bad), throwsA(anything));
    });
  });

  test('StoreItem.copyWith changes only the flags it is given', () {
    final item = StoreItem.fromJson(_item());
    final bought = item.copyWith(owned: true);
    expect(bought.owned, isTrue);
    expect(bought.equipped, isFalse);
    expect(bought.slug, item.slug);
    expect(item.copyWith(equipped: true).owned, isFalse);
  });

  test('PurchaseOutcome and EquipOutcome parse', () {
    final p = PurchaseOutcome.fromJson({'balance': 350, 'itemId': 'i1'});
    expect(p.balance, 350);
    expect(p.itemId, 'i1');
    final e = EquipOutcome.fromJson({'itemId': 'i1', 'category': 'avatar_border'});
    expect(e.category, 'avatar_border');
  });

  test('MeProfile parses the equipped username colour and theme, and reads absent fields as null', () {
    final base = {
      'username': 'ada', 'displayName': 'Ada', 'avatarUrl': null, 'whatsappNumber': null, 'country': null,
      'locale': 'en', 'membershipTier': 'guardian', 'kycVerified': false, 'deletionRequestedAt': null,
      'profileCompletedAt': null, 'phoneVerifiedAt': null, 'consentWhatsappUpdates': false,
      'gameInterests': <String>[], 'bubbleSkinUrl': null,
    };
    final withCosmetics = MeProfile.fromJson({...base, 'usernameColour': 'username_gold', 'profileTheme': 'theme_neon_grid'});
    expect(withCosmetics.usernameColour, 'username_gold');
    expect(withCosmetics.profileTheme, 'theme_neon_grid');
    final older = MeProfile.fromJson(base);
    expect(older.usernameColour, isNull);
    expect(older.profileTheme, isNull);
  });
}
