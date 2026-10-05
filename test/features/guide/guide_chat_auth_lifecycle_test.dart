import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/core/api/chat_models.dart';
import 'package:sentinelx_mobile/core/lifecycle/app_lifecycle_provider.dart';
import 'package:sentinelx_mobile/core/providers.dart';
import 'package:sentinelx_mobile/core/storage/local_kv.dart';
import 'package:sentinelx_mobile/features/guide/guide_providers.dart';
import 'package:sentinelx_mobile/features/guide/guide_repository.dart';
import 'package:sentinelx_mobile/features/support_chat/chat_notifier.dart';
import 'package:sentinelx_mobile/features/support_chat/chat_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../fakes/fake_chat_repository.dart';
import '../../fakes/fake_guide_repository.dart';
import '../../fakes/fake_realtime.dart' show FakeLifecycle;
import '../../support/guide_fixtures.dart';

void main() {
  test('a token-refreshed Session (same user) neither refetches quests nor resets the chat; a different user does both', () async {
    final guide = FakeGuideRepository(seed: [quest()]);
    final chat = FakeChatRepository();
    final session = StreamController<Session?>.broadcast();
    addTearDown(session.close);
    var seq = 0;
    Session sessionFor(String id) => Session(
          accessToken: 'tok-$id-${seq++}',
          tokenType: 'bearer',
          user: User(id: id, appMetadata: const {}, userMetadata: const {}, aud: '', createdAt: ''),
        );
    final c = ProviderContainer(retry: (_, _) => null, overrides: [
      guideRepositoryProvider.overrideWithValue(guide),
      chatRepositoryProvider.overrideWithValue(chat),
      sessionProvider.overrideWith((ref) => session.stream),
      appLifecycleSourceProvider.overrideWithValue(FakeLifecycle()),
      chatDeviceIdProvider.overrideWith((ref) async => 'device-abc-123'),
    ]);
    addTearDown(c.dispose);
    c.listen(sessionProvider, (_, _) {});
    c.listen(questsProvider, (_, _) {});
    c.listen(chatProvider, (_, _) {});

    session.add(sessionFor('u1'));
    await pumpEventQueue();
    expect(guide.questsCalls, 1);
    final turn = c.read(chatProvider.notifier).send('hello', locale: 'en');
    await pumpEventQueue();
    chat.last.add(const ChatDone(false));
    await chat.last.close();
    await turn;
    expect(c.read(chatProvider).bubbles, hasLength(2));

    session.add(sessionFor('u1')); // token refresh, same user
    await pumpEventQueue();
    expect(guide.questsCalls, 1, reason: 'keyed on the user id, not the token');
    expect(c.read(chatProvider).bubbles, hasLength(2), reason: 'the conversation survives a refresh');

    session.add(sessionFor('u2')); // a different account
    await pumpEventQueue();
    expect(guide.questsCalls, 2);
    expect(c.read(chatProvider).bubbles, isEmpty, reason: 'never show user A their predecessor\'s chat');
  });
}
