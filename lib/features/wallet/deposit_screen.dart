import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/gen/app_localizations.dart';
import '../../core/theme/sx_colors.dart';
import 'deposit_controller.dart';
import 'money_format.dart';
import 'wallet_errors.dart';

/// Smallest top-up the server accepts (the API enforces it too; this only avoids a pointless round trip).
const walletMinAmount = 100;

/// `/account/wallet/deposit`. The Paystack fee shown here is the one the SERVER returned for this deposit.
class DepositScreen extends ConsumerStatefulWidget {
  const DepositScreen({super.key});

  @override
  ConsumerState<DepositScreen> createState() => _DepositScreenState();
}

class _DepositScreenState extends ConsumerState<DepositScreen> {
  final _amount = TextEditingController();
  bool _belowMin = false;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final amount = int.tryParse(_amount.text);
    if (amount == null || amount < walletMinAmount) {
      setState(() => _belowMin = true);
      return;
    }
    setState(() => _belowMin = false);
    await ref.read(depositControllerProvider.notifier).start(amount);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(depositControllerProvider);
    final theme = Theme.of(context);
    final done = state.phase == DepositPhase.confirmed;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.walletDepositTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            key: const Key('deposit-amount'),
            controller: _amount,
            enabled: !state.busy && !done,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              labelText: l10n.walletAmountLabel,
              errorText: _belowMin ? l10n.walletMinAmount(formatNaira(walletMinAmount)) : null,
            ),
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 12),
          if (state.fee != null && state.total != null)
            Text(
              l10n.walletDepositFee(formatNaira(state.fee!), formatNaira(state.total!)),
              key: const Key('deposit-fee'),
              style: theme.textTheme.bodySmall?.copyWith(color: SxColors.textSecondary),
            ),
          const SizedBox(height: 16),
          if (state.phase == DepositPhase.idle || state.phase == DepositPhase.starting || state.phase == DepositPhase.failed)
            FilledButton(
              key: const Key('deposit-continue'),
              onPressed: state.busy ? null : _submit,
              child: Text(l10n.walletDepositContinue),
            ),
          if (state.phase == DepositPhase.failed)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                walletErrorCodeCopy(l10n, state.errorCode ?? 'network', state.fieldErrors),
                key: const Key('deposit-error'),
                style: theme.textTheme.bodyMedium?.copyWith(color: SxColors.warning),
              ),
            ),
          if (state.phase == DepositPhase.awaitingPayment || state.phase == DepositPhase.confirming)
            Row(
              children: [
                const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                const SizedBox(width: 12),
                Expanded(child: Text(l10n.walletDepositConfirming, key: const Key('deposit-confirming'))),
              ],
            ),
          if (state.phase == DepositPhase.mayArrive) ...[
            Text(state.checkoutClosed ? l10n.walletDepositClosed : l10n.walletDepositMayArrive, key: const Key('deposit-may-arrive')),
            const SizedBox(height: 12),
            OutlinedButton(
              key: const Key('deposit-check-again'),
              onPressed: () => ref.read(depositControllerProvider.notifier).recheck(),
              child: Text(l10n.walletDepositCheckAgain),
            ),
          ],
          if (done) ...[
            Text(l10n.walletDepositSuccess, key: const Key('deposit-success'), style: theme.textTheme.bodyLarge?.copyWith(color: SxColors.success)),
            const SizedBox(height: 12),
            FilledButton(
              key: const Key('deposit-done'),
              onPressed: () => context.canPop() ? context.pop() : context.go('/account/wallet'),
              child: Text(l10n.walletDone),
            ),
          ],
        ],
      ),
    );
  }
}
