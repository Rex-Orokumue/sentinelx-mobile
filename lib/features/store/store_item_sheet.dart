import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/store_models.dart';
import '../../core/l10n/gen/app_localizations.dart';
import '../../core/providers.dart';
import '../../core/theme/sx_colors.dart';
import '../../core/utils/write_flow.dart';
import '../../shared/cosmetics/cosmetic_art.dart';
import '../wallet/wallet_providers.dart';
import 'coin_format.dart';
import 'store_errors.dart';
import 'store_providers.dart';

Future<void> showStoreItemSheet(BuildContext context, String itemId) => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => StoreItemSheet(itemId: itemId),
    );

/// The detail sheet for one store item: preview, price and Buy / Equip / Unequip. State always comes back from
/// the server (the catalogue is refetched after every action); nothing is assumed locally. A purchase uses one
/// `Idempotency-Key` per item, and a double tap cannot open two confirmations.
class StoreItemSheet extends ConsumerStatefulWidget {
  const StoreItemSheet({super.key, required this.itemId});

  final String itemId;

  @override
  ConsumerState<StoreItemSheet> createState() => _StoreItemSheetState();
}

class _StoreItemSheetState extends ConsumerState<StoreItemSheet> {
  bool _confirming = false; // a field, not setState: two taps in one frame must still be one confirmation
  bool _busy = false;
  String? _notice;
  Object? _equipError;

  String get _scope => 'store-purchase:${widget.itemId}';

  Future<void> _buy(StoreItem item, int balance) async {
    if (_confirming || _busy) return;
    _confirming = true;
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.storeBuyConfirmTitle(item.name)),
        content: Text(l10n.storeBuyConfirmBody(formatCoins(item.priceCoins), formatCoins(balance - item.priceCoins))),
        actions: [
          TextButton(key: const Key('store-buy-cancel'), onPressed: () => Navigator.of(ctx).pop(false), child: Text(l10n.storeCancel)),
          FilledButton(key: const Key('store-buy-confirm'), onPressed: () => Navigator.of(ctx).pop(true), child: Text(l10n.storeBuy)),
        ],
      ),
    );
    _confirming = false;
    if (confirmed != true || !mounted) return;

    setState(() {
      _notice = null;
      _equipError = null;
    });
    final repo = ref.read(storeRepositoryProvider);
    final ok = await ref.read(writeFlowProvider(_scope).notifier).run(
      (key) async {
        await repo.purchase(item.id, idempotencyKey: key);
      },
      fingerprint: item.id,
    );
    if (!mounted) return;
    if (ok) setState(() => _notice = l10n.storeBought);
    // Success or failure, show the truth from the server (e.g. `already_owned` after buying on another device).
    ref.invalidate(storeCatalogueProvider);
    if (ok) ref.invalidate(walletOverviewProvider); // the coin balance beside the wallet changed
  }

  Future<void> _setEquipped(StoreItem item, bool equip) async {
    if (_busy) return;
    final l10n = AppLocalizations.of(context);
    setState(() {
      _busy = true;
      _notice = null;
      _equipError = null;
    });
    try {
      final repo = ref.read(storeRepositoryProvider);
      if (equip) {
        await repo.equip(item.id);
      } else {
        await repo.unequip(item.id);
      }
      if (!mounted) return;
      setState(() => _notice = equip ? l10n.storeEquippedNow : l10n.storeUnequippedNow);
      ref.invalidate(meProvider); // the Account identity and the assistant bubble pick the change up
    } catch (e) {
      if (!mounted) return;
      setState(() => _equipError = e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    ref.invalidate(storeCatalogueProvider);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final catalogue = ref.watch(storeCatalogueProvider).asData?.value;
    final flow = ref.watch(writeFlowProvider(_scope)); // watched so the idempotent write outlives each tap
    StoreItem? item;
    for (final i in catalogue?.items ?? const <StoreItem>[]) {
      if (i.id == widget.itemId) item = i;
    }
    if (item == null) return const SizedBox(height: 120, child: Center(child: CircularProgressIndicator()));
    final balance = catalogue?.balance; // null = signed out

    String? error;
    if (flow.phase == WritePhase.failed) error = storeErrorCodeCopy(l10n, flow.errorCode ?? 'network');
    if (_equipError != null) error = storeErrorCopy(l10n, _equipError!);

    final affordable = balance != null && balance >= item.priceCoins;
    return SafeArea(
      child: SingleChildScrollView(
        key: const Key('store-sheet'),
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 160,
              child: CosmeticArt.image(
                item.previewUrl,
                fit: BoxFit.contain,
                fallback: const Icon(Icons.image_not_supported_outlined, size: 48, color: SxColors.textSecondary),
              ),
            ),
            const SizedBox(height: 12),
            Text(item.name, style: theme.textTheme.titleLarge),
            if (item.description != null) ...[
              const SizedBox(height: 4),
              Text(item.description!, style: theme.textTheme.bodyMedium?.copyWith(color: SxColors.textSecondary)),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.monetization_on_outlined, color: SxColors.warning),
                const SizedBox(width: 6),
                Text(formatCoins(item.priceCoins), style: theme.textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 16),
            if (item.owned && item.equipped)
              OutlinedButton(
                key: const Key('store-unequip'),
                onPressed: _busy ? null : () => _setEquipped(item!, false),
                child: Text(l10n.storeUnequip),
              )
            else if (item.owned)
              FilledButton(
                key: const Key('store-equip'),
                onPressed: _busy ? null : () => _setEquipped(item!, true),
                child: Text(l10n.storeEquip),
              )
            else if (balance == null)
              FilledButton(
                key: const Key('store-buy'),
                onPressed: () {
                  Navigator.of(context).pop();
                  context.push('/login');
                },
                child: Text(l10n.storeLogInToBuy),
              )
            else ...[
              FilledButton(
                key: const Key('store-buy'),
                onPressed: affordable && !flow.busy ? () => _buy(item!, balance) : null,
                child: Text(l10n.storeBuy),
              ),
              if (!affordable)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    l10n.storeNeedMore(formatCoins(item.priceCoins - balance)),
                    key: const Key('store-need-more'),
                    style: theme.textTheme.bodySmall?.copyWith(color: SxColors.warning),
                  ),
                ),
            ],
            if (_notice != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(_notice!, key: const Key('store-notice'), style: const TextStyle(color: SxColors.success)),
              ),
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(error, key: const Key('store-error'), style: const TextStyle(color: SxColors.warning)),
              ),
          ],
        ),
      ),
    );
  }
}
