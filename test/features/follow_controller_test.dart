import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/core/api/models.dart';
import 'package:sentinelx_mobile/core/api/players_models.dart';
import 'package:sentinelx_mobile/core/providers.dart';
import 'package:sentinelx_mobile/features/players/players_providers.dart';

import '../support/fake_players_repository.dart';

MeResponse _me() => const MeResponse(id: 'me1', email: null, roles: [], isStaff: false, isAdmin: false, profile: null);

ProviderContainer _container(FakePlayersRepository repo, {bool signedIn = true}) {
  final c = ProviderContainer(
    retry: (_, _) => null,
    overrides: [
      playersRepositoryProvider.overrideWithValue(repo),
      meProvider.overrideWith((ref) async => signedIn ? _me() : null),
      followRetryDelayProvider.overrideWithValue(Duration.zero),
    ],
  );
  addTearDown(c.dispose);
  return c;
}

Future<MyFollowsNotifier> _ready(ProviderContainer c) async {
  c.listen(myFollowsProvider, (_, _) {}); // an auto-dispose provider needs a listener, like a mounted screen has
  await c.read(myFollowsProvider.future);
  return c.read(myFollowsProvider.notifier);
}

void main() {
  test('signed out: state is null and /me/follows is never requested', () async {
    final repo = FakePlayersRepository();
    final c = _container(repo, signedIn: false);
    expect(await c.read(myFollowsProvider.future), isNull);
    expect(repo.myFollowsCalls, 0);
    final n = c.read(myFollowsProvider.notifier);
    expect(await n.follow(targetId: 'p1', username: 'ada'), isNull);
    expect(repo.followCalls, isEmpty); // signed out: no write either
  });

  test('follow flips optimistically, sends one PUT with a key, and bumps the follower delta on a created follow', () async {
    final repo = FakePlayersRepository();
    final c = _container(repo);
    final n = await _ready(c);
    final pending = n.follow(targetId: 'p1', username: 'ada');
    expect(c.read(myFollowsProvider).value!.followingIds, {'p1'}); // flipped before the request resolves
    expect(await pending, isNull);
    expect(repo.followCalls.single.username, 'ada');
    expect(repo.followCalls.single.key, isNotEmpty);
    expect(c.read(followerDeltaProvider)['p1'], 1);
  });

  test('a duplicate follow (created:false) does not bump the delta', () async {
    final repo = FakePlayersRepository()..followResult = const FollowOutcome(following: true, created: false);
    final c = _container(repo);
    final n = await _ready(c);
    await n.follow(targetId: 'p1', username: 'ada');
    expect(c.read(followerDeltaProvider)['p1'] ?? 0, 0);
  });

  test('failures roll back to the exact previous state and map to a distinct failure', () async {
    final cases = <(Object, FollowFailure)>[
      (apiError(403, 'follow_blocked'), FollowFailure.blocked),
      (apiError(400, 'cannot_follow_self'), FollowFailure.self),
      (apiError(404, 'not_found'), FollowFailure.notFound),
      (apiError(401, 'unauthorized'), FollowFailure.unauthorized),
      (apiError(500, 'follow_failed'), FollowFailure.generic),
    ];
    for (final (error, expected) in cases) {
      final repo = FakePlayersRepository()
        ..sets = const FollowSets(followingIds: {'x'}, followerIds: {'y'})
        ..followErrors.add(error);
      final c = _container(repo);
      final n = await _ready(c);
      expect(await n.follow(targetId: 'p1', username: 'ada'), expected, reason: '$error');
      final s = c.read(myFollowsProvider).value!;
      expect(s.followingIds, {'x'}, reason: 'rolled back for $error');
      expect(s.followerIds, {'y'});
      expect(c.read(followerDeltaProvider)['p1'] ?? 0, 0);
      expect(repo.followCalls, hasLength(1), reason: 'non-retryable errors are not retried');
    }
  });

  test('a network failure retries once with the SAME Idempotency-Key and then succeeds', () async {
    final repo = FakePlayersRepository()..followErrors.add(apiError(0, 'network'));
    final c = _container(repo);
    final n = await _ready(c);
    expect(await n.follow(targetId: 'p1', username: 'ada'), isNull);
    expect(repo.followCalls, hasLength(2));
    expect(repo.followCalls[0].key, repo.followCalls[1].key);
    expect(c.read(myFollowsProvider).value!.followingIds, {'p1'});
  });

  test('409 idempotency_in_progress is retried once with the same key', () async {
    final repo = FakePlayersRepository()..followErrors.add(apiError(409, 'idempotency_in_progress'));
    final c = _container(repo);
    final n = await _ready(c);
    expect(await n.follow(targetId: 'p1', username: 'ada'), isNull);
    expect(repo.followCalls[0].key, repo.followCalls[1].key);
  });

  test('two network failures in a row roll back (retry is bounded to one)', () async {
    final repo = FakePlayersRepository()..followErrors.addAll([apiError(0, 'network'), apiError(0, 'network')]);
    final c = _container(repo);
    final n = await _ready(c);
    expect(await n.follow(targetId: 'p1', username: 'ada'), FollowFailure.generic);
    expect(repo.followCalls, hasLength(2));
    expect(c.read(myFollowsProvider).value!.followingIds, isEmpty);
  });

  test('a fresh tap after a completed one uses a NEW key', () async {
    final repo = FakePlayersRepository();
    final c = _container(repo);
    final n = await _ready(c);
    await n.follow(targetId: 'p1', username: 'ada');
    await n.unfollow(targetId: 'p1', username: 'ada');
    await n.follow(targetId: 'p1', username: 'ada');
    expect(repo.followCalls[0].key, isNot(repo.followCalls[1].key));
  });

  test('a second tap while the first is in flight is ignored', () async {
    final gate = Completer<void>();
    final repo = FakePlayersRepository()..followGate = gate;
    final c = _container(repo);
    final n = await _ready(c);
    final first = n.follow(targetId: 'p1', username: 'ada');
    await Future<void>.delayed(Duration.zero);
    expect(await n.unfollow(targetId: 'p1', username: 'ada'), isNull); // ignored
    expect(await n.follow(targetId: 'p1', username: 'ada'), isNull); // ignored
    gate.complete();
    await first;
    expect(repo.followCalls, hasLength(1));
    expect(repo.unfollowCalls, isEmpty);
    expect(c.read(myFollowsProvider).value!.followingIds, {'p1'});
  });

  test('unfollow of a followed player removes them and decrements the delta; failure rolls back', () async {
    final repo = FakePlayersRepository()..sets = const FollowSets(followingIds: {'p1'}, followerIds: {});
    final c = _container(repo);
    final n = await _ready(c);
    expect(await n.unfollow(targetId: 'p1', username: 'ada'), isNull);
    expect(c.read(myFollowsProvider).value!.followingIds, isEmpty);
    expect(c.read(followerDeltaProvider)['p1'], -1);

    final repo2 = FakePlayersRepository()
      ..sets = const FollowSets(followingIds: {'p1'}, followerIds: {})
      ..unfollowError = apiError(500, 'unfollow_failed');
    final c2 = _container(repo2);
    final n2 = await _ready(c2);
    expect(await n2.unfollow(targetId: 'p1', username: 'ada'), FollowFailure.generic);
    expect(c2.read(myFollowsProvider).value!.followingIds, {'p1'});
    expect(c2.read(followerDeltaProvider)['p1'] ?? 0, 0);
  });

  test('leaving the screen mid-request (provider disposed) does not throw or touch other providers', () async {
    final gate = Completer<void>();
    final repo = FakePlayersRepository()..followGate = gate;
    final c = _container(repo);
    final sub = c.listen(myFollowsProvider, (_, _) {});
    await c.read(myFollowsProvider.future);
    final n = c.read(myFollowsProvider.notifier);
    final pending = n.follow(targetId: 'p1', username: 'ada');
    await Future<void>.delayed(Duration.zero);
    sub.close(); // no listeners left: the auto-dispose provider goes away
    await Future<void>.delayed(Duration.zero);
    gate.complete();
    expect(await pending, isNull);
  });
}
