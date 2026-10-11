import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/gen/app_localizations.dart';
import '../../core/theme/sx_colors.dart';
import 'wallet_providers.dart';
import 'wallet_widgets.dart';

/// `/account/wallet/transactions`: the ledger, newest first, filterable and cursor-paged. Rows load as the player
/// nears the end of the list; a failed page shows an inline retry and never drops what is already loaded.
class TransactionsScreen extends ConsumerStatefulWidget {
  const TransactionsScreen({super.key});

  @override
  ConsumerState<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends ConsumerState<TransactionsScreen> {
  static const _filters = ['all', 'winnings', 'withdrawals', 'deposits'];

  final _scroll = ScrollController();
  String _filter = 'all';

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_maybeLoadMore);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _maybeLoadMore() {
    if (!_scroll.hasClients || _scroll.position.extentAfter > 300) return;
    final list = ref.read(walletTransactionsProvider(_filter)).asData?.value;
    if (list == null || list.nextCursor == null || list.loadingMore || list.loadMoreFailed) return;
    ref.read(walletTransactionsProvider(_filter).notifier).loadMore();
  }

  String _label(AppLocalizations l10n, String filter) => switch (filter) {
        'winnings' => l10n.walletFilterWinnings,
        'withdrawals' => l10n.walletFilterWithdrawals,
        'deposits' => l10n.walletFilterDeposits,
        _ => l10n.walletFilterAll,
      };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final provider = walletTransactionsProvider(_filter);
    final list = ref.watch(provider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.walletTransactions)),
      body: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                for (final f in _filters)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      key: Key('txn-filter-$f'),
                      label: Text(_label(l10n, f)),
                      selected: _filter == f,
                      onSelected: (_) => setState(() => _filter = f),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: list.when(
              loading: () => const Center(child: CircularProgressIndicator(key: Key('txn-loading'))),
              error: (_, _) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(l10n.walletLoadFailed),
                    TextButton(key: const Key('txn-retry'), onPressed: () => ref.invalidate(provider), child: Text(l10n.walletRetry)),
                  ],
                ),
              ),
              data: (data) => RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(provider);
                  await ref.read(provider.future);
                },
                child: data.items.isEmpty
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(16),
                        children: [Text(l10n.walletTxnEmpty, style: const TextStyle(color: SxColors.textSecondary))],
                      )
                    : ListView.builder(
                        controller: _scroll,
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        itemCount: data.items.length + (data.nextCursor != null || data.loadMoreFailed ? 1 : 0),
                        itemBuilder: (context, i) {
                          if (i < data.items.length) return WalletTxnTile(data.items[i], key: ValueKey('txn-${data.items[i].id}'));
                          if (data.loadMoreFailed) {
                            return InkWell(
                              key: const Key('txn-load-more-retry'),
                              onTap: () => ref.read(provider.notifier).loadMore(),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Center(child: Text(l10n.walletTxnLoadMoreFailed)),
                              ),
                            );
                          }
                          return const Padding(
                            padding: EdgeInsets.all(16),
                            child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
                          );
                        },
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
