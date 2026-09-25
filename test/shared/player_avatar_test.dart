import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/shared/widgets/player_avatar.dart';

void main() {
  testWidgets('deleted accounts show a neutral placeholder, never a network image', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: PlayerAvatar(avatarUrl: 'https://x/a.png', isDeleted: true))));
    expect(find.byKey(const Key('avatar-placeholder')), findsOneWidget);
    expect(find.byType(Image), findsNothing);
  });

  testWidgets('missing avatar url falls back to the placeholder', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: PlayerAvatar(avatarUrl: null))));
    expect(find.byKey(const Key('avatar-placeholder')), findsOneWidget);
  });

  test('resolveAsset resolves site-relative paths, passes absolute urls through and keeps null', () {
    expect(resolveAsset('/x.webp', 'https://s.test'), 'https://s.test/x.webp');
    expect(resolveAsset('https://cdn.test/y.png', 'https://s.test'), 'https://cdn.test/y.png');
    expect(resolveAsset(null, 'https://s.test'), isNull);
  });
}
