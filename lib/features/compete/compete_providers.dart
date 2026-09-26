import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/compete_models.dart';
import '../../core/providers.dart';
import 'compete_models.dart';
import 'compete_reads_repository.dart';
import 'registration_repository.dart';

final competeReadsRepositoryProvider =
    Provider<CompeteReadsRepository>((ref) => SupabaseCompeteReadsRepository(ref.watch(supabaseClientProvider)));

final registrationRepositoryProvider =
    Provider<RegistrationRepository>((ref) => ApiRegistrationRepository(ref.watch(apiClientProvider)));

class TournamentTabNotifier extends Notifier<TournamentTab> {
  @override
  TournamentTab build() => TournamentTab.all;
  void select(TournamentTab tab) => state = tab;
}

final tournamentTabProvider = NotifierProvider<TournamentTabNotifier, TournamentTab>(TournamentTabNotifier.new);

class GameFilterNotifier extends Notifier<String?> {
  @override
  String? build() => null;
  void select(String? slug) => state = slug;
}

final tournamentGameFilterProvider = NotifierProvider<GameFilterNotifier, String?>(GameFilterNotifier.new);

/// Accepts a tournament id (in-app routes) or slug (web links).
final competeTournamentProvider = FutureProvider.autoDispose.family<CompeteTournament, String>(
  (ref, idOrSlug) => ref.watch(competeReadsRepositoryProvider).fetchTournament(idOrSlug),
);

/// Public endpoint: works signed out (returns view `guest`). Re-read after any registration change
/// with `ref.invalidate(registrationStateProvider(id))`.
final registrationStateProvider = FutureProvider.autoDispose.family<RegistrationState, String>(
  (ref, id) => ref.watch(registrationRepositoryProvider).registrationState(id),
);

final gamesProvider = FutureProvider.autoDispose<List<GameSummary>>(
  (ref) => ref.watch(competeReadsRepositoryProvider).fetchGames(),
);

/// Empty when signed out — never queries with a null user.
final myInvitationsProvider = FutureProvider.autoDispose<List<PendingInvitation>>((ref) async {
  final me = ref.watch(meProvider).asData?.value;
  if (me == null) return const [];
  return ref.watch(competeReadsRepositoryProvider).fetchMyPendingInvitations(me.id);
});

class TournamentListState {
  const TournamentListState({
    this.items = const [],
    this.page = 0,
    this.hasMore = true,
    this.loadingMore = false,
    this.loadMoreFailed = false,
  });

  final List<CompeteTournament> items;
  final int page;
  final bool hasMore;
  final bool loadingMore;
  final bool loadMoreFailed;

  TournamentListState copyWith({
    List<CompeteTournament>? items,
    int? page,
    bool? hasMore,
    bool? loadingMore,
    bool? loadMoreFailed,
  }) =>
      TournamentListState(
        items: items ?? this.items,
        page: page ?? this.page,
        hasMore: hasMore ?? this.hasMore,
        loadingMore: loadingMore ?? this.loadingMore,
        loadMoreFailed: loadMoreFailed ?? this.loadMoreFailed,
      );
}

/// Rebuilds (and reloads page 1) whenever the tab or game filter changes.
class TournamentListNotifier extends AsyncNotifier<TournamentListState> {
  @override
  Future<TournamentListState> build() async {
    final tab = ref.watch(tournamentTabProvider);
    final game = ref.watch(tournamentGameFilterProvider);
    final rows = await ref.read(competeReadsRepositoryProvider).fetchTournaments(tab: tab, gameSlug: game, page: 1);
    return TournamentListState(items: rows, page: 1, hasMore: rows.length == kTournamentPageSize);
  }

  Future<void> loadMore() async {
    final cur = state.asData?.value;
    if (cur == null || !cur.hasMore || cur.loadingMore) return;
    state = AsyncData(cur.copyWith(loadingMore: true, loadMoreFailed: false));
    try {
      final rows = await ref.read(competeReadsRepositoryProvider).fetchTournaments(
            tab: ref.read(tournamentTabProvider),
            gameSlug: ref.read(tournamentGameFilterProvider),
            page: cur.page + 1,
          );
      if (!ref.mounted) return;
      state = AsyncData(cur.copyWith(
        items: [...cur.items, ...rows],
        page: cur.page + 1,
        hasMore: rows.length == kTournamentPageSize,
        loadingMore: false,
        loadMoreFailed: false,
      ));
    } catch (_) {
      if (!ref.mounted) return;
      state = AsyncData(cur.copyWith(loadingMore: false, loadMoreFailed: true));
    }
  }
}

final tournamentListProvider =
    AsyncNotifierProvider.autoDispose<TournamentListNotifier, TournamentListState>(TournamentListNotifier.new);
