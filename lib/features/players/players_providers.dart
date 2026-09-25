import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/players_models.dart';
import '../../core/providers.dart';
import 'players_repository.dart';

final playersRepositoryProvider = Provider<PlayersRepository>((ref) => ApiPlayersRepository(ref.watch(apiClientProvider)));

class PlayerSearchQueryNotifier extends Notifier<String> {
  @override
  String build() => '';
  void set(String q) => state = q.trim();
}

final playerSearchQueryProvider =
    NotifierProvider.autoDispose<PlayerSearchQueryNotifier, String>(PlayerSearchQueryNotifier.new);

/// `GET /players` cannot exclude the caller (public, byte-identical for everyone), so the app drops its own row.
final playerSearchProvider = FutureProvider.autoDispose<List<PlayerListItem>>((ref) async {
  final q = ref.watch(playerSearchQueryProvider);
  final results = await ref.watch(playersRepositoryProvider).search(q);
  final myUsername = ref.watch(meProvider).asData?.value?.profile?.username;
  return myUsername == null ? results : results.where((p) => p.username != myUsername).toList();
});

final playerProfileProvider = FutureProvider.autoDispose.family<PlayerProfile, String>(
  (ref, username) => ref.watch(playersRepositoryProvider).profile(username),
);

enum FollowListKind { followers, following }

final followListProvider = FutureProvider.autoDispose.family<List<FollowEntry>, (String, FollowListKind)>((ref, args) {
  final repo = ref.watch(playersRepositoryProvider);
  return args.$2 == FollowListKind.followers ? repo.followers(args.$1) : repo.following(args.$1);
});
