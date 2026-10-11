import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/wallet_models.dart';
import '../../core/l10n/gen/app_localizations.dart';
import '../../core/theme/sx_colors.dart';
import 'wallet_errors.dart';
import 'wallet_providers.dart';
import 'wallet_widgets.dart';

/// `/account/wallet/payout-account`. The account number is typed once and held only in the text field: it is
/// cleared on save and on dispose, never stored, logged or shown again (the saved account reads back masked).
class PayoutAccountScreen extends ConsumerStatefulWidget {
  const PayoutAccountScreen({super.key});

  @override
  ConsumerState<PayoutAccountScreen> createState() => _PayoutAccountScreenState();
}

class _PayoutAccountScreenState extends ConsumerState<PayoutAccountScreen> {
  final _number = TextEditingController();
  WalletBank? _bank;
  String? _resolvedName;
  Object? _error;
  String? _notice;
  bool _busy = false;

  @override
  void dispose() {
    _number.clear();
    _number.dispose();
    super.dispose();
  }

  bool get _ready => _bank != null && RegExp(r'^\d{10}$').hasMatch(_number.text);

  void _invalidateConfirmation() {
    _resolvedName = null;
    _error = null;
    _notice = null;
  }

  Future<void> _pickBank() async {
    final picked = await showModalBottomSheet<WalletBank>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _BankSheet(),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _bank = picked;
      _invalidateConfirmation();
    });
  }

  Future<void> _resolve() async {
    final bank = _bank;
    if (bank == null || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
      _resolvedName = null;
    });
    try {
      final name = await ref.read(walletRepositoryProvider).resolvePayoutAccount(bankCode: bank.code, accountNumber: _number.text);
      if (!mounted) return;
      setState(() => _resolvedName = name);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    final bank = _bank;
    if (bank == null || _resolvedName == null || _busy) return;
    final l10n = AppLocalizations.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(walletRepositoryProvider).setPayoutAccount(bankCode: bank.code, accountNumber: _number.text);
      if (!mounted) return;
      _number.clear();
      setState(() {
        _bank = null;
        _resolvedName = null;
        _notice = l10n.walletPayoutSaved;
      });
      ref.invalidate(walletOverviewProvider);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _remove() async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.walletPayoutRemoveTitle),
        content: Text(l10n.walletPayoutRemoveBody),
        actions: [
          TextButton(key: const Key('payout-remove-cancel'), onPressed: () => Navigator.of(ctx).pop(false), child: Text(l10n.walletCancel)),
          FilledButton(key: const Key('payout-remove-confirm'), onPressed: () => Navigator.of(ctx).pop(true), child: Text(l10n.walletPayoutRemove)),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(walletRepositoryProvider).removePayoutAccount();
      if (!mounted) return;
      setState(() => _notice = l10n.walletPayoutRemoved);
      ref.invalidate(walletOverviewProvider);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final overview = ref.watch(walletOverviewProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.walletPayoutAccount)),
      body: overview.when(
        loading: () => const Center(child: CircularProgressIndicator(key: Key('payout-loading'))),
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
                child: TextButton(
                  key: const Key('payout-login'),
                  onPressed: () => context.push('/login'),
                  child: Text(l10n.walletSignedOut),
                ),
              )
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (_notice != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(_notice!, key: const Key('payout-notice'), style: const TextStyle(color: SxColors.success)),
                    ),
                  if (data.payoutAccount != null) _saved(context, l10n, data.payoutAccount!) else _form(context, l10n),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(walletErrorCopy(l10n, _error!), key: const Key('payout-error'), style: const TextStyle(color: SxColors.warning)),
                    ),
                ],
              ),
      ),
    );
  }

  Widget _saved(BuildContext context, AppLocalizations l10n, PayoutAccount account) => WalletPanel(
        children: [
          Text(account.bankName),
          Text(account.accountName),
          Text(account.accountNumberMasked),
          const SizedBox(height: 4),
          Text(l10n.walletPayoutVerified, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: SxColors.success)),
          const SizedBox(height: 12),
          OutlinedButton(
            key: const Key('payout-remove'),
            onPressed: _busy ? null : _remove,
            child: Text(l10n.walletPayoutRemove),
          ),
        ],
      );

  Widget _form(BuildContext context, AppLocalizations l10n) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          key: const Key('payout-bank'),
          onTap: _busy ? null : _pickBank,
          child: InputDecorator(
            decoration: InputDecoration(labelText: l10n.walletPayoutBank),
            child: Text(_bank?.name ?? l10n.walletPayoutBankHint),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          key: const Key('payout-number'),
          controller: _number,
          enabled: !_busy,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)],
          decoration: InputDecoration(labelText: l10n.walletPayoutNumber),
          onChanged: (_) => setState(_invalidateConfirmation),
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          key: const Key('payout-resolve'),
          onPressed: _ready && !_busy ? _resolve : null,
          child: Text(l10n.walletPayoutResolve),
        ),
        if (_resolvedName != null) ...[
          const SizedBox(height: 12),
          Text(l10n.walletPayoutAccountName(_resolvedName!), key: const Key('payout-name'), style: theme.textTheme.titleSmall),
          const SizedBox(height: 4),
          Text(l10n.walletPayoutConfirmPrompt, style: theme.textTheme.bodySmall?.copyWith(color: SxColors.textSecondary)),
        ],
        const SizedBox(height: 12),
        FilledButton(
          key: const Key('payout-save'),
          onPressed: _resolvedName != null && !_busy ? _save : null,
          child: Text(l10n.walletPayoutSave),
        ),
      ],
    );
  }
}

class _BankSheet extends ConsumerStatefulWidget {
  const _BankSheet();

  @override
  ConsumerState<_BankSheet> createState() => _BankSheetState();
}

class _BankSheetState extends ConsumerState<_BankSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final banks = ref.watch(walletBanksProvider);
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.7,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: TextField(
                  key: const Key('payout-bank-search'),
                  decoration: InputDecoration(labelText: l10n.walletPayoutSearchBank, prefixIcon: const Icon(Icons.search)),
                  onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
                ),
              ),
              Expanded(
                child: banks.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (_, _) => Center(
                    child: TextButton(onPressed: () => ref.invalidate(walletBanksProvider), child: Text(l10n.walletRetry)),
                  ),
                  data: (all) {
                    final shown = [for (final b in all) if (b.name.toLowerCase().contains(_query)) b];
                    return ListView.builder(
                      itemCount: shown.length,
                      itemBuilder: (_, i) => ListTile(
                        key: Key('bank-${shown[i].code}'),
                        title: Text(shown[i].name),
                        onTap: () => Navigator.of(context).pop(shown[i]),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
