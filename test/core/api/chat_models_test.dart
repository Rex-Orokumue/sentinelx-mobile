import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/core/api/chat_models.dart';

void main() {
  group('parseChatLine', () {
    test('each known event', () {
      expect(parseChatLine('{"t":"status","state":"checking_account"}'), isA<ChatStatus>());
      expect((parseChatLine('{"t":"delta","text":"hi"}') as ChatDelta).text, 'hi');
      expect((parseChatLine('{"t":"done","persisted":true}') as ChatDone).persisted, isTrue);
      expect((parseChatLine('{"t":"error","code":"chat_truncated"}') as ChatError).code, 'chat_truncated');
    });
    test('actions keep only known destinations', () {
      final a = parseChatLine('{"t":"actions","items":["wallet","evil",7,"tournaments"]}') as ChatActions;
      expect(a.items, [ChatDestination.wallet, ChatDestination.tournaments]);
    });
    test('blank, garbage, non-object, unknown t and wrong field types are null, never throw', () {
      for (final l in ['', '  ', 'nope', '[1]', '{"t":"future"}', '{"t":"delta","text":5}', '{"x":1}']) {
        expect(parseChatLine(l), isNull, reason: l);
      }
    });
    test('an error without a string code becomes "internal"', () {
      expect((parseChatLine('{"t":"error"}') as ChatError).code, 'internal');
    });
  });
  group('cleanChatText', () {
    test('strips control and bidi-override characters, keeps newlines, emoji and ZWJ sequences', () {
      expect(cleanChatText('a\u0000b\u202Ec\u2066d\u200Fe'), 'abcde');
      expect(cleanChatText('x\ny\tz'), 'x\ny\tz');
      expect(cleanChatText('👨‍👩‍👧 ok'), '👨‍👩‍👧 ok');
    });
    test('does not interpret markup: it is returned verbatim', () {
      expect(cleanChatText('<b>hi</b> [x](https://evil.example)'), '<b>hi</b> [x](https://evil.example)');
    });
  });
  test('ChatHistoryPage skips bad rows', () {
    final p = ChatHistoryPage.fromJson({'messages': [
      {'id': 'a', 'role': 'user', 'content': 'hi', 'createdAt': '2026-10-05T10:00:00Z'},
      {'id': 'b', 'role': 'system', 'content': 'x', 'createdAt': '2026-10-05T10:00:00Z'},
      {'id': 'c', 'role': 'assistant', 'content': 'x', 'createdAt': 'not a date'},
    ], 'nextBefore': 'cur'});
    expect(p.messages.map((m) => m.id), ['a']);
    expect(p.nextBefore, 'cur');
  });
}
