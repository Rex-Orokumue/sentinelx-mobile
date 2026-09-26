import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/match_models.dart';
import '../../core/l10n/gen/app_localizations.dart';
import '../../core/theme/sx_colors.dart';
import '../match/load_error.dart';
import '../match/match_format.dart';
import '../match/match_providers.dart';
import '../match/match_reads_repository.dart';

/// Group standings, fixtures and knockout rounds for one tournament, plus the champion banner and stage list.
/// Everything shown is rendered from the API payload; nothing is recomputed here.
class BracketScreen extends ConsumerWidget {
  const BracketScreen({super.key, required this.tournamentId, required this.onMatchTap, required this.onStageTap});

  final String tournamentId;
  final void Function(String matchId) onMatchTap;
  final void Function(StageInfo stage) onStageTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final async = ref.watch(bracketProvider(tournamentId));
    return Scaffold(
      appBar: AppBar(title: Text(l10n.mtcBracketTitle)),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => LoadError(onRetry: () => ref.invalidate(bracketProvider(tournamentId))),
        data: (view) => _BracketBody(tournamentId: tournamentId, view: view, onMatchTap: onMatchTap, onStageTap: onStageTap),
      ),
    );
  }
}

class _TabSpec {
  const _TabSpec(this.key, this.label, this.content);
  final String key;
  final String label;
  final List<Widget> content;
}

class _BracketBody extends ConsumerWidget {
  const _BracketBody({required this.tournamentId, required this.view, required this.onMatchTap, required this.onStageTap});

  final String tournamentId;
  final BracketView view;
  final void Function(String matchId) onMatchTap;
  final void Function(StageInfo stage) onStageTap;

  Future<void> _refresh(WidgetRef ref) async {
    ref.invalidate(bracketProvider(tournamentId));
    ref.invalidate(stagesProvider(tournamentId));
    try {
      await ref.read(bracketProvider(tournamentId).future);
    } catch (_) {
      // the error state renders on its own
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final v = view;
    final tabs = <_TabSpec>[
      if (v.hasGroups) _TabSpec('tab-groups', l10n.mtcTabGroups, [for (final g in v.standings) _GroupTable(group: g)]),
      if (!v.fixtures.isEmpty) _TabSpec('tab-fixtures', l10n.mtcTabFixtures, _fixtureSections(l10n)),
      if (v.hasKnockout || v.projected.isNotEmpty) _TabSpec('tab-knockout', l10n.mtcTabKnockout, _knockoutSections(context, l10n)),
    ];
    final stages = ref.watch(stagesProvider(tournamentId)).asData?.value ?? const <StageInfo>[];
    final banner = v.champion == null ? null : _ChampionBanner(champion: v.champion!, thirdPlace: v.thirdPlace);
    final stagesSection = stages.isEmpty ? null : _StagesSection(stages: stages, onStageTap: onStageTap);

    if (tabs.isEmpty) {
      return RefreshIndicator(
        onRefresh: () => _refresh(ref),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            ?banner,
            Padding(padding: const EdgeInsets.symmetric(vertical: 24), child: Center(child: Text(l10n.mtcNoDrawYet, textAlign: TextAlign.center))),
            ?stagesSection,
          ],
        ),
      );
    }

    return DefaultTabController(
      key: ValueKey(tabs.map((t) => t.key).join(',')),
      length: tabs.length,
      child: Column(children: [
        if (banner != null) Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 0), child: banner),
        TabBar(tabs: [for (final t in tabs) Tab(key: Key(t.key), text: t.label)]),
        Expanded(
          child: TabBarView(children: [
            for (final t in tabs)
              RefreshIndicator(
                onRefresh: () => _refresh(ref),
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  children: t.content,
                ),
              ),
          ]),
        ),
        if (stagesSection != null)
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 148),
            child: ListView(shrinkWrap: true, padding: const EdgeInsets.fromLTRB(16, 4, 16, 8), children: [stagesSection]),
          ),
      ]),
    );
  }

  List<Widget> _fixtureSections(AppLocalizations l10n) {
    Widget section(String key, String title, List<BracketFixture> items) => ExpansionTile(
          key: Key('section-$key'),
          initiallyExpanded: true,
          tilePadding: EdgeInsets.zero,
          title: Text('$title (${items.length})'),
          children: [for (final f in items) FixtureRow(fixture: f, onTap: onMatchTap)],
        );
    final s = view.fixtures;
    return [
      if (s.live.isNotEmpty) section('live', l10n.mtcFixtLive, s.live),
      if (s.upcoming.isNotEmpty) section('upcoming', l10n.mtcFixtUpcoming, s.upcoming),
      if (s.completed.isNotEmpty) section('completed', l10n.mtcFixtCompleted, s.completed),
      if (s.disputedOrCancelled.isNotEmpty) section('disputed', l10n.mtcFixtDisputed, s.disputedOrCancelled),
    ];
  }

  List<Widget> _knockoutSections(BuildContext context, AppLocalizations l10n) {
    final heading = Theme.of(context).textTheme.titleMedium;
    return [
      for (final r in view.rounds) ...[
        Padding(padding: const EdgeInsets.only(top: 8, bottom: 4), child: Text(r.label, style: heading)),
        for (final m in r.matches) FixtureRow(fixture: m, onTap: onMatchTap),
      ],
      for (final p in view.projected) ...[
        Padding(padding: const EdgeInsets.only(top: 8, bottom: 4), child: Text(p.label, style: heading)),
        Text(l10n.mtcProjectedMatches(p.matchCount), style: const TextStyle(color: SxColors.textSecondary)),
      ],
      if (view.thirdPlaceMatch != null) ...[
        Padding(padding: const EdgeInsets.only(top: 8, bottom: 4), child: Text(l10n.mtcThirdPlace, style: heading)),
        FixtureRow(fixture: view.thirdPlaceMatch!, onTap: onMatchTap),
      ],
    ];
  }
}

