import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/progress_models.dart';
import '../../core/l10n/gen/app_localizations.dart';
import '../../core/providers.dart';
import '../../core/theme/sx_colors.dart';
import '../../shared/widgets/player_avatar.dart';
import 'rankings_providers.dart';

class RankingsScreen extends ConsumerWidget {
  const RankingsScreen({super.key, required this.onGoTo});
  final void Function(String) onGoTo;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final value = ref.watch(rankingsProvider);
    final p = value.asData?.value ?? ref.watch(rankingsCacheProvider);
    final myId = ref.watch(meProvider).asData?.value?.id;
    final siteUrl = ref.watch(appConfigProvider).apiBaseUrl;
    return Scaffold(
      appBar: AppBar(title: Text(l.rankingsTitle)),
      body: p == null
          ? value.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stackTrace) => _initialError(ref, l),
              data: (_) => const SizedBox.shrink(),
            )
          : RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(rankingsProvider);
                ref.invalidate(rankingsMeProvider);
              },
              child: ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  if (value.hasError)
                    InkWell(
                      onTap: () => ref.invalidate(rankingsProvider),
                      child: MaterialBanner(
                        content: Text(l.rankingsErrorRetry),
                        actions: const [SizedBox.shrink()],
                      ),
                    ),
                  _chips(ref, p, l),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final t in p.tabs)
                          Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: ChoiceChip(
                              key: Key('tab-metric-${t.key}'),
                              label: Text(t.label),
                              selected: p.scope.metric == t.key,
                              onSelected: (_) => ref
                                  .read(rankingsQueryProvider.notifier)
                                  .setMetric(t.key),
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (p.subGames.isNotEmpty)
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          ChoiceChip(
                            key: const Key('chip-tabgame-all'),
                            label: Text(p.subGamesAllLabel ?? ''),
                            selected: p.scope.tabGame == null,
                            onSelected: (_) => ref
                                .read(rankingsQueryProvider.notifier)
                                .setTabGame(null),
                          ),
                          for (final g in p.subGames)
                            ChoiceChip(
                              key: Key('chip-tabgame-${g.slug}'),
                              label: Text(g.name),
                              selected: p.scope.tabGame == g.slug,
                              onSelected: (_) => ref
                                  .read(rankingsQueryProvider.notifier)
                                  .setTabGame(g.slug),
                            ),
                        ],
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Text(
                      '${p.scope.metricLabel} · ${l.rankingsPlayersRanked(p.stats.playersRanked)}',
                    ),
                  ),
                  _yourRank(ref, p, l, siteUrl),
                  if (p.rows.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(32),
                      child: Center(child: Text(l.rankingsEmpty)),
                    )
                  else
                    for (final r in p.rows)
                      _RankRow(
                        row: r,
                        l: l,
                        metric: p.scope.metric,
                        isMe: myId != null && r.player.id == myId,
                        siteUrl: siteUrl,
                      ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton(
                        key: const Key('page-prev'),
                        onPressed: p.page.page > 1
                            ? () => ref
                                  .read(rankingsQueryProvider.notifier)
                                  .setPage(p.page.page - 1)
                            : null,
                        child: Text(l.rankingsPrev),
                      ),
                      Text(l.rankingsPageOf(p.page.page, p.page.totalPages)),
                      TextButton(
                        key: const Key('page-next'),
                        onPressed: p.page.page < p.page.totalPages
                            ? () => ref
                                  .read(rankingsQueryProvider.notifier)
                                  .setPage(p.page.page + 1)
                            : null,
                        child: Text(l.rankingsNext),
                      ),
                    ],
                  ),
                  ListTile(
                    title: Text(l.seasonsTitle),
                    onTap: () => onGoTo('/seasons'),
                  ),
                  ListTile(
                    title: Text(l.hallOfFameTitle),
                    onTap: () => onGoTo('/hall-of-fame'),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _initialError(WidgetRef ref, AppLocalizations l) => ListView(
    padding: const EdgeInsets.all(12),
    children: [
      Row(
        children: [
          ChoiceChip(
            key: const Key('chip-game-all'),
            label: Text(l.rankingsAllGames),
            selected: true,
            onSelected: (_) =>
                ref.read(rankingsQueryProvider.notifier).setGame(null),
          ),
          ChoiceChip(
            key: const Key('chip-region-all'),
            label: Text(l.rankingsAllRegions),
            selected: true,
            onSelected: (_) =>
                ref.read(rankingsQueryProvider.notifier).setRegion(null),
          ),
        ],
      ),
      InkWell(
        onTap: () => ref.invalidate(rankingsProvider),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Center(child: Text(l.rankingsErrorRetry)),
        ),
      ),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          TextButton(
            key: const Key('page-prev'),
            onPressed: null,
            child: Text(l.rankingsPrev),
          ),
          Text(l.rankingsPageOf(1, 1)),
          TextButton(
            key: const Key('page-next'),
            onPressed: null,
            child: Text(l.rankingsNext),
          ),
        ],
      ),
    ],
  );

  Widget _chips(WidgetRef ref, RankingsPage p, AppLocalizations l) => Column(
    children: [
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            ChoiceChip(
              key: const Key('chip-game-all'),
              label: Text(l.rankingsAllGames),
              selected: p.scope.game == null,
              onSelected: (_) =>
                  ref.read(rankingsQueryProvider.notifier).setGame(null),
            ),
            for (final g in p.games)
              ChoiceChip(
                key: Key('chip-game-${g.slug}'),
                label: Text(g.name),
                selected: p.scope.game == g.slug,
                onSelected: (_) =>
                    ref.read(rankingsQueryProvider.notifier).setGame(g.slug),
              ),
          ],
        ),
      ),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            ChoiceChip(
              key: const Key('chip-region-all'),
              label: Text(l.rankingsAllRegions),
              selected: p.scope.region == null,
              onSelected: (_) =>
                  ref.read(rankingsQueryProvider.notifier).setRegion(null),
            ),
            for (final r in p.regions)
              ChoiceChip(
                key: Key('chip-region-$r'),
                label: Text(r),
                selected: p.scope.region == r,
                onSelected: (_) =>
                    ref.read(rankingsQueryProvider.notifier).setRegion(r),
              ),
          ],
        ),
      ),
    ],
  );
  Widget _yourRank(
    WidgetRef ref,
    RankingsPage p,
    AppLocalizations l,
    String siteUrl,
  ) => ref
      .watch(rankingsMeProvider)
      .maybeWhen(
        data: (r) => r != null && !p.rows.any((x) => x.player.id == r.player.id)
            ? Card(
                key: const Key('your-rank-card'),
                child: Column(
                  children: [
                    Text(l.rankingsYourRank),
                    _RankRow(
                      row: r,
                      l: l,
                      metric: p.scope.metric,
                      siteUrl: siteUrl,
                    ),
                  ],
                ),
              )
            : const SizedBox.shrink(),
        orElse: () => const SizedBox.shrink(),
      );
}

