import 'dart:async';

import 'package:sentinelx_mobile/core/api/api_client.dart';
import 'package:sentinelx_mobile/core/api/players_models.dart';
import 'package:sentinelx_mobile/features/players/players_repository.dart';

import 'players_fixtures.dart';

class FakePlayersRepository implements PlayersRepository {
  Map<String, dynamic> profileData = profileJson();
  Object? profileError;
  List<PlayerListItem> searchResults = const [];
  List<FollowEntry> followerList = const [];
  List<FollowEntry> followingList = const [];
  FollowSets sets = const FollowSets(followingIds: {}, followerIds: {});
  Object? myFollowsError;

  /// One entry is consumed (thrown) per follow() call before a call is allowed to succeed.
  final List<Object> followErrors = [];
  Object? unfollowError;
  FollowOutcome followResult = const FollowOutcome(following: true, created: true);
  Completer<void>? followGate; // set to hold follow() open (double-tap tests)

  final searches = <String>[];
  final profileRequests = <String>[];
  var myFollowsCalls = 0;
  final followCalls = <({String username, String key})>[];
  final unfollowCalls = <String>[];

  @override
  Future<List<PlayerListItem>> search(String q) async {
    searches.add(q);
    return searchResults;
  }

  @override
  Future<PlayerProfile> profile(String username) async {
    profileRequests.add(username);
    if (profileError != null) throw profileError!;
    return PlayerProfile.fromJson(profileData);
  }

  @override
  Future<List<FollowEntry>> followers(String username) async => followerList;

  @override
  Future<List<FollowEntry>> following(String username) async => followingList;

  @override
  Future<FollowSets> myFollows() async {
    myFollowsCalls++;
    if (myFollowsError != null) throw myFollowsError!;
    return sets;
  }

  @override
  Future<FollowOutcome> follow(String username, String idempotencyKey) async {
    followCalls.add((username: username, key: idempotencyKey));
    if (followGate != null) await followGate!.future;
    if (followErrors.isNotEmpty) throw followErrors.removeAt(0);
    return followResult;
  }

  @override
  Future<FollowOutcome> unfollow(String username) async {
    unfollowCalls.add(username);
    if (unfollowError != null) throw unfollowError!;
    return const FollowOutcome(following: false, created: false);
  }
}

ApiException apiError(int status, String code) => ApiException(status: status, code: code, message: code);
