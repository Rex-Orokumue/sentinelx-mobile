import 'package:supabase_flutter/supabase_flutter.dart';

/// What a channel listens to. The hub never interprets these; the port wires them to the socket.
sealed class RealtimeBinding {
  const RealtimeBinding();
}

/// A table change. Carries no payload to the app on purpose: realtime is only a nudge, content is always
/// refetched through the API (Phase 5b architecture rule).
class PostgresBinding extends RealtimeBinding {
  const PostgresBinding({
    required this.table,
    this.schema = 'public',
    this.filterColumn,
    this.filterValue,
    this.event = 'all',
  });

  final String table;
  final String schema;
  final String? filterColumn;
  final String? filterValue;

  /// `all` | `insert` | `update` | `delete`.
  final String event;
}

class BroadcastBinding extends RealtimeBinding {
  const BroadcastBinding(this.event, this.onPayload);

  final String event;
  final void Function(Map<String, dynamic> payload) onPayload;
}

class PresenceBinding extends RealtimeBinding {
  const PresenceBinding({required this.key, required this.onSync, this.trackPayload});

  /// Presence key (the viewer's user id).
  final String key;

  /// Called with the presence keys currently on the channel after every sync.
  final void Function(Set<String> keys) onSync;

  /// Tracked by the hub on every `subscribed` status (first join and every rejoin); null = listen only.
  final Map<String, dynamic>? trackPayload;
}

class RealtimeChannelSpec {
  const RealtimeChannelSpec({
    required this.topic,
    this.private = false,
    this.selfBroadcast = false,
    this.presenceKey,
    this.bindings = const [],
  });

  final String topic;
  final bool private;
  final bool selfBroadcast;
  final String? presenceKey;
  final List<RealtimeBinding> bindings;
}

enum PortStatus { subscribed, error, closed, timedOut }

abstract class RealtimeChannelPort {
  /// Joins the channel. [onStatus] reports every status change; [onEvent] fires for each postgres change.
  void subscribe(void Function(PortStatus status) onStatus, void Function() onEvent);

  Future<void> send(String event, Map<String, dynamic> payload);

  Future<void> track(Map<String, dynamic> payload);

  Future<void> dispose();
}

abstract class RealtimeChannelFactory {
  RealtimeChannelPort create(RealtimeChannelSpec spec);
}

PostgresChangeEvent _event(String e) => switch (e) {
      'insert' => PostgresChangeEvent.insert,
      'update' => PostgresChangeEvent.update,
      'delete' => PostgresChangeEvent.delete,
      _ => PostgresChangeEvent.all,
    };

class SupabaseRealtimeChannelFactory implements RealtimeChannelFactory {
  SupabaseRealtimeChannelFactory(this._client);

  final SupabaseClient _client;

  @override
  RealtimeChannelPort create(RealtimeChannelSpec spec) => _SupabasePort(_client, spec);
}

class _SupabasePort implements RealtimeChannelPort {
  _SupabasePort(this._client, this._spec);

  final SupabaseClient _client;
  final RealtimeChannelSpec _spec;
  RealtimeChannel? _channel;

  @override
  void subscribe(void Function(PortStatus status) onStatus, void Function() onEvent) {
    final channel = _client.channel(
      _spec.topic,
      opts: RealtimeChannelConfig(private: _spec.private, self: _spec.selfBroadcast, key: _spec.presenceKey ?? ''),
    );
    for (final b in _spec.bindings) {
      switch (b) {
        case PostgresBinding():
          final column = b.filterColumn;
          final value = b.filterValue;
          channel.onPostgresChanges(
            event: _event(b.event),
            schema: b.schema,
            table: b.table,
            filter: column == null || value == null
                ? null
                : PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: column, value: value),
            callback: (_) => onEvent(),
          );
        case BroadcastBinding():
          channel.onBroadcast(event: b.event, callback: b.onPayload);
        case PresenceBinding():
          channel.onPresenceSync((_) {
            b.onSync({for (final s in channel.presenceState()) s.key});
          });
      }
    }
    _channel = channel;
    channel.subscribe((status, error) {
      onStatus(switch (status) {
        RealtimeSubscribeStatus.subscribed => PortStatus.subscribed,
        RealtimeSubscribeStatus.channelError => PortStatus.error,
        RealtimeSubscribeStatus.closed => PortStatus.closed,
        RealtimeSubscribeStatus.timedOut => PortStatus.timedOut,
      });
    });
  }

  @override
  Future<void> send(String event, Map<String, dynamic> payload) async {
    await _channel?.sendBroadcastMessage(event: event, payload: payload);
  }

  @override
  Future<void> track(Map<String, dynamic> payload) async {
    await _channel?.track(payload);
  }

  @override
  Future<void> dispose() async {
    final c = _channel;
    _channel = null;
    if (c != null) await _client.removeChannel(c);
  }
}
