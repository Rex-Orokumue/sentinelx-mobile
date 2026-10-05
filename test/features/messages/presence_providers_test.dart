import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/core/providers.dart';
import 'package:sentinelx_mobile/core/realtime/realtime_hub.dart';
import 'package:sentinelx_mobile/core/realtime/realtime_port.dart';
import 'package:sentinelx_mobile/features/messages/inbox_providers.dart';
import 'package:sentinelx_mobile/features/messages/presence_providers.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../fakes/fake_messages_repository.dart';
import '../../fakes/fake_realtime.dart';
import '../../support/pump_conversation.dart';
import 'inbox_screen_test.dart' show pumpInbox;

class _Viewer extends Notifier<String?> {
  _Viewer(this.initial);
  final String? initial;

  @override
  String? build() => initial;

  void set(String? v) => state = v;
}

final _viewerProvider = NotifierProvider<_Viewer, String?>(() => _Viewer('me'));

class _Rig {
  _Rig({String? viewer = 'me'}) {
    hub = RealtimeHub(factory: factory, lifecycle: FakeLifecycle());
    container = ProviderContainer(retry: (_, _) => null, overrides: [
      realtimeHubProvider.overrideWithValue(hub),
      _viewerProvider.overrideWith(() => _Viewer(viewer)),
      dmViewerIdProvider.overrideWith((ref) async => ref.watch(_viewerProvider)),
    ]);
    container.listen(onlinePlayersProvider, (_, next) {
      final v = next.asData?.value;
      if (v != null) emissions.add(v);
    });
  }

  final factory = FakeChannelFactory();
  late final RealtimeHub hub;
  late final ProviderContainer container;
  final emissions = <Set<String>>[];

  FakeChannelPort get port => factory.live('dm-online')!;
  bool online(String id) => container.read(isOnlineProvider(id));

  Future<void> sync(Set<String> keys) async {
    port.emitPresence(keys);
    await pumpEventQueue();
  }

  void dispose() => container.dispose();
}

Future<_Rig> _ready({String? viewer = 'me'}) async {
  final r = _Rig(viewer: viewer);
  addTearDown(r.dispose);
  await pumpEventQueue();
  return r;
}

