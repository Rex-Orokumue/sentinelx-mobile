import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/core/api/models.dart';
import 'package:sentinelx_mobile/core/notifications/push/push_bootstrap.dart';
import 'package:sentinelx_mobile/core/notifications/push/push_gateway.dart';
import 'package:sentinelx_mobile/core/notifications/push/push_models.dart';
import 'package:sentinelx_mobile/core/notifications/push/push_tap_router.dart';
import 'package:sentinelx_mobile/core/providers.dart';
import 'package:sentinelx_mobile/features/notifications/notifications_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthException;

import '../fakes/fake_notifications_repository.dart';
import '../fakes/fake_push_gateway.dart';

Session _session() => Session(
      accessToken: 'tok',
      tokenType: 'bearer',
      user: User(id: 'u1', appMetadata: const {}, userMetadata: const {}, aud: '', createdAt: ''),
    );

MeResponse _me() => MeResponse(
      id: 'u1', email: 'a@b.com', roles: const [], isStaff: false, isAdmin: false,
      profile: const MeProfile(
        username: 'ada', displayName: 'Ada', avatarUrl: null, whatsappNumber: null, country: null,
        locale: 'en', membershipTier: null, kycVerified: false, deletionRequestedAt: null,
      ),
    );

class _Rig {
  _Rig({PushGateway? gateway, this.signedIn = true})
      : gateway = gateway ?? FakePushGateway(),
        repo = FakeNotificationsRepository() {
    container = ProviderContainer(retry: (_, _) => null, overrides: [
      pushGatewayProvider.overrideWithValue(this.gateway),
      notificationsRepositoryProvider.overrideWithValue(repo),
      pushNavigatorProvider.overrideWithValue(visited.add),
      sessionProvider.overrideWith((ref) async* {
        await sessionGate.future;
        yield signedIn ? _session() : null;
      }),
      meProvider.overrideWith((ref) async {
        await meGate.future;
        return signedIn ? _me() : null;
      }),
    ]);
  }

  final PushGateway gateway;
  final FakeNotificationsRepository repo;
  final bool signedIn;
  final visited = <String>[];
  final sessionGate = Completer<void>();
  final meGate = Completer<void>();
  late final ProviderContainer container;

  void start() => container.listen(pushBootstrapProvider, (_, _) {});
}

void main() {
  test('creates exactly the five channels at startup, localized', () async {
    final g = FakePushGateway();
    final r = _Rig(gateway: g);
    addTearDown(r.container.dispose);
    r.start();
    await pumpEventQueue();
    expect(g.createdChannels!.map((c) => c.id), kPushChannelIds);
    expect(g.createdChannels!.every((c) => c.name.isNotEmpty), isTrue);
  });

  test('cold start while signed in: no route until session AND /me settle, then exactly once (Review Focus 1)', () async {
    final g = FakePushGateway(initialMessage: const PushMessage(url: '/matches/m1'));
    final r = _Rig(gateway: g);
    addTearDown(r.container.dispose);
    r.start();
    await pumpEventQueue();
    expect(r.visited, isEmpty, reason: 'the session has not restored yet');

    r.sessionGate.complete();
    await pumpEventQueue();
    expect(r.visited, isEmpty, reason: '/me has not loaded yet — routing now would hit the login/onboarding gate');

    r.meGate.complete();
    await pumpEventQueue();
    expect(r.visited, ['/matches/m1'], reason: 'one hop, straight to the destination, no /login or /onboarding in between');
  });

  test('cold start signed out: the queued tap is dropped, never routed', () async {
    final g = FakePushGateway(initialMessage: const PushMessage(url: '/matches/m1'));
    final r = _Rig(gateway: g, signedIn: false);
    addTearDown(r.container.dispose);
    r.start();
    r.sessionGate.complete();
    r.meGate.complete();
    await pumpEventQueue();
    expect(r.visited, isEmpty);
  });

  test('a background tap (onMessageOpened) routes once the app has settled', () async {
    final g = FakePushGateway();
    final r = _Rig(gateway: g);
    addTearDown(r.container.dispose);
    r.start();
    r.sessionGate.complete();
    r.meGate.complete();
    await pumpEventQueue();
    g.opened.add(const PushMessage(url: '/community/3f2b8c1e-9d4a-4b7e-8a61-5c0d2e7f9a10'));
    await pumpEventQueue();
    expect(r.visited, ['/community/3f2b8c1e-9d4a-4b7e-8a61-5c0d2e7f9a10']);
  });

  test('a foreground message is shown as a banner, not routed', () async {
    final g = FakePushGateway();
    final r = _Rig(gateway: g);
    addTearDown(r.container.dispose);
    r.container.listen(foregroundPushProvider, (_, _) {});
    r.start();
    r.sessionGate.complete();
    r.meGate.complete();
    await pumpEventQueue();
    g.foreground.add(const PushMessage(title: 'New fixture', body: 'vs Ada', url: '/matches/m1'));
    await pumpEventQueue();
    expect(r.container.read(foregroundPushProvider)!.title, 'New fixture');
    expect(r.visited, isEmpty);
  });

  test('a gateway whose getInitialMessage throws still starts, and later taps still work', () async {
    final g = FakePushGateway()..throwOnInitialMessage = true;
    final r = _Rig(gateway: g);
    addTearDown(r.container.dispose);
    r.start();
    r.sessionGate.complete();
    r.meGate.complete();
    await pumpEventQueue();
    g.opened.add(const PushMessage(url: '/matches/m9'));
    await pumpEventQueue();
    expect(r.visited, ['/matches/m9']);
  });

  test('the disabled gateway does nothing and never throws', () async {
    final r = _Rig(gateway: const DisabledPushGateway());
    addTearDown(r.container.dispose);
    r.start();
    r.sessionGate.complete();
    r.meGate.complete();
    await pumpEventQueue();
    expect(r.visited, isEmpty);
  });
}
