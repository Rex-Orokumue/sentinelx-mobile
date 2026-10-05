import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/core/providers.dart';
import 'package:sentinelx_mobile/features/guide/guide_repository.dart';
import 'package:sentinelx_mobile/features/guide/guide_screen.dart';
import 'package:sentinelx_mobile/features/support_chat/chat_repository.dart';
import 'package:sentinelx_mobile/features/support_chat/chat_screen.dart';
import 'package:sentinelx_mobile/core/lifecycle/app_lifecycle_provider.dart';
import '../fakes/fake_chat_repository.dart';
import '../fakes/fake_realtime.dart' show FakeLifecycle;

import '../fakes/fake_guide_repository.dart';
import '../support/guide_fixtures.dart';
import '../support/pump_app.dart';

void main() {
testWidgets('/guide opens the guide screen outside the shell', (tester) async {
  await pumpRouterWithRepo(tester, initialLocation: '/guide', overrides: [
    viewerIdProvider.overrideWith((ref) async => 'u1'),
    guideRepositoryProvider.overrideWithValue(FakeGuideRepository(seed: [quest()])),
  ]);
  await tester.pumpAndSettle();
  expect(find.byType(GuideScreen), findsOneWidget);
  expect(find.byType(NavigationBar), findsNothing);
});

  testWidgets('/guide/chat opens the chat screen outside the shell, signed out too', (tester) async {
    await pumpRouterWithRepo(tester, initialLocation: '/guide/chat', overrides: [
      viewerIdProvider.overrideWith((ref) async => null),
      chatRepositoryProvider.overrideWithValue(FakeChatRepository()),
      appLifecycleSourceProvider.overrideWithValue(FakeLifecycle()),
    ]);
    await tester.pumpAndSettle();
    expect(find.byType(ChatScreen), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });
}
