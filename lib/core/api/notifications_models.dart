// Phase 5a notification wire models (prefs, mutes). Shapes come from the web repo's
// lib/mobile-api/endpoints/notifications.ts. Parsing is deliberately tolerant: a newer server may add
// or omit preference keys, and one bad row must never fail a whole response.

/// The 17 user-toggleable push types. `status_removed` is deliberately absent: it is always delivered.
const kPushPrefKeys = <String>[
  'match_reminder',
  'result_confirmed',
  'achievement_unlocked',
  'challenge_completed',
  'new_announcement',
  'tournament_announced',
  'wager_settled',
  'referral_converted',
  'post_comment',
  'post_reaction',
  'bracket_released',
  'match_assigned',
  'prize_credited',
  'status_from_friend',
  'status_viewed',
  'new_follower',
  'direct_message',
];

const kWhatsappPrefKeys = <String>[
  'match_reminder',
  'result_confirmed',
  'prize_credited',
  'challenge_completed',
  'achievement_unlocked',
  'registration_confirmed',
];

const kSharingPrefKeys = <String>['tournament', 'milestone', 'streak', 'social', 'other'];

enum PrefSection {
  push('push'),
  whatsapp('whatsapp'),
  achievementSharing('achievementSharing');

  const PrefSection(this.wire);
  final String wire;
}

Map<String, bool> _bools(Object? v) {
  if (v is! Map) return const {};
  return {
    for (final e in v.entries)
      if (e.key is String && e.value is bool) e.key as String: e.value as bool,
  };
}

class NotificationPrefs {
  const NotificationPrefs({required this.push, required this.whatsapp, required this.achievementSharing});

  final Map<String, bool> push;
  final Map<String, bool> whatsapp;
  final Map<String, bool> achievementSharing;

  factory NotificationPrefs.fromJson(Map<String, dynamic> j) => NotificationPrefs(
        push: _bools(j['push']),
        whatsapp: _bools(j['whatsapp']),
        achievementSharing: _bools(j['achievementSharing']),
      );

  Map<String, bool> section(PrefSection s) => switch (s) {
        PrefSection.push => push,
        PrefSection.whatsapp => whatsapp,
        PrefSection.achievementSharing => achievementSharing,
      };

  NotificationPrefs withValue(PrefSection s, String key, bool value) {
    Map<String, bool> next(Map<String, bool> m) => {...m, key: value};
    return NotificationPrefs(
      push: s == PrefSection.push ? next(push) : push,
      whatsapp: s == PrefSection.whatsapp ? next(whatsapp) : whatsapp,
      achievementSharing: s == PrefSection.achievementSharing ? next(achievementSharing) : achievementSharing,
    );
  }
}

class MutedType {
  const MutedType(this.type, this.mutedUntil);
  final String type;
  final DateTime mutedUntil;
}

class MutedPost {
  const MutedPost(this.postId, this.mutedUntil);
  final String postId;
  final DateTime mutedUntil;
}

class NotificationMutes {
  const NotificationMutes({required this.types, required this.posts});

  final List<MutedType> types;
  final List<MutedPost> posts;

  static const empty = NotificationMutes(types: [], posts: []);

  factory NotificationMutes.fromJson(Map<String, dynamic> j) {
    final types = <MutedType>[];
    final posts = <MutedPost>[];
    for (final r in (j['types'] as List<dynamic>? ?? const [])) {
      if (r is! Map) continue;
      final until = DateTime.tryParse('${r['mutedUntil']}');
      final type = r['type'];
      if (until != null && type is String) types.add(MutedType(type, until));
    }
    for (final r in (j['posts'] as List<dynamic>? ?? const [])) {
      if (r is! Map) continue;
      final until = DateTime.tryParse('${r['mutedUntil']}');
      final id = r['postId'];
      if (until != null && id is String) posts.add(MutedPost(id, until));
    }
    return NotificationMutes(types: types, posts: posts);
  }

  bool isTypeMuted(String type, DateTime now) => types.any((t) => t.type == type && t.mutedUntil.isAfter(now));
  bool isPostMuted(String postId, DateTime now) => posts.any((p) => p.postId == postId && p.mutedUntil.isAfter(now));
}

enum MuteDuration {
  oneHour('1h'),
  oneWeek('1w'),
  always('always');

  const MuteDuration(this.wire);
  final String wire;
}
