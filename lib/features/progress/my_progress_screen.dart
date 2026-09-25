import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/players_models.dart';
import '../../core/l10n/gen/app_localizations.dart';
import '../../core/providers.dart';
import '../../core/theme/sx_colors.dart';
import 'history_labels.dart';
import 'progress_providers.dart';

class MyProgressScreen extends ConsumerWidget {
  const MyProgressScreen({super.key, required this.onGoTo, required this.onLogIn});

  final void Function(String path) onGoTo;
  final VoidCallback onLogIn;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final me = ref.watch(meProvider);
    final progress = ref.watch(progressProvider);
    Widget body;
    if (me.asData?.value == null && !me.isLoading) {
      body = Center(
        key: const Key('progress-signin'),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(l10n.progressSignIn),
          const SizedBox(height: 12),
          ElevatedButton(key: const Key('progress-login'), onPressed: onLogIn, child: Text(l10n.authLoginSubmit)),
        ]),
      );
    } else {
      body = progress.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Center(child: TextButton(onPressed: () => ref.invalidate(progressProvider), child: Text(l10n.commonLoadError))),
        data: (p) => p == null
            ? const SizedBox.shrink()
            : RefreshIndicator(
                onRefresh: () async => ref.invalidate(progressProvider),
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _XpCard(p: p),
                    _Card(
                      title: l10n.progressSxScore,
                      children: [
                        Text('${p.sxScore}', style: Theme.of(context).textTheme.headlineSmall),
                        if (p.sentinelTier != null) Text(humanizeCode(p.sentinelTier!)),
                      ],
                    ),
                    _Card(
                      title: l10n.progressCoins,
                      children: [Text('${p.coinBalance}', style: Theme.of(context).textTheme.headlineSmall)],
                    ),
                    _SeasonCard(standing: p.seasonStanding),
                    const SizedBox(height: 8),
                    ListTile(key: const Key('progress-link-xp'), title: Text(l10n.progressHistoryXp), trailing: const Icon(Icons.chevron_right), onTap: () => onGoTo('/account/progress/xp')),
                    ListTile(key: const Key('progress-link-score'), title: Text(l10n.progressHistoryScore), trailing: const Icon(Icons.chevron_right), onTap: () => onGoTo('/account/progress/score')),
                    ListTile(key: const Key('progress-link-coins'), title: Text(l10n.progressHistoryCoins), trailing: const Icon(Icons.chevron_right), onTap: () => onGoTo('/account/progress/coins')),
                  ],
                ),
              ),
      );
    }
    return Scaffold(appBar: AppBar(title: Text(l10n.progressTitle)), body: body);
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: SxColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: SxColors.border)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: Theme.of(context).textTheme.titleSmall?.copyWith(color: SxColors.textSecondary)),
          const SizedBox(height: 8),
          ...children,
        ]),
      );
}

class _XpCard extends StatelessWidget {
  const _XpCard({required this.p});
  final MyProgress p;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final t = p.tierProgress;
    return _Card(
      title: l10n.progressXpHeading,
      children: [
        Text(tierLabel(l10n, p.membershipTier), style: Theme.of(context).textTheme.headlineSmall),
        Text('${p.xp} XP'),
        const SizedBox(height: 8),
        // The server sends the progress numbers; the app never computes tier thresholds.
        if (t != null) ...[
          LinearProgressIndicator(value: t.fraction),
          const SizedBox(height: 4),
          Text(l10n.progressXpToNext(t.xpIntoTier, t.xpForNextTier, tierLabel(l10n, t.next))),
        ] else
          Text(l10n.progressMaxTier),
      ],
    );
  }
}

class _SeasonCard extends StatelessWidget {
  const _SeasonCard({required this.standing});
  final SeasonStanding? standing;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final s = standing;
    return _Card(
      title: l10n.progressSeasonHeading,
      children: s == null
          ? [Text(l10n.progressSeasonNone)]
          : [
              if (s.seasonName != null) Text(s.seasonName!),
              Text(s.rank == null ? l10n.progressSeasonUnranked : l10n.progressSeasonRank(s.rank!), style: Theme.of(context).textTheme.headlineSmall),
              Text(l10n.seasonsPoints(s.points)),
              Text(l10n.progressToRankSixteen(s.pointsAtRankSixteen)),
              const SizedBox(height: 8),
              Text(l10n.progressSeasonMonthly, style: Theme.of(context).textTheme.titleSmall),
              Text([
                s.monthlyRank == null ? l10n.progressSeasonUnranked : l10n.progressSeasonRank(s.monthlyRank!),
                l10n.seasonsPoints(s.monthlyPoints),
              ].join(' · ')),
            ],
    );
  }
}
