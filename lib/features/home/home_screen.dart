import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_providers.dart';
import '../../core/auth/onboarding_gate.dart';
import '../../core/l10n/gen/app_localizations.dart';
import 'home_providers.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key, required this.onGoTo});

  final void Function(String path) onGoTo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(sessionStartedProvider); // side-effecting; result not rendered
    // Catches a signed-in user with no username who reached Home some way
    // other than the confirm-link flow (incoming_links.dart routes that case
    // straight to /onboarding/username already) - chiefly a fresh Google
    // sign-in, which has no username metadata either. Watched (not listened
    // to) so a gate that is already `username` on first build still redirects;
    // navigation is deferred a frame since it cannot run mid-build.
    if (ref.watch(onboardingGateProvider) == OnboardingGate.username) {
      WidgetsBinding.instance.addPostFrameCallback((_) => onGoTo('/onboarding/username'));
    }
    final home = ref.watch(homeProvider);
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Sentinel X')),
      body: home.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Failed to load: $e')),
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
