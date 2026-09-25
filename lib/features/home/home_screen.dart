import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/gen/app_localizations.dart';
import '../../core/providers.dart';
import 'home_providers.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key, required this.onGoTo});

  final void Function(String path) onGoTo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(homeProvider, (previous, next) {
      if (next case AsyncError(:final error, :final stackTrace)) {
        ref.read(errorReporterProvider).report(error, stackTrace, route: '/');
      }
    });
    final home = ref.watch(homeProvider);
    final l10n = AppLocalizations.of(context);
    final isSignedIn = ref.watch(meProvider).asData?.value != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sentinel X'),
        actions: [
          IconButton(
            key: const Key('home-account'),
            icon: Icon(isSignedIn ? Icons.person : Icons.person_outline),
            onPressed: () => onGoTo(isSignedIn ? '/account' : '/login'),
          ),
        ],
      ),
      body: home.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(l10n.homeLoadError)),
        data: (summary) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(homeProvider),
          child: ListView(
            children: [
              if (summary.featuredTournament != null)
                ListTile(
                  key: const Key('home-featured'),
                  title: Text(summary.featuredTournament!.title),
                  subtitle: Text(summary.featuredTournament!.status),
                  onTap: () => onGoTo('/tournaments/${summary.featuredTournament!.id}'),
                ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text('${summary.stats.playerCount} players · ${summary.stats.tournamentCount} tournaments'),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(l10n.homeUpcomingHeading),
                    TextButton(onPressed: () => onGoTo('/tournaments'), child: Text(l10n.homeFullRankingsLink)),
                  ],
                ),
              ),
              for (final t in summary.upcomingTournaments)
                ListTile(title: Text(t.title), onTap: () => onGoTo('/tournaments/${t.id}')),
              Padding(padding: const EdgeInsets.all(16), child: Text(l10n.homeTopPlayersHeading)),
              for (final p in summary.leaderboardTeaser) ListTile(title: Text(p.displayName ?? p.username ?? '—')),
            ],
          ),
        ),
      ),
    );
  }
}
