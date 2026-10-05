import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart' show ImageSource;

import '../../core/api/api_client.dart';
import '../../core/api/messages_models.dart';
import '../../core/l10n/gen/app_localizations.dart';
import '../../core/theme/sx_colors.dart';
import '../../core/utils/idempotency_key.dart';
import 'block_report.dart';
import 'composer.dart';
import 'dm_image_pipeline.dart';
import 'dm_media_uploader.dart';
import 'forward_sheet.dart';
import 'inbox_providers.dart';
import 'message_actions_sheet.dart';
import 'online_dot.dart';
import 'presence_providers.dart';
import 'message_bubble.dart';
import 'message_error_copy.dart';
import 'request_view.dart';
import 'message_media.dart';
import 'sticker_picker.dart';
import 'messages_repository.dart';
import 'thread_providers.dart';
import 'thread_window.dart';
import 'typing_controller.dart';
import 'voice/voice_bubble.dart';
import 'voice/voice_composer.dart';
import 'voice/voice_recorder_controller.dart';

const _editWindow = Duration(minutes: 10);

/// `/messages/:threadId`. Reads and writes go through the API; realtime only nudges a refetch of the window.
class ConversationScreen extends ConsumerStatefulWidget {
  const ConversationScreen({super.key, required this.threadId});

  final String threadId;

  @override
  ConsumerState<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends ConsumerState<ConversationScreen> with WidgetsBindingObserver {
  final _scroll = ScrollController();
  late final OpenThread _openThread;
  DmMessage? _replyTo;
  DmMessage? _editing;
  final _windowClosed = <String>{};
  bool _resumed = true;
  bool _showPill = false;
  bool _stampedOnOpen = false;
  bool _forwarding = false;
  bool _requestBusy = false;
  Timer? _poll;
  VoidCallback _onTyping = () {};

  @override
  void initState() {
    super.initState();
    _openThread = ref.read(openThreadIdProvider.notifier);
    WidgetsBinding.instance.addObserver(this);
    _scroll.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _claimOpen());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _poll?.cancel();
    _scroll.dispose();
    final notifier = _openThread;
    final id = widget.threadId;
    // Provider state cannot change while the tree is being torn down: release the open-thread claim right after.
    scheduleMicrotask(() {
      try {
        notifier.close(id);
      } catch (_) {
        // the container is already gone
      }
    });
    super.dispose();
  }

