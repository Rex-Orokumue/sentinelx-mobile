import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/progress_models.dart';
import '../../core/l10n/gen/app_localizations.dart';
import '../../shared/widgets/player_avatar.dart';
import 'hall_of_fame_providers.dart';

class HallOfFameScreen extends ConsumerWidget {
  const HallOfFameScreen({super.key});
  @override
  Widget build(BuildContext c, WidgetRef r) {
    final l = AppLocalizations.of(c);
    return Scaffold(
      appBar: AppBar(title: Text(l.hallOfFameTitle)),
      body: r
          .watch(hallOfFameProvider)
          .when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, stack) => Center(child: Text(l.rankingsErrorRetry)),
            data: (h) {
              final empty = h.selectedGame == null;
              return ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        ChoiceChip(
                          key: const Key('hof-chip-all'),
                          label: Text(l.rankingsAllGames),
                          selected: h.selectedGame == null,
                          onSelected: (_) => r
                              .read(hallOfFameGameProvider.notifier)
                              .setGame(null),
                        ),
                        for (final g in h.games)
                          ChoiceChip(
                            key: Key('hof-chip-${g.slug}'),
                            label: Text(g.name),
                            selected: h.selectedGame == g.slug,
                            onSelected: (_) => r
                                .read(hallOfFameGameProvider.notifier)
                                .setGame(g.slug),
                          ),
                      ],
                    ),
                  ),
                  if (h.awards.mvp != null)
                    _Person(
                      title: l.hallOfFameMvp,
                      p: h.awards.mvp!,
                      value: '${h.awards.mvp!.sxScore}',
                    ),
                  if (h.awards.goldenBoot.isNotEmpty)
                    _Award(
                      title: l.hallOfFameGoldenBoot,
                      options: h.awards.goldenBoot,
                    ),
                  for (final a in h.awards.categories)
                    _Award(title: a.label, options: a.options),
                  _section(
                    l.hallOfFameChampionsCup,
                    h.champions.championsCup,
                    empty,
                    l,
                  ),
                  _section(l.hallOfFameMasters, h.champions.masters, empty, l),
                  _section(
                    l.hallOfFameCommunityClub,
                    h.champions.communityClub,
                    empty,
                    l,
                  ),
                  _section(l.hallOfFameOpen, h.champions.open, empty, l),
                  Text(
                    l.hallOfFameBronze,
                    style: Theme.of(c).textTheme.titleLarge,
                  ),
                  for (final b in h.bronze)
                    ListTile(
                      title: Text(b.player.name),
                      subtitle: Text(b.title),
                    ),
                ],
              );
            },
          ),
    );
  }

  Widget _section(
    String title,
    List<HofChampion> xs,
    bool show,
    AppLocalizations l,
  ) => xs.isEmpty && !show
      ? const SizedBox.shrink()
      : Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            if (xs.isEmpty) Text(l.hallOfFameEmpty),
            for (final x in xs)
              ListTile(
                title: Text(x.champion.name),
                subtitle: Text(x.title),
                trailing: x.runnerUp == null
                    ? null
                    : Text(l.hallOfFameRunnerUp(x.runnerUp!.name)),
              ),
          ],
        );
}

class _Person extends StatelessWidget {
  const _Person({required this.title, required this.p, required this.value});
  final String title, value;
  final PlayerCard p;
  @override
  Widget build(BuildContext c) => Card(
    child: ListTile(
      leading: PlayerAvatar(
        avatarUrl: p.avatarUrl,
        frameUrl: p.frameUrl,
        isDeleted: p.isDeleted,
      ),
      title: Text(title),
      subtitle: Text(p.label),
      trailing: Text(value),
    ),
  );
}

class _Award extends StatefulWidget {
  const _Award({required this.title, required this.options});
  final String title;
  final List<AwardOption> options;
  @override
  State<_Award> createState() => _AwardState();
}

class _AwardState extends State<_Award> {
  int selected = 0;
  @override
  Widget build(BuildContext c) {
    final o = widget.options[selected];
    return Column(
      children: [
        if (widget.options.length > 1)
          Wrap(
            children: [
              for (var i = 0; i < widget.options.length; i++)
                ChoiceChip(
                  key: Key(
                    'award-option-${widget.title}-${widget.options[i].gameLabel}',
                  ),
                  label: Text(widget.options[i].gameLabel),
                  selected: i == selected,
                  onSelected: (_) => setState(() => selected = i),
                ),
            ],
          ),
        if (o.winner != null)
          _Person(title: widget.title, p: o.winner!, value: '${o.metricValue}'),
      ],
    );
  }
}
