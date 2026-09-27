import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/progress_models.dart';
import '../../core/l10n/gen/app_localizations.dart';
import '../../core/providers.dart';
import 'seasons_providers.dart';

class SeasonDetailScreen extends ConsumerWidget {
  const SeasonDetailScreen({super.key, required this.slug});
  final String slug;
  @override
  Widget build(BuildContext c, WidgetRef r) {
    final l = AppLocalizations.of(c);
    return r
        .watch(seasonDetailProvider(slug))
        .when(
          loading: () => Scaffold(
            appBar: AppBar(),
            body: const Center(child: CircularProgressIndicator()),
          ),
          error: (error, stackTrace) => Scaffold(
            appBar: AppBar(),
            body: Center(
              child: InkWell(
                onTap: () => r.invalidate(seasonDetailProvider(slug)),
                child: Text(l.rankingsErrorRetry),
              ),
            ),
          ),
          data: (d) => d.games.isEmpty
              ? Scaffold(
                  appBar: AppBar(title: Text(d.season.name)),
                  body: RefreshIndicator(
                    onRefresh: () =>
                        r.refresh(seasonDetailProvider(slug).future),
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(32),
                          child: Center(child: Text(l.hallOfFameEmpty)),
                        ),
                      ],
                    ),
                  ),
                )
              : DefaultTabController(
                  length: d.games.length,
                  child: Scaffold(
                    appBar: AppBar(
                      title: Text(d.season.name),
                      bottom: TabBar(
                        isScrollable: true,
                        tabs: [for (final g in d.games) Tab(text: g.gameName)],
                      ),
                    ),
                    body: TabBarView(
                      children: [
                        for (final g in d.games)
                          _Game(
                            game: g,
                            myId: r.watch(meProvider).asData?.value?.id,
                            l: l,
                            onRefresh: () =>
                                r.refresh(seasonDetailProvider(slug).future),
                          ),
                      ],
                    ),
                  ),
                ),
        );
  }
}

class _Game extends StatelessWidget {
  const _Game({
    required this.game,
    required this.myId,
    required this.l,
    required this.onRefresh,
  });
  final SeasonGame game;
  final String? myId;
  final AppLocalizations l;
  final Future<void> Function() onRefresh;
  @override
  Widget build(BuildContext c) {
    final provisional = game.leaderboard.any((x) => x.isProvisional);
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(12),
        children: [
          Text(game.tierLabels.qualificationNote),
          if (game.leaderboard.isEmpty) Text(l.seasonsLeaderboardEmpty),
          for (var i = 0; i < game.leaderboard.take(50).length; i++)
            Container(
              key: game.leaderboard[i].playerId == myId
                  ? const Key('season-row-me')
                  : null,
              color: game.leaderboard[i].playerId == myId
                  ? Theme.of(c).colorScheme.primary.withValues(alpha: .12)
                  : null,
              child: ListTile(
                leading: Text(switch (i) {
                  0 => '🥇',
                  1 => '🥈',
                  2 => '🥉',
                  _ => '#${i + 1}',
                }),
                title: Text(
                  game.leaderboard[i].displayName ??
                      game.leaderboard[i].username ??
                      l.commonDeletedPlayer,
                ),
                subtitle: game.leaderboard[i].isProvisional
                    ? Text(l.seasonsProvisional)
                    : null,
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(l.seasonsPoints(game.leaderboard[i].points)),
                    if (game.leaderboard[i].playerId == myId)
                      Text(l.seasonsYou),
                  ],
                ),
              ),
            ),
          if (provisional) Text(l.seasonsProvisionalNote),
          const SizedBox(height: 12),
          Text(l.seasonsTournaments),
          for (final t in game.tournaments)
            ListTile(
              title: Text(t.title),
              trailing: t.invitationOnly
                  ? Chip(label: Text(l.seasonsInviteOnly))
                  : null,
            ),
        ],
      ),
    );
  }
}
