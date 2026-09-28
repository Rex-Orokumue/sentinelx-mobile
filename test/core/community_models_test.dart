import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/core/api/community_models.dart';

import '../support/community_fixtures.dart';

void main() {
  test('PostView.fromJson round-trips every field for a text-only post', () {
    final json = postViewJson(
      id: 'p1',
      postType: 'achievement',
      content: 'GG',
      isPinned: true,
      boostedUntil: '2026-10-01T00:00:00Z',
      canDelete: false,
      canBoost: false,
      myReaction: 'crown',
      commentCount: 4,
    );
    final post = PostView.fromJson(json);
    expect(post.id, 'p1');
    expect(post.postType, PostType.achievement);
    expect(post.content, 'GG');
    expect(post.imageUrl, isNull);
    expect(post.imageUrls, isEmpty);
    expect(post.referenceId, isNull);
    expect(post.isPinned, isTrue);
    expect(post.boostedUntil, '2026-10-01T00:00:00Z');
    expect(post.createdAt, '2026-09-28T12:00:00Z');
    expect(post.author.id, 'u1');
    expect(post.author.membershipTier, 'free');
    expect(post.canDelete, isFalse);
    expect(post.canBoost, isFalse);
    expect(post.reactionCounts.total, 0);
    expect(post.myReaction, ReactionType.crown);
    expect(post.commentCount, 4);
    expect(post.matchResult, isNull);
    expect(post.mutedByViewer, isFalse);

    // Same round trip, but a match_result post carrying a non-null matchResult and imageUrls.
    final withMatch = PostView.fromJson(postViewJson(
      postType: 'match_result',
      imageUrl: 'https://x/a.png',
      imageUrls: const ['https://x/a.png', 'https://x/b.png'],
      referenceId: 'ref-1',
      matchResult: matchResultDetailJson(),
    ));
    expect(withMatch.postType, PostType.matchResult);
    expect(withMatch.imageUrl, 'https://x/a.png');
    expect(withMatch.imageUrls, ['https://x/a.png', 'https://x/b.png']);
    expect(withMatch.referenceId, 'ref-1');
    expect(withMatch.matchResult, isNotNull);
    expect(withMatch.matchResult!.matchId, 'm1');
    expect(withMatch.matchResult!.tournamentTitle, 'Champions Cup');
    expect(withMatch.matchResult!.roundLabel, 'Final');
    expect(withMatch.matchResult!.scoreA, 2);
    expect(withMatch.matchResult!.scoreB, 1);
    expect(withMatch.matchResult!.playerA!.username, 'ada');
    expect(withMatch.matchResult!.playerB!.username, 'bola');
  });

  test('postType parses all four wire values and throws on unknown', () {
    expect(postTypeFromJson('manual'), PostType.manual);
    expect(postTypeFromJson('match_result'), PostType.matchResult);
    expect(postTypeFromJson('achievement'), PostType.achievement);
    expect(postTypeFromJson('announcement'), PostType.announcement);
    expect(() => postTypeFromJson('bogus'), throwsFormatException);
  });

  test('reactionTypeFromJson parses all four values and throws on unknown', () {
    expect(reactionTypeFromJson('fire'), ReactionType.fire);
    expect(reactionTypeFromJson('crown'), ReactionType.crown);
    expect(reactionTypeFromJson('strong'), ReactionType.strong);
    expect(reactionTypeFromJson('wow'), ReactionType.wow);
    expect(() => reactionTypeFromJson('bogus'), throwsFormatException);
  });

  test('ReactionCounts.increment/decrement change only the targeted field, and [] reads it', () {
    const counts = ReactionCounts(fire: 1, crown: 2, strong: 3, wow: 4);

    final incremented = counts.increment(ReactionType.crown);
    expect(incremented.fire, 1);
    expect(incremented.crown, 3);
    expect(incremented.strong, 3);
    expect(incremented.wow, 4);

    final decremented = counts.decrement(ReactionType.wow);
    expect(decremented.fire, 1);
    expect(decremented.crown, 2);
    expect(decremented.strong, 3);
    expect(decremented.wow, 3);

    expect(counts[ReactionType.fire], 1);
    expect(counts[ReactionType.crown], 2);
    expect(counts[ReactionType.strong], 3);
    expect(counts[ReactionType.wow], 4);
    expect(counts.total, 10);
  });

  test('CommunityFeedPage.fromJson parses non-empty pinned posts and hasMore: true', () {
    final json = feedPageJson(
      pinned: [postViewJson(id: 'pin1', isPinned: true)],
      posts: [postViewJson(id: 'p2'), postViewJson(id: 'p3')],
      hasMore: true,
    );
    final page = CommunityFeedPage.fromJson(json);
    expect(page.pinned, hasLength(1));
    expect(page.pinned.single.id, 'pin1');
    expect(page.pinned.single.isPinned, isTrue);
    expect(page.posts.map((p) => p.id), ['p2', 'p3']);
    expect(page.hasMore, isTrue);
  });

  test('ChallengesWidget.fromJson and BestPlayBanner.fromJson parse a real object', () {
    final challenges = ChallengesWidget.fromJson(challengesJson());
    expect(challenges.weekLabel, 'Week 39');
    expect(challenges.challenges, hasLength(1));
    expect(challenges.challenges.single.slug, 'react-5');
    expect(challenges.challenges.single.goal, 5);
    expect(challenges.challenges.single.completed, isFalse);

    final bestPlay = BestPlayBanner.fromJson(bestPlayJson());
    expect(bestPlay.nominations, hasLength(1));
    expect(bestPlay.nominations.single.nominationId, 'n1');
    expect(bestPlay.nominations.single.voteCount, 3);
    expect(bestPlay.myVoteNominationId, isNull);

    final bestPlayWithVote = BestPlayBanner.fromJson(bestPlayJson(myVoteNominationId: 'n1'));
    expect(bestPlayWithVote.myVoteNominationId, 'n1');
  });

  test('StatusRing.fromJson parses an empty statuses list and hasUnseen: false', () {
    final json = statusRingJson(statuses: const [], hasUnseen: false);
    final ring = StatusRing.fromJson(json);
    expect(ring.playerId, 'u1');
    expect(ring.statuses, isEmpty);
    expect(ring.hasUnseen, isFalse);
    expect(ring.isSelf, isFalse);
  });

  test('CommunityGalleryPage.fromJson and CommunityStats.fromJson parse', () {
    final gallery = CommunityGalleryPage.fromJson(galleryPageJson(hasMore: true));
    expect(gallery.items, hasLength(1));
    expect(gallery.items.single.id, 'g1');
    expect(gallery.hasMore, isTrue);

    final stats = CommunityStats.fromJson(communityStatsJson(memberCount: 500, countryCount: 12, tournamentCount: 30));
    expect(stats.memberCount, 500);
    expect(stats.countryCount, 12);
    expect(stats.tournamentCount, 30);
  });

  test('ReportReasonCode.wireName matches the spec wire strings exactly', () {
    expect(ReportReasonCode.spam.wireName, 'spam');
    expect(ReportReasonCode.harassment.wireName, 'harassment');
    expect(ReportReasonCode.hateSpeech.wireName, 'hate_speech');
    expect(ReportReasonCode.nudityOrSexualContent.wireName, 'nudity_or_sexual_content');
    expect(ReportReasonCode.violence.wireName, 'violence');
    expect(ReportReasonCode.misinformation.wireName, 'misinformation');
    expect(ReportReasonCode.other.wireName, 'other');
  });
}
