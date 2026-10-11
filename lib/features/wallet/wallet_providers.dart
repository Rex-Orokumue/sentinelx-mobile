import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/wallet_models.dart';
import '../../core/providers.dart';
import 'wallet_repository.dart';

final walletRepositoryProvider = Provider<WalletRepository>(
  (ref) => ApiWalletRepository(ref.watch(apiClientProvider)),
);

/// The wallet overview, or null when signed out (no request is made). Keyed on the viewer id, so a token refresh
/// does not refetch.
final walletOverviewProvider = FutureProvider.autoDispose<WalletOverview?>((ref) async {
  final viewer = await ref.watch(viewerIdProvider.future);
  if (viewer == null) return null;
  return ref.watch(walletRepositoryProvider).getMyWallet();
});

final walletBanksProvider = FutureProvider.autoDispose<List<WalletBank>>(
  (ref) => ref.watch(walletRepositoryProvider).listWalletBanks(),
);

final myWithdrawalsProvider = FutureProvider.autoDispose<WithdrawalPage?>((ref) async {
  final viewer = await ref.watch(viewerIdProvider.future);
  if (viewer == null) return null;
  return ref.watch(walletRepositoryProvider).listMyWithdrawals();
});

/// A growing, cursor-paged ledger list for one filter.
class WalletTxnList {
  const WalletTxnList({required this.items, required this.nextCursor, this.loadingMore = false, this.loadMoreFailed = false});

  final List<WalletTxn> items;
  final String? nextCursor;
  final bool loadingMore;
  final bool loadMoreFailed;

  WalletTxnList copyWith({List<WalletTxn>? items, String? nextCursor, bool? loadingMore, bool? loadMoreFailed, bool clearCursor = false}) =>
      WalletTxnList(
        items: items ?? this.items,
        nextCursor: clearCursor ? null : (nextCursor ?? this.nextCursor),
        loadingMore: loadingMore ?? this.loadingMore,
        loadMoreFailed: loadMoreFailed ?? this.loadMoreFailed,
      );
}

/// Family key is the filter: `all`, `winnings`, `withdrawals` or `deposits`. Each filter keeps its own list.
final walletTransactionsProvider =
    AsyncNotifierProvider.autoDispose.family<WalletTransactionsNotifier, WalletTxnList, String>(WalletTransactionsNotifier.new);

class WalletTransactionsNotifier extends AsyncNotifier<WalletTxnList> {
  WalletTransactionsNotifier(this.filter);

  final String filter;

  @override
  Future<WalletTxnList> build() async {
    final page = await ref.watch(walletRepositoryProvider).listMyWalletTransactions(filter: filter);
    return WalletTxnList(items: page.items, nextCursor: page.nextCursor);
  }

  /// Appends the next page. A failure keeps everything already loaded and sets [WalletTxnList.loadMoreFailed];
  /// calling this again retries. Rows already shown (same id) are never duplicated.
  Future<void> loadMore() async {
    final current = state.asData?.value;
    if (current == null || current.nextCursor == null || current.loadingMore) return;
    state = AsyncData(current.copyWith(loadingMore: true, loadMoreFailed: false));
    try {
      final page = await ref.read(walletRepositoryProvider).listMyWalletTransactions(filter: filter, cursor: current.nextCursor);
      if (!ref.mounted) return;
      final seen = {for (final t in current.items) t.id};
      state = AsyncData(
        WalletTxnList(
          items: [...current.items, for (final t in page.items) if (!seen.contains(t.id)) t],
          nextCursor: page.nextCursor,
        ),
      );
    } catch (_) {
      if (!ref.mounted) return;
      state = AsyncData(current.copyWith(loadingMore: false, loadMoreFailed: true));
    }
  }
}
