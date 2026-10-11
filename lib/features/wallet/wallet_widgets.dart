import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/api/wallet_models.dart';
import '../../core/l10n/gen/app_localizations.dart';
import '../../core/theme/sx_colors.dart';
import '../../core/utils/date_locale.dart';
import 'money_format.dart';

/// The card container every wallet screen uses.
class WalletPanel extends StatelessWidget {
  const WalletPanel({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: SxColors.surface,
          border: Border.all(color: SxColors.border),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
      );
}

/// A label on the left and a bold value on the right; the label wraps instead of overflowing on narrow screens.
class WalletStat extends StatelessWidget {
  const WalletStat(this.label, this.value, {super.key});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Expanded(child: Text(label)),
            const SizedBox(width: 8),
            Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
      );
}

/// Human label for a ledger row. Raw codes from the server fall back to a generic word, never to the code itself.
String walletTxnLabel(AppLocalizations l10n, WalletTxn txn) {
  if (txn.type == 'deposit') return l10n.walletCatDeposit;
  switch (txn.category) {
    case 'tournament_prize':
      return l10n.walletCatPrize;
    case 'referral':
      return l10n.walletCatReferral;
    case 'bonus':
      return l10n.walletCatBonus;
    case 'withdrawal':
      return l10n.walletCatWithdrawal;
  }
  return l10n.walletCatOther;
}

String walletStatusLabel(AppLocalizations l10n, String status) => switch (status) {
      'pending' => l10n.walletStatusPending,
      'failed' => l10n.walletStatusFailed,
      'paid' => l10n.walletStatusPaid,
      'rejected' => l10n.walletStatusRejected,
      _ => status,
    };

/// One ledger row: label and date on the left, signed amount (credits `+`, debits `−`) on the right, and a status
/// chip for anything not completed.
class WalletTxnTile extends StatelessWidget {
  const WalletTxnTile(this.txn, {super.key});

  final WalletTxn txn;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final date = DateFormat.MMMd(dateLocale(Localizations.localeOf(context).languageCode)).format(txn.createdAt.toLocal());
    final credit = txn.amount > 0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(walletTxnLabel(l10n, txn)),
                Text(date, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: SxColors.textSecondary)),
                if (txn.status != 'completed')
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      walletStatusLabel(l10n, txn.status),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(color: SxColors.warning),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            credit ? '+${formatNaira(txn.amount)}' : formatNaira(txn.amount),
            style: TextStyle(fontWeight: FontWeight.bold, color: credit ? SxColors.success : null),
          ),
        ],
      ),
    );
  }
}
