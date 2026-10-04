import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'push_models.dart';

/// Everything the app needs from the OS push stack. Only [FirebasePushGateway] knows about Firebase;
/// the rest of the app (and every test) talks to this interface.
abstract class PushGateway {
  /// False when Firebase could not be initialized (no config file, tests, iOS without a plist). Every
  /// caller must treat an unavailable gateway as "push is off", never as an error.
  bool get isAvailable;

  Future<String?> getToken();

  /// Invalidates this install's FCM token (the next [getToken] mints a new one). Best-effort: never throws.
  Future<void> deleteToken();
  Stream<String> get onTokenRefresh;

  Future<PushPermission> permission();
  Future<PushPermission> requestPermission();

  /// A push that arrived while the app is in the foreground (the OS shows nothing for these).
  Stream<PushMessage> get onForegroundMessage;

  /// A notification tapped while the app was in the background.
  Stream<PushMessage> get onMessageOpened;

  /// The notification whose tap launched the app from a terminated state, if any.
  Future<PushMessage?> getInitialMessage();

  Future<void> createChannels(List<PushChannelSpec> channels);
  Future<void> openSystemSettings();
}

class DisabledPushGateway implements PushGateway {
  const DisabledPushGateway();

  @override
  bool get isAvailable => false;
  @override
  Future<String?> getToken() async => null;
  @override
  Future<void> deleteToken() async {}
  @override
  Stream<String> get onTokenRefresh => const Stream.empty();
  @override
  Future<PushPermission> permission() async => PushPermission.denied;
  @override
  Future<PushPermission> requestPermission() async => PushPermission.denied;
  @override
  Stream<PushMessage> get onForegroundMessage => const Stream.empty();
  @override
  Stream<PushMessage> get onMessageOpened => const Stream.empty();
  @override
  Future<PushMessage?> getInitialMessage() async => null;
  @override
  Future<void> createChannels(List<PushChannelSpec> channels) async {}
  @override
  Future<void> openSystemSettings() async {}
}

/// Overridden in main() with the Firebase gateway (or [DisabledPushGateway] when init fails) and by
/// tests with a fake. The default is disabled so a test that does not care never touches Firebase.
final pushGatewayProvider = Provider<PushGateway>((ref) => const DisabledPushGateway());
