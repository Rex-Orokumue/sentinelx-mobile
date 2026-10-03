import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/core/notifications/push/push_gateway.dart';
import 'package:sentinelx_mobile/core/notifications/push/push_models.dart';
import 'package:sentinelx_mobile/core/notifications/push/push_permission.dart';
import 'package:sentinelx_mobile/core/providers.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthException;

import '../fakes/fake_push_gateway.dart';

Session _session() => Session(
      accessToken: 'tok',
      tokenType: 'bearer',
      user: User(id: 'u1', appMetadata: const {}, userMetadata: const {}, aud: '', createdAt: ''),
    );

Future<ProviderContainer> _container(FakePushGateway gateway, {bool signedIn = true}) async {
  final c = ProviderContainer(overrides: [
    sessionProvider.overrideWith((ref) => Stream.value(signedIn ? _session() : null)),
    pushGatewayProvider.overrideWithValue(gateway),
  ]);
  // Riverpod 3 pauses a provider nobody listens to; the app always has listeners (router, lifecycle).
  c.listen(sessionProvider, (_, _) {});
  await c.read(sessionProvider.future);
  return c;
}

void main() {
  group('onStake — the contextual ask at the first confirmed stake', () {
    test('asks once when the OS has never been asked (notDetermined)', () async {
      final g = FakePushGateway(permissionResult: PushPermission.notDetermined);
      final c = await _container(g);
      addTearDown(c.dispose);
      await c.read(pushPermissionPrompterProvider).onStake();
      expect(g.requestPermissionCalls, 1);
    });

    test('never asks when already authorized (also the below-API-33 case) or after any denial', () async {
      for (final status in [PushPermission.authorized, PushPermission.denied, PushPermission.deniedPermanently]) {
        final g = FakePushGateway(permissionResult: status);
        final c = await _container(g);
        addTearDown(c.dispose);
        await c.read(pushPermissionPrompterProvider).onStake();
        expect(g.requestPermissionCalls, 0, reason: '$status');
      }
    });

    test('a double stake asks once, even while the first dialog is still showing', () async {
      final g = FakePushGateway(permissionResult: PushPermission.notDetermined)..requestGate = Completer<void>();
      final c = await _container(g);
      addTearDown(c.dispose);
      final prompter = c.read(pushPermissionPrompterProvider);
      final first = prompter.onStake();
      await pumpEventQueue();
      final second = prompter.onStake(); // arrives while the dialog is open
      g.requestGate!.complete();
      await Future.wait([first, second]);
      await prompter.onStake(); // and later
      expect(g.requestPermissionCalls, 1);
    });

    test('does not ask again after the user answered the dialog with a denial', () async {
      final g = FakePushGateway(permissionResult: PushPermission.notDetermined, requestResult: PushPermission.denied);
      final c = await _container(g);
      addTearDown(c.dispose);
      final prompter = c.read(pushPermissionPrompterProvider);
      await prompter.onStake();
      await prompter.onStake();
      expect(g.requestPermissionCalls, 1);
    });

    test('an OEM that leaves the status notDetermined after the dialog is still asked at most once per run', () async {
      final g = FakePushGateway(permissionResult: PushPermission.notDetermined, requestResult: PushPermission.notDetermined);
      final c = await _container(g);
      addTearDown(c.dispose);
      final prompter = c.read(pushPermissionPrompterProvider);
      await prompter.onStake();
      await prompter.onStake();
      expect(g.requestPermissionCalls, 1);
    });

    test('signed out: never asks', () async {
      final g = FakePushGateway(permissionResult: PushPermission.notDetermined);
      final c = await _container(g, signedIn: false);
      addTearDown(c.dispose);
      await c.read(pushPermissionPrompterProvider).onStake();
      expect(g.requestPermissionCalls, 0);
    });

    test('an unavailable gateway: never asks', () async {
      final g = FakePushGateway(available: false, permissionResult: PushPermission.notDetermined);
      final c = await _container(g);
      addTearDown(c.dispose);
      await c.read(pushPermissionPrompterProvider).onStake();
      expect(g.requestPermissionCalls, 0);
    });

    test('a throwing gateway never throws out of onStake', () async {
      final g = FakePushGateway(permissionResult: PushPermission.notDetermined)..throwOnPermission = true;
      final c = await _container(g);
      addTearDown(c.dispose);
      await expectLater(c.read(pushPermissionPrompterProvider).onStake(), completes);
    });

    test('with no session machinery at all (a bare container) it still completes', () async {
      final c = ProviderContainer(overrides: [pushGatewayProvider.overrideWithValue(FakePushGateway())]);
      addTearDown(c.dispose);
      await expectLater(c.read(pushPermissionPrompterProvider).onStake(), completes);
    });
  });

  group('enableFromUser — the passive rows (bell empty state, settings)', () {
    test('authorized: no dialog, no settings', () async {
      final g = FakePushGateway(permissionResult: PushPermission.authorized);
      final c = await _container(g);
      addTearDown(c.dispose);
      expect(await c.read(pushPermissionPrompterProvider).enableFromUser(), PushPermission.authorized);
      expect(g.requestPermissionCalls, 0);
      expect(g.openSettingsCalls, 0);
    });

    test('notDetermined: dialog only', () async {
      final g = FakePushGateway(permissionResult: PushPermission.notDetermined, requestResult: PushPermission.denied);
      final c = await _container(g);
      addTearDown(c.dispose);
      expect(await c.read(pushPermissionPrompterProvider).enableFromUser(), PushPermission.denied);
      expect(g.requestPermissionCalls, 1);
      expect(g.openSettingsCalls, 0);
    });

    test('denied: tries the dialog once, and opens system settings if it did not help', () async {
      final g = FakePushGateway(permissionResult: PushPermission.denied, requestResult: PushPermission.denied);
      final c = await _container(g);
      addTearDown(c.dispose);
      await c.read(pushPermissionPrompterProvider).enableFromUser();
      expect(g.requestPermissionCalls, 1);
      expect(g.openSettingsCalls, 1);
    });

    test('denied but the dialog is granted: settings are not opened', () async {
      final g = FakePushGateway(permissionResult: PushPermission.denied, requestResult: PushPermission.authorized);
      final c = await _container(g);
      addTearDown(c.dispose);
      expect(await c.read(pushPermissionPrompterProvider).enableFromUser(), PushPermission.authorized);
      expect(g.openSettingsCalls, 0);
    });

    test('deniedPermanently: opens settings and returns the status', () async {
      final g = FakePushGateway(permissionResult: PushPermission.deniedPermanently, requestResult: PushPermission.deniedPermanently);
      final c = await _container(g);
      addTearDown(c.dispose);
      expect(await c.read(pushPermissionPrompterProvider).enableFromUser(), PushPermission.deniedPermanently);
      expect(g.openSettingsCalls, 1);
    });
  });

  test('pushPermissionProvider reflects the OS status and re-reads when invalidated (return from settings)', () async {
    final g = FakePushGateway(permissionResult: PushPermission.deniedPermanently);
    final c = await _container(g);
    addTearDown(c.dispose);
    c.listen(pushPermissionProvider, (_, _) {});
    expect(await c.read(pushPermissionProvider.future), PushPermission.deniedPermanently);
    g.permissionResult = PushPermission.authorized; // user flipped it in system settings
    c.invalidate(pushPermissionProvider);
    expect(await c.read(pushPermissionProvider.future), PushPermission.authorized);
  });
}
