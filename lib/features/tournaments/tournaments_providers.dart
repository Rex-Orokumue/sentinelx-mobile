import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../data/supabase_tournaments_repository.dart';
import '../../data/tournaments_repository.dart';
import '../../models/bracket_match.dart';
import '../../models/tournament.dart';

final tournamentsRepositoryProvider = Provider<TournamentsRepository>(
  (ref) => SupabaseTournamentsRepository(ref.watch(supabaseClientProvider)),
);

final tournamentsProvider = FutureProvider.autoDispose<List<Tournament>>(
  (ref) => ref.watch(tournamentsRepositoryProvider).fetchTournaments(),
);

final tournamentProvider = FutureProvider.autoDispose.family<Tournament, String>(
  (ref, id) => ref.watch(tournamentsRepositoryProvider).fetchTournament(id),
);

final bracketProvider = FutureProvider.autoDispose.family<List<BracketMatch>, String>(
  (ref, id) => ref.watch(tournamentsRepositoryProvider).fetchBracket(id),
);
