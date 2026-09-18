import 'package:flutter/material.dart';

import '../../data/tournaments_repository.dart';
import '../../models/bracket_match.dart';

class BracketScreen extends StatefulWidget {
  const BracketScreen({
    super.key,
    required this.repository,
    required this.tournamentId,
  });

  final TournamentsRepository repository;
  final String tournamentId;

  @override
  State<BracketScreen> createState() => _BracketScreenState();
}

class _BracketScreenState extends State<BracketScreen> {
  late final Future<List<BracketMatch>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.repository.fetchBracket(widget.tournamentId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bracket')),
      body: FutureBuilder<List<BracketMatch>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Failed to load bracket: ${snapshot.error}'));
          }
          final matches = snapshot.data!;
          if (matches.isEmpty) {
            return const Center(child: Text('No matches yet.'));
          }

          final matchesByRound = <String, List<BracketMatch>>{};
          for (final match in matches) {
            matchesByRound.putIfAbsent(match.round, () => []).add(match);
          }
          final rounds = matchesByRound.keys.toList()
            ..sort((a, b) => roundSortIndex(a).compareTo(roundSortIndex(b)));

          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final round in rounds)
                  Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: _RoundColumn(
                      round: round,
                      matches: matchesByRound[round]!,
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _RoundColumn extends StatelessWidget {
  const _RoundColumn({required this.round, required this.matches});

  final String round;
  final List<BracketMatch> matches;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            roundDisplayName(round),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final match in matches) _MatchCard(match: match),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MatchCard extends StatelessWidget {
  const _MatchCard({required this.match});

  final BracketMatch match;

  @override
  Widget build(BuildContext context) {
    final hasScore = match.scoreA != null && match.scoreB != null;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(match.participantALabel),
            Text(match.participantBLabel),
            if (hasScore) ...[
              const SizedBox(height: 4),
              Text('${match.scoreA} - ${match.scoreB}'),
            ],
          ],
        ),
      ),
    );
  }
}
