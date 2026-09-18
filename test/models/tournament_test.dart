import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/models/tournament.dart';

void main() {
  group('Tournament.fromJson', () {
    test('parses a fully populated row with an embedded game name', () {
      final json = {
        'id': '88a63aee-bd27-4fa7-b517-469df2ca8adf',
        'title': 'FC Mobile Premier League — Season 2',
        'slug': 'fc-mobile-premier-league-season-2',
        'description': 'The second season of the FC Mobile Premier League.',
        'banner_url': 'https://example.com/banner.png',
        'card_image_url': 'https://example.com/card.png',
        'status': 'active',
        'format': 'group_knockout',
        'competition_format': 'head_to_head',
        'entry_unit': 'solo',
        'prize_pool': 50000,
        'prize_second': 20000,
        'prize_third': 10000,
        'registration_fee': 500,
        'max_players': 32,
        'registration_start': '2026-09-01T00:00:00+00:00',
        'registration_end': '2026-09-10T00:00:00+00:00',
        'tournament_start': '2026-09-11T00:00:00+00:00',
        'tournament_end': null,
        'rules': 'Standard rules apply.',
        'games': {'name': 'EA FC Mobile'},
      };

      final tournament = Tournament.fromJson(json);

      expect(tournament.id, '88a63aee-bd27-4fa7-b517-469df2ca8adf');
      expect(tournament.title, 'FC Mobile Premier League — Season 2');
      expect(tournament.status, 'active');
      expect(tournament.entryUnit, 'solo');
      expect(tournament.prizePool, 50000);
      expect(tournament.maxPlayers, 32);
      expect(tournament.tournamentStart, DateTime.parse('2026-09-11T00:00:00+00:00'));
      expect(tournament.tournamentEnd, isNull);
      expect(tournament.gameName, 'EA FC Mobile');
    });

    test('falls back to "Unknown game" when the games embed is missing', () {
      final json = {
        'id': 'e04f3194-75f2-4c03-92c9-eadffcdd5c00',
        'title': 'DRY RUN — Clash Squad 2v2',
        'slug': 'dry-run-clash-squad-2v2-team-test',
        'description': null,
        'banner_url': null,
        'card_image_url': null,
        'status': 'completed',
        'format': 'group_knockout',
        'competition_format': 'head_to_head',
        'entry_unit': 'squad',
        'prize_pool': 0,
        'prize_second': null,
        'prize_third': null,
        'registration_fee': 500,
        'max_players': null,
        'registration_start': null,
        'registration_end': null,
        'tournament_start': null,
        'tournament_end': null,
        'rules': null,
        'games': null,
      };

      final tournament = Tournament.fromJson(json);

      expect(tournament.gameName, 'Unknown game');
      expect(tournament.tournamentStart, isNull);
    });
  });
}
