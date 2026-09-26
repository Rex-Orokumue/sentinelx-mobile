import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/features/compete/compete_models.dart';

import '../../support/compete_fixtures.dart';

void main() {
  test('CompeteTournament parses a full row', () {
    final t = CompeteTournament.fromJson(tournamentRow());
    expect(t.title, 'FC Mobile Cup');
    expect(t.gameName, 'FC Mobile');
    expect(t.gameSlug, 'fc-mobile');
    expect(t.registrationEnd, DateTime.utc(2026, 10, 1, 10));
    expect(t.rules, 'Be nice.');
    expect(t.invitationOnly, isFalse);
  });

  test('tolerates a null games join, null max_players and null rules', () {
    final t = CompeteTournament.fromJson(tournamentRow(games: null, maxPlayers: null, rules: null));
    expect(t.gameName, isNull);
    expect(t.maxPlayers, isNull);
    expect(t.rules, isNull);
  });

  test('a games join returned as a one-element list is accepted', () {
    final t = CompeteTournament.fromJson(tournamentRow(games: [
      {'name': 'FC Mobile', 'slug': 'fc-mobile'}
    ]));
    expect(t.gameSlug, 'fc-mobile');
  });

  test('GameSummary and PendingInvitation parse', () {
    final g = GameSummary.fromJson({'id': 'g1', 'name': 'DLS', 'slug': 'dls', 'icon_url': null});
    expect(g.slug, 'dls');
    final i = PendingInvitation.fromJson({
      'id': 'i1', 'tournament_id': 't1', 'expires_at': '2026-10-05T00:00:00Z',
      'tournament': {'title': 'Masters', 'registration_fee': 1000},
    });
    expect(i.tournamentTitle, 'Masters');
    expect(i.registrationFee, 1000);
    final i2 = PendingInvitation.fromJson({
      'id': 'i2', 'tournament_id': 't2', 'expires_at': '2026-10-05T00:00:00Z',
      'tournament': [
        {'title': 'Masters 2', 'registration_fee': 0}
      ],
    });
    expect(i2.tournamentTitle, 'Masters 2');
  });
}
