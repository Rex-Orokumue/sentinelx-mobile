import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/core/api/api_client.dart';
import 'package:sentinelx_mobile/core/notifications/push/push_gateway.dart';
import 'package:sentinelx_mobile/core/notifications/push/push_registration.dart';
import 'package:sentinelx_mobile/core/providers.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthException;

import '../fakes/fake_push_gateway.dart';

// Session has value equality, so a token refresh (same user, new access token) needs a distinct token.
var _seq = 0;
Session _sessionFor(String userId) => Session(
      accessToken: 'tok-$userId-${_seq++}',
      tokenType: 'bearer',
      user: User(id: userId, appMetadata: const {}, userMetadata: const {}, aud: '', createdAt: ''),
    );

class _Registration {
  _Registration(this.token, this.platform, this.appVersion);
  final String token, platform, appVersion;
}

class _FakeApi implements ApiClient {
  final registered = <_Registration>[];
  final unregistered = <String>[];
  int failRegisterTimes = 0;
  Object? unregisterError;
  Completer<void>? unregisterGate;

  @override
  Future<void> registerDevice({required String token, required String platform, required String appVersion}) async {
    if (failRegisterTimes > 0) {
      failRegisterTimes--;
      throw ApiException(status: 500, code: 'internal', message: 'x');
    }
    registered.add(_Registration(token, platform, appVersion));
  }

  @override
  Future<void> unregisterDevice(String token) async {
    unregistered.add(token);
    if (unregisterGate != null) await unregisterGate!.future;
    if (unregisterError != null) throw unregisterError!;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Harness {
  _Harness({FakePushGateway? gateway, _FakeApi? api})
      : gateway = gateway ?? FakePushGateway(),
        api = api ?? _FakeApi() {
    container = ProviderContainer(overrides: [
      sessionProvider.overrideWith((ref) => session.stream),
      apiClientProvider.overrideWith((ref) => this.api),
      pushGatewayProvider.overrideWithValue(this.gateway),
      installedVersionProvider.overrideWithValue('1.2.3'),
    ]);
    container.listen(pushRegistrationProvider, (_, _) {});
  }

  final FakePushGateway gateway;
  final _FakeApi api;
  final session = StreamController<Session?>.broadcast();
  late final ProviderContainer container;

  Future<void> emit(Session? s) async {
    session.add(s);
    await pumpEventQueue();
  }

  Future<void> start() => pumpEventQueue(); // let the StreamProvider subscribe before a broadcast add

  void dispose() {
    container.dispose();
    session.close();
  }
}

void main() {
  test('registers once on sign-in with platform and app version, not again for a token-refreshed Session', () async {
    final h = _Harness();
    addTearDown(h.dispose);
    await h.start();
    await h.emit(_sessionFor('u1'));
    await h.emit(_sessionFor('u1')); // Supabase token refresh: a new Session instance, same user
    expect(h.api.registered, hasLength(1));
    expect(h.api.registered.single.token, 'tok-1');
    expect(h.api.registered.single.platform, 'android');
    expect(h.api.registered.single.appVersion, '1.2.3');
  });

  test('registers the refreshed FCM token while signed in', () async {
    final h = _Harness();
    addTearDown(h.dispose);
    await h.start();
    await h.emit(_sessionFor('u1'));
    h.gateway.tokenRefresh.add('tok-2');
    await pumpEventQueue();
    expect(h.api.registered.map((r) => r.token), ['tok-1', 'tok-2']);
  });

  test('a token refresh while signed out sends nothing', () async {
    final h = _Harness();
    addTearDown(h.dispose);
    await h.start();
    h.gateway.tokenRefresh.add('tok-2');
    await pumpEventQueue();
    expect(h.api.registered, isEmpty);
  });

  test('account switch on one phone registers the same token again for the new user (Review Focus 4)', () async {
    final h = _Harness();
    addTearDown(h.dispose);
    await h.start();
    await h.emit(_sessionFor('A'));
    await h.emit(_sessionFor('B'));
    expect(h.api.registered.map((r) => r.token), ['tok-1', 'tok-1']);
  });

  test('sign-out then sign-in registers again', () async {
    final h = _Harness();
    addTearDown(h.dispose);
    await h.start();
    await h.emit(_sessionFor('A'));
    await h.emit(null);
    await h.emit(_sessionFor('A'));
    expect(h.api.registered, hasLength(2));
  });

  test('a failed registration is retried on the next session event', () async {
    final api = _FakeApi()..failRegisterTimes = 1;
    final h = _Harness(api: api);
    addTearDown(h.dispose);
    await h.start();
    await h.emit(_sessionFor('u1'));
    expect(api.registered, isEmpty);
    await h.emit(_sessionFor('u1'));
    expect(api.registered, hasLength(1));
  });

  test('an unavailable gateway never calls the API', () async {
    final h = _Harness(gateway: FakePushGateway(available: false));
    addTearDown(h.dispose);
    await h.start();
    await h.emit(_sessionFor('u1'));
    expect(h.api.registered, isEmpty);
  });

  test('no token (FCM could not mint one) sends nothing and does not throw', () async {
    final h = _Harness(gateway: FakePushGateway(token: null));
    addTearDown(h.dispose);
    await h.start();
    await h.emit(_sessionFor('u1'));
    expect(h.api.registered, isEmpty);
  });

  group('unregister', () {
    test('deletes this device token', () async {
      final h = _Harness();
      addTearDown(h.dispose);
      await h.start();
      await h.emit(_sessionFor('u1'));
      await h.container.read(pushRegistrationProvider).unregister();
      expect(h.api.unregistered, ['tok-1']);
    });

    test('swallows an API failure and completes normally', () async {
      final api = _FakeApi()..unregisterError = ApiException(status: 0, code: 'network', message: 'down');
      final h = _Harness(api: api);
      addTearDown(h.dispose);
      await h.start();
      await h.emit(_sessionFor('u1'));
      await expectLater(h.container.read(pushRegistrationProvider).unregister(), completes);
    });

    test('after unregister a token refresh does not re-register the signing-out user; reregister restores it', () async {
      final h = _Harness();
      addTearDown(h.dispose);
      await h.start();
      await h.emit(_sessionFor('u1'));
      await h.container.read(pushRegistrationProvider).unregister();
      h.gateway.tokenRefresh.add('tok-2');
      await h.emit(_sessionFor('u1')); // a session refresh in the same window
      expect(h.api.registered.map((r) => r.token), ['tok-1']);

      // Sign-out failed: the user is still signed in and must keep receiving pushes.
      await h.container.read(pushRegistrationProvider).reregister();
      expect(h.api.registered, hasLength(2));
    });

    test('an unavailable gateway has nothing to unregister', () async {
      final h = _Harness(gateway: FakePushGateway(available: false));
      addTearDown(h.dispose);
      await h.container.read(pushRegistrationProvider).unregister();
      expect(h.api.unregistered, isEmpty);
    });

    test('gives up after 5 seconds so sign-out is never held hostage', () {
      fakeAsync((async) {
        final api = _FakeApi()..unregisterGate = Completer<void>(); // never completes
        final h = _Harness(api: api);
        var done = false;
        h.container.read(pushRegistrationProvider).unregister().then((_) => done = true);
        async.flushMicrotasks();
        expect(done, isFalse);
        async.elapse(const Duration(seconds: 5));
        async.flushMicrotasks();
        expect(done, isTrue);
        h.dispose();
      });
    });
  });
}