class _RankRow extends StatefulWidget {
  const _RankRow({
    required this.row,
    required this.l,
    required this.metric,
    required this.siteUrl,
    this.isMe = false,
  });
  final RankingRow row;
  final AppLocalizations l;
  final String metric;
  final String siteUrl;
  final bool isMe;
  @override
  State<_RankRow> createState() => _RankRowState();
}

class _RankRowState extends State<_RankRow> {
  bool open = false;
  @override
  Widget build(BuildContext c) {
    final r = widget.row, p = r.player, l = widget.l;
    return Column(
      children: [
        ListTile(
          key: widget.isMe
              ? const Key('rank-row-me')
              : Key('rank-row-${r.rank}'),
          tileColor: widget.isMe
              ? SxColors.primary.withValues(alpha: 0.1)
              : null,
          onTap: widget.metric == 'wins'
              ? () => setState(() => open = !open)
              : null,
          leading: Text(
            r.rank < 4 ? ['', '🥇', '🥈', '🥉'][r.rank] : '#${r.rank}',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          title: Row(
            children: [
              PlayerAvatar(
                avatarUrl: p.avatarUrl,
                frameUrl: resolveAsset(p.frameUrl, widget.siteUrl),
                isDeleted: p.isDeleted,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        p.isDeleted ? l.commonDeletedPlayer : p.label,
                      ),
                    ),
                    if (widget.isMe) ...[
                      const SizedBox(width: 4),
                      Text(
                        l.rankingsYou,
                        style: const TextStyle(color: SxColors.accentText),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          subtitle: Text(
            '${l.rankingsWinsCount(r.wins)} · ${l.rankingsMatchesCount(r.totalMatches)}',
          ),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${r.metricValue}',
                style: const TextStyle(
                  color: SxColors.accentText,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text('${(r.winRate * 100).round()}%'),
              Text(
                switch (r.trend.direction) {
                  'up' => '▲ ${r.trend.delta}',
                  'down' => '▼ ${r.trend.delta}',
                  _ => '—',
                },
                style: TextStyle(
                  color: switch (r.trend.direction) {
                    'up' => SxColors.success,
                    'down' => Theme.of(c).colorScheme.error,
                    _ => SxColors.textSecondary,
                  },
                ),
              ),
            ],
          ),
        ),
        if (open)
          Container(
            key: Key('wins-by-game-${p.id}'),
            padding: const EdgeInsets.all(8),
            child: Text(
              r.winsByGame.map((g) => '${g.gameName}: ${g.wins}').join(' · '),
            ),
          ),
      ],
    );
  }
}
