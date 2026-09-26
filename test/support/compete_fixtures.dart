Map<String, dynamic> tournamentRow({
  String id = 't1',
  String title = 'FC Mobile Cup',
  String status = 'registration_open',
  int registrationFee = 500,
  int? maxPlayers = 16,
  Object? games = const {'name': 'FC Mobile', 'slug': 'fc-mobile'},
  String? rules = 'Be nice.',
  bool invitationOnly = false,
  String? description,
}) =>
    {
      'id': id, 'title': title, 'slug': 'fc-mobile-cup', 'description': description, 'banner_url': null, 'card_image_url': null,
      'status': status, 'format': 'knockout', 'competition_format': 'knockout', 'prize_pool': 8000,
      'prize_second': null, 'prize_third': null, 'registration_fee': registrationFee, 'max_players': maxPlayers,
      'registration_start': null, 'registration_end': '2026-10-01T10:00:00Z', 'tournament_start': null,
      'tournament_end': null, 'rules': rules, 'invitation_only': invitationOnly, 'games': games,
    };
