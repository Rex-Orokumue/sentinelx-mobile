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
          loading: () =>
              const Scaffold(body: Center(child: CircularProgressIndicator())),
          error: (error, stackTrace) =>
              Scaffold(body: Center(child: Text(l.rankingsErrorRetry))),
          data: (d) => d.games.isEmpty
              ? Scaffold(
                  appBar: AppBar(title: Text(d.season.name)),
                  body: Center(child: Text(l.hallOfFameEmpty)),
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
                          ),
                      ],
                    ),
                  ),
                ),
        );
  }
}

class _Game extends StatelessWidget {
  const _Game({required this.game, required this.myId, required this.l});
  final SeasonGame game;
  final String? myId;
  final AppLocalizations l;
  @override
  Widget build(BuildContext c) {
    if (game.leaderboard.isEmpty && game.tournaments.isEmpty) {
      return Center(child: Text(l.hallOfFameEmpty));
    }
    final provisional = game.leaderboard.any((x) => x.isProvisional);
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Text(game.tierLabels.qualificationNote),
        for (var i = 0; i < game.leaderboard.length; i++)
          Container(
            key: game.leaderboard[i].playerId == myId
                ? const Key('season-row-me')
                : null,
            color: game.leaderboard[i].playerId == myId
                ? Theme.of(c).colorScheme.primary.withValues(alpha: .12)
                : null,
            child: ListTile(
              leading: Text('#${i + 1}'),
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
                  if (game.leaderboard[i].playerId == myId) Text(l.seasonsYou),
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
    );
  }
}
