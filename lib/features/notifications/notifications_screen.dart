import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_client.dart';
import '../../core/api/notifications_models.dart';
import '../../core/l10n/gen/app_localizations.dart';
import '../../core/routing/web_links.dart';
import '../../core/theme/sx_colors.dart';
import 'notification_error_copy.dart';
import 'notification_models.dart';
import 'notification_prefs_providers.dart';
import 'notifications_providers.dart';
import 'notifications_repository.dart';
import 'push_permission_row.dart';
import 'relative_time.dart';

/// The in-app bell, at `/notifications`. Rows are read straight from `player_notifications` (owner RLS +
/// realtime); every write goes through the API.
class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  final _scroll = ScrollController();
  bool _markingAll = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_maybeLoadMore);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _maybeLoadMore() {
    if (_scroll.hasClients && _scroll.position.extentAfter < 300) {
      unawaited(ref.read(notificationsProvider.notifier).loadMore());
    }
  }

  void _say(ScaffoldMessengerState messenger, String text) {
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _open(BellNotification n) async {
    // Everything that needs `ref`/`context` is resolved before the first await (a disposed widget's must not
    // be used afterwards).
    final notifier = ref.read(notificationsProvider.notifier);
    final messenger = ScaffoldMessenger.of(context);
    final failed = AppLocalizations.of(context).ntfActionFailed;
    final router = GoRouter.of(context);
    final link = n.link;
    final destination = link == null ? null : resolveWebLink(link);
    final pending = notifier.markRead(n.id);
    if (destination != null) unawaited(router.push<void>(destination));
    if (!await pending) _say(messenger, failed);
  }

  Future<void> _markAll() async {
    final notifier = ref.read(notificationsProvider.notifier);
    final messenger = ScaffoldMessenger.of(context);
    final failed = AppLocalizations.of(context).ntfActionFailed;
    setState(() => _markingAll = true);
    final ok = await notifier.markAllRead();
    if (mounted) setState(() => _markingAll = false);
    if (!ok) _say(messenger, failed);
  }

  Future<MuteDuration?> _askDuration() => showModalBottomSheet<MuteDuration>(
        context: context,
        builder: (sheet) {
          final l10n = AppLocalizations.of(sheet);
          return SafeArea(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              ListTile(key: const Key('ntf-mute-1h'), title: Text(l10n.ntfMuteFor1h), onTap: () => Navigator.pop(sheet, MuteDuration.oneHour)),
              ListTile(key: const Key('ntf-mute-1w'), title: Text(l10n.ntfMuteFor1w), onTap: () => Navigator.pop(sheet, MuteDuration.oneWeek)),
              ListTile(key: const Key('ntf-mute-always'), title: Text(l10n.ntfMuteAlways), onTap: () => Navigator.pop(sheet, MuteDuration.always)),
            ]),
          );
        },
      );

  Future<void> _menu(BellNotification n, String choice) async {
    final repo = ref.read(notificationsRepositoryProvider);
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    final container = ProviderScope.containerOf(context);
    try {
      final String done;
      switch (choice) {
        case 'mute-thread':
          final d = await _askDuration();
          if (d == null) return;
          await repo.mutePost(n.postId!, d);
          done = l10n.ntfMuted;
        case 'unmute-thread':
          await repo.unmutePost(n.postId!);
          done = l10n.ntfUnmuted;
        case 'mute-type':
          final d = await _askDuration();
          if (d == null) return;
          await repo.muteType(n.type, d);
          done = l10n.ntfMuted;
        default:
          await repo.unmuteType(n.type);
          done = l10n.ntfUnmuted;
      }
      container.invalidate(notificationMutesProvider);
      container.invalidate(notificationPrefsProvider);
      _say(messenger, done);
    } on ApiException catch (e) {
      _say(messenger, notificationErrorCopy(l10n, e.code));
    } catch (_) {
      _say(messenger, l10n.ntfActionFailed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final viewer = ref.watch(notificationsViewerIdProvider);
    final async = ref.watch(notificationsProvider);
    final unread = async.asData?.value.unreadCount ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.ntfTitle),
        actions: [
          TextButton(
            key: const Key('ntf-mark-all'),
            onPressed: unread > 0 && !_markingAll ? _markAll : null,
            child: Text(l10n.ntfMarkAllRead),
          ),
        ],
      ),
      body: _body(context, l10n, viewer, async),
    );
  }

  Widget _body(BuildContext context, AppLocalizations l10n, AsyncValue<String?> viewer, AsyncValue<BellState> async) {
    if (viewer.hasValue && viewer.value == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(l10n.ntfSignedOut, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(key: const Key('ntf-login'), onPressed: () => context.push('/login'), child: Text(l10n.ntfLogIn)),
          ]),
        ),
      );
    }
    if (async.hasError && !async.hasValue) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(l10n.ntfLoadError, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton(key: const Key('ntf-retry'), onPressed: () => ref.invalidate(notificationsProvider), child: Text(l10n.ntfRetry)),
          ]),
        ),
      );
    }
    final state = async.asData?.value;
    if (state == null) return const Center(child: CircularProgressIndicator());

    final mutes = ref.watch(notificationMutesProvider).asData?.value;
    final prefs = ref.watch(notificationPrefsProvider).asData?.value;
    final now = DateTime.now();

    if (state.items.isEmpty) {
      return RefreshIndicator(
        onRefresh: () => ref.read(notificationsProvider.notifier).refresh(),
        child: ListView(
          controller: _scroll,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          children: [
            const SizedBox(height: 48),
            const Icon(Icons.notifications_none, size: 48, color: SxColors.textSecondary),
            const SizedBox(height: 12),
            Text(l10n.ntfEmptyTitle, textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(l10n.ntfEmptyBody, textAlign: TextAlign.center, style: const TextStyle(color: SxColors.textSecondary)),
            const SizedBox(height: 16),
            const PushPermissionRow(),
          ],
        ),
      );
    }

    final unread = state.unreadCount;
    return RefreshIndicator(
      onRefresh: () => ref.read(notificationsProvider.notifier).refresh(),
      child: ListView.builder(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: state.items.length + 1 + (state.loadingMore ? 1 : 0),
        itemBuilder: (context, i) {
          if (i == 0) {
            return unread == 0
                ? const SizedBox(height: 4)
                : Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                    child: Text(l10n.ntfUnreadCount(unread), key: const Key('ntf-unread-header'), style: const TextStyle(color: SxColors.textSecondary)),
                  );
          }
          final index = i - 1;
          if (index >= state.items.length) {
            return const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator()));
          }
          final n = state.items[index];
          return _row(context, l10n, n, mutes, prefs, now);
        },
      ),
    );
  }

  Widget _row(BuildContext context, AppLocalizations l10n, BellNotification n, NotificationMutes? mutes, NotificationPrefs? prefs, DateTime now) {
    final threadMuted = n.postId != null && (mutes?.isPostMuted(n.postId!, now) ?? false);
    final typeMuted = n.typeMutable && isTypeSilenced(n.type, prefs: prefs, mutes: mutes, now: now);
    final entries = <PopupMenuEntry<String>>[
      if (n.postId != null)
        PopupMenuItem(value: threadMuted ? 'unmute-thread' : 'mute-thread', child: Text(threadMuted ? l10n.ntfUnmuteThread : l10n.ntfMuteThread)),
      if (n.typeMutable)
        PopupMenuItem(value: typeMuted ? 'unmute-type' : 'mute-type', child: Text(typeMuted ? l10n.ntfUnmuteType : l10n.ntfMuteType)),
    ];
    return ListTile(
      key: Key('ntf-row-${n.id}'),
      onTap: () => _open(n),
      leading: SizedBox(
        width: 12,
        child: n.read ? null : Center(child: Container(key: Key('ntf-dot-${n.id}'), width: 10, height: 10, decoration: const BoxDecoration(color: SxColors.primary, shape: BoxShape.circle))),
      ),
      title: Text(n.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: n.read ? FontWeight.w400 : FontWeight.w700)),
      subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (n.body.isNotEmpty) Text(n.body, maxLines: 3, overflow: TextOverflow.ellipsis),
        Text(relativeTime(l10n, n.createdAt, now), style: const TextStyle(color: SxColors.textSecondary, fontSize: 12)),
      ]),
      trailing: entries.isEmpty
          ? null
          : PopupMenuButton<String>(
              key: Key('ntf-menu-${n.id}'),
              onSelected: (choice) => _menu(n, choice),
              itemBuilder: (_) => entries,
            ),
    );
  }
}
