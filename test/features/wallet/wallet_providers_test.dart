import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/core/api/api_client.dart';
import 'package:sentinelx_mobile/core/api/wallet_models.dart';
import 'package:sentinelx_mobile/core/providers.dart';
import 'package:sentinelx_mobile/features/wallet/money_format.dart';
import 'package:sentinelx_mobile/features/wallet/wallet_providers.dart';

import '../../fakes/fake_wallet_repository.dart';

void main() {
  ProviderContainer container(FakeWalletRepository repo, {String? viewer = 'u1'}) => ProviderContainer(
        retry: (_, _) => null,
        overrides: [
          walletRepositoryProvider.overrideWithValue(repo),
          viewerIdProvider.overrideWith((ref) async => viewer),
        ],
      );

  group('formatNaira', () {
    test('groups thousands and prefixes the naira sign', () {
      expect(formatNaira(0), '₦0');
      expect(formatNaira(950), '₦950');
      expect(formatNaira(1250000), '₦1,250,000');
    });
    test('uses a true minus sign for negative amounts', () {
      expect(formatNaira(-3000), '−₦3,000');
    });
  });

  group('walletOverviewProvider', () {
    test('loads the overview for a signed-in viewer', () async {
      final repo = FakeWalletRepository()..overview = walletOverviewFixture(balance: 7000);
      final c = container(repo);
      addTearDown(c.dispose);
      expect((await c.read(walletOverviewProvider.future))!.balance, 7000);
      expect(repo.calls, ['overview']);
    });

    test('is null and makes no request when signed out', () async {
      final repo = FakeWalletRepository();
      final c = container(repo, viewer: null);
      addTearDown(c.dispose);
      expect(await c.read(walletOverviewProvider.future), isNull);
      expect(repo.calls, isEmpty);
    });
  });

  group('walletTransactionsProvider', () {
    test('loads the first page with the requested filter', () async {
      final repo = FakeWalletRepository()
        ..txnPages.add(WalletTxnPage(items: [walletTxnFixture('a')], nextCursor: 'c1'));
      final c = container(repo);
      addTearDown(c.dispose);
      final list = await c.read(walletTransactionsProvider('winnings').future);
      expect(list.items.map((t) => t.id), ['a']);
      expect(list.nextCursor, 'c1');
      expect(repo.txnRequests.single, (filter: 'winnings', cursor: null));
    });

    test('loadMore appends the next page using the cursor and drops a duplicated id', () async {
      final repo = FakeWalletRepository()
        ..txnPages.add(WalletTxnPage(items: [walletTxnFixture('a'), walletTxnFixture('b')], nextCursor: 'c1'))
        ..txnPages.add(WalletTxnPage(items: [walletTxnFixture('b'), walletTxnFixture('c')], nextCursor: null));
      final c = container(repo);
      addTearDown(c.dispose);
      await c.read(walletTransactionsProvider('all').future);
      await c.read(walletTransactionsProvider('all').notifier).loadMore();
      final list = c.read(walletTransactionsProvider('all')).requireValue;
      expect(list.items.map((t) => t.id), ['a', 'b', 'c']);
      expect(list.nextCursor, isNull);
      expect(repo.txnRequests.last.cursor, 'c1');
    });

    test('loadMore does nothing once there is no next cursor', () async {
      final repo = FakeWalletRepository()..txnPages.add(WalletTxnPage(items: [walletTxnFixture('a')], nextCursor: null));
      final c = container(repo);
      addTearDown(c.dispose);
      await c.read(walletTransactionsProvider('all').future);
      await c.read(walletTransactionsProvider('all').notifier).loadMore();
      expect(repo.txnRequests, hasLength(1));
    });

    test('a failed loadMore keeps the loaded items, flags the failure, and a retry clears it', () async {
      final repo = FakeWalletRepository()
        ..txnPages.add(WalletTxnPage(items: [walletTxnFixture('a')], nextCursor: 'c1'))
        ..txnPages.add(ApiException(status: 0, code: 'network', message: 'offline'))
        ..txnPages.add(WalletTxnPage(items: [walletTxnFixture('b')], nextCursor: null));
      final c = container(repo);
      addTearDown(c.dispose);
      await c.read(walletTransactionsProvider('all').future);
      final notifier = c.read(walletTransactionsProvider('all').notifier);
      await notifier.loadMore();
      var list = c.read(walletTransactionsProvider('all')).requireValue;
      expect(list.items.map((t) => t.id), ['a']);
      expect(list.loadMoreFailed, isTrue);
      await notifier.loadMore();
      list = c.read(walletTransactionsProvider('all')).requireValue;
      expect(list.items.map((t) => t.id), ['a', 'b']);
      expect(list.loadMoreFailed, isFalse);
    });

    test('each filter keeps its own list', () async {
      final repo = FakeWalletRepository()
        ..txnPages.add(WalletTxnPage(items: [walletTxnFixture('a')], nextCursor: null))
        ..txnPages.add(WalletTxnPage(items: [walletTxnFixture('z')], nextCursor: null));
      final c = container(repo);
      addTearDown(c.dispose);
      final all = await c.read(walletTransactionsProvider('all').future);
      final deposits = await c.read(walletTransactionsProvider('deposits').future);
      expect(all.items.single.id, 'a');
      expect(deposits.items.single.id, 'z');
    });
  });

  test('myWithdrawalsProvider is null when signed out and loads for a viewer', () async {
    final repo = FakeWalletRepository()..withdrawals = WithdrawalPage(items: [withdrawalFixture('wr1')], nextCursor: null);
    final signedOut = container(repo, viewer: null);
    addTearDown(signedOut.dispose);
    expect(await signedOut.read(myWithdrawalsProvider.future), isNull);
    expect(repo.calls, isEmpty);
    final c = container(repo);
    addTearDown(c.dispose);
    expect((await c.read(myWithdrawalsProvider.future))!.items.single.id, 'wr1');
  });
}