void main() {
  test('opens dm-online as a private presence channel keyed by the viewer id, tracking online_at', () async {
    final r = await _ready();
    final spec = r.port.spec;
    expect(spec.topic, 'dm-online');
    expect(spec.private, isTrue);
    expect(spec.presenceKey, 'me');
    final b = spec.bindings.whereType<PresenceBinding>().single;
    expect(b.key, 'me');
    expect(b.trackPayload!.containsKey('online_at'), isTrue);
  });

  test('a presence sync marks those players online; a later sync flips them back', () async {
    final r = await _ready();
    r.port.emitStatus(PortStatus.subscribed);
    await r.sync({'a', 'b'});
    expect(r.online('a'), isTrue);
    expect(r.online('b'), isTrue);
    expect(r.online('z'), isFalse);
    await r.sync({'b'});
    expect(r.online('a'), isFalse);
    expect(r.online('b'), isTrue);
  });

  test('two consecutive syncs with different contents both notify (lesson 2)', () async {
    final r = await _ready();
    await r.sync({'a'});
    await r.sync({'a', 'b'});
    expect(r.emissions, [
      {'a'},
      {'a', 'b'},
    ]);
    expect(identical(r.emissions[0], r.emissions[1]), isFalse, reason: 'a new Set each time');
  });

  test('the viewer is tracked but never shown as someone else online', () async {
    final r = await _ready();
    r.port.emitStatus(PortStatus.subscribed);
    await r.sync({'me', 'a'});
    expect(r.online('me'), isFalse);
    expect(r.online('a'), isTrue);
    expect(r.port.tracked, hasLength(1), reason: 'own presence is still announced');
  });

  test('tracked once per subscribed and re-tracked after a reconnect', () async {
    final r = await _ready();
    final first = r.port;
    first.emitStatus(PortStatus.subscribed);
    expect(first.tracked, hasLength(1));
    first.emitStatus(PortStatus.subscribed); // the socket rejoined the same channel
    expect(first.tracked, hasLength(2));
  });

  test('signed out opens no channel', () async {
    final r = await _ready(viewer: null);
    expect(r.factory.created, isEmpty);
    expect(r.online('anyone'), isFalse);
  });

  test('disposing closes the channel', () async {
    final r = await _ready();
    final port = r.port;
    r.dispose();
    await pumpEventQueue();
    expect(port.disposed, isTrue);
  });

  test('an account switch re-opens the channel under the new key', () async {
    final r = await _ready();
    expect(r.factory.created, hasLength(1));
    r.container.read(_viewerProvider.notifier).set('someone-else');
    await pumpEventQueue();
    expect(r.factory.created.length, greaterThanOrEqualTo(2));
    expect(r.port.spec.presenceKey, 'someone-else');
    expect(r.factory.created.first.disposed, isTrue);
  });

  test('a real refreshed Session for the same user does not re-open; a different user does', () async {
    final factory = FakeChannelFactory();
    final hub = RealtimeHub(factory: factory, lifecycle: FakeLifecycle());
    final session = StreamController<Session?>.broadcast();
    addTearDown(session.close);
    var seq = 0;
    Session sessionFor(String id) => Session(
          accessToken: 'tok-$id-${seq++}',
          tokenType: 'bearer',
          user: User(id: id, appMetadata: const {}, userMetadata: const {}, aud: '', createdAt: ''),
        );
    final c = ProviderContainer(retry: (_, _) => null, overrides: [
      realtimeHubProvider.overrideWithValue(hub),
      sessionProvider.overrideWith((ref) => session.stream),
    ]);
    addTearDown(c.dispose);
    c.listen(sessionProvider, (_, _) {});
    c.listen(onlinePlayersProvider, (_, _) {});
    await pumpEventQueue();
    session.add(sessionFor('u1'));
    await pumpEventQueue();
    expect(factory.created, hasLength(1));
    session.add(sessionFor('u1'));
    await pumpEventQueue();
    expect(factory.created, hasLength(1), reason: 'keyed on the user id, not the token');
    session.add(sessionFor('u2'));
    await pumpEventQueue();
    expect(factory.created.length, greaterThanOrEqualTo(2));
  });

  group('dots', () {
    testWidgets('the inbox row shows a labelled green dot only for an online player', (tester) async {
      final repo = FakeMessagesRepository(inbox: [thread('a'), thread('b')]);
      final handle = tester.ensureSemantics();
      await pumpInbox(tester, repo, overrides: [onlinePlayersProvider.overrideWith((ref) => Stream.value({'p-a'}))]);
      expect(find.byKey(const Key('dm-online-a')), findsOneWidget);
      expect(find.byKey(const Key('dm-online-b')), findsNothing);
      expect(find.byWidgetPredicate((w) => w is Semantics && w.properties.label == 'Online'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('the conversation header shows the dot when the other player is online, not otherwise', (tester) async {
      final repo = FakeMessagesRepository()
        ..headers['t1'] = header('t1', name: 'Ada', otherId: 'ada-id')
        ..messagesByThread['t1'] = [dmMsg('m', body: 'hi', at: kNow.subtract(const Duration(minutes: 1)))];
      await pumpConversation(tester, repo, overrides: [onlinePlayersProvider.overrideWith((ref) => Stream.value({'ada-id'}))]);
      expect(find.byKey(const Key('dm-online-header')), findsOneWidget);

      await pumpConversation(tester, repo, overrides: [onlinePlayersProvider.overrideWith((ref) => Stream.value({'someone-else'}))]);
      expect(find.byKey(const Key('dm-online-header')), findsNothing);
    });
  });
}
