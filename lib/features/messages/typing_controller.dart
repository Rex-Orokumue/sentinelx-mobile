import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/realtime/realtime_hub.dart';
import '../../core/realtime/realtime_port.dart';
import 'inbox_providers.dart';
import 'thread_providers.dart';

const kTypingSendInterval = Duration(seconds: 3);
const kTypingExpire = Duration(seconds: 5);

/// Per-thread PRIVATE broadcast channel, event `typing`, payload `{userId}`. Never the `dm-online` presence
/// channel, and never stored anywhere.
String typingTopic(String threadId) => 'dm-typing:$threadId';

/// Sends at most one typing event per [kTypingSendInterval] however fast the player types.
class TypingSender {
  TypingSender(this._now, this._send);

  final DateTime Function() _now;
  final void Function() _send;
  DateTime? _last;

  void keystroke() {
    final now = _now();
    final last = _last;
    if (last != null && now.difference(last) < kTypingSendInterval) return;
    _last = now;
    _send();
  }
}

/// Who is typing: true for [kTypingExpire] after the last event from that user.
class TypingTracker {
  TypingTracker(this._now);

  final DateTime Function() _now;
  final _last = <String, DateTime>{};

  void onEvent(String userId) => _last[userId] = _now();

  bool isTyping(String userId) {
    final at = _last[userId];
    return at != null && _now().difference(at) < kTypingExpire;
  }

  void clear() => _last.clear();
}

/// [enabled] is `request accepted (or unknown) && not blocked either way && app resumed && screen visible`:
/// when false NO channel is opened (a pending request or a block must never reveal typing).
class ThreadTypingArgs {
  const ThreadTypingArgs({required this.threadId, required this.otherId, required this.enabled});

  final String threadId;
  final String otherId;
  final bool enabled;

  @override
  bool operator ==(Object other) =>
      other is ThreadTypingArgs && other.threadId == threadId && other.otherId == otherId && other.enabled == enabled;

  @override
  int get hashCode => Object.hash(threadId, otherId, enabled);
}

/// One channel per open thread, shared by the indicator (receive) and the composer (send).
class TypingChannel {
  TypingChannel._(this._handle, this._viewer, this._other, this._now) {
    _tracker = TypingTracker(_now);
    _sender = TypingSender(_now, () => unawaited(_handle.send('typing', {'userId': _viewer})));
  }

  final RealtimeHandle _handle;
  final String _viewer;
  final String _other;
  final DateTime Function() _now;
  late final TypingTracker _tracker;
  late final TypingSender _sender;
  final _controller = StreamController<bool>.broadcast();
  Timer? _ticker;
  StreamSubscription<RealtimeSignal>? _signals;
  var _typing = false;

  Stream<bool> get typing => _controller.stream;

  void keystroke() => _sender.keystroke();

  void _set(bool v) {
    if (_typing == v || _controller.isClosed) return;
    _typing = v;
    _controller.add(v);
  }

  void _onEvent(Map<String, dynamic> payload) {
    // Tolerate both the bare payload and the full broadcast envelope.
    final inner = payload['payload'];
    final body = inner is Map ? inner : payload;
    final id = body['userId'];
    if (id is! String || id == _viewer || id != _other) return;
    _tracker.onEvent(id);
    _set(true);
    _ticker ??= Timer.periodic(const Duration(seconds: 1), (_) {
      if (!_tracker.isTyping(_other)) {
        _set(false);
        _ticker?.cancel();
        _ticker = null;
      }
    });
  }

  void _reset() {
    _tracker.clear();
    _ticker?.cancel();
    _ticker = null;
    _set(false);
  }

  Future<void> dispose() async {
    _ticker?.cancel();
    await _signals?.cancel();
    await _handle.close();
    await _controller.close();
  }
}

final typingChannelProvider = Provider.autoDispose.family<TypingChannel?, ThreadTypingArgs>((ref, args) {
  if (!args.enabled) return null;
  final viewer = ref.watch(dmViewerIdProvider).asData?.value;
  if (viewer == null) return null;
  late final TypingChannel channel;
  final handle = ref.watch(realtimeHubProvider).open(
        RealtimeChannelSpec(
          topic: typingTopic(args.threadId),
          private: true,
          selfBroadcast: false,
          bindings: [BroadcastBinding('typing', (payload) => channel._onEvent(payload))],
        ),
      );
  channel = TypingChannel._(handle, viewer, args.otherId, ref.read(dmClockProvider));
  // Listening is what opens the channel; a reconnect or resume forgets who was typing.
  channel._signals = handle.signals.listen((s) {
    if (s.kind != RealtimeSignalKind.event) channel._reset();
  });
  ref.onDispose(() => unawaited(channel.dispose()));
  return channel;
});

/// True while the OTHER player is typing in this thread.
final threadTypingProvider = StreamProvider.autoDispose.family<bool, ThreadTypingArgs>((ref, args) {
  final channel = ref.watch(typingChannelProvider(args));
  return channel?.typing ?? Stream.value(false);
});

/// The composer calls this on every text change; it throttles to one event per 3 s and is a no-op when typing
/// is disabled for the thread.
final typingNotifierProvider = Provider.autoDispose.family<void Function(), ThreadTypingArgs>((ref, args) {
  final channel = ref.watch(typingChannelProvider(args));
  return channel == null ? () {} : channel.keystroke;
});
