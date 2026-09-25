import '../../core/api/api_client.dart';
import '../../core/api/players_models.dart';

abstract class PlayersRepository {
  Future<List<PlayerListItem>> search(String q);
  Future<PlayerProfile> profile(String username);
  Future<List<FollowEntry>> followers(String username);
  Future<List<FollowEntry>> following(String username);
  Future<FollowSets> myFollows();
  Future<FollowOutcome> follow(String username, String idempotencyKey);
  Future<FollowOutcome> unfollow(String username);
}

class ApiPlayersRepository implements PlayersRepository {
  ApiPlayersRepository(this._api);
  final ApiClient _api;

  @override
  Future<List<PlayerListItem>> search(String q) => _api.searchPlayers(q: q);
  @override
  Future<PlayerProfile> profile(String username) => _api.getPlayerProfile(username);
  @override
  Future<List<FollowEntry>> followers(String username) => _api.getPlayerFollowers(username);
  @override
  Future<List<FollowEntry>> following(String username) => _api.getPlayerFollowing(username);
  @override
  Future<FollowSets> myFollows() => _api.getMyFollows();
  @override
  Future<FollowOutcome> follow(String username, String idempotencyKey) =>
      _api.followPlayer(username, idempotencyKey: idempotencyKey);
  @override
  Future<FollowOutcome> unfollow(String username) => _api.unfollowPlayer(username);
}
