import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/messages_models.dart';
import '../../core/l10n/gen/app_localizations.dart';
import '../../core/theme/sx_colors.dart';
import '../notifications/relative_time.dart';
import 'inbox_providers.dart';
import 'online_dot.dart';
import 'presence_providers.dart';
import 'stickers.dart';

/// `/messages`: the player's conversations. Every read goes through the API (never PostgREST); realtime only
/// nudges a refetch of the window already loaded.
class InboxScreen extends StatelessWidget {
  const InboxScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.dmInboxTitle)),
      body: ThreadListBody(provider: inboxProvider, requestsBox: false),
    );
  }
}

/// The one-line preview under a conversation's name. Unknown kinds (a newer server) and unknown sticker ids
/// degrade to the generic label, never an error.
String threadPreviewText(AppLocalizations l10n, ThreadSummary t) {
  if (t.requestState == RequestState.pending && t.direction == RequestDirection.outgoing) {
    return l10n.dmWaitingFor(t.other.displayName);
  }
  return switch (t.preview.kind) {
    PreviewKind.text => t.preview.text ?? l10n.dmPreviewOther,
    PreviewKind.image => l10n.dmPreviewPhoto,
    PreviewKind.sticker => stickerById(t.preview.stickerId ?? '')?.emoji ?? l10n.dmPreviewOther,
    PreviewKind.voice => l10n.dmPreviewVoice,
    PreviewKind.removed => l10n.dmPreviewRemoved,
    PreviewKind.unknown => l10n.dmPreviewOther,
  };
}

class ThreadListBody extends ConsumerStatefulWidget {
  const ThreadListBody({super.key, required this.provider, required this.requestsBox});

  final AsyncNotifierProvider<InboxNotifier, InboxState> provider;
  final bool requestsBox;

  @override
  ConsumerState<ThreadListBody> createState() => _ThreadListBodyState();
}

class _ThreadListBodyState extends ConsumerState<ThreadListBody> {
  final _scroll = ScrollController();

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
      unawaited(ref.read(widget.provider.notifier).loadMore());
    }
  }

  Future<void> _refresh() async {
    final messenger = ScaffoldMessenger.of(context);
    final failed = AppLocalizations.of(context).dmLoadError;
    final ok = await ref.read(widget.provider.notifier).refresh();
    if (!ok) {
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(SnackBar(content: Text(failed)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final viewer = ref.watch(dmViewerIdProvider);
    final async = ref.watch(widget.provider);

    if (viewer.hasValue && viewer.value == null) {
      return _Centered(children: [
        Text(l10n.dmSignedOut, textAlign: TextAlign.center),
        const SizedBox(height: 12),
        FilledButton(key: const Key('dm-login'), onPressed: () => context.push('/login'), child: Text(l10n.dmLogIn)),
      ]);
    }
    if (async.hasError && !async.hasValue) {
      return _Centered(children: [
        Text(l10n.dmLoadError, textAlign: TextAlign.center),
        const SizedBox(height: 12),
        OutlinedButton(key: const Key('dm-retry'), onPressed: () => ref.invalidate(widget.provider), child: Text(l10n.dmRetry)),
      ]);
    }
    final state = async.asData?.value;
    if (state == null) return const Center(child: CircularProgressIndicator());

    final showRequestsRow = !widget.requestsBox && state.requestCount > 0;
    final now = DateTime.now();

    if (state.threads.isEmpty) {
      return RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          controller: _scroll,
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            if (showRequestsRow) _RequestsRow(count: state.requestCount),
            Padding(
              key: const Key('dm-empty'),
              padding: const EdgeInsets.all(32),
              child: Column(children: [
                const SizedBox(height: 32),
                const Icon(Icons.mail_outline, size: 48, color: SxColors.textSecondary),
                const SizedBox(height: 12),
                Text(
                  widget.requestsBox ? l10n.dmEmptyRequests : l10n.dmEmptyInbox,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: SxColors.textSecondary),
                ),
              ]),
            ),
          ],
        ),
      );
    }

    final lead = showRequestsRow ? 1 : 0;
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.builder(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: lead + state.threads.length + (state.loadingMore ? 1 : 0),
        itemBuilder: (context, i) {
          if (i < lead) return _RequestsRow(count: state.requestCount);
          final index = i - lead;
          if (index >= state.threads.length) {
            return const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator()));
          }
          return ThreadRow(thread: state.threads[index], now: now);
        },
      ),
    );
  }
}

class _Centered extends StatelessWidget {
  const _Centered({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: children)),
      );
}

class _RequestsRow extends StatelessWidget {
  const _RequestsRow({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ListTile(
      key: const Key('dm-requests-row'),
      leading: const Icon(Icons.mark_email_unread_outlined),
      title: Text(l10n.dmRequestsRow(count), maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => context.push('/messages/requests'),
    );
  }
}

class ThreadRow extends ConsumerWidget {
  const ThreadRow({super.key, required this.thread, required this.now});

  final ThreadSummary thread;
  final DateTime now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final t = thread;
    final online = ref.watch(isOnlineProvider(t.other.id));
    final unread = t.unread > 0;
    final isRequest = t.requestState == RequestState.pending && t.direction == RequestDirection.incoming;
    return InkWell(
      key: Key('dm-thread-${t.threadId}'),
      onTap: () => context.push('/messages/${Uri.encodeComponent(t.threadId)}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(children: [
          AvatarWithPresence(avatarUrl: t.other.avatarUrl, online: online, dotKey: Key('dm-online-${t.threadId}')),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Flexible(
                  child: Text(
                    t.other.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontWeight: unread ? FontWeight.w700 : FontWeight.w600),
                  ),
                ),
                if (isRequest) ...[
                  const SizedBox(width: 8),
                  Container(
                    key: Key('dm-request-chip-${t.threadId}'),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(border: Border.all(color: SxColors.primary), borderRadius: BorderRadius.circular(8)),
                    child: Text(l10n.dmRequestChip, style: const TextStyle(fontSize: 11, color: SxColors.primary)),
                  ),
                ],
              ]),
              const SizedBox(height: 2),
              Text(
                threadPreviewText(l10n, t),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: unread ? null : SxColors.textSecondary, fontWeight: unread ? FontWeight.w600 : FontWeight.w400),
              ),
            ]),
          ),
          const SizedBox(width: 8),
          Column(crossAxisAlignment: CrossAxisAlignment.end, mainAxisSize: MainAxisSize.min, children: [
            Text(relativeTime(l10n, t.lastMessageAt, now), style: const TextStyle(color: SxColors.textSecondary, fontSize: 12)),
            const SizedBox(height: 4),
            if (unread)
              Semantics(
                label: l10n.dmUnreadCount(t.unread),
                excludeSemantics: true,
                child: Container(
                  key: Key('dm-unread-${t.threadId}'),
                  constraints: const BoxConstraints(minWidth: 20),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: SxColors.primary, borderRadius: BorderRadius.circular(10)),
                  child: Text(
                    t.unread > 99 ? '99+' : '${t.unread}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w700),
                  ),
                ),
              )
            else
              const SizedBox(height: 20),
          ]),
        ]),
      ),
    );
  }
}
