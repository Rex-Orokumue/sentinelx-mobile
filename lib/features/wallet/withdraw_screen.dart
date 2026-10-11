import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/api/wallet_models.dart';
import '../../core/l10n/gen/app_localizations.dart';
import '../../core/theme/sx_colors.dart';
import '../../core/utils/date_locale.dart';
import '../../core/utils/write_flow.dart';
import 'money_format.dart';
import 'wallet_errors.dart';
import 'wallet_providers.dart';
import 'wallet_widgets.dart';

const _withdrawMinAmount = 100;
const _scope = 'wallet-withdraw';

enum _LocalError { min, exceeds }

/// `/account/wallet/withdraw`. A request is paid out by an administrator, not instantly. The balance and the
/// "one pending request" rule come from the API; the checks here only avoid a pointless round trip.
class WithdrawScreen extends ConsumerStatefulWidget {
  const WithdrawScreen({super.key});

  @override
  ConsumerState<WithdrawScreen> createState() => _WithdrawScreenState();
}

class _WithdrawScreenState extends ConsumerState<WithdrawScreen> {
  final _amount = TextEditingController();
  _LocalError? _local;
  bool _submitted = false;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _submit(WalletOverview overview) async {
    final amount = int.tryParse(_amount.text);
    if (amount == null || amount < _withdrawMinAmount) {
      setState(() => _local = _LocalError.min);
      return;
    }
    if (amount > overview.balance) {
      setState(() => _local = _LocalError.exceeds);
      return;
    }
    setState(() {
      _local = null;
      _submitted = false;
    });
    final ok = await ref.read(writeFlowProvider(_scope).notifier).run(
      (key) async {
        await ref.read(walletRepositoryProvider).requestWithdrawal(amount, idempotencyKey: key);
      },
      fingerprint: amount, // a changed amount must not replay the response stored for the old one
    );
    if (!ok || !mounted) return;
    _amount.clear();
    setState(() => _submitted = true);
    ref.invalidate(walletOverviewProvider);
    ref.invalidate(myWithdrawalsProvider);
    ref.invalidate(walletTransactionsProvider);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final overview = ref.watch(walletOverviewProvider);
    final flow = ref.watch(writeFlowProvider(_scope)); // watched so the idempotent write outlives each tap
    return Scaffold(
      appBar: AppBar(title: Text(l10n.walletWithdrawTitle)),
      body: overview.when(
        loading: () => const Center(child: CircularProgressIndicator(key: Key('withdraw-loading'))),
        error: (_, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l10n.walletLoadFailed),
              TextButton(onPressed: () => ref.invalidate(walletOverviewProvider), child: Text(l10n.walletRetry)),
            ],
          ),
        ),
        data: (data) => data == null
            ? Center(
                child: TextButton(onPressed: () => context.push('/login'), child: Text(l10n.walletSignedOut)),
              )
            : _body(context, l10n, data, flow),
      ),
    );
  }

  Widget _body(BuildContext context, AppLocalizations l10n, WalletOverview data, WriteState flow) {
    final theme = Theme.of(context);
    final noAccount = data.payoutAccount == null;
    final pending = data.activeWithdrawal != null;
    final blocked = noAccount || pending;
    final history = ref.watch(myWithdrawalsProvider);
    final date = DateFormat.MMMd(dateLocale(Localizations.localeOf(context).languageCode));

    String? fieldError;
    if (_local == _LocalError.min) fieldError = l10n.walletMinAmount(formatNaira(_withdrawMinAmount));
    if (_local == _LocalError.exceeds) fieldError = l10n.walletWithdrawExceeds;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(l10n.walletWithdrawAvailable(formatNaira(data.balance)), key: const Key('withdraw-available'), style: theme.textTheme.titleMedium),
        const SizedBox(height: 12),
        TextField(
          key: const Key('withdraw-amount'),
          controller: _amount,
          enabled: !blocked && !flow.busy,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(labelText: l10n.walletAmountLabel, errorText: fieldError),
          onChanged: (_) => setState(() {
            _local = null;
            _submitted = false;
          }),
        ),
        const SizedBox(height: 12),
        if (noAccount) ...[
          Text(l10n.walletWithdrawNeedAccount, style: theme.textTheme.bodyMedium?.copyWith(color: SxColors.textSecondary)),
          const SizedBox(height: 8),
          OutlinedButton(
            key: const Key('withdraw-add-account'),
            onPressed: () => context.push('/account/wallet/payout-account'),
            child: Text(l10n.walletPayoutAdd),
          ),
          const SizedBox(height: 12),
        ],
        if (pending)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(l10n.walletWithdrawPendingExists, key: const Key('withdraw-pending'), style: const TextStyle(color: SxColors.warning)),
          ),
        FilledButton(
          key: const Key('withdraw-request'),
          onPressed: blocked || flow.busy ? null : () => _submit(data),
          child: Text(l10n.walletWithdrawRequest),
        ),
        if (flow.phase == WritePhase.failed)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              walletErrorCodeCopy(l10n, flow.errorCode ?? 'network', flow.fieldErrors),
              key: const Key('withdraw-error'),
              style: const TextStyle(color: SxColors.warning),
            ),
          ),
        if (_submitted)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(l10n.walletWithdrawSubmitted, key: const Key('withdraw-submitted'), style: const TextStyle(color: SxColors.success)),
          ),
        const SizedBox(height: 8),
        Text(l10n.walletManualPayoutNotice, style: theme.textTheme.bodySmall?.copyWith(color: SxColors.textSecondary)),
        const SizedBox(height: 24),
        Text(l10n.walletWithdrawHistory, style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        history.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => TextButton(onPressed: () => ref.invalidate(myWithdrawalsProvider), child: Text(l10n.walletRetry)),
          data: (page) => page == null || page.items.isEmpty
              ? Text(l10n.walletWithdrawNone, style: theme.textTheme.bodyMedium?.copyWith(color: SxColors.textSecondary))
              : Column(
                  children: [
                    for (final w in page.items)
                      Padding(
                        key: ValueKey('wd-${w.id}'),
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(formatNaira(w.amount), style: const TextStyle(fontWeight: FontWeight.bold)),
                                  Text(
                                    date.format(w.requestedAt.toLocal()),
                                    style: theme.textTheme.bodySmall?.copyWith(color: SxColors.textSecondary),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              walletStatusLabel(l10n, w.status),
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: switch (w.status) {
                                  'paid' => SxColors.success,
                                  'rejected' => SxColors.warning,
                                  _ => null,
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}
