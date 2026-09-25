import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/players_models.dart';
import '../../core/l10n/gen/app_localizations.dart';
import '../../core/theme/sx_colors.dart';
import 'history_labels.dart';
import 'progress_providers.dart';

/// Infinite-scroll list over a [HistoryNotifier]. The loading footer asks for the next page when it is built;
/// a failed page swaps it for a retry tile that never fetches on its own (no failure loop).
class HistoryListScreen<T> extends ConsumerWidget {
  const HistoryListScreen({super.key, required this.title, required this.provider, required this.rowBuilder});

  final String title;
  final AsyncNotifierProvider<HistoryNotifier<T>, HistoryState<T>> provider;
  final Widget Function(BuildContext context, T item) rowBuilder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(provider);
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Center(child: TextButton(onPressed: () => ref.invalidate(provider), child: Text(l10n.commonLoadError))),
        data: (s) {
          if (s.items.isEmpty) return Center(child: Text(l10n.historyEmpty));
          final hasFooter = s.nextCursor != null || s.loadingMore || s.loadMoreFailed;
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(provider),
            child: ListView.builder(
              itemCount: s.items.length + (hasFooter ? 1 : 0),
              itemBuilder: (context, i) {
                if (i < s.items.length) return rowBuilder(context, s.items[i]);
                if (s.loadMoreFailed) {
                  return TextButton(
                    key: const Key('history-retry'),
                    onPressed: () => ref.read(provider.notifier).loadMore(retry: true),
                    child: Text(l10n.historyLoadMoreError),
                  );
                }
                // Safe to schedule on every build: the notifier ignores calls while a page is loading.
                WidgetsBinding.instance.addPostFrameCallback((_) => ref.read(provider.notifier).loadMore());
                return const Padding(
                  key: Key('history-loading-more'),
                  padding: EdgeInsets.all(16),
                  child: Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

String _date(BuildContext context, String iso) {
  final d = DateTime.tryParse(iso);
  return d == null ? iso : MaterialLocalizations.of(context).formatShortDate(d.toLocal());
}

String _signed(int n) => n > 0 ? '+$n' : '$n';

Color _deltaColor(int n) => n > 0 ? SxColors.success : (n < 0 ? Colors.redAccent : SxColors.textSecondary);

Widget xpRow(BuildContext context, XpEvent e) => ListTile(
      title: Text(xpSourceLabel(AppLocalizations.of(context), e.source)),
      subtitle: Text(_date(context, e.createdAt)),
      trailing: Text('+${e.xp} XP', style: const TextStyle(color: SxColors.success)),
    );

Widget scoreRow(BuildContext context, SxScoreEvent e) => ListTile(
      title: Text(scoreEventLabel(AppLocalizations.of(context), e.eventType)),
      subtitle: Text(_date(context, e.createdAt)),
      trailing: Text(_signed(e.pointsDelta), style: TextStyle(color: _deltaColor(e.pointsDelta))),
    );

Widget coinRow(BuildContext context, CoinTransaction e) {
  final l10n = AppLocalizations.of(context);
  return ListTile(
    title: Text(coinSourceLabel(l10n, e.source)),
    subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (e.description != null) Text(e.description!),
      Text(_date(context, e.createdAt)),
    ]),
    isThreeLine: e.description != null,
    trailing: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.end, children: [
      Text(_signed(e.amount), style: TextStyle(color: _deltaColor(e.amount))),
      Text(l10n.historyBalanceAfter(e.balanceAfter), style: Theme.of(context).textTheme.bodySmall),
    ]),
  );
}