  void _claimOpen() {
    if (mounted && _resumed) _openThread.open(widget.threadId);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      setState(() => _resumed = true);
      _claimOpen();
      _stampIfAllowed();
      ref.invalidate(threadHeaderProvider(widget.threadId)); // a request may have been answered while away
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      setState(() => _resumed = false);
      _openThread.close(widget.threadId);
      _stopPoll();
    }
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    // The list is reversed: the position grows toward OLDER messages.
    if (_scroll.position.extentAfter < 300) unawaited(ref.read(threadProvider(widget.threadId).notifier).loadOlder());
    if (_showPill && _scroll.position.pixels < 80) setState(() => _showPill = false);
  }

  /// A request waiting for the viewer's answer is preview-only: opening it must not stamp read receipts.
  bool _stampAllowed() {
    final h = ref.read(threadHeaderProvider(widget.threadId)).value;
    if (h == null) return false;
    return !(h.requestState == RequestState.pending && h.direction == RequestDirection.incoming);
  }

  void _stampIfAllowed() {
    if (!_resumed || !_stampAllowed()) return;
    unawaited(ref.read(threadProvider(widget.threadId).notifier).markRead());
  }

  /// While the viewer is waiting on a request they sent, ask the server every 25 s whether it was accepted (or
  /// blocked). Runs only while this screen is open and the app visible, and stops the moment that state ends.
  void _syncPoll(ThreadHeader? h) {
    final should = _resumed && h != null && threadModeFor(h) == ThreadMode.outgoingRequest;
    if (should && _poll == null) {
      _poll = Timer.periodic(kOutgoingPendingPollInterval, (_) {
        if (mounted) ref.invalidate(threadHeaderProvider(widget.threadId));
      });
    } else if (!should) {
      _stopPoll();
    }
  }

  void _stopPoll() {
    _poll?.cancel();
    _poll = null;
  }

  void _refreshInboxes() {
    ref.invalidate(inboxProvider);
    ref.invalidate(requestsInboxProvider);
  }

  Future<void> _accept() async {
    if (_requestBusy) return;
    _requestBusy = true;
    setState(() {});
    final repo = ref.read(messagesRepositoryProvider);
    final notifier = ref.read(threadProvider(widget.threadId).notifier);
    final l10n = AppLocalizations.of(context);
    try {
      await repo.accept(widget.threadId);
      if (!mounted) return;
      ref.invalidate(threadHeaderProvider(widget.threadId));
      _refreshInboxes();
      await ref.read(threadHeaderProvider(widget.threadId).future);
      unawaited(notifier.markRead());
    } catch (e) {
      // Only a failure re-arms the buttons: after success the panel is replaced, so a late second tap on the
      // old button must still be ignored.
      _requestBusy = false;
      if (mounted) {
        setState(() {});
        _say(dmErrorCopy(l10n, e));
      }
    }
  }

  Future<void> _decline() async {
    if (_requestBusy) return;
    _requestBusy = true;
    setState(() {});
    final repo = ref.read(messagesRepositoryProvider);
    final l10n = AppLocalizations.of(context);
    final router = GoRouter.of(context);
    try {
      await repo.decline(widget.threadId);
      _refreshInboxes();
      if (mounted) {
        if (router.canPop()) {
          router.pop();
        } else {
          router.go('/messages');
        }
      }
    } catch (e) {
      _requestBusy = false;
      if (mounted) {
        setState(() {});
        _say(dmErrorCopy(l10n, e));
      }
    }
  }

  Future<void> _blockAndReport(ThreadHeader h) async {
    if (_requestBusy) return;
    final blocked = await confirmAndBlock(context, ref, threadId: widget.threadId, other: h.other);
    if (blocked && mounted) await reportFlow(context, ref, threadId: widget.threadId);
  }

  void _say(String text) {
    final m = ScaffoldMessenger.of(context);
    m.hideCurrentSnackBar();
    m.showSnackBar(SnackBar(content: Text(text)));
  }

  bool _withinWindow(DmMessage m) =>
      !_windowClosed.contains(m.id) && ref.read(dmClockProvider)().difference(m.createdAt) < _editWindow;

  Future<void> _showActions(DmMessage m, String viewerId) async {
    final actions = availableActions(m, mine: m.isMine(viewerId), withinWindow: _withinWindow(m), canForward: true, canReport: true);
    if (actions.isEmpty) return;
    final picked = await showModalBottomSheet<MessageAction>(
      context: context,
      builder: (_) => MessageActionsSheet(actions: actions),
    );
    if (picked == null || !mounted) return;
    switch (picked) {
      case MessageAction.reply:
        setState(() {
          _replyTo = m;
          _editing = null;
        });
      case MessageAction.copy:
        await Clipboard.setData(ClipboardData(text: m.body ?? ''));
        if (mounted) _say(AppLocalizations.of(context).dmCopied);
      case MessageAction.edit:
        setState(() {
          _editing = m;
          _replyTo = null;
        });
      case MessageAction.unsend:
        await _unsend(m);
      case MessageAction.forward:
        await _forward(m);
      case MessageAction.report:
        await reportFlow(context, ref, threadId: widget.threadId, messageId: m.id);
    }
  }

  Future<void> _forward(DmMessage m) async {
    final target = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (_) => ForwardSheet(currentThreadId: widget.threadId),
    );
    if (target == null || !mounted || _forwarding) return;
    _forwarding = true;
    final notifier = ref.read(threadProvider(widget.threadId).notifier);
    final l10n = AppLocalizations.of(context);
    try {
      final ok = await notifier.forward(m.id, target);
      if (mounted) _say(ok ? l10n.dmForwarded : dmErrorCopy(l10n, notifier.lastActionError ?? ''));
    } finally {
      _forwarding = false;
    }
  }

  Future<void> _attachPhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (sheet) {
        final l10n = AppLocalizations.of(sheet);
        return SafeArea(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            ListTile(key: const Key('dm-photo-library'), leading: const Icon(Icons.photo_library_outlined), title: Text(l10n.dmPhotoLibrary), onTap: () => Navigator.pop(sheet, ImageSource.gallery)),
            ListTile(key: const Key('dm-photo-camera'), leading: const Icon(Icons.photo_camera_outlined), title: Text(l10n.dmPhotoCamera), onTap: () => Navigator.pop(sheet, ImageSource.camera)),
          ]),
        );
      },
    );
    if (source == null || !mounted) return;
    final l10n = AppLocalizations.of(context);
    final picker = ref.read(dmImagePickerProvider);
    final sanitize = ref.read(dmImageSanitizerProvider);
    final uploader = ref.read(dmMediaUploaderProvider);
    final notifier = ref.read(threadProvider(widget.threadId).notifier);
    final viewer = ref.read(dmViewerIdProvider).asData?.value;
    if (viewer == null) return;
    final picked = await picker.pick(source);
    if (picked == null || !mounted) return;
    if (picked.bytes.length > kMaxPickedBytes) {
      _say(l10n.dmErrorImageTooLarge);
      return;
    }
    final Uint8List jpeg;
    try {
      jpeg = await sanitize(picked.bytes);
    } on FormatException {
      if (mounted) _say(l10n.dmErrorGeneric);
      return;
    }
    if (!mounted) return;
    if (jpeg.length > kMaxSanitizedBytes) {
      _say(l10n.dmErrorImageTooLarge);
      return;
    }
    // One storage path per compose action: every retry reuses it, and the upload runs once it has succeeded.
    final pathId = newIdempotencyKey();
    String? uploaded;
    unawaited(notifier.send(
      const SendDraft(),
      localImage: jpeg,
      prepare: (draft) async {
        uploaded ??= await uploader.uploadImage(userId: viewer, jpeg: jpeg, pathId: pathId);
        return draft.copyWith(imagePath: uploaded);
      },
    ));
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  Future<void> _pickSticker() async {
    final id = await showModalBottomSheet<String>(context: context, builder: (_) => const StickerPicker());
    if (id == null || !mounted) return;
    unawaited(ref.read(threadProvider(widget.threadId).notifier).send(SendDraft(stickerId: id)));
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  Future<void> _unsend(DmMessage m) async {
    final notifier = ref.read(threadProvider(widget.threadId).notifier);
    final l10n = AppLocalizations.of(context);
    final ok = await notifier.unsend(m.id);
    if (!ok && mounted) _actionFailed(m, notifier.lastActionError, l10n);
  }

  Future<void> _submitEdit(String body) async {
    final target = _editing;
    if (target == null) return;
    final notifier = ref.read(threadProvider(widget.threadId).notifier);
    final l10n = AppLocalizations.of(context);
    setState(() => _editing = null);
    final ok = await notifier.edit(target.id, body);
    if (!ok && mounted) _actionFailed(target, notifier.lastActionError, l10n);
  }

  void _actionFailed(DmMessage m, Object? error, AppLocalizations l10n) {
    if (error is ApiException && error.code == 'edit_window_closed') setState(() => _windowClosed.add(m.id));
    _say(dmErrorCopy(l10n, error ?? ''));
  }

  void _send(String body) {
    final reply = _replyTo;
    setState(() => _replyTo = null);
    unawaited(ref.read(threadProvider(widget.threadId).notifier).send(SendDraft(body: body, replyToId: reply?.id)));
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final id = widget.threadId;
    final viewer = ref.watch(dmViewerIdProvider).asData?.value;
    final thread = ref.watch(threadProvider(id));
    final header = ref.watch(threadHeaderProvider(id));

    ref.listen(threadProvider(id), (prev, next) {
      final before = prev?.asData?.value.messages ?? const <DmMessage>[];
      final after = next.asData?.value.messages;
      if (after == null || viewer == null) return;
      final seen = {for (final m in before) m.id};
      final arrived = [for (final m in after) if (!seen.contains(m.id) && !m.isMine(viewer)) m];
      if (before.isNotEmpty && arrived.isNotEmpty) {
        if (_scroll.hasClients && _scroll.position.pixels > 80) setState(() => _showPill = true);
        _stampIfAllowed();
      }
    });
    // Stamp once on open, as soon as both the thread and its header (request state) are known.
    if (!_stampedOnOpen && thread.hasValue && header.hasValue && viewer != null) {
      _stampedOnOpen = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _stampIfAllowed();
      });
    }

    ref.listen(voiceRecorderControllerProvider(id), (prev, next) {
      if (next.tooShort && !(prev?.tooShort ?? false)) {
        _say(l10n.dmVoiceTooShort);
        ref.read(voiceRecorderControllerProvider(id).notifier).clearTooShort();
      }
    });
    final h = header.value; // keeps the last header while a poll or refetch is in flight
    _syncPoll(h);
    // Typing runs only for an accepted, unblocked thread while the app is visible: otherwise no channel opens.
    var typing = false;
    _onTyping = () {};
    if (h != null) {
      final args = ThreadTypingArgs(
        threadId: id,
        otherId: h.other.id,
        enabled: _resumed && threadModeFor(h) == ThreadMode.open,
      );
      _onTyping = ref.watch(typingNotifierProvider(args));
      typing = ref.watch(threadTypingProvider(args)).asData?.value ?? false;
    }
    final notFound = (thread.hasError && !thread.hasValue && _isNotFound(thread.error)) || (header.hasError && _isNotFound(header.error));

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: h == null
            ? const SizedBox.shrink()
            : InkWell(
                key: const Key('dm-header'),
                onTap: h.other.username == null ? null : () => context.push('/players/${Uri.encodeComponent(h.other.username!)}'),
                child: Row(children: [
                  AvatarWithPresence(avatarUrl: h.other.avatarUrl, online: ref.watch(isOnlineProvider(h.other.id)), dotKey: const Key('dm-online-header'), size: 34),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                      Text(h.other.displayName, maxLines: 1, overflow: TextOverflow.ellipsis),
                      if (typing) Text(l10n.dmTyping, key: const Key('dm-typing'), style: const TextStyle(fontSize: 12, color: SxColors.primary)),
                    ]),
                  ),
                ]),
              ),
        actions: [if (h != null) _menu(l10n, h)],
      ),
      body: notFound
          ? Center(key: const Key('dm-not-found'), child: Padding(padding: const EdgeInsets.all(24), child: Text(l10n.dmConversationNotFound, textAlign: TextAlign.center)))
          : _body(context, l10n, thread, h, viewer),
    );
  }

  Widget _menu(AppLocalizations l10n, ThreadHeader h) => PopupMenuButton<String>(
        key: const Key('dm-menu'),
        tooltip: l10n.dmMore,
        onSelected: (choice) {
          switch (choice) {
            case 'block':
              unawaited(confirmAndBlock(context, ref, threadId: widget.threadId, other: h.other));
            case 'unblock':
              unawaited(unblockPlayer(context, ref, threadId: widget.threadId, other: h.other));
            case 'report':
              unawaited(reportFlow(context, ref, threadId: widget.threadId));
          }
        },
        itemBuilder: (_) => [
          if (h.blockedByMe)
            PopupMenuItem(key: const Key('dm-menu-unblock'), value: 'unblock', child: Text(l10n.dmUnblock))
          else
            PopupMenuItem(key: const Key('dm-menu-block'), value: 'block', child: Text(l10n.dmBlock)),
          PopupMenuItem(key: const Key('dm-menu-report'), value: 'report', child: Text(l10n.dmReport)),
        ],
      );

  bool _isNotFound(Object? e) => e is ApiException && e.code == 'not_found';

  Widget _body(BuildContext context, AppLocalizations l10n, AsyncValue<ThreadView> thread, ThreadHeader? h, String? viewer) {
    if (thread.hasError && !thread.hasValue) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(l10n.dmLoadError, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          OutlinedButton(key: const Key('dm-retry'), onPressed: () => ref.invalidate(threadProvider(widget.threadId)), child: Text(l10n.dmRetry)),
        ]),
      );
    }
    final view = thread.asData?.value;
    if (view == null || viewer == null) return const Center(child: CircularProgressIndicator());
    return Column(children: [
      Expanded(child: Stack(children: [_list(context, l10n, view, viewer), if (_showPill) _pill(l10n)])),
      _footer(l10n, h, view),
    ]);
  }

  Widget _pill(AppLocalizations l10n) => Positioned(
        bottom: 8,
        left: 0,
        right: 0,
        child: Center(
          child: ActionChip(
            key: const Key('dm-new-pill'),
            label: Text(l10n.dmNewMessages),
            onPressed: () {
              setState(() => _showPill = false);
              if (_scroll.hasClients) _scroll.jumpTo(0);
            },
          ),
        ),
      );

  Widget _footer(AppLocalizations l10n, ThreadHeader? h, ThreadView view) {
    final header = ref.read(threadHeaderProvider(widget.threadId));
    if (h == null && !header.hasError) return const SizedBox.shrink(); // request state unknown yet: no composer flash
    final mode = h == null ? ThreadMode.open : threadModeFor(h);
    if (h != null && mode == ThreadMode.incomingRequest) {
      return IncomingRequestPanel(
        name: h.other.displayName,
        busy: _requestBusy,
        onAccept: () => unawaited(_accept()),
        onDecline: () => unawaited(_decline()),
        onBlockAndReport: () => unawaited(_blockAndReport(h)),
      );
    }
    if (h != null && mode == ThreadMode.outgoingRequest) {
      final viewer = ref.read(dmViewerIdProvider).asData?.value;
      final sentOne = view.messages.any((m) => m.isMine(viewer ?? '')) || view.pending.any((p) => p.status == PendingStatus.sending);
      if (sentOne) return WaitingBanner(name: h.other.displayName);
    }
    if (h != null && mode == ThreadMode.blocked) {
      final text = h.blockedByMe ? l10n.dmBlockedByMeBanner(h.other.displayName) : l10n.dmCannotMessage;
      return SafeArea(
        top: false,
        child: Container(
          key: const Key('dm-blocked-banner'),
          width: double.infinity,
          color: SxColors.surface,
          padding: const EdgeInsets.all(16),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(text, textAlign: TextAlign.center),
            if (h.blockedByMe)
              TextButton(
                key: const Key('dm-unblock'),
                onPressed: () => unawaited(unblockPlayer(context, ref, threadId: widget.threadId, other: h.other)),
                child: Text(l10n.dmUnblock),
              ),
          ]),
        ),
      );
    }
    if (ref.watch(voiceRecorderControllerProvider(widget.threadId)).phase != VoicePhase.idle) {
      return VoiceComposer(threadId: widget.threadId);
    }
    return Composer(
      threadId: widget.threadId,
      replyTo: _replyTo,
      onCancelReply: () => setState(() => _replyTo = null),
      editing: _editing,
      onCancelEdit: () => setState(() => _editing = null),
      onSend: _send,
      onSubmitEdit: _submitEdit,
      onTyping: _onTyping,
      trailing: h != null && mode == ThreadMode.outgoingRequest ? const [] : [ // text only until accepted
        IconButton(
          key: const Key('dm-mic-button'),
          tooltip: l10n.dmMicTooltip,
          icon: const Icon(Icons.mic_none),
          onPressed: () => unawaited(ref.read(voiceRecorderControllerProvider(widget.threadId).notifier).begin()),
        ),
        IconButton(
          key: const Key('dm-photo-button'),
          tooltip: l10n.dmAttachPhoto,
          icon: const Icon(Icons.photo_outlined),
          onPressed: _attachPhoto,
        ),
        IconButton(
          key: const Key('dm-sticker-button'),
          tooltip: l10n.dmStickers,
          icon: const Icon(Icons.emoji_emotions_outlined),
          onPressed: _pickSticker,
        ),
      ],
    );
  }

  Widget _list(BuildContext context, AppLocalizations l10n, ThreadView view, String viewer) {
    final notifier = ref.read(threadProvider(widget.threadId).notifier);
    final now = ref.read(dmClockProvider)().toLocal();
    final rows = <Widget>[
      for (final p in view.pending.reversed)
        PendingBubble(
          item: p,
          mediaBuilder: (context, item) => item.localImage == null
              ? null
              : ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.memory(item.localImage!, key: Key('dm-pending-image-${item.localId}'), width: 200, fit: BoxFit.cover),
                ),
          onRetry: () => unawaited(notifier.retry(p.localId)),
          onDiscard: () => notifier.discard(p.localId),
        ),
    ];
    final messages = view.messages;
    for (var i = 0; i < messages.length; i++) {
      final m = messages[i];
      rows.add(MessageBubble(
        message: m,
        mine: m.isMine(viewer),
        onLongPress: () => unawaited(_showActions(m, viewer)),
        mediaBuilder: (context, message) => _media(context, l10n, message),
      ));
      final next = i + 1 < messages.length ? messages[i + 1] : null;
      final day = _day(m.createdAt);
      if (next == null ? !view.hasOlder : _day(next.createdAt) != day) rows.add(_DateSeparator(label: _dayLabel(context, l10n, m.createdAt, now)));
    }
    if (view.loadingOlder) {
      rows.add(const Padding(padding: EdgeInsets.all(12), child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)))));
    }
    return ListView.builder(
      key: const Key('dm-list'),
      controller: _scroll,
      reverse: true,
      itemCount: rows.length,
      itemBuilder: (_, i) => rows[i],
    );
  }

  Widget? _media(BuildContext context, AppLocalizations l10n, DmMessage m) {
    if (m.kind == MessageKind.image) {
      return ImageBubble(
        url: m.imageUrl ?? '',
        onError: () => unawaited(ref.read(threadProvider(widget.threadId).notifier).requestMediaRefresh()),
      );
    }
    if (m.kind == MessageKind.voice) {
      return VoiceBubble(
        message: m,
        onPlaybackError: () => unawaited(ref.read(threadProvider(widget.threadId).notifier).requestMediaRefresh()),
      );
    }
    return null;
  }

  DateTime _day(DateTime t) {
    final l = t.toLocal();
    return DateTime(l.year, l.month, l.day);
  }

  String _dayLabel(BuildContext context, AppLocalizations l10n, DateTime at, DateTime now) {
    final day = _day(at);
    final today = DateTime(now.year, now.month, now.day);
    if (day == today) return l10n.dmToday;
    if (day == today.subtract(const Duration(days: 1))) return l10n.dmYesterday;
    return MaterialLocalizations.of(context).formatMediumDate(day);
  }
}

class _DateSeparator extends StatelessWidget {
  const _DateSeparator({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Center(child: Text(label, key: Key('dm-day-$label'), style: const TextStyle(fontSize: 12, color: SxColors.textSecondary))),
      );
}
