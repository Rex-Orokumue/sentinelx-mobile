import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'tournaments_providers.dart';

class TournamentDetailScreen extends ConsumerWidget {
  const TournamentDetailScreen({
    super.key,
    required this.tournamentId,
    required this.onViewBracket,
  });

  final String tournamentId;
  final VoidCallback onViewBracket;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(tournamentProvider(tournamentId));
    return Scaffold(
      appBar: AppBar(title: const Text('Tournament')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Failed to load tournament: $error')),
        data: (tournament) => SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(tournament.title, style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text('${tournament.gameName} • ${tournament.status}'),
              const SizedBox(height: 16),
              Text('Prize pool: ${tournament.prizePool}'),
              if (tournament.prizeSecond != null) Text('2nd place: ${tournament.prizeSecond}'),
              if (tournament.prizeThird != null) Text('3rd place: ${tournament.prizeThird}'),
              const SizedBox(height: 8),
              Text('Registration fee: ${tournament.registrationFee}'),
              if (tournament.maxPlayers != null) Text('Max players: ${tournament.maxPlayers}'),
              if (tournament.description != null) ...[
                const SizedBox(height: 16),
                Text(tournament.description!),
              ],
              const SizedBox(height: 24),
              ElevatedButton(
                key: const Key('view-bracket-button'),
                onPressed: onViewBracket,
                child: const Text('View Bracket'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
