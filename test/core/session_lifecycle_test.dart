import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/core/api/api_client.dart';
import 'package:sentinelx_mobile/core/api/models.dart';
import 'package:sentinelx_mobile/core/providers.dart';
import 'package:sentinelx_mobile/core/session/session_lifecycle.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthException;

Session _sessionFor(String userId) => Session(
      accessToken: 'tok-$userId',
      tokenType: 'bearer',
      user: User(id: userId, appMetadata: const {}, userMetadata: const {}, aud: '', createdAt: ''),
    );

class _CountingApiClient implements ApiClient {
  _CountingApiClient(this.onCall);
  final void Function() onCall;

  @override
  Future<SessionStartResponse> postSessionStart() async {
    onCall();
    return const SessionStartResponse(
      dailyLogin: DailyLoginAward(awardedToday: false, coinsAwarded: 0, xpAwarded: 0, streak: 0, milestone: null),
      deletionRequestedAt: null,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('fires postSessionStart once for a given user id even if the Session object re-emits', () async {
    var calls = 0;
    final controller = StreamController<Session?>.broadcast();
    final container = ProviderContainer(overrides: [
      sessionProvider.overrideWith((ref) => controller.stream),
      apiClientProvider.overrideWith((ref) => _CountingApiClient(() => calls++)),
    ]);
    addTearDown(container.dispose);
    addTearDown(controller.close);

    container.listen(sessionLifecycleProvider, (_, _) {});
    await pumpEventQueue(); // let the StreamProvider subscribe before a broadcast add
    controller.add(_sessionFor('u1'));
    await pumpEventQueue();
    // Simulate a token refresh: a new Session instance, same user id.
    controller.add(_sessionFor('u1'));
    await pumpEventQueue();

    expect(calls, 1);
  });

  test('a sign-out then a different sign-in fires again for the new user', () async {
    var calls = 0;
    final controller = StreamController<Session?>.broadcast();
    final container = ProviderContainer(overrides: [
      sessionProvider.overrideWith((ref) => controller.stream),
      apiClientProvider.overrideWith((ref) => _CountingApiClient(() => calls++)),
    ]);
    addTearDown(container.dispose);
    addTearDown(controller.close);

    container.listen(sessionLifecycleProvider, (_, _) {});
    await pumpEventQueue(); // let the StreamProvider subscribe before a broadcast add
    controller.add(_sessionFor('u1'));
    await pumpEventQueue();
    controller.add(null);
    await pumpEventQueue();
    controller.add(_sessionFor('u2'));
    await pumpEventQueue();

    expect(calls, 2);
  });
}
