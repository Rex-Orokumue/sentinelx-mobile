import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/api/players_models.dart';
import '../../core/providers.dart';
import '../../core/utils/idempotency_key.dart';
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

enum FollowFailure { self, blocked, notFound, unauthorized, generic }

FollowFailure _failureOf(Object e) {
  if (e is ApiException) {
    if (e.code == 'cannot_follow_self') return FollowFailure.self;
    if (e.code == 'follow_blocked') return FollowFailure.blocked;
    if (e.status == 404) return FollowFailure.notFound;
    if (e.status == 401) return FollowFailure.unauthorized;
  }
  return FollowFailure.generic;
}

/// Worth exactly one retry with the SAME key: nothing reached the server, or the server is still finishing that key.
bool _retryable(Object e) => e is ApiException && (e.status == 0 || e.code == 'idempotency_in_progress');

class FollowerDeltaNotifier extends Notifier<Map<String, int>> {
  @override
  Map<String, int> build() => const {};
  void add(String id, int by) => state = {...state, id: (state[id] ?? 0) + by};
}

final followerDeltaProvider =
    NotifierProvider.autoDispose<FollowerDeltaNotifier, Map<String, int>>(FollowerDeltaNotifier.new);

final followRetryDelayProvider = Provider<Duration>((ref) => const Duration(milliseconds: 400));

class MyFollowsNotifier extends AsyncNotifier<FollowSets?> {
  final _inFlight = <String>{};

  @override
  Future<FollowSets?> build() async {
    final me = await ref.watch(meProvider.future);
    if (me == null) return null; // signed out: never touch /me/*
    return ref.watch(playersRepositoryProvider).myFollows();
  }

  Future<FollowFailure?> follow({required String targetId, required String username}) async {
    final before = state.value;
    if (before == null || _inFlight.contains(targetId)) return null;
    _inFlight.add(targetId);
    state = AsyncData(before.copyWith(followingIds: {...before.followingIds, targetId}));
    final key = newIdempotencyKey(); // one key per tap, reused on the retry below
    final repo = ref.read(playersRepositoryProvider);
    try {
      FollowOutcome outcome;
      try {
        outcome = await repo.follow(username, key);
      } catch (e) {
        if (!_retryable(e)) rethrow;
        await Future<void>.delayed(ref.read(followRetryDelayProvider));
        outcome = await repo.follow(username, key);
      }
      if (!ref.mounted) return null; // the screen left mid-request; nothing left to update
      if (outcome.created) ref.read(followerDeltaProvider.notifier).add(targetId, 1);
      return null;
    } catch (e) {
      if (!ref.mounted) return null;
      state = AsyncData(before);
      return e is ApiException && _retryable(e) ? FollowFailure.generic : _failureOf(e);
    } finally {
      _inFlight.remove(targetId);
    }
  }

  Future<FollowFailure?> unfollow({required String targetId, required String username}) async {
    final before = state.value;
    if (before == null || _inFlight.contains(targetId)) return null;
    _inFlight.add(targetId);
    final wasFollowing = before.followingIds.contains(targetId);
    state = AsyncData(before.copyWith(followingIds: {...before.followingIds}..remove(targetId)));
    try {
      await ref.read(playersRepositoryProvider).unfollow(username);
      if (!ref.mounted) return null;
      if (wasFollowing) ref.read(followerDeltaProvider.notifier).add(targetId, -1);
      return null;
    } catch (e) {
      if (!ref.mounted) return null;
      state = AsyncData(before);
      return _failureOf(e);
    } finally {
      _inFlight.remove(targetId);
    }
  }
}

/// null when signed out — and then NO request is made.
final myFollowsProvider = AsyncNotifierProvider.autoDispose<MyFollowsNotifier, FollowSets?>(MyFollowsNotifier.new);
