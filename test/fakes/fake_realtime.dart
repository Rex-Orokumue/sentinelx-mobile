import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:sentinelx_mobile/core/realtime/realtime_hub.dart';
import 'package:sentinelx_mobile/core/realtime/realtime_port.dart';

/// A channel the test drives by hand: statuses, postgres nudges, broadcast payloads and presence syncs.
class FakeChannelPort implements RealtimeChannelPort {
  FakeChannelPort(this.spec);

  final RealtimeChannelSpec spec;
  void Function(PortStatus)? _onStatus;
  void Function()? _onEvent;
  bool subscribeCalled = false;
  bool disposed = false;
  final sent = <({String event, Map<String, dynamic> payload})>[];
  final tracked = <Map<String, dynamic>>[];

  @override
  void subscribe(void Function(PortStatus status) onStatus, void Function() onEvent) {
    subscribeCalled = true;
    _onStatus = onStatus;
    _onEvent = onEvent;
  }

  @override
  Future<void> send(String event, Map<String, dynamic> payload) async => sent.add((event: event, payload: payload));

  @override
  Future<void> track(Map<String, dynamic> payload) async => tracked.add(payload);

  @override
  Future<void> dispose() async => disposed = true;

  // --- test drivers ---
  void emitStatus(PortStatus s) => _onStatus?.call(s);
  void emitEvent() => _onEvent?.call();

  void emitBroadcast(String event, Map<String, dynamic> payload) {
    for (final b in spec.bindings) {
      if (b is BroadcastBinding && b.event == event) b.onPayload(payload);
    }
  }

  void emitPresence(Set<String> keys) {
    for (final b in spec.bindings) {
      if (b is PresenceBinding) b.onSync(keys);
    }
  }
}

class FakeChannelFactory implements RealtimeChannelFactory {
  final created = <FakeChannelPort>[];

  @override
  RealtimeChannelPort create(RealtimeChannelSpec spec) {
    final p = FakeChannelPort(spec);
    created.add(p);
    return p;
  }

  /// Channels created for a topic, oldest first.
  List<FakeChannelPort> forTopic(String topic) => [for (final p in created) if (p.spec.topic == topic) p];

  /// The live (not disposed) channel for a topic, if any.
  FakeChannelPort? live(String topic) {
    for (final p in created.reversed) {
      if (p.spec.topic == topic && !p.disposed) return p;
    }
    return null;
  }
}

class FakeLifecycle implements AppLifecycleSource {
  final _c = StreamController<AppLifecycleState>.broadcast(sync: true);

  @override
  Stream<AppLifecycleState> get changes => _c.stream;

  void push(AppLifecycleState s) => _c.add(s);
}
