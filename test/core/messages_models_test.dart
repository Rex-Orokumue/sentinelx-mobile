import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/core/api/messages_models.dart';

Map<String, dynamic> _other({String? username = 'rex', String? avatar = 'https://x/a.png', String name = 'Rex'}) =>
    {'id': 'p1', 'name': name, 'username': username, 'avatarUrl': avatar};

Map<String, dynamic> _thread({
  String id = 't1',
  Map<String, dynamic>? preview,
  String requestState = 'accepted',
  Object? direction,
  Object? other,
}) =>
    {
      'threadId': id,
      'other': other ?? _other(),
      'preview': preview ?? {'kind': 'text', 'text': 'hi', 'stickerId': null},
      'lastMessageAt': '2026-10-05T10:00:00.000Z',
      'unread': 2,
      'requestState': requestState,
      'direction': direction,
    };

Map<String, dynamic> _msg({String id = 'm1', Map<String, dynamic>? over}) => {
      'id': id,
      'senderId': 'me',
      'body': null,
      'imageUrl': null,
      'stickerId': null,
      'audioUrl': null,
      'audioDurationSeconds': null,
      'forwarded': false,
      'createdAt': '2026-10-05T10:00:00.000Z',
      'deliveredAt': null,
      'readAt': null,
      'editedAt': null,
      'deletedAt': null,
      'replyTo': null,
      ...?over,
    };

