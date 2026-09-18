class Tournament {
  const Tournament({
    required this.id,
    required this.title,
    required this.slug,
    required this.description,
    required this.bannerUrl,
    required this.cardImageUrl,
    required this.status,
    required this.format,
    required this.competitionFormat,
    required this.entryUnit,
    required this.prizePool,
    required this.prizeSecond,
    required this.prizeThird,
    required this.registrationFee,
    required this.maxPlayers,
    required this.registrationStart,
    required this.registrationEnd,
    required this.tournamentStart,
    required this.tournamentEnd,
    required this.rules,
    required this.gameName,
  });

  final String id;
  final String title;
  final String slug;
  final String? description;
  final String? bannerUrl;
  final String? cardImageUrl;
  final String status;
  final String format;
  final String competitionFormat;
  final String entryUnit;
  final int prizePool;
  final int? prizeSecond;
  final int? prizeThird;
  final int registrationFee;
  final int? maxPlayers;
  final DateTime? registrationStart;
  final DateTime? registrationEnd;
  final DateTime? tournamentStart;
  final DateTime? tournamentEnd;
  final String? rules;
  final String gameName;

  factory Tournament.fromJson(Map<String, dynamic> json) {
    final gameJson = json['games'] as Map<String, dynamic>?;
    return Tournament(
      id: json['id'] as String,
      title: json['title'] as String,
      slug: json['slug'] as String,
      description: json['description'] as String?,
      bannerUrl: json['banner_url'] as String?,
      cardImageUrl: json['card_image_url'] as String?,
      status: json['status'] as String,
      format: json['format'] as String,
      competitionFormat: json['competition_format'] as String,
      entryUnit: json['entry_unit'] as String,
      prizePool: json['prize_pool'] as int,
      prizeSecond: json['prize_second'] as int?,
      prizeThird: json['prize_third'] as int?,
      registrationFee: json['registration_fee'] as int,
      maxPlayers: json['max_players'] as int?,
      registrationStart: _parseDate(json['registration_start']),
      registrationEnd: _parseDate(json['registration_end']),
      tournamentStart: _parseDate(json['tournament_start']),
      tournamentEnd: _parseDate(json['tournament_end']),
      rules: json['rules'] as String?,
      gameName: gameJson?['name'] as String? ?? 'Unknown game',
    );
  }

  static DateTime? _parseDate(dynamic value) =>
      value == null ? null : DateTime.parse(value as String);
}
