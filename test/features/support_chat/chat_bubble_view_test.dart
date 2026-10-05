import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/features/support_chat/chat_bubble_view.dart';

void main() {
// test/features/support_chat/chat_bubble_view_test.dart
testWidgets('renders markup, links and bidi characters literally as one plain selectable text with no tap handlers', (tester) async {
  const raw = '<b>hi</b> [x](https://evil.example) a\u202Eb';
  await tester.pumpWidget(const MaterialApp(home: Scaffold(body: ChatBubbleView(text: raw, fromUser: false))));
  expect(find.byType(SelectableText), findsOneWidget);
  final st = tester.widget<SelectableText>(find.byType(SelectableText));
  expect(st.data, '<b>hi</b> [x](https://evil.example) ab'); // the widget strips unsafe characters itself too
  expect(st.textSpan, isNull);                                // no parsed spans
  expect(st.onTap, isNull);
});
}
