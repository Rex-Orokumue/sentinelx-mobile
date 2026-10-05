import 'package:flutter/material.dart';

import '../../core/api/messages_models.dart';
import '../../core/l10n/gen/app_localizations.dart';
import '../../core/theme/sx_colors.dart';
import 'message_error_copy.dart';
import 'stickers.dart';
import 'thread_window.dart';

String _time(BuildContext context, DateTime at) =>
    MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(at.toLocal()), alwaysUse24HourFormat: true);

/// One confirmed message. Every kind has a defined rendering: removed, unknown and unknown-sticker never throw.
class MessageBubble extends StatelessWidget {
  const MessageBubble({super.key, required this.message, required this.mine, this.onLongPress, this.mediaBuilder});

  final DmMessage message;
  final bool mine;
  final VoidCallback? onLongPress;

  /// Renders image/voice content (added with photos and voice notes); null renders a neutral placeholder.
  final Widget? Function(BuildContext context, DmMessage message)? mediaBuilder;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final m = message;
    final isSticker = m.kind == MessageKind.sticker && stickerById(m.stickerId ?? '') != null;
    final bg = isSticker ? Colors.transparent : (mine ? SxColors.primary.withValues(alpha: 0.85) : SxColors.surface);
    final fg = mine && !isSticker ? Colors.white : null;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.78),
        child: GestureDetector(
          key: Key('dm-msg-${m.id}'),
          onLongPress: onLongPress,
          behavior: HitTestBehavior.opaque,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
            padding: isSticker ? EdgeInsets.zero : const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (m.forwarded && m.kind != MessageKind.removed)
                  Text(l10n.dmForwardedLabel, style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: fg ?? SxColors.textSecondary)),
                if (m.replyTo != null && m.kind != MessageKind.removed) ReplyQuote(reply: m.replyTo!, onBubble: mine),
                _content(context, l10n, fg),
                const SizedBox(height: 2),
                _footer(context, l10n, fg),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _content(BuildContext context, AppLocalizations l10n, Color? fg) {
    final m = message;
    switch (m.kind) {
      case MessageKind.text:
        return Text(m.body ?? '', style: TextStyle(color: fg));
      case MessageKind.removed:
        return Text(l10n.dmMessageRemoved, style: TextStyle(fontStyle: FontStyle.italic, color: fg ?? SxColors.textSecondary));
      case MessageKind.sticker:
        final s = stickerById(m.stickerId ?? '');
        if (s == null) return const _StickerPlaceholder();
        return Semantics(label: s.label, child: Text(s.emoji, style: const TextStyle(fontSize: 56)));
      case MessageKind.image:
      case MessageKind.voice:
        return mediaBuilder?.call(context, m) ?? _MediaPlaceholder(label: m.kind == MessageKind.voice ? l10n.dmVoiceMessage : l10n.dmPreviewPhoto);
      case MessageKind.unknown:
        return Text(l10n.dmUnsupported, style: TextStyle(fontStyle: FontStyle.italic, color: fg ?? SxColors.textSecondary));
    }
  }

  Widget _footer(BuildContext context, AppLocalizations l10n, Color? fg) {
    final m = message;
    final muted = (fg ?? SxColors.textSecondary).withValues(alpha: 0.8);
    return Row(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.end, children: [
      if (m.isEdited && m.kind != MessageKind.removed) ...[
        Text(l10n.dmEditedLabel, style: TextStyle(fontSize: 10, color: muted)),
        const SizedBox(width: 4),
      ],
      Text(_time(context, m.createdAt), style: TextStyle(fontSize: 10, color: muted)),
      if (mine && m.kind != MessageKind.removed) ...[const SizedBox(width: 4), Receipt(message: m, color: muted)],
    ]);
  }
}

/// Sent (one tick), delivered (two grey), read (two accent). Mine only; the label differs per state.
class Receipt extends StatelessWidget {
  const Receipt({super.key, required this.message, required this.color});

