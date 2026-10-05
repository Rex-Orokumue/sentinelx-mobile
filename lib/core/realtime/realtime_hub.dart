import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import 'realtime_port.dart';

enum RealtimeSignalKind { event, reconnected, resumed }

/// A counter, never `void`: every signal has a new [seq] so every one notifies listeners (Phase 4 lesson 2).
class RealtimeSignal {
  const RealtimeSignal(this.seq, this.kind);

  final int seq;
  final RealtimeSignalKind kind;
}

/// App lifecycle as a stream, so tests can push states without a widget binding.
abstract class AppLifecycleSource {
  Stream<AppLifecycleState> get changes;
}

class WidgetsLifecycleSource with WidgetsBindingObserver implements AppLifecycleSource {
  WidgetsLifecycleSource() {
    WidgetsBinding.instance.addObserver(this);
  }

  final _c = StreamController<AppLifecycleState>.broadcast();

  @override
  Stream<AppLifecycleState> get changes => _c.stream;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) => _c.add(state);

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _c.close();
  }
}

/// 2 s, 4 s, 8 s ... capped at 30 s.
Duration defaultRealtimeBackoff(int attempt) => Duration(seconds: math.min(30, 2 << math.min(attempt, 8)));

class RealtimeHub {
  RealtimeHub({
    required RealtimeChannelFactory factory,
    required AppLifecycleSource lifecycle,
    Duration Function(int attempt)? backoff,
  })  : _factory = factory,
        _backoff = backoff ?? defaultRealtimeBackoff {
    _lifecycleSub = lifecycle.changes.listen(_onLifecycle);
  }

  final RealtimeChannelFactory _factory;
  final Duration Function(int attempt) _backoff;
  final _handles = <_Handle>{};
  StreamSubscription<AppLifecycleState>? _lifecycleSub;

  /// One managed channel per call. Nothing connects until [RealtimeHandle.signals] is listened to;
  /// cancelling that subscription (or calling [RealtimeHandle.close]) disposes the channel.
  /// Signals are NOT debounced here: see [debouncedSignals].
  RealtimeHandle open(RealtimeChannelSpec spec) => _Handle(this, spec);

  void _onLifecycle(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        for (final h in _handles.toList()) {
          h._pause();
        }
      case AppLifecycleState.resumed:
        for (final h in _handles.toList()) {
          h._resume();
        }
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        break;
    }
  }

  Future<void> dispose() async {
    await _lifecycleSub?.cancel();
    _lifecycleSub = null;
    for (final h in _handles.toList()) {
      await h.close();
    }
  }
}

abstract class RealtimeHandle {
  Stream<RealtimeSignal> get signals;

  /// Best-effort: dropped (never throws) while the channel is not subscribed.
  Future<void> send(String event, Map<String, dynamic> payload);

  Future<void> close();
}

class _Handle implements RealtimeHandle {
  _Handle(this._hub, this._spec) {
    _controller = StreamController<RealtimeSignal>.broadcast(sync: true, onListen: _onListen, onCancel: close);
  }

  final RealtimeHub _hub;
  final RealtimeChannelSpec _spec;
  late final StreamController<RealtimeSignal> _controller;
  RealtimeChannelPort? _port;
  Timer? _retry;
  var _seq = 0;
  var _attempt = 0;
  var _everSubscribed = false;
  var _subscribed = false;
  var _paused = false;
  var _closed = false;

  @override
  Stream<RealtimeSignal> get signals => _controller.stream;

  void _onListen() {
    _hub._handles.add(this);
    _connect();
  }

  void _emit(RealtimeSignalKind kind) {
    if (_closed || _controller.isClosed) return;
    _controller.add(RealtimeSignal(++_seq, kind));
  }

  void _connect() {
    if (_closed || _paused || _port != null) return;
    final port = _hub._factory.create(_spec);
    _port = port;
    port.subscribe((status) => _onStatus(port, status), () {
      if (identical(_port, port)) _emit(RealtimeSignalKind.event);
    });
  }

  void _onStatus(RealtimeChannelPort port, PortStatus status) {
    if (_closed || !identical(_port, port)) return;
    switch (status) {
      case PortStatus.subscribed:
        _attempt = 0;
        _subscribed = true;
        final reconnected = _everSubscribed;
        _everSubscribed = true;
        for (final b in _spec.bindings) {
          if (b is PresenceBinding && b.trackPayload != null) _swallow(port.track(b.trackPayload!));
        }
        if (reconnected) _emit(RealtimeSignalKind.reconnected);
      case PortStatus.error:
      case PortStatus.closed:
      case PortStatus.timedOut:
        _dropPort();
        if (_paused) return;
        _retry?.cancel();
        _retry = Timer(_hub._backoff(_attempt++), () {
          _retry = null;
          _connect();
        });
    }
  }

  void _dropPort() {
    final port = _port;
    _port = null;
    _subscribed = false;
    if (port != null) _swallow(port.dispose());
  }

  void _pause() {
    if (_closed) return;
    _paused = true;
    _retry?.cancel();
    _retry = null;
    _dropPort();
  }

  void _resume() {
    if (_closed || !_paused) return;
    _paused = false;
    _attempt = 0;
    _connect();
    _emit(RealtimeSignalKind.resumed);
  }

  @override
  Future<void> send(String event, Map<String, dynamic> payload) async {
    final port = _port;
    if (_closed || port == null || !_subscribed) return;
    try {
      await port.send(event, payload);
    } catch (_) {
      // typing and other broadcasts are best-effort
    }
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _retry?.cancel();
    _retry = null;
    _hub._handles.remove(this);
    final port = _port;
    _port = null;
    _subscribed = false;
    if (port != null) await port.dispose();
    if (!_controller.isClosed) unawaited(_controller.close());
  }
}

void _swallow(Future<void> f) {
  f.catchError((_) {});
}

/// Coalesces a burst of signals into one (matches the web's 400 ms coalesce), keeping the strongest kind:
/// `reconnected`/`resumed` win over `event` inside one window. Each emission gets a fresh `seq`.
Stream<RealtimeSignal> debouncedSignals(
  Stream<RealtimeSignal> source, {
  Duration debounce = const Duration(milliseconds: 400),
}) {
  late StreamController<RealtimeSignal> controller;
  StreamSubscription<RealtimeSignal>? sub;
  Timer? timer;
  RealtimeSignalKind? pending;
  var seq = 0;
  controller = StreamController<RealtimeSignal>.broadcast(
    onListen: () {
      sub = source.listen((s) {
        if (pending == null || pending == RealtimeSignalKind.event) {
          pending = s.kind;
        } else if (s.kind != RealtimeSignalKind.event) {
          pending = s.kind;
        }
        timer?.cancel();
        timer = Timer(debounce, () {
          final kind = pending;
          pending = null;
          if (kind != null && !controller.isClosed) controller.add(RealtimeSignal(++seq, kind));
        });
      });
    },
    onCancel: () {
      timer?.cancel();
      sub?.cancel();
      sub = null;
      pending = null;
    },
  );
  return controller.stream;
}

final realtimeHubProvider = Provider<RealtimeHub>((ref) {
  final lifecycle = WidgetsLifecycleSource();
  final hub = RealtimeHub(factory: SupabaseRealtimeChannelFactory(ref.watch(supabaseClientProvider)), lifecycle: lifecycle);
  ref.onDispose(() {
    hub.dispose();
    lifecycle.dispose();
  });
  return hub;
});
