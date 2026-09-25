import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/core/api/players_models.dart';

import '../support/players_fixtures.dart';

void main() {
  test('PlayerProfile parses every section, including nullable rank and match fields', () {
    final p = PlayerProfile.fromJson(profileJson());
    expect(p.player.label, 'Ada');
    expect(p.player.xp, 1500);
    expect(p.stats.rank, 3);
    expect(p.stats.categoryStats.single.category, 'football');
    expect(p.titles.single.gameName, 'DLS');
    expect(p.recentMatches.last.completedAt, isNull);
    expect(p.recentMatches.first.outcome, 'win');
    expect(p.posts.single.postType, 'manual');
    expect(p.gallery.single.imageUrl, 'https://img.test/1.png');
  });

  test('achievements: only unlocked objects exist; locked is a pure count', () {
    final a = PlayerProfile.fromJson(profileJson(totalAchievements: 5, unlockedAchievements: 2)).achievements;
    expect(a.unlocked.map((x) => x.slug), ['a0', 'a1']); // server (rarity) order preserved, never re-sorted
    expect(a.lockedCount, 3);
    expect(a.showcase, ['a0']);
  });

  test('achievements: total 0 and total < unlocked never go negative', () {
    expect(PlayerProfile.fromJson(profileJson(totalAchievements: 0, unlockedAchievements: 0)).achievements.lockedCount, 0);
    expect(PlayerProfile.fromJson(profileJson(totalAchievements: 1, unlockedAchievements: 2)).achievements.lockedCount, 0);
  });

  test('profile with null rank, null bio and no activity parses', () {
    final p = PlayerProfile.fromJson(profileJson(rank: null, totalRanked: null, bio: null, withActivity: false));
    expect(p.stats.rank, isNull);
    expect(p.stats.totalRankedPlayers, isNull);
    expect(p.player.bio, isNull);
    expect(p.titles, isEmpty);
    expect(p.recentMatches, isEmpty);
  });

  test('FollowEntry with a null username is a tombstone with an empty label', () {
    final e = FollowEntry.fromJson(followEntryJson('u1', null));
    expect(e.isDeleted, isTrue);
    expect(e.label, '');
    expect(FollowEntry.fromJson(followEntryJson('u2', 'ada')).isDeleted, isFalse);
  });

  test('PlayerListItem label prefers displayName, falls back to username', () {
    final base = {'username': 'ada', 'displayName': null, 'avatarUrl': null, 'sxScore': 9, 'sentinelTier': null, 'membershipTier': 'recruit', 'equippedAvatarBorder': null};
    expect(PlayerListItem.fromJson(base).label, 'ada');
    expect(PlayerListItem.fromJson({...base, 'displayName': 'Ada'}).label, 'Ada');
  });

  test('FollowSets and FollowOutcome parse', () {
    final s = FollowSets.fromJson({'followingIds': ['a', 'b'], 'followerIds': ['c']});
    expect(s.followingIds, {'a', 'b'});
    expect(s.copyWith(followingIds: {'z'}).followerIds, {'c'});
    expect(FollowOutcome.fromJson({'following': true, 'created': false}).created, isFalse);
    expect(FollowOutcome.fromJson({'following': false}).created, isFalse);
  });

  test('MyProgress: null tierProgress at max tier and null seasonStanding with no season', () {
    final p = MyProgress.fromJson({
      'xp': 60000, 'membershipTier': 'legend', 'tierProgress': null, 'sxScore': 1500, 'sentinelTier': null,
      'coinBalance': 1234, 'seasonStanding': null,
    });
    expect(p.tierProgress, isNull);
    expect(p.seasonStanding, isNull);
    expect(p.coinBalance, 1234);
  });

  test('TierProgress.fraction is clamped and safe against a zero denominator', () {
    TierProgress t(int into, int need) => TierProgress.fromJson({'current': 'recruit', 'next': 'guardian', 'xpIntoTier': into, 'xpForNextTier': need});
    expect(t(250, 1000).fraction, 0.25);
    expect(t(2000, 1000).fraction, 1.0);
    expect(t(5, 0).fraction, 0.0);
  });

  test('SeasonStanding parses nullable ranks', () {
    final s = SeasonStanding.fromJson({
      'seasonName': null, 'rank': null, 'points': 0, 'pointsAtRankSixteen': 40, 'monthlyRank': 7, 'monthlyPoints': 12,
    });
    expect(s.rank, isNull);
    expect(s.monthlyRank, 7);
  });

  test('history rows parse, including negative deltas and nullable fields', () {
    final xp = HistoryPage.parse({'items': [{'id': '1', 'xp': 10, 'source': 'match_won', 'createdAt': '2026-09-01T00:00:00+00:00'}], 'nextCursor': 'c1'}, XpEvent.fromJson);
    expect(xp.items.single.xp, 10);
    expect(xp.nextCursor, 'c1');
    final sx = HistoryPage.parse({'items': [{'id': '2', 'eventType': 'no_show', 'pointsDelta': -15, 'matchId': null, 'createdAt': 'x'}], 'nextCursor': null}, SxScoreEvent.fromJson);
    expect(sx.items.single.pointsDelta, -15);
    expect(sx.items.single.matchId, isNull);
    expect(sx.nextCursor, isNull);
    final coin = HistoryPage.parse({'items': [{'id': '3', 'amount': -200, 'balanceAfter': 50, 'source': 'post_boost', 'description': null, 'createdAt': 'x'}], 'nextCursor': null}, CoinTransaction.fromJson);
    expect(coin.items.single.amount, -200);
    expect(coin.items.single.description, isNull);
  });
}