  final DmMessage message;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final m = message;
    final (IconData icon, String label, Color tint) = m.readAt != null
        ? (Icons.done_all, l10n.dmReceiptRead, Colors.lightBlueAccent)
        : m.deliveredAt != null
            ? (Icons.done_all, l10n.dmReceiptDelivered, color)
            : (Icons.done, l10n.dmReceiptSent, color);
    return Semantics(label: label, child: ExcludeSemantics(child: Icon(icon, key: Key('dm-receipt-${m.id}'), size: 14, color: tint)));
  }
}

class ReplyQuote extends StatelessWidget {
  const ReplyQuote({super.key, required this.reply, this.onBubble = false});

  final ReplyPreview reply;
  final bool onBubble;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = reply.removed ? l10n.dmReplyRemoved : (reply.body ?? l10n.dmPreviewOther);
    return Container(
      key: const Key('dm-reply-quote'),
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.only(left: 8),
      decoration: const BoxDecoration(border: Border(left: BorderSide(color: SxColors.primary, width: 3))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (reply.senderName != null)
          Text(reply.senderName!, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
        Text(text, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, fontStyle: reply.removed ? FontStyle.italic : null)),
      ]),
    );
  }
}

class _StickerPlaceholder extends StatelessWidget {
  const _StickerPlaceholder();

  @override
  Widget build(BuildContext context) => Semantics(
        label: AppLocalizations.of(context).dmStickerUnknown,
        child: Container(
          key: const Key('dm-sticker-unknown'),
          width: 72,
          height: 72,
          decoration: BoxDecoration(color: SxColors.surface, borderRadius: BorderRadius.circular(12)),
          child: const Icon(Icons.image_not_supported_outlined, color: SxColors.textSecondary),
        ),
      );
}

class _MediaPlaceholder extends StatelessWidget {
  const _MediaPlaceholder({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.perm_media_outlined, size: 18),
        const SizedBox(width: 6),
        Flexible(child: Text(label)),
      ]);
}

/// An outgoing message the server has not confirmed: a clock while sending, the error and Retry/Discard when
/// it failed. Retry is hidden for codes that can never succeed.
class PendingBubble extends StatelessWidget {
  const PendingBubble({super.key, required this.item, required this.onRetry, required this.onDiscard, this.mediaBuilder});

  final PendingItem item;
  final VoidCallback onRetry;
  final VoidCallback onDiscard;
  final Widget? Function(BuildContext context, PendingItem item)? mediaBuilder;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final d = item.draft;
    final failed = item.status == PendingStatus.failed;
    final Widget content;
    if (d.stickerId != null) {
      final s = stickerById(d.stickerId!);
      content = s == null ? const _StickerPlaceholder() : Text(s.emoji, style: const TextStyle(fontSize: 56));
    } else if (d.body != null) {
      content = Text(d.body!, style: const TextStyle(color: Colors.white));
    } else {
      content = mediaBuilder?.call(context, item) ?? _MediaPlaceholder(label: d.audioPath != null || d.audioDurationSeconds != null ? l10n.dmVoiceMessage : l10n.dmPreviewPhoto);
    }
    return Align(
      alignment: Alignment.centerRight,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.78),
        child: Container(
          key: Key('dm-pending-${item.localId}'),
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(color: SxColors.primary.withValues(alpha: failed ? 0.45 : 0.7), borderRadius: BorderRadius.circular(14)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.end, mainAxisSize: MainAxisSize.min, children: [
            Align(alignment: Alignment.centerLeft, child: content),
            const SizedBox(height: 2),
            if (!failed)
              Semantics(label: l10n.dmSending, child: const ExcludeSemantics(child: Icon(Icons.schedule, size: 14, color: Colors.white70)))
            else ...[
              Text(dmErrorCopy(l10n, item.error ?? ''), style: const TextStyle(fontSize: 12, color: Colors.white)),
              Wrap(spacing: 8, children: [
                if (item.canRetry)
                  TextButton(key: Key('dm-retry-${item.localId}'), onPressed: onRetry, child: Text(l10n.dmRetryAction)),
                TextButton(key: Key('dm-discard-${item.localId}'), onPressed: onDiscard, child: Text(l10n.dmDiscard)),
              ]),
            ],
          ]),
        ),
      ),
    );
  }
}