class _ChampionBanner extends StatelessWidget {
  const _ChampionBanner({required this.champion, required this.thirdPlace});
  final NameRef champion;
  final NameRef? thirdPlace;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context).textTheme;
    return Card(
      key: const Key('champion-banner'),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(children: [
          const Icon(Icons.emoji_events, color: SxColors.warning),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(l10n.mtcChampion, style: theme.labelSmall),
              Text(champion.name, style: theme.titleMedium, maxLines: 2, overflow: TextOverflow.ellipsis),
              if (thirdPlace != null)
                Text('${l10n.mtcThirdPlace}: ${thirdPlace!.name}', maxLines: 2, overflow: TextOverflow.ellipsis),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _GroupTable extends StatelessWidget {
  const _GroupTable({required this.group});
  final GroupStandings group;

  static const _rankW = 44.0, _nameW = 128.0, _statW = 34.0, _ptsW = 40.0;

  Widget _cell(String text, double width, {TextAlign align = TextAlign.center, TextStyle? style, bool ellipsis = false}) => SizedBox(
        width: width,
        child: Text(text, textAlign: align, style: style, maxLines: 1, overflow: ellipsis ? TextOverflow.ellipsis : TextOverflow.clip),
      );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final head = Theme.of(context).textTheme.labelMedium?.copyWith(color: SxColors.textSecondary);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(l10n.mtcGroupCol(group.groupName), style: Theme.of(context).textTheme.titleMedium, maxLines: 2, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Column(children: [
            Row(children: [
              _cell(l10n.mtcColRank, _rankW, style: head),
              _cell('', _nameW, style: head),
              _cell(l10n.mtcColPlayed, _statW, style: head),
              _cell(l10n.mtcColWins, _statW, style: head),
              _cell(l10n.mtcColDraws, _statW, style: head),
              _cell(l10n.mtcColLosses, _statW, style: head),
              _cell(l10n.mtcColGoalDiff, _statW, style: head),
              _cell(l10n.mtcColPoints, _ptsW, style: head),
            ]),
            for (final r in group.rows)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(children: [
                  SizedBox(
                    width: _rankW,
                    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      if (r.advancing)
                        Semantics(
                          key: Key('advancing-${r.playerId}'),
                          label: l10n.mtcAdvancing,
                          child: const Icon(Icons.circle, size: 8, color: SxColors.success),
                        ),
                      const SizedBox(width: 4),
                      Text('${r.rank}'),
                    ]),
                  ),
                  _cell(r.name, _nameW, align: TextAlign.start, ellipsis: true),
                  _cell('${r.played}', _statW),
                  _cell('${r.wins}', _statW),
                  _cell('${r.draws}', _statW),
                  _cell('${r.losses}', _statW),
                  _cell('${r.goalDiff}', _statW),
                  _cell('${r.points}', _ptsW, style: const TextStyle(fontWeight: FontWeight.bold)),
                ]),
              ),
          ]),
        ),
      ]),
    );
  }
}

/// One fixture line: `A vs B`, the score only when both scores exist, else the schedule. Byes are not tappable.
class FixtureRow extends StatelessWidget {
  const FixtureRow({super.key, required this.fixture, required this.onTap});
  final BracketFixture fixture;
  final void Function(String matchId) onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final f = fixture;
    final isBye = f.status == 'bye';
    final hasScore = f.scoreA != null && f.scoreB != null;
    final status = matchStatusText(l10n, f.status);
    final trailing = isBye ? null : (hasScore ? '${f.scoreA} – ${f.scoreB}' : scheduleText(l10n, f.scheduledAt, isFullDay: f.isFullDay));
    return ListTile(
      key: Key('fixture-${f.id}'),
      contentPadding: EdgeInsets.zero,
      onTap: isBye ? null : () => onTap(f.id),
      title: Text('${f.playerA.name} ${l10n.mtcVs} ${f.playerB.name}', maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: status == null ? null : Text(status),
      trailing: trailing == null
          ? null
          : ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 112),
              child: Text(trailing, textAlign: TextAlign.end, maxLines: 2, overflow: TextOverflow.ellipsis),
            ),
    );
  }
}

class _StagesSection extends StatelessWidget {
  const _StagesSection({required this.stages, required this.onStageTap});
  final List<StageInfo> stages;
  final void Function(StageInfo stage) onStageTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(padding: const EdgeInsets.only(top: 8), child: Text(l10n.mtcStages, style: Theme.of(context).textTheme.titleMedium)),
      for (final s in stages)
        ListTile(
          key: Key('stage-${s.id}'),
          contentPadding: EdgeInsets.zero,
          dense: true,
          title: Text(s.name, maxLines: 1, overflow: TextOverflow.ellipsis),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => onStageTap(s),
        ),
    ]);
  }
}
