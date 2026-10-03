import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../providers.dart';
import 'push_gateway.dart';

String get _platform => defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android';

/// Keeps this device's FCM token registered against the signed-in user (POST /devices; the server moves a
/// token that changes accounts). Owned by app startup, like SessionLifecycle.
///
/// - Registers once per signed-in user id (a Supabase token refresh re-emits a new Session for the same id
///   and must not re-register), and again when the FCM token itself refreshes.
/// - Registers regardless of notification permission: the server sends, the OS drops what the user turned
///   off, and enabling later then needs no re-registration.
/// - A failed registration clears the guard so the next session/token event retries.
class PushRegistration {
  PushRegistration(this._ref) {
    _sessionSub = _ref.listen<AsyncValue<Session?>>(sessionProvider, _onSession, fireImmediately: true);
    _tokenSub = _ref.read(pushGatewayProvider).onTokenRefresh.listen(_onTokenRefresh, onError: (Object _) {});
  }

  final Ref _ref;
  late final ProviderSubscription<AsyncValue<Session?>> _sessionSub;
  late final StreamSubscription<String> _tokenSub;

  String? _userId;
  String? _registeredFor;
  String? _token;

  /// Set by [unregister] so a token-refresh event between "device deleted" and "session cleared" cannot
  /// quietly re-register the phone for the user who is signing out. Reset when the session ends or by
  /// [reregister] (used when the sign-out itself failed).
  bool _suppressed = false;

  void _onSession(AsyncValue<Session?>? previous, AsyncValue<Session?> next) {
    final id = next.asData?.value?.user.id;
    if (id != _userId) _suppressed = false;
    _userId = id;
    if (id == null) {
      _registeredFor = null;
      return;
    }
    if (_registeredFor == id || _suppressed) return;
    _registeredFor = id;
    unawaited(_register(id));
  }

  Future<void> _register(String userId) async {
    final gateway = _ref.read(pushGatewayProvider);
    if (!gateway.isAvailable) return;
    try {
      final token = await gateway.getToken();
      if (token == null) {
        if (_registeredFor == userId) _registeredFor = null;
        return;
      }
      _token = token;
      if (_userId != userId || _suppressed) return; // the user changed while we waited
      await _send(token);
    } catch (_) {
      if (_registeredFor == userId) _registeredFor = null; // retry on the next session/token event
    }
  }

  Future<void> _send(String token) => _ref.read(apiClientProvider).registerDevice(
        token: token,
        platform: _platform,
        appVersion: _ref.read(installedVersionProvider),
      );

  Future<void> _onTokenRefresh(String token) async {
    _token = token;
    final userId = _userId;
    if (userId == null || _suppressed || !_ref.read(pushGatewayProvider).isAvailable) return;
    try {
      await _send(token);
      _registeredFor = userId;
    } catch (_) {
      if (_registeredFor == userId) _registeredFor = null;
    }
  }

  /// Best-effort DELETE /devices for this token, called before sign-out. Never throws and never takes
  /// longer than 5 seconds: a stale token is cleaned up by the sender when FCM rejects it, so a failure
  /// here must not block signing out.
  Future<void> unregister() async {
    final gateway = _ref.read(pushGatewayProvider);
    if (!gateway.isAvailable) return;
    _suppressed = true;
    try {
      final token = _token ?? await gateway.getToken();
      if (token == null) return;
      await _ref.read(apiClientProvider).unregisterDevice(token).timeout(const Duration(seconds: 5));
    } catch (_) {
      // swallowed on purpose
    } finally {
      _registeredFor = null;
    }
  }

  /// Undoes [unregister] when signing out did not go through: the user is still signed in and must keep
  /// receiving pushes.
  Future<void> reregister() async {
    _suppressed = false;
    final id = _userId;
    if (id == null || _registeredFor == id) return;
    _registeredFor = id;
    await _register(id);
  }

  void dispose() {
    _sessionSub.close();
    _tokenSub.cancel();
  }
}

final pushRegistrationProvider = Provider<PushRegistration>((ref) {
  final registration = PushRegistration(ref);
  ref.onDispose(registration.dispose);
  return registration;
});
