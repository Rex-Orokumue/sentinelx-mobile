import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/providers.dart';

/// Merges several change streams into one signal, debounced (matches web's own 400ms coalesce,
/// spec §7). A feature-internal helper for the feed and post-detail screens — not the general-
/// purpose cross-app channel manager `unread_counts.dart` defers until DMs exist (see this plan's
/// Global Constraints "Realtime architecture decision").
Stream<void> debouncedChangeSignal(List<Stream<dynamic>> sources, {Duration debounce = const Duration(milliseconds: 400)}) {
  late StreamController<void> controller;
  Timer? timer;
  final subs = <StreamSubscription<dynamic>>[];
  controller = StreamController<void>.broadcast(
    onListen: () {
      for (final s in sources) {
        subs.add(s.listen((_) {
          timer?.cancel();
          timer = Timer(debounce, () {
            if (!controller.isClosed) controller.add(null);
          });
        }));
      }
    },
    onCancel: () {
      timer?.cancel();
      for (final s in subs) {
        s.cancel();
      }
      subs.clear();
    },
  );
  return controller.stream;
}

Stream<void> _channel(
  SupabaseClient client,
  String name,
  String table, {
  PostgresChangeEvent event = PostgresChangeEvent.all,
  PostgresChangeFilter? filter,
}) {
  late StreamController<void> controller;
  RealtimeChannel? channel;
  controller = StreamController<void>.broadcast(
    onListen: () {
      channel = client.channel(name)
        ..onPostgresChanges(event: event, schema: 'public', table: table, filter: filter, callback: (_) => controller.add(null))
        ..subscribe();
    },
    onCancel: () async {
      final c = channel;
      channel = null;
      if (c != null) await client.removeChannel(c);
    },
  );
  return controller.stream;
}

/// Feed screen: new post, any reaction, any comment (count badges live on the feed too), any
/// status appearing/expiring-by-deletion. Unfiltered — spec §7.
Stream<void> feedChangeSignal(SupabaseClient client) => debouncedChangeSignal([
      _channel(client, 'cmt-feed-posts', 'community_posts', event: PostgresChangeEvent.insert),
      _channel(client, 'cmt-feed-reactions', 'post_reactions'),
      _channel(client, 'cmt-feed-comments', 'post_comments'),
      _channel(client, 'cmt-feed-statuses-ins', 'player_statuses', event: PostgresChangeEvent.insert),
      _channel(client, 'cmt-feed-statuses-del', 'player_statuses', event: PostgresChangeEvent.delete),
    ]);

/// Post-detail screen: comments and reactions for this one post only — spec §7.
Stream<void> postDetailChangeSignal(SupabaseClient client, String postId) => debouncedChangeSignal([
      _channel(client, 'cmt-detail-comments-$postId', 'post_comments',
          filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'post_id', value: postId)),
      _channel(client, 'cmt-detail-reactions-$postId', 'post_reactions',
          filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'post_id', value: postId)),
    ]);

/// Numbers each event. `StreamProvider<void>` can't be used directly: every `null` is equal to the
/// last, so Riverpod would notify listeners for the first event only and silently drop the rest.
Stream<int> tickSignal(Stream<void> source) {
  var tick = 0;
  return source.map((_) => ++tick);
}

final communityFeedRealtimeProvider = StreamProvider.autoDispose<int>((ref) => tickSignal(feedChangeSignal(ref.watch(supabaseClientProvider))));
final communityPostDetailRealtimeProvider =
    StreamProvider.autoDispose.family<int, String>((ref, postId) => tickSignal(postDetailChangeSignal(ref.watch(supabaseClientProvider), postId)));
