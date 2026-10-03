import 'dart:async';

import 'package:sentinelx_mobile/core/notifications/push/push_gateway.dart';
import 'package:sentinelx_mobile/core/notifications/push/push_models.dart';

/// Controllable [PushGateway] for tests. Never touches Firebase.
class FakePushGateway implements PushGateway {
  FakePushGateway({
    this.available = true,
    this.token = 'tok-1',
    this.permissionResult = PushPermission.notDetermined,
    this.requestResult,
    this.initialMessage,
  });

  bool available;
  String? token;
  PushPermission permissionResult;

  /// What a system dialog answers; defaults to [PushPermission.authorized] once asked.
  PushPermission? requestResult;
  PushMessage? initialMessage;

  /// When set, requestPermission waits on it (to model a dialog still on screen).
  Completer<void>? requestGate;

  int requestPermissionCalls = 0;
  int openSettingsCalls = 0;
  List<PushChannelSpec>? createdChannels;
  bool throwOnPermission = false;
  bool throwOnInitialMessage = false;

  final tokenRefresh = StreamController<String>.broadcast();
  final foreground = StreamController<PushMessage>.broadcast();
  final opened = StreamController<PushMessage>.broadcast();

  @override
  bool get isAvailable => available;

  @override
  Future<String?> getToken() async => token;

  @override
  Stream<String> get onTokenRefresh => tokenRefresh.stream;

  @override
  Future<PushPermission> permission() async {
    if (throwOnPermission) throw StateError('permission failed');
    return permissionResult;
  }

  @override
  Future<PushPermission> requestPermission() async {
    requestPermissionCalls++;
    if (requestGate != null) await requestGate!.future;
    permissionResult = requestResult ?? PushPermission.authorized;
    return permissionResult;
  }

  @override
  Stream<PushMessage> get onForegroundMessage => foreground.stream;

  @override
  Stream<PushMessage> get onMessageOpened => opened.stream;

  @override
  Future<PushMessage?> getInitialMessage() async {
    if (throwOnInitialMessage) throw StateError('initial message failed');
    return initialMessage;
  }

  @override
  Future<void> createChannels(List<PushChannelSpec> channels) async => createdChannels = channels;

  @override
  Future<void> openSystemSettings() async => openSettingsCalls++;
}
