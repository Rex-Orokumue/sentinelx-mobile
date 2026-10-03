import 'dart:async';

import 'package:app_settings/app_settings.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'push_gateway.dart';
import 'push_models.dart';

/// The only file that imports the Firebase / local-notifications / app-settings plugins.
///
/// No Dart background-message handler is registered on purpose: the server sends Android pushes with a
/// top-level `notification` block, which the OS displays itself when the app is backgrounded or killed.
/// `flutter_local_notifications` is used for channel creation only; its own permission API is never
/// called (firebase_messaging owns the Android 13+ dialog).
class FirebasePushGateway implements PushGateway {
  FirebasePushGateway._(this._messaging, this._local);

  final FirebaseMessaging _messaging;
  final FlutterLocalNotificationsPlugin _local;

  /// Never throws. Any failure (no google-services.json, no plist, a plugin error, a hang) yields the
  /// disabled gateway and the app starts normally with push off.
  static Future<PushGateway> tryInitialize() async {
    try {
      await Firebase.initializeApp().timeout(const Duration(seconds: 10));
      return FirebasePushGateway._(FirebaseMessaging.instance, FlutterLocalNotificationsPlugin());
    } catch (error) {
      debugPrint('Push disabled: Firebase could not initialize ($error)');
      return const DisabledPushGateway();
    }
  }

  @override
  bool get isAvailable => true;

  @override
  Future<String?> getToken() async {
    try {
      return await _messaging.getToken();
    } catch (_) {
      return null;
    }
  }

  @override
  Stream<String> get onTokenRefresh => _messaging.onTokenRefresh;

  PushPermission _map(AuthorizationStatus s) => switch (s) {
        AuthorizationStatus.authorized || AuthorizationStatus.provisional => PushPermission.authorized,
        AuthorizationStatus.notDetermined => PushPermission.notDetermined,
        AuthorizationStatus.denied => PushPermission.denied,
        AuthorizationStatus.deniedPermanently => PushPermission.deniedPermanently,
      };

  @override
  Future<PushPermission> permission() async {
    try {
      return _map((await _messaging.getNotificationSettings()).authorizationStatus);
    } catch (_) {
      return PushPermission.denied;
    }
  }

  @override
  Future<PushPermission> requestPermission() async {
    try {
      return _map((await _messaging.requestPermission()).authorizationStatus);
    } catch (_) {
      return PushPermission.denied;
    }
  }

  PushMessage _toMessage(RemoteMessage m) => PushMessage.fromData(
        m.data,
        title: m.notification?.title,
        body: m.notification?.body,
      );

  @override
  Stream<PushMessage> get onForegroundMessage => FirebaseMessaging.onMessage.map(_toMessage);

  @override
  Stream<PushMessage> get onMessageOpened => FirebaseMessaging.onMessageOpenedApp.map(_toMessage);

  @override
  Future<PushMessage?> getInitialMessage() async {
    try {
      final m = await _messaging.getInitialMessage();
      return m == null ? null : _toMessage(m);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> createChannels(List<PushChannelSpec> channels) async {
    try {
      final android = _local.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (android == null) return;
      for (final c in channels) {
        await android.createNotificationChannel(AndroidNotificationChannel(
          c.id,
          c.name,
          description: c.description,
          importance: c.highImportance ? Importance.high : Importance.defaultImportance,
        ));
      }
    } catch (error) {
      debugPrint('Could not create notification channels ($error)');
    }
  }

  @override
  Future<void> openSystemSettings() async {
    try {
      await AppSettings.openAppSettings(type: AppSettingsType.notification);
    } catch (_) {}
  }
}
