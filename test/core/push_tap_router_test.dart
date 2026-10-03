import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/core/notifications/push/push_models.dart';
import 'package:sentinelx_mobile/core/notifications/push/push_tap_router.dart';
import 'package:sentinelx_mobile/features/notifications/notifications_repository.dart';

import '../fakes/fake_notifications_repository.dart';

const _post = '3f2b8c1e-9d4a-4b7e-8a61-5c0d2e7f9a10';

class _Rig {
  _Rig({FakeNotificationsRepository? repo}) : repo = repo ?? FakeNotificationsRepository() {
    container = ProviderContainer(overrides: [
      notificationsRepositoryProvider.overrideWithValue(this.repo),
      pushNavigatorProvider.overrideWithValue(visited.add),
    ]);
  }
  final FakeNotificationsRepository repo;
  final visited = <String>[];
  late final ProviderContainer container;
  PushTapRouter get router => container.read(pushTapRouterProvider);
}

void main() {
  group('destinationFor', () {
    test('maps web links the app has screens for', () {
      expect(destinationFor(const PushMessage(url: '/matches/m1')), '/matches/m1');
      expect(destinationFor(const PushMessage(url: '/community/$_post')), '/community/$_post');
      expect(destinationFor(const PushMessage(url: 'https://sentinelxesports.com.ng/fr/tournaments/cup')), '/tournaments/cup');
      expect(destinationFor(const PushMessage(url: '/dashboard/settings')), '/account/notifications');
    });

    test('a missing, blank or unmappable url opens the bell instead of doing nothing', () {
      expect(destinationFor(const PushMessage()), '/notifications');
      expect(destinationFor(const PushMessage(url: '')), '/notifications');
      expect(destinationFor(const PushMessage(url: '/dashboard/wallet')), '/notifications');
      expect(destinationFor(const PushMessage(url: '/messages/abc')), '/notifications');
      expect(destinationFor(const PushMessage(url: 'https://evil.example/matches/1')), '/notifications');
    });
  });

  group('PushTapRouter', () {
    test('after ready, a tap routes immediately (foreground banner and background taps)', () {
      final r = _Rig();
      addTearDown(r.container.dispose);
      r.router.markReady();
      r.router.onTap(const PushMessage(url: '/matches/m1'));
      expect(r.visited, ['/matches/m1']);
    });

    test('a tap before ready routes nothing, then exactly once when ready (Review Focus 1)', () {
      final r = _Rig();
      addTearDown(r.container.dispose);
      r.router.onTap(const PushMessage(url: '/matches/m1'));
      expect(r.visited, isEmpty);
      r.router.markReady();
      expect(r.visited, ['/matches/m1']);
      r.router.markReady();
      expect(r.visited, ['/matches/m1'], reason: 'a second markReady must not re-route');
    });

    test('two taps before ready: only the latest is routed', () {
      final r = _Rig();
      addTearDown(r.container.dispose);
      r.router.onTap(const PushMessage(url: '/matches/a'));
      r.router.onTap(const PushMessage(url: '/matches/b'));
      r.router.markReady();
      expect(r.visited, ['/matches/b']);
    });

    test('dropPending forgets a queued tap (signed out when the app settled)', () {
      final r = _Rig();
      addTearDown(r.container.dispose);
      r.router.onTap(const PushMessage(url: '/matches/a'));
      r.router.dropPending();
      r.router.markReady();
      expect(r.visited, isEmpty);
    });

    test('routing marks the notification read for mapped and unmapped links, never for a null url', () async {
      final r = _Rig();
      addTearDown(r.container.dispose);
      r.router.markReady();
      r.router.onTap(const PushMessage(url: '/matches/m1'));
      r.router.onTap(const PushMessage(url: '/dashboard/wallet'));
      r.router.onTap(const PushMessage());
      await pumpEventQueue();
      expect(r.repo.readForLink, ['/matches/m1', '/dashboard/wallet']);
      expect(r.visited, ['/matches/m1', '/notifications', '/notifications']);
    });
  });
}
