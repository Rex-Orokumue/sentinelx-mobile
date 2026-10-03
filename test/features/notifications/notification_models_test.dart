import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/features/notifications/notification_models.dart';

Map<String, dynamic> _row({Object? id = 'n1', Object? type = 'match_assigned', Object? title = 'T', Object? body = 'B', Object? link = '/matches/m1', Object? read = false, Object? createdAt = '2026-10-03T10:00:00.000Z'}) =>
    {'id': id, 'type': type, 'title': title, 'body': body, 'link': link, 'read': read, 'created_at': createdAt};

const _post = '3f2b8c1e-9d4a-4b7e-8a61-5c0d2e7f9a10';

void main() {
  group('BellNotification.tryParse is tolerant (Review Focus 2)', () {
    test('a full row', () {
      final n = BellNotification.tryParse(_row())!;
      expect(n.id, 'n1');
      expect(n.type, 'match_assigned');
      expect(n.title, 'T');
      expect(n.body, 'B');
      expect(n.link, '/matches/m1');
      expect(n.read, isFalse);
      expect(n.createdAt, DateTime.utc(2026, 10, 3, 10));
    });

    test('an unknown type is kept verbatim', () {
      expect(BellNotification.tryParse(_row(type: 'something_new'))!.type, 'something_new');
    });

    test('null or odd title/body become empty strings', () {
      final n = BellNotification.tryParse(_row(title: null, body: 5))!;
      expect(n.title, '');
      expect(n.body, '');
    });

    test('a row without an id cannot be acted on and is dropped', () {
      expect(BellNotification.tryParse(_row(id: null)), isNull);
      expect(BellNotification.tryParse(_row(id: '')), isNull);
    });

    test('a bad or missing created_at falls back to the epoch instead of throwing', () {
      expect(BellNotification.tryParse(_row(createdAt: 'garbage'))!.createdAt, DateTime.fromMillisecondsSinceEpoch(0, isUtc: true));
      expect(BellNotification.tryParse(_row(createdAt: null))!.createdAt, DateTime.fromMillisecondsSinceEpoch(0, isUtc: true));
    });

    test('a non-bool read means unread; a non-string link means no link', () {
      expect(BellNotification.tryParse(_row(read: 'true'))!.read, isFalse);
      expect(BellNotification.tryParse(_row(link: 7))!.link, isNull);
      expect(BellNotification.tryParse(_row(link: '  '))!.link, isNull);
    });

    test('copyWith changes only read', () {
      final n = BellNotification.tryParse(_row())!;
      final r = n.copyWith(read: true);
      expect(r.read, isTrue);
      expect(r.id, n.id);
      expect(r.title, n.title);
    });
  });

  group('postId', () {
    test('is the uuid of a community post link, with or without host and locale', () {
      expect(BellNotification.tryParse(_row(link: '/community/$_post'))!.postId, _post);
      expect(BellNotification.tryParse(_row(link: 'https://sentinelxesports.com.ng/fr/community/$_post'))!.postId, _post);
    });

    test('is null for everything else', () {
      for (final link in ['/community/compose', '/matches/x', '/community', null, 'not a url at all', '/community/$_post/extra']) {
        expect(BellNotification.tryParse(_row(link: link))!.postId, isNull, reason: '$link');
      }
    });
  });

  group('typeMutable', () {
    test('only the 17 user-toggleable push types can be muted', () {
      expect(BellNotification.tryParse(_row(type: 'post_reaction'))!.typeMutable, isTrue);
      expect(BellNotification.tryParse(_row(type: 'direct_message'))!.typeMutable, isTrue);
      expect(BellNotification.tryParse(_row(type: 'status_removed'))!.typeMutable, isFalse);
      expect(BellNotification.tryParse(_row(type: 'something_new'))!.typeMutable, isFalse);
    });
  });
}