void main() {
  group('threads', () {
    test('parses a full row', () {
      final t = ThreadSummary.tryParse(_thread())!;
      expect(t.threadId, 't1');
      expect(t.other.username, 'rex');
      expect(t.preview.kind, PreviewKind.text);
      expect(t.preview.text, 'hi');
      expect(t.unread, 2);
      expect(t.requestState, RequestState.accepted);
      expect(t.direction, isNull);
      expect(t.lastMessageAt.toUtc(), DateTime.utc(2026, 10, 5, 10));
    });

    test('unknown preview.kind degrades to unknown', () {
      final t = ThreadSummary.tryParse(_thread(preview: {'kind': 'poll', 'text': null, 'stickerId': null}))!;
      expect(t.preview.kind, PreviewKind.unknown);
    });

    test('every known preview kind parses', () {
      for (final e in {
        'text': PreviewKind.text,
        'image': PreviewKind.image,
        'sticker': PreviewKind.sticker,
        'voice': PreviewKind.voice,
        'removed': PreviewKind.removed,
      }.entries) {
        expect(parsePreviewKind(e.key), e.value);
      }
      expect(parsePreviewKind(null), PreviewKind.unknown);
    });

    test('unknown requestState and direction degrade and the list survives', () {
      final page = ThreadsPage.fromJson({
        'threads': [
          _thread(id: 'a', requestState: 'quantum', direction: 'sideways'),
          _thread(id: 'b', requestState: 'pending', direction: 'incoming'),
        ],
        'nextCursor': 'c1',
        'requestCount': 3,
      });
      expect(page.threads.map((t) => t.threadId), ['a', 'b']);
      expect(page.threads[0].requestState, RequestState.unknown);
      expect(page.threads[0].direction, isNull);
      expect(page.threads[1].requestState, RequestState.pending);
      expect(page.threads[1].direction, RequestDirection.incoming);
      expect(page.nextCursor, 'c1');
      expect(page.requestCount, 3);
    });

    test('a malformed row is skipped, the rest kept', () {
      final bad = _thread()..remove('threadId');
      final page = ThreadsPage.fromJson({
        'threads': [bad, 'junk', _thread(id: 'ok')],
        'nextCursor': null,
        'requestCount': 0,
      });
      expect(page.threads.map((t) => t.threadId), ['ok']);
      expect(page.nextCursor, isNull);
    });

    test('a bad lastMessageAt still lists the thread (epoch)', () {
      final row = _thread()..['lastMessageAt'] = 'nope';
      final t = ThreadSummary.tryParse(row)!;
      expect(t.lastMessageAt.millisecondsSinceEpoch, 0);
    });

    test('null username and avatar fall back for displayName', () {
      final t = ThreadSummary.tryParse(_thread(other: _other(username: null, avatar: null, name: '  ')))!;
      expect(t.other.avatarUrl, isNull);
      expect(t.other.displayName, '?');
      final u = OtherPlayer(id: 'x', name: '', username: 'zed');
      expect(u.displayName, 'zed');
      expect(const OtherPlayer(id: 'x', name: 'Ann').displayName, 'Ann');
    });
  });

  group('header', () {
    ThreadHeader header({bool me = false, bool them = false, String state = 'accepted'}) => ThreadHeader.fromJson({
          'threadId': 't1',
          'other': _other(),
          'blockedByMe': me,
          'blockedByThem': them,
          'requestState': state,
          'direction': null,
        });

    test('canSend truth table', () {
      expect(header().canSend, isTrue);
      expect(header(me: true).canSend, isFalse);
      expect(header(them: true).canSend, isFalse);
      expect(header(state: 'declined').canSend, isFalse);
      expect(header(state: 'pending').canSend, isTrue);
      expect(header(state: 'weird').canSend, isTrue);
      expect(header(them: true).iAmBlocked, isTrue);
    });

    test('unknown direction is null', () {
      final h = ThreadHeader.fromJson({
        'threadId': 't',
        'other': _other(),
        'blockedByMe': false,
        'blockedByThem': false,
        'requestState': 'pending',
        'direction': 'diagonal',
      });
      expect(h.direction, isNull);
      expect(h.requestState, RequestState.pending);
    });
  });

  group('messages', () {
    test('each kind', () {
      expect(DmMessage.tryParse(_msg(over: {'body': 'yo'}))!.kind, MessageKind.text);
      expect(DmMessage.tryParse(_msg(over: {'imageUrl': 'https://x/i.jpg'}))!.kind, MessageKind.image);
      expect(DmMessage.tryParse(_msg(over: {'stickerId': 'gg'}))!.kind, MessageKind.sticker);
      expect(DmMessage.tryParse(_msg(over: {'audioUrl': 'https://x/a.m4a', 'audioDurationSeconds': 4}))!.kind,
          MessageKind.voice);
    });

    test('audio wins over image over sticker over text', () {
      final m = DmMessage.tryParse(_msg(over: {
        'body': 'b',
        'stickerId': 'gg',
        'imageUrl': 'i',
        'audioUrl': 'a',
      }))!;
      expect(m.kind, MessageKind.voice);
      expect(DmMessage.tryParse(_msg(over: {'body': 'b', 'stickerId': 'gg', 'imageUrl': 'i'}))!.kind,
          MessageKind.image);
      expect(DmMessage.tryParse(_msg(over: {'body': 'b', 'stickerId': 'gg'}))!.kind, MessageKind.sticker);
    });

    test('audioDurationSeconds accepts int and double, rounds, min 1', () {
      expect(DmMessage.tryParse(_msg(over: {'audioUrl': 'a', 'audioDurationSeconds': 12.0}))!.audioDurationSeconds, 12);
      expect(DmMessage.tryParse(_msg(over: {'audioUrl': 'a', 'audioDurationSeconds': 12}))!.audioDurationSeconds, 12);
      expect(DmMessage.tryParse(_msg(over: {'audioUrl': 'a', 'audioDurationSeconds': 0.2}))!.audioDurationSeconds, 1);
      expect(DmMessage.tryParse(_msg())!.audioDurationSeconds, isNull);
    });

    test('unsent message (all content null, deletedAt set) is removed', () {
      final m = DmMessage.tryParse(_msg(over: {'deletedAt': '2026-10-05T10:01:00.000Z'}))!;
      expect(m.kind, MessageKind.removed);
      expect(m.deletedAt, isNotNull);
    });

    test('deletedAt wins over a stale body', () {
      final m = DmMessage.tryParse(_msg(over: {'body': 'stale', 'deletedAt': '2026-10-05T10:01:00.000Z'}))!;
      expect(m.kind, MessageKind.removed);
    });

    test('no content and not deleted is unknown', () {
      expect(DmMessage.tryParse(_msg())!.kind, MessageKind.unknown);
    });

    test('replyTo variants', () {
      expect(DmMessage.tryParse(_msg(over: {'body': 'x'}))!.replyTo, isNull);
      final removed = DmMessage.tryParse(_msg(over: {
        'body': 'x',
        'replyTo': {'id': 'r', 'senderName': 'Ann', 'body': null, 'removed': true},
      }))!;
      expect(removed.replyTo!.removed, isTrue);
      final nameless = DmMessage.tryParse(_msg(over: {
        'body': 'x',
        'replyTo': {'id': 'r', 'senderName': null, 'body': 'hey', 'removed': false},
      }))!;
      expect(nameless.replyTo!.senderName, isNull);
      expect(nameless.replyTo!.body, 'hey');
    });

    test('isMine, isEdited, forwarded, receipts', () {
      final m = DmMessage.tryParse(_msg(over: {
        'body': 'x',
        'forwarded': true,
        'editedAt': '2026-10-05T10:02:00.000Z',
        'deliveredAt': '2026-10-05T10:00:05.000Z',
        'readAt': '2026-10-05T10:00:09.000Z',
      }))!;
      expect(m.isMine('me'), isTrue);
      expect(m.isMine('other'), isFalse);
      expect(m.isEdited, isTrue);
      expect(m.forwarded, isTrue);
      expect(m.deliveredAt, isNotNull);
      expect(m.readAt, isNotNull);
    });

    test('a bad createdAt or missing id makes the row malformed', () {
      expect(DmMessage.tryParse(_msg(over: {'createdAt': 'nope'})), isNull);
      expect(DmMessage.tryParse(_msg()..remove('id')), isNull);
      expect(DmMessage.tryParse('junk'), isNull);
    });

    test('MessagesPage skips bad rows and keeps nextBefore', () {
      final page = MessagesPage.fromJson({
        'messages': [_msg(id: 'a', over: {'body': 'x'}), 7, _msg(id: 'b', over: {'body': 'y'})],
        'nextBefore': 'cur',
      });
      expect(page.messages.map((m) => m.id), ['a', 'b']);
      expect(page.nextBefore, 'cur');
    });
  });
}
