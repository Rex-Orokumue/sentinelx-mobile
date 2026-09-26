import 'package:sentinelx_mobile/features/compete/compete_models.dart';
import 'package:sentinelx_mobile/features/compete/compete_reads_repository.dart';

class FakeCompeteReads implements CompeteReadsRepository {
  FakeCompeteReads({
    this.tournaments = const [],
    this.games = const [],
    this.invitations = const [],
    this.pendingReference,
    this.failNextPage = false,
    this.failAll = false,
  });

  List<CompeteTournament> tournaments;
  List<GameSummary> games;
  List<PendingInvitation> invitations;
  String? pendingReference;
  bool failNextPage;
  bool failAll;
  final pagesRequested = <int>[];
  final tabsRequested = <TournamentTab>[];
  final gamesRequested = <String?>[];

  @override
  Future<List<CompeteTournament>> fetchTournaments({required TournamentTab tab, String? gameSlug, int page = 1}) async {
    tabsRequested.add(tab);
    gamesRequested.add(gameSlug);
    pagesRequested.add(page);
    if (failAll) throw Exception('boom');
    if (page > 1 && failNextPage) {
      failNextPage = false;
      throw Exception('boom');
    }
    final start = (page - 1) * kTournamentPageSize;
    if (start >= tournaments.length) return const [];
    return tournaments.skip(start).take(kTournamentPageSize).toList();
  }

  @override
  Future<CompeteTournament> fetchTournament(String id) async {
    if (failAll) throw Exception('boom');
    return tournaments.firstWhere((t) => t.id == id || t.slug == id);
  }

  @override
  Future<List<GameSummary>> fetchGames() async {
    if (failAll) throw Exception('boom');
    return games;
  }

  @override
  Future<List<PendingInvitation>> fetchMyPendingInvitations(String userId) async => invitations;

  @override
  Future<String?> fetchMyPendingReference(String tournamentId, String userId) async => pendingReference;
}
