import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/tournament.dart';
import 'tournaments_providers.dart';

class TournamentListScreen extends ConsumerWidget {
  const TournamentListScreen({super.key, required this.onTournamentTap});

  final void Function(Tournament tournament) onTournamentTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tournaments = ref.watch(tournamentsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Tournaments')),
      body: tournaments.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Failed to load tournaments: $error')),
        data: (items) {
          if (items.isEmpty) {
            return const Center(child: Text('No tournaments yet.'));
          }
          return ListView.builder(
            itemCount: items.length,
            itemBuilder: (context, index) {
              final tournament = items[index];
              return ListTile(
                key: Key('tournament-tile-${tournament.id}'),
                title: Text(tournament.title),
                subtitle: Text('${tournament.gameName} • ${tournament.status}'),
                onTap: () => onTournamentTap(tournament),
              );
            },
          );
        },
      ),
    );
  }
}
