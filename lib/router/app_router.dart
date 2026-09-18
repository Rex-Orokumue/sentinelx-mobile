import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/supabase_tournaments_repository.dart';
import '../data/tournaments_repository.dart';
import '../features/tournaments/bracket_screen.dart';
import '../features/tournaments/tournament_detail_screen.dart';
import '../features/tournaments/tournament_list_screen.dart';

GoRouter buildAppRouter({TournamentsRepository? repository}) {
  final tournamentsRepository =
      repository ?? SupabaseTournamentsRepository(Supabase.instance.client);

  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => TournamentListScreen(
          repository: tournamentsRepository,
          onTournamentTap: (tournament) => context.push('/tournaments/${tournament.id}'),
        ),
      ),
      GoRoute(
        path: '/tournaments/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return TournamentDetailScreen(
            repository: tournamentsRepository,
            tournamentId: id,
            onViewBracket: () => context.push('/tournaments/$id/bracket'),
          );
        },
      ),
      GoRoute(
        path: '/tournaments/:id/bracket',
        builder: (context, state) => BracketScreen(
          repository: tournamentsRepository,
          tournamentId: state.pathParameters['id']!,
        ),
      ),
    ],
  );
}
