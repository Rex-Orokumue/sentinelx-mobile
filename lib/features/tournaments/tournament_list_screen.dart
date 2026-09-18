import 'package:flutter/material.dart';

import '../../data/tournaments_repository.dart';
import '../../models/tournament.dart';

class TournamentListScreen extends StatefulWidget {
  const TournamentListScreen({
    super.key,
    required this.repository,
    required this.onTournamentTap,
  });

  final TournamentsRepository repository;
  final void Function(Tournament tournament) onTournamentTap;

  @override
  State<TournamentListScreen> createState() => _TournamentListScreenState();
}

class _TournamentListScreenState extends State<TournamentListScreen> {
  late final Future<List<Tournament>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.repository.fetchTournaments();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tournaments')),
      body: FutureBuilder<List<Tournament>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Failed to load tournaments: ${snapshot.error}'));
          }
          final tournaments = snapshot.data!;
          if (tournaments.isEmpty) {
            return const Center(child: Text('No tournaments yet.'));
          }
          return ListView.builder(
            itemCount: tournaments.length,
            itemBuilder: (context, index) {
              final tournament = tournaments[index];
              return ListTile(
                key: Key('tournament-tile-${tournament.id}'),
                title: Text(tournament.title),
                subtitle: Text('${tournament.gameName} • ${tournament.status}'),
                onTap: () => widget.onTournamentTap(tournament),
              );
            },
          );
        },
      ),
    );
  }
}
