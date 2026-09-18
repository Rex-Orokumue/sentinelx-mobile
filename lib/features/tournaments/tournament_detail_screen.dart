import 'package:flutter/material.dart';

import '../../data/tournaments_repository.dart';
import '../../models/tournament.dart';

class TournamentDetailScreen extends StatefulWidget {
  const TournamentDetailScreen({
    super.key,
    required this.repository,
    required this.tournamentId,
    required this.onViewBracket,
  });

  final TournamentsRepository repository;
  final String tournamentId;
  final VoidCallback onViewBracket;

  @override
  State<TournamentDetailScreen> createState() => _TournamentDetailScreenState();
}

class _TournamentDetailScreenState extends State<TournamentDetailScreen> {
  late final Future<Tournament> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.repository.fetchTournament(widget.tournamentId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tournament')),
      body: FutureBuilder<Tournament>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Failed to load tournament: ${snapshot.error}'));
          }
          final tournament = snapshot.data!;
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tournament.title, style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 8),
                Text('${tournament.gameName} • ${tournament.status}'),
                const SizedBox(height: 16),
                Text('Prize pool: ${tournament.prizePool}'),
                if (tournament.prizeSecond != null)
                  Text('2nd place: ${tournament.prizeSecond}'),
                if (tournament.prizeThird != null)
                  Text('3rd place: ${tournament.prizeThird}'),
                const SizedBox(height: 8),
                Text('Registration fee: ${tournament.registrationFee}'),
                if (tournament.maxPlayers != null)
                  Text('Max players: ${tournament.maxPlayers}'),
                if (tournament.description != null) ...[
                  const SizedBox(height: 16),
                  Text(tournament.description!),
                ],
                const SizedBox(height: 24),
                ElevatedButton(
                  key: const Key('view-bracket-button'),
                  onPressed: widget.onViewBracket,
                  child: const Text('View Bracket'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
