import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/core/api/api_client.dart';
import 'package:sentinelx_mobile/core/api/store_models.dart';
import 'package:sentinelx_mobile/core/l10n/gen/app_localizations_en.dart';
import 'package:sentinelx_mobile/core/providers.dart';
import 'package:sentinelx_mobile/features/store/coin_format.dart';
import 'package:sentinelx_mobile/features/store/store_errors.dart';
import 'package:sentinelx_mobile/features/store/store_providers.dart';

import '../../fakes/fake_store_repository.dart';

ApiException _e(String code, {Map<String, String> fields = const {}}) =>
    ApiException(status: 400, code: code, message: 'RAW SERVER MESSAGE', fields: fields);

void main() {
  group('formatCoins', () {
    test('groups thousands with a fixed comma and uses a true minus', () {
      expect(formatCoins(0), '0');
      expect(formatCoins(150), '150');
      expect(formatCoins(1200), '1,200');
      expect(formatCoins(5000000), '5,000,000');
      expect(formatCoins(-150), '−150');
    });
  });

  group('storeErrorCopy', () {
    final l10n = AppLocalizationsEn();

    test('known codes map to localized copy', () {
      expect(storeErrorCopy(l10n, _e('not_found')), l10n.storeErrNotFound);
      expect(storeErrorCopy(l10n, _e('item_unavailable')), l10n.storeErrUnavailable);
      expect(storeErrorCopy(l10n, _e('already_owned')), l10n.storeErrOwned);
      expect(storeErrorCopy(l10n, _e('insufficient_coins')), l10n.storeErrInsufficient);
      expect(storeErrorCopy(l10n, _e('not_owned')), l10n.storeErrNotOwned);
      expect(storeErrorCopy(l10n, _e('store_unavailable')), l10n.storeErrStore);
      expect(storeErrorCopy(l10n, _e('store_load_failed')), l10n.storeErrStore);
      expect(storeErrorCopy(l10n, _e('account_pending_deletion')), l10n.storeErrPendingDeletion);
      expect(storeErrorCopy(l10n, _e('network')), l10n.storeErrNetwork);
      expect(storeErrorCopy(l10n, _e('unauthorized')), l10n.storeErrSession);
      expect(storeErrorCopy(l10n, _e('idempotency_in_progress')), l10n.storeErrInProgress);
    });

    test('anything unknown, and non-API errors, show the generic copy and never the raw server message', () {
      expect(storeErrorCopy(l10n, _e('something_new')), l10n.storeErrGeneric);
      expect(storeErrorCopy(l10n, StateError('boom')), l10n.storeErrGeneric);
      expect(storeErrorCopy(l10n, _e('something_new')), isNot(contains('RAW SERVER MESSAGE')));
    });

    test('the code-only variant matches (what a WriteState carries)', () {
      expect(storeErrorCodeCopy(l10n, 'insufficient_coins'), l10n.storeErrInsufficient);
      expect(storeErrorCodeCopy(l10n, 'zzz'), l10n.storeErrGeneric);
    });
  });

  group('storeCatalogueProvider', () {
    ProviderContainer container(FakeStoreRepository repo, {String? viewer = 'u1'}) => ProviderContainer(
          retry: (_, _) => null,
          overrides: [
            storeRepositoryProvider.overrideWithValue(repo),
            viewerIdProvider.overrideWith((ref) async => viewer),
          ],
        );

    test('loads the catalogue for a signed-in viewer', () async {
      final repo = FakeStoreRepository()..catalogueResult = StoreCatalogue(balance: 777, items: [storeItemFixture('i1', owned: true)]);
      final c = container(repo);
      addTearDown(c.dispose);
      final cat = await c.read(storeCatalogueProvider.future);
      expect(cat.balance, 777);
      expect(cat.items.single.owned, isTrue);
    });

    test('also loads for a signed-out viewer (the catalogue is public)', () async {
      final repo = FakeStoreRepository()..catalogueResult = StoreCatalogue(balance: null, items: [storeItemFixture('i1')]);
      final c = container(repo, viewer: null);
      addTearDown(c.dispose);
      expect((await c.read(storeCatalogueProvider.future)).balance, isNull);
      expect(repo.calls, ['catalogue']);
    });

    test('a failed load is an error state, not an empty store', () async {
      final repo = FakeStoreRepository()..catalogueResult = ApiException(status: 500, code: 'store_load_failed', message: 'x');
      final c = container(repo);
      addTearDown(c.dispose);
      await expectLater(c.read(storeCatalogueProvider.future), throwsA(isA<ApiException>()));
    });
  });
}
