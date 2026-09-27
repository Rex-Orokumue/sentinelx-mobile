import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/core/api/match_models.dart';

import '../support/match_fixtures.dart';

void main() {
  test('BracketView parses standings, fixture buckets, rounds, projected and flags', () {
    final b = BracketView.fromJson(bracketJson());
    expect(b.standings.single.groupName, 'Group A');
    expect(b.standings.single.rows[0].rank, 1);
    expect(b.standings.single.rows[0].advancing, isTrue);
    expect(b.standings.single.rows[0].clubName, 'FC Ada');
    expect(b.standings.single.rows[1].clubName, isNull);
    expect(b.fixtures.live.single.id, 'live1');
    expect(b.fixtures.upcoming.single.id, 'up1');
    expect(b.fixtures.completed.single.scoreA, 2);
    expect(b.fixtures.disputedOrCancelled, isEmpty);
    expect(b.rounds.single.label, 'Semi-finals');
    expect(b.rounds.single.matches.single.round, 'semi_final');
    expect(b.projected.single.matchCount, 1);
    expect(b.hasGroups, isTrue);
    expect(b.hasKnockout, isTrue);
  });

  test('a bye / unplayed fixture has null scores', () {
    final f = BracketFixture.fromJson(fixtureJson(status: 'bye', scheduledAt: null));
    expect(f.scoreA, isNull);
    expect(f.scoreB, isNull);
    expect(f.scheduledAt, isNull);
    expect(f.playerA.name, 'Ada');
  });

  test('null champion / thirdPlace / thirdPlaceMatch parse to nulls; a set champion parses', () {
    final none = BracketView.fromJson(bracketJson());
    expect(none.champion, isNull);
    expect(none.thirdPlace, isNull);
    expect(none.thirdPlaceMatch, isNull);
    final json = bracketJson(champion: {'id': 'p1', 'name': 'Ada'})
      ..['thirdPlace'] = {'id': 'p3', 'name': 'Chi'}
      ..['thirdPlaceMatch'] = fixtureJson(id: 'tp');
    final set = BracketView.fromJson(json);
    expect(set.champion!.name, 'Ada');
    expect(set.thirdPlace!.id, 'p3');
    expect(set.thirdPlaceMatch!.id, 'tp');
  });

  test('PointsStandingRow with null bestPlacement and an unresolved tie', () {
    final r = PointsStandingRow.fromJson({
      'entrantId': 'e1',
      'displayName': 'Ada',
      'played': 2,
      'totalPoints': 30,
      'totalKills': 5,
      'bestPlacement': null,
      'lastRoundPlacement': 3,
      'rank': 1,
      'advancing': false,
      'unresolvedTieWith': ['e2'],
    });
    expect(r.bestPlacement, isNull);
    expect(r.lastRoundPlacement, 3);
    expect(r.unresolvedTieWith, ['e2']);
  });

  test('TournamentResults: no winner, and a full champion entry', () {
    final none = TournamentResults.fromJson({'champion': null, 'noWinner': true});
    expect(none.champion, isNull);
    expect(none.noWinner, isTrue);
    final full = TournamentResults.fromJson({
      'champion': {
        'tournamentId': 't1',
        'slug': 'cup',
        'title': 'Cup',
        'tournamentType': 'open',
        'gameId': 'g1',
        'gameName': 'eFootball',
        'date': '2026-10-01',
        'prizePool': 5000,
        'champion': {'id': 'p1', 'name': 'Ada'},
        'runnerUp': {'id': 'p2', 'name': 'Bola'},
        'championAvatarUrl': 'https://x/a.png',
        'seasonName': 'S1',
      },
      'noWinner': false,
    });
    expect(full.champion!.champion.name, 'Ada');
    expect(full.champion!.runnerUp!.name, 'Bola');
    expect(full.champion!.prizePool, 5000);
    final sparse = ChampionEntry.fromJson({
      'tournamentId': 't1',
      'slug': 'cup',
      'title': 'Cup',
      'tournamentType': 'open',
      'gameId': 'g1',
      'gameName': 'eFootball',
      'date': null,
      'prizePool': null,
      'champion': {'id': 'p1', 'name': 'Ada'},
      'runnerUp': null,
      'championAvatarUrl': null,
      'seasonName': null,
    });
    expect(sparse.runnerUp, isNull);
    expect(sparse.date, isNull);
    expect(sparse.prizePool, isNull);
    expect(sparse.championAvatarUrl, isNull);
    expect(sparse.seasonName, isNull);
  });

  test('MatchCentre maps verdicts, flattens pools, nullable pick; unknown verdict throws', () {
    final c = MatchCentre.fromJson(centreJson(isParticipant: true, canCheckIn: true, verdict: 'one', checkedIn: ['p1']));
    expect(c.checkInVerdict, CheckInVerdict.one);
    expect(c.checkedInPlayerIds, ['p1']);
    expect(c.isParticipant, isTrue);
    expect(c.wager.poolA, 300);
    expect(c.wager.poolB, 200);
    expect(c.wager.feeRate, 0.1);
    expect(c.wager.myPickPlayerId, isNull);
    expect(c.wager.myStakeCoins, isNull);
    expect(c.wager.estimatedPayoutIfIStakeA100, 166.5);
    expect(MatchCentre.fromJson(centreJson(verdict: 'both')).checkInVerdict, CheckInVerdict.both);
    expect(MatchCentre.fromJson(centreJson(verdict: 'none')).checkInVerdict, CheckInVerdict.none);
    expect(() => MatchCentre.fromJson(centreJson(verdict: 'weird')), throwsFormatException);
  });

  test('MeSummary parses null nextMatch, both banner kinds; unknown kind throws', () {
    final s = MeSummary.fromJson(summaryJson(banners: [
      {'kind': 'qualified', 'tournamentTitle': 'Cup', 'tournamentSlug': 'cup', 'round': 'semi_final', 'awaitingOpponent': true},
      {'kind': 'eliminated', 'tournamentTitle': 'Cup', 'tournamentSlug': 'cup', 'round': 'quarter_final'},
    ], registrations: [
      {'id': 'r1', 'paymentStatus': 'pending', 'tournamentTitle': 'Cup', 'tournamentSlug': 'cup'},
    ]));
    expect(s.nextMatch, isNull);
    expect(s.nextLobby, isNull);
    expect(s.banners[0].kind, BannerKind.qualified);
    expect(s.banners[0].awaitingOpponent, isTrue);
    expect(s.banners[1].kind, BannerKind.eliminated);
    expect(s.banners[1].awaitingOpponent, isFalse);
    expect(s.registrations.single.paymentStatus, 'pending');
    final full = MeSummary.fromJson(summaryJson(nextMatch: nextMatchJson(), nextLobby: nextLobbyJson(), hasSubmittableMatch: true));
    expect(full.nextMatch!.tournamentTitle, 'Champions Cup');
    expect(full.nextLobby!.roundNo, 2);
    expect(full.nextLobby!.scheduledAt, isNull);
    expect(full.hasSubmittableMatch, isTrue);
    expect(
      () => MeSummary.fromJson(summaryJson(banners: [
        {'kind': 'mystery', 'tournamentTitle': 'x', 'tournamentSlug': 'x', 'round': 'x'},
      ])),
      throwsFormatException,
    );
  });

  test('CreatedSquad and SquadPreview parse', () {
    final c = CreatedSquad.fromJson({'squadId': 's1', 'inviteCode': 'ABC123'});
    expect(c.squadId, 's1');
    expect(c.inviteCode, 'ABC123');
    final p = SquadPreview.fromJson({'id': 's1', 'name': 'Lions', 'memberCount': 2, 'teamSize': 4});
    expect(p.name, 'Lions');
    expect(p.teamSize, 4);
  });
}
