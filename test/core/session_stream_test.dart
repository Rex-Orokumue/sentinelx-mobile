import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sentinelx_mobile/core/providers.dart';

Session _session(String id) => Session(
      accessToken: 'tok-$id',
      tokenType: 'bearer',
      user: User(id: id, appMetadata: const {}, userMetadata: const {}, aud: 'authenticated', createdAt: '2026-01-01T00:00:00Z'),
    );

class _FakeAuth implements GoTrueClient {
  _FakeAuth(this.currentSession);
  @override
  final Session? currentSession;
  final controller = StreamController<AuthState>.broadcast();
  @override
  Stream<AuthState> get onAuthStateChange => controller.stream;
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError(invocation.memberName.toString());
}

class _FakeClient implements SupabaseClient {
  _FakeClient(this._auth);
  final _FakeAuth _auth;
  @override
  GoTrueClient get auth => _auth;
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError(invocation.memberName.toString());
}

void main() {
  test('an error event on the auth stream (cancelled Google link, failed refresh) does not turn the session into an error', () async {
    final auth = _FakeAuth(_session('u1'));
    final c = ProviderContainer(retry: (_, _) => null, overrides: [supabaseClientProvider.overrideWithValue(_FakeClient(auth))]);
    addTearDown(() async {
      c.dispose();
      await auth.controller.close();
    });
    c.listen(sessionProvider, (_, _) {});
    await pumpEventQueue();
    expect(c.read(sessionProvider).asData?.value?.user.id, 'u1');

    // supabase_flutter's _handleDeeplink does exactly this when the OAuth callback carries an error.
    auth.controller.addError(const AuthException('access_denied', code: 'access_denied'));
    await pumpEventQueue();

    final after = c.read(sessionProvider);
    expect(after.hasError, isFalse, reason: 'an auth-stream error is not a sign-out');
    expect(after.asData?.value?.user.id, 'u1', reason: 'the signed-in user must stay signed in');
  });

  test('the session provider keeps following sign-in and sign-out after an error event', () async {
    final auth = _FakeAuth(null);
    final c = ProviderContainer(retry: (_, _) => null, overrides: [supabaseClientProvider.overrideWithValue(_FakeClient(auth))]);
    addTearDown(() async {
      c.dispose();
      await auth.controller.close();
    });
    c.listen(sessionProvider, (_, _) {});
    await pumpEventQueue();
    auth.controller.addError(const AuthException('boom'));
    await pumpEventQueue();
    auth.controller.add(AuthState(AuthChangeEvent.signedIn, _session('u2')));
    await pumpEventQueue();
    expect(c.read(sessionProvider).asData?.value?.user.id, 'u2');
    auth.controller.add(const AuthState(AuthChangeEvent.signedOut, null));
    await pumpEventQueue();
    expect(c.read(sessionProvider).asData?.value, isNull);
    expect(c.read(sessionProvider).hasError, isFalse);
  });
}
