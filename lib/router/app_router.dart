import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/debug/debug_sign_in_screen.dart';
import '../features/tournaments/bracket_screen.dart';
import '../features/tournaments/tournament_detail_screen.dart';
import '../features/tournaments/tournament_list_screen.dart';
import '../core/providers.dart';
import '../core/routing/web_links.dart';

GoRouter buildAppRouter({bool debugTools = false}) {
  return GoRouter(
    initialLocation: '/',
    // App Links (and later, push/bell taps) hand go_router the raw web URL, which is not itself
    // a valid route path. resolveWebLink() is the single place that maps it to one.
    redirect: (context, state) {
      final incoming = state.uri.toString();
      final resolved = resolveWebLink(incoming);
      return (resolved != null && resolved != incoming) ? resolved : null;
    },
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => TournamentListScreen(
          onTournamentTap: (tournament) => context.push('/tournaments/${tournament.id}'),
        ),
      ),
      GoRoute(
        path: '/tournaments/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return TournamentDetailScreen(
            tournamentId: id,
            onViewBracket: () => context.push('/tournaments/$id/bracket'),
          );
        },
      ),
      GoRoute(
        path: '/tournaments/:id/bracket',
        builder: (context, state) => BracketScreen(tournamentId: state.pathParameters['id']!),
      ),
      if (debugTools)
        GoRoute(path: '/debug', builder: (context, state) => const DebugSignInScreen()),
    ],
  );
}

final routerProvider = Provider<GoRouter>((ref) {
  final router = buildAppRouter(debugTools: ref.watch(appConfigProvider).debugTools);
  ref.onDispose(router.dispose);
  return router;
});
