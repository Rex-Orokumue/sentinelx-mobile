import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/core/api/notifications_models.dart';

Map<String, dynamic> _prefsJson() => {
      'push': {for (final k in kPushPrefKeys) k: true},
      'whatsapp': {for (final k in kWhatsappPrefKeys) k: false},
      'achievementSharing': {for (final k in kSharingPrefKeys) k: true},
    };

void main() {
  test('key lists have 17 / 6 / 5 entries and push has no status_removed', () {
    expect(kPushPrefKeys, hasLength(17));
    expect(kWhatsappPrefKeys, hasLength(6));
    expect(kSharingPrefKeys, hasLength(5));
    expect(kPushPrefKeys, isNot(contains('status_removed')));
  });

  test('NotificationPrefs.fromJson reads all three sections', () {
    final p = NotificationPrefs.fromJson(_prefsJson());
    expect(p.push, hasLength(17));
    expect(p.whatsapp.values.every((v) => !v), isTrue);
    expect(p.achievementSharing['social'], isTrue);
  });

  test('a newer server adding a key, or omitting one, does not break parsing', () {
    final j = _prefsJson();
    (j['push'] as Map<String, dynamic>)['brand_new_key'] = false;
    (j['whatsapp'] as Map<String, dynamic>).remove('match_reminder');
    j.remove('achievementSharing');
    final p = NotificationPrefs.fromJson(j);
    expect(p.push['brand_new_key'], isFalse);
    expect(p.whatsapp.containsKey('match_reminder'), isFalse);
    expect(p.achievementSharing, isEmpty);
  });

  test('withValue changes only that key and returns a new object', () {
    final p = NotificationPrefs.fromJson(_prefsJson());
    final q = p.withValue(PrefSection.push, 'post_reaction', false);
    expect(q.push['post_reaction'], isFalse);
    expect(p.push['post_reaction'], isTrue);
    expect(q.push['post_comment'], isTrue);
    expect(q.whatsapp, p.whatsapp);
  });

  test('PrefSection wire names match the API', () {
    expect(PrefSection.push.wire, 'push');
    expect(PrefSection.whatsapp.wire, 'whatsapp');
    expect(PrefSection.achievementSharing.wire, 'achievementSharing');
  });

  test('NotificationMutes parses timestamps and drops unparseable rows', () {
    final m = NotificationMutes.fromJson({
      'types': [
        {'type': 'post_reaction', 'mutedUntil': '2099-01-01T00:00:00.000Z'},
        {'type': 'bad', 'mutedUntil': 'not a date'},
      ],
      'posts': [
        {'postId': 'p1', 'mutedUntil': '2000-01-01T00:00:00.000Z'},
      ],
    });
    expect(m.types.map((t) => t.type), ['post_reaction']);
    final now = DateTime.utc(2026, 10, 3);
    expect(m.isTypeMuted('post_reaction', now), isTrue);
    expect(m.isTypeMuted('post_comment', now), isFalse);
    expect(m.isPostMuted('p1', now), isFalse, reason: 'a lapsed mute is not a mute');
  });

  test('MuteDuration wire values', () {
    expect(MuteDuration.oneHour.wire, '1h');
    expect(MuteDuration.oneWeek.wire, '1w');
    expect(MuteDuration.always.wire, 'always');
  });
}
