import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/store_models.dart';
import '../../core/l10n/gen/app_localizations.dart';
import '../../core/theme/sx_colors.dart';
import '../../shared/cosmetics/cosmetic_art.dart';
import 'coin_format.dart';
import 'store_item_sheet.dart';
import 'store_providers.dart';

const _categories = ['avatar_border', 'bubble_skin', 'profile_theme', 'username_colour'];

/// `/account/store`: the coin store. Browsing is public; ownership and the balance appear when signed in. Every
/// figure comes from the API, and nothing here suggests coins can be bought with money (they are earned only).
class StoreScreen extends ConsumerStatefulWidget {
  const StoreScreen({super.key});

  @override
  ConsumerState<StoreScreen> createState() => _StoreScreenState();
}

class _StoreScreenState extends ConsumerState<StoreScreen> {
  String _category = _categories.first;

  String _categoryLabel(AppLocalizations l10n, String c) => switch (c) {
        'bubble_skin' => l10n.storeCatBubbles,
        'profile_theme' => l10n.storeCatThemes,
        'username_colour' => l10n.storeCatColours,
        _ => l10n.storeCatBorders,
      };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final catalogue = ref.watch(storeCatalogueProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.storeTitle)),
      body: catalogue.when(
        loading: () => const Center(child: CircularProgressIndicator(key: Key('store-loading'))),
        error: (_, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l10n.storeLoadFailed),
              TextButton(
                key: const Key('store-retry'),
                onPressed: () => ref.invalidate(storeCatalogueProvider),
                child: Text(l10n.storeRetry),
              ),
            ],
          ),
        ),
        data: (data) => RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(storeCatalogueProvider);
            await ref.read(storeCatalogueProvider.future);
          },
          child: _body(context, l10n, data),
        ),
      ),
    );
  }

  Widget _body(BuildContext context, AppLocalizations l10n, StoreCatalogue data) {
    final theme = Theme.of(context);
    final items = [for (final i in data.items) if (i.category == _category) i];
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (data.balance != null)
                  Row(
                    children: [
                      const Icon(Icons.monetization_on_outlined, color: SxColors.warning),
                      const SizedBox(width: 8),
                      Expanded(child: Text(l10n.storeBalance, style: theme.textTheme.labelLarge)),
                      Text(formatCoins(data.balance!), key: const Key('store-balance'), style: theme.textTheme.titleLarge),
                    ],
                  ),
                const SizedBox(height: 8),
                Text(
                  l10n.storeDisclaimer,
                  key: const Key('store-disclaimer'),
                  style: theme.textTheme.bodySmall?.copyWith(color: SxColors.textSecondary),
                ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final c in _categories)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            key: Key('store-cat-$c'),
                            label: Text(_categoryLabel(l10n, c)),
                            selected: _category == c,
                            onSelected: (_) => setState(() => _category = c),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
        if (items.isEmpty)
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverToBoxAdapter(
              child: Text(l10n.storeEmpty, style: theme.textTheme.bodyMedium?.copyWith(color: SxColors.textSecondary)),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.74,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, i) => _ItemCard(item: items[i]),
                childCount: items.length,
              ),
            ),
          ),
      ],
    );
  }
}

class _ItemCard extends StatelessWidget {
  const _ItemCard({required this.item});

  final StoreItem item;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final badge = item.equipped ? l10n.storeEquipped : (item.owned ? l10n.storeOwned : null);
    return InkWell(
      key: Key('store-item-${item.id}'),
      borderRadius: BorderRadius.circular(16),
      onTap: () => showStoreItemSheet(context, item.id),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: SxColors.surface,
          border: Border.all(color: item.equipped ? SxColors.primary : SxColors.border),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: CosmeticArt.image(
                item.previewUrl,
                fit: BoxFit.contain,
                fallback: const Icon(Icons.image_not_supported_outlined, color: SxColors.textSecondary),
              ),
            ),
            const SizedBox(height: 8),
            Text(item.name, style: theme.textTheme.titleSmall, maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.monetization_on_outlined, size: 16, color: SxColors.warning),
                const SizedBox(width: 4),
                Expanded(child: Text(formatCoins(item.priceCoins), style: theme.textTheme.bodyMedium)),
              ],
            ),
            if (badge != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  badge,
                  style: theme.textTheme.labelSmall?.copyWith(color: item.equipped ? SxColors.accentText : SxColors.success),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
