import 'package:go_router/go_router.dart';

import '../data/tournaments_repository.dart';
import '../features/tournaments/bracket_screen.dart';
import '../features/tournaments/tournament_detail_screen.dart';
import '../features/tournaments/tournament_list_screen.dart';

GoRouter buildAppRouter({required TournamentsRepository repository}) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => TournamentListScreen(
          repository: repository,
          onTournamentTap: (tournament) => context.push('/tournaments/${tournament.id}'),
        ),
      ),
      GoRoute(
        path: '/tournaments/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return TournamentDetailScreen(
            repository: repository,
            tournamentId: id,
            onViewBracket: () => context.push('/tournaments/$id/bracket'),
          );
        },
      ),
      GoRoute(
        path: '/tournaments/:id/bracket',
        builder: (context, state) => BracketScreen(
          repository: repository,
          tournamentId: state.pathParameters['id']!,
        ),
      ),
    ],
  );
}
