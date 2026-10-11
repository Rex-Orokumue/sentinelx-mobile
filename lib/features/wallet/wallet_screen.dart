import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/wallet_models.dart';
import '../../core/l10n/gen/app_localizations.dart';
import '../../core/theme/sx_colors.dart';
import '../store/coin_format.dart';
import 'money_format.dart';
import 'wallet_providers.dart';
import 'wallet_widgets.dart';

/// `/account/wallet`: balance, earnings, recent transactions and the payout account. Every figure comes from
/// `GET /wallet`; nothing is computed on the device.
class WalletScreen extends ConsumerWidget {
  const WalletScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final overview = ref.watch(walletOverviewProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.walletTitle)),
      body: overview.when(
        loading: () => const Center(child: CircularProgressIndicator(key: Key('wallet-loading'))),
        error: (_, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l10n.walletLoadFailed),
              TextButton(
                key: const Key('wallet-retry'),
                onPressed: () => ref.invalidate(walletOverviewProvider),
                child: Text(l10n.walletRetry),
              ),
            ],
          ),
        ),
        data: (data) => data == null
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(l10n.walletSignedOut),
                    TextButton(
                      key: const Key('wallet-login'),
                      onPressed: () => context.push('/login'),
                      child: Text(l10n.accountLogIn),
                    ),
                  ],
                ),
              )
            : RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(walletOverviewProvider);
                  await ref.read(walletOverviewProvider.future);
                },
                child: _Body(data: data),
              ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.data});

  final WalletOverview data;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final trend = data.earnings.tournamentPrizeTrendPct;
    final account = data.payoutAccount;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        WalletPanel(
          children: [
            Text(l10n.walletBalance, style: theme.textTheme.labelMedium),
            const SizedBox(height: 4),
            Text(formatNaira(data.balance), key: const Key('wallet-balance'), style: theme.textTheme.headlineMedium),
            if (data.pendingWithdrawal > 0)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  l10n.walletPendingWithdrawal(formatNaira(data.pendingWithdrawal)),
                  key: const Key('wallet-pending'),
                  style: theme.textTheme.bodySmall?.copyWith(color: SxColors.warning),
                ),
              ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton(
                  key: const Key('wallet-add-money'),
                  onPressed: () => context.push('/account/wallet/deposit'),
                  child: Text(l10n.walletAddMoney),
                ),
                FilledButton(
                  key: const Key('wallet-withdraw'),
                  onPressed: account == null ? null : () => context.push('/account/wallet/withdraw'),
                  child: Text(l10n.walletWithdraw),
                ),
              ],
            ),
            if (account == null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  l10n.walletWithdrawNeedAccount,
                  key: const Key('wallet-withdraw-hint'),
                  style: theme.textTheme.bodySmall?.copyWith(color: SxColors.textSecondary),
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        WalletPanel(
          children: [
            Row(
              key: const Key('wallet-coins'),
              children: [
                const Icon(Icons.monetization_on_outlined, color: SxColors.warning),
                const SizedBox(width: 8),
                Expanded(child: Text(l10n.walletCoinBalance, style: theme.textTheme.titleSmall)),
                Text(formatCoins(data.coinBalance), style: theme.textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              l10n.storeDisclaimer,
              style: theme.textTheme.bodySmall?.copyWith(color: SxColors.textSecondary),
            ),
          ],
        ),
        const SizedBox(height: 16),
        WalletPanel(
          children: [
            Text(l10n.walletEarnings, style: theme.textTheme.titleSmall),
            const SizedBox(height: 4),
            WalletStat(l10n.walletEarnPrize, formatNaira(data.earnings.tournamentPrize)),
            if (trend != null)
              Text(
                l10n.walletTrend(trend > 0 ? '+$trend' : '$trend'),
                key: const Key('wallet-trend'),
                style: theme.textTheme.bodySmall?.copyWith(color: trend >= 0 ? SxColors.success : SxColors.warning),
              ),
            WalletStat(l10n.walletEarnReferral, formatNaira(data.earnings.referral)),
            WalletStat(l10n.walletEarnBonus, formatNaira(data.earnings.bonus)),
          ],
        ),
        const SizedBox(height: 16),
        WalletPanel(
          children: [
            Row(
              children: [
                Expanded(child: Text(l10n.walletTransactions, style: theme.textTheme.titleSmall)),
                TextButton(
                  key: const Key('wallet-see-all'),
                  onPressed: () => context.push('/account/wallet/transactions'),
                  child: Text(l10n.walletSeeAll),
                ),
              ],
            ),
            if (data.recentTransactions.isEmpty)
              Text(l10n.walletNoTransactions, style: theme.textTheme.bodyMedium?.copyWith(color: SxColors.textSecondary))
            else
              for (final t in data.recentTransactions) WalletTxnTile(t, key: ValueKey('txn-${t.id}')),
          ],
        ),
        const SizedBox(height: 16),
        WalletPanel(
          children: [
            Text(l10n.walletPayoutAccount, style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            if (account == null) ...[
              Text(l10n.walletPayoutNone, style: theme.textTheme.bodyMedium?.copyWith(color: SxColors.textSecondary)),
              const SizedBox(height: 8),
              FilledButton(
                key: const Key('wallet-payout-add'),
                onPressed: () => context.push('/account/wallet/payout-account'),
                child: Text(l10n.walletPayoutAdd),
              ),
            ] else ...[
              Text(account.bankName),
              Text(account.accountName),
              Text(account.accountNumberMasked),
              const SizedBox(height: 4),
              Text(l10n.walletPayoutVerified, style: theme.textTheme.labelSmall?.copyWith(color: SxColors.success)),
              const SizedBox(height: 8),
              OutlinedButton(
                key: const Key('wallet-payout-manage'),
                onPressed: () => context.push('/account/wallet/payout-account'),
                child: Text(l10n.walletPayoutManage),
              ),
            ],
          ],
        ),
        const SizedBox(height: 16),
        Text(
          l10n.walletManualPayoutNotice,
          key: const Key('wallet-manual-notice'),
          style: theme.textTheme.bodySmall?.copyWith(color: SxColors.textSecondary),
        ),
      ],
    );
  }
}
