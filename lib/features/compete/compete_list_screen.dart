import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/gen/app_localizations.dart';
import 'compete_models.dart';
import 'compete_providers.dart';

/// Chip label for a tournament status; null hides the chip (e.g. `draft` never reaches the list).
String? statusLabel(AppLocalizations l10n, String status) => switch (status) {
      'registration_open' => l10n.cmpStatusRegistrationOpen,
      'registration_closed' => l10n.cmpStatusRegistrationClosed,
      'active' => l10n.cmpStatusActive,
      'completed' => l10n.cmpStatusCompleted,
      _ => null,
    };

class CompeteListScreen extends ConsumerWidget {
  const CompeteListScreen({super.key, required this.onTournamentTap});

  final void Function(CompeteTournament tournament) onTournamentTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final tab = ref.watch(tournamentTabProvider);
    final game = ref.watch(tournamentGameFilterProvider);
    final games = ref.watch(gamesProvider).asData?.value ?? const <GameSummary>[];
    final list = ref.watch(tournamentListProvider);

    final tabLabels = {
      TournamentTab.all: l10n.cmpTabAll,
      TournamentTab.live: l10n.cmpTabLive,
      TournamentTab.upcoming: l10n.cmpTabUpcoming,
      TournamentTab.completed: l10n.cmpTabCompleted,
    };

    return Scaffold(
      appBar: AppBar(title: Text(l10n.navTournaments)),
      body: Column(children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(children: [
            for (final t in TournamentTab.values)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  key: Key('tab-${t.name}'),
                  label: Text(tabLabels[t]!),
                  selected: tab == t,
                  onSelected: (_) => ref.read(tournamentTabProvider.notifier).select(t),
                ),
              ),
          ]),
        ),
        if (games.isNotEmpty)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(children: [
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  key: const Key('game-chip-all'),
                  label: Text(l10n.cmpAllGames),
                  selected: game == null,
                  onSelected: (_) => ref.read(tournamentGameFilterProvider.notifier).select(null),
                ),
              ),
              for (final g in games)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    key: Key('game-chip-${g.slug}'),
                    label: Text(g.name),
                    selected: game == g.slug,
                    onSelected: (_) => ref.read(tournamentGameFilterProvider.notifier).select(g.slug),
                  ),
                ),
            ]),
          ),
        Expanded(
          child: list.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, _) => _LoadError(onRetry: () => ref.invalidate(tournamentListProvider)),
            data: (s) => RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(tournamentListProvider);
                await ref.read(tournamentListProvider.future);
              },
              child: s.items.isEmpty
                  ? ListView(children: [Padding(padding: const EdgeInsets.all(32), child: Center(child: Text(l10n.cmpEmpty)))])
                  : ListView.builder(
                      itemCount: s.items.length + (s.hasMore ? 1 : 0),
                      itemBuilder: (context, i) {
                        if (i == s.items.length) return _Footer(state: s);
                        return _TournamentCard(tournament: s.items[i], onTap: () => onTournamentTap(s.items[i]));
                      },
                    ),
            ),
          ),
        ),
      ]),
    );
  }
}

class _Footer extends ConsumerWidget {
  const _Footer({required this.state});
  final TournamentListState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    if (state.loadingMore) {
      return const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator()));
    }
    return Padding(
      padding: const EdgeInsets.all(8),
      child: TextButton(
        key: const Key('load-more'),
        onPressed: () => ref.read(tournamentListProvider.notifier).loadMore(),
        child: Text(state.loadMoreFailed ? l10n.cmpRetry : l10n.cmpLoadMore),
      ),
    );
  }
}

class _TournamentCard extends StatelessWidget {
  const _TournamentCard({required this.tournament, required this.onTap});
  final CompeteTournament tournament;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final status = statusLabel(l10n, tournament.status);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: InkWell(
        key: Key('tournament-tile-${tournament.id}'),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(tournament.title, style: Theme.of(context).textTheme.titleMedium, maxLines: 2, overflow: TextOverflow.ellipsis),
            if (tournament.gameName != null) Text(tournament.gameName!),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
              Text('${l10n.cmpPrizePool}: ₦${tournament.prizePool}'),
              Text('${l10n.cmpEntryFee}: ${tournament.registrationFee == 0 ? l10n.cmpFree : '₦${tournament.registrationFee}'}'),
              if (status != null) Chip(label: Text(status), visualDensity: VisualDensity.compact),
            ]),
          ]),
        ),
      ),
    );
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(l10n.cmpLoadError, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: onRetry, child: Text(l10n.cmpRetry)),
        ]),
      ),
    );
  }
}
