import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/match_models.dart';
import '../../core/l10n/gen/app_localizations.dart';
import '../../core/theme/sx_colors.dart';
import '../match/load_error.dart';
import '../match/match_providers.dart';
import '../match/match_reads_repository.dart';

/// Points-race (BR / round-robin) stage table, rendered exactly as the API ranks it.
class StageStandingsScreen extends ConsumerWidget {
  const StageStandingsScreen({super.key, required this.tournamentId, required this.stage});

  final String tournamentId;
  final StageInfo stage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final key = (tournamentId: tournamentId, stageId: stage.id);
    final async = ref.watch(stageStandingsProvider(key));
    return Scaffold(
      appBar: AppBar(title: Text(stage.name, maxLines: 1, overflow: TextOverflow.ellipsis)),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => LoadError(onRetry: () => ref.invalidate(stageStandingsProvider(key))),
        data: (rows) => rows.isEmpty
            ? Center(child: Text(l10n.mtcNoDrawYet))
            : RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(stageStandingsProvider(key));
                  try {
                    await ref.read(stageStandingsProvider(key).future);
                  } catch (_) {}
                },
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  children: [
                    _HeaderRow(l10n: l10n),
                    for (final r in rows) _StandingsRow(row: r, l10n: l10n),
                  ],
                ),
              ),
      ),
    );
  }
}

const _rankW = 44.0, _statW = 34.0, _ptsW = 44.0, _killsW = 52.0;

class _HeaderRow extends StatelessWidget {
  const _HeaderRow({required this.l10n});
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final head = Theme.of(context).textTheme.labelMedium?.copyWith(color: SxColors.textSecondary);
    Widget c(String t, double w) => SizedBox(width: w, child: Text(t, textAlign: TextAlign.center, style: head, maxLines: 1, overflow: TextOverflow.ellipsis));
    return Row(children: [
      c(l10n.mtcColRank, _rankW),
      const Expanded(child: SizedBox.shrink()),
      c(l10n.mtcColPlayed, _statW),
      c(l10n.mtcColPoints, _ptsW),
      c(l10n.mtcColKills, _killsW),
    ]);
  }
}

class _StandingsRow extends StatelessWidget {
  const _StandingsRow({required this.row, required this.l10n});
  final PointsStandingRow row;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    Widget c(String t, double w, {bool bold = false}) =>
        SizedBox(width: w, child: Text(t, textAlign: TextAlign.center, style: bold ? const TextStyle(fontWeight: FontWeight.bold) : null));
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        SizedBox(
          width: _rankW,
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            if (row.advancing)
              Semantics(
                key: Key('advancing-${row.entrantId}'),
                label: l10n.mtcAdvancing,
                child: const Icon(Icons.circle, size: 8, color: SxColors.success),
              ),
            const SizedBox(width: 4),
            Text('${row.rank}'),
          ]),
        ),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(row.displayName, maxLines: 1, overflow: TextOverflow.ellipsis),
            if (row.unresolvedTieWith.isNotEmpty)
              Text(l10n.mtcTieUnresolved, style: const TextStyle(fontSize: 12, color: SxColors.warning)),
          ]),
        ),
        c('${row.played}', _statW),
        c('${row.totalPoints}', _ptsW, bold: true),
        c('${row.totalKills}', _killsW),
      ]),
    );
  }
}
