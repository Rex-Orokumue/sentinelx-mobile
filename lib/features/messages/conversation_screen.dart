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
import '../../shared/widgets/player_avatar.dart';
import 'composer.dart';
import 'dm_image_pipeline.dart';
import 'dm_media_uploader.dart';
import 'forward_sheet.dart';
import 'inbox_providers.dart';
import 'message_actions_sheet.dart';
import 'message_bubble.dart';
import 'message_error_copy.dart';
import 'message_media.dart';
import 'sticker_picker.dart';
import 'messages_repository.dart';
import 'thread_providers.dart';
import 'thread_window.dart';

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
      _resumed = true;
      _claimOpen();
      _stampIfAllowed();
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      _resumed = false;
      _openThread.close(widget.threadId);
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
    final h = ref.read(threadHeaderProvider(widget.threadId)).asData?.value;
    if (h == null) return false;
    return !(h.requestState == RequestState.pending && h.direction == RequestDirection.incoming);
  }

  void _stampIfAllowed() {
    if (!_resumed || !_stampAllowed()) return;
    unawaited(ref.read(threadProvider(widget.threadId).notifier).markRead());
  }

  void _say(String text) {
    final m = ScaffoldMessenger.of(context);
    m.hideCurrentSnackBar();
    m.showSnackBar(SnackBar(content: Text(text)));
  }

  bool _withinWindow(DmMessage m) =>
      !_windowClosed.contains(m.id) && ref.read(dmClockProvider)().difference(m.createdAt) < _editWindow;

  Future<void> _showActions(DmMessage m, String viewerId) async {
    final actions = availableActions(m, mine: m.isMine(viewerId), withinWindow: _withinWindow(m), canForward: true);
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
        break; // wired by its own task
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

    final h = header.asData?.value;
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
                  PlayerAvatar(avatarUrl: h.other.avatarUrl, size: 34),
                  const SizedBox(width: 10),
                  Expanded(child: Text(h.other.displayName, maxLines: 1, overflow: TextOverflow.ellipsis)),
                ]),
              ),
      ),
      body: notFound
          ? Center(key: const Key('dm-not-found'), child: Padding(padding: const EdgeInsets.all(24), child: Text(l10n.dmConversationNotFound, textAlign: TextAlign.center)))
          : _body(context, l10n, thread, h, viewer),
    );
  }

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
      _footer(l10n, h),
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

  Widget _footer(AppLocalizations l10n, ThreadHeader? h) {
    if (h != null && !h.canSend) {
      final text = h.blockedByMe ? l10n.dmBlockedByMeBanner(h.other.displayName) : l10n.dmCannotMessage;
      return SafeArea(
        top: false,
        child: Container(
          key: const Key('dm-blocked-banner'),
          width: double.infinity,
          color: SxColors.surface,
          padding: const EdgeInsets.all(16),
          child: Text(text, textAlign: TextAlign.center),
        ),
      );
    }
    return Composer(
      threadId: widget.threadId,
      replyTo: _replyTo,
      onCancelReply: () => setState(() => _replyTo = null),
      editing: _editing,
      onCancelEdit: () => setState(() => _editing = null),
      onSend: _send,
      onSubmitEdit: _submitEdit,
      trailing: [
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
