import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/messages_models.dart';
import '../../core/l10n/gen/app_localizations.dart';
import '../../core/theme/sx_colors.dart';
import 'message_bubble.dart';
import 'thread_providers.dart';

const kMaxMessageChars = 2000;

/// The text composer. Enter inserts a newline (there is no hardware-Enter send). The draft survives the
/// screen being popped through [threadDraftProvider]. A reply bar and an edit bar sit above the field.
class Composer extends ConsumerStatefulWidget {
  const Composer({
    super.key,
    required this.threadId,
    required this.onSend,
    required this.onSubmitEdit,
    this.replyTo,
    this.onCancelReply,
    this.editing,
    this.onCancelEdit,
    this.trailing = const [],
  });

  final String threadId;
  final void Function(String body) onSend;
  final void Function(String body) onSubmitEdit;
  final DmMessage? replyTo;
  final VoidCallback? onCancelReply;
  final DmMessage? editing;
  final VoidCallback? onCancelEdit;

  /// Extra buttons right of the field (stickers, photos, voice), added by their own tasks.
  final List<Widget> trailing;

  @override
  ConsumerState<Composer> createState() => _ComposerState();
}

class _ComposerState extends ConsumerState<Composer> {
  late final TextEditingController _controller;
  String _stash = '';
  bool _programmatic = false; // text set by the edit bar, not typed: must not touch providers mid-build

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: ref.read(threadDraftProvider(widget.threadId)));
    _controller.addListener(_onChanged);
    if (widget.editing != null) _enterEdit(widget.editing!);
  }

  void _onChanged() {
    if (_programmatic) return;
    if (widget.editing == null) ref.read(threadDraftProvider(widget.threadId).notifier).set(_controller.text);
    setState(() {});
  }

  void _setText(String text) {
    _programmatic = true;
    _controller.text = text;
    _controller.selection = TextSelection.collapsed(offset: text.length);
    _programmatic = false;
  }

  void _enterEdit(DmMessage m) {
    _stash = _controller.text;
    _setText(m.body ?? '');
  }

  @override
  void didUpdateWidget(Composer old) {
    super.didUpdateWidget(old);
    if (old.editing == null && widget.editing != null) {
      _enterEdit(widget.editing!);
    } else if (old.editing != null && widget.editing == null) {
      _setText(_stash);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _canSend => _controller.text.trim().isNotEmpty;

  void _submit() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    if (widget.editing != null) {
      widget.onSubmitEdit(text);
      return;
    }
    // Cleared before the send starts: a second tap sees an empty field and does nothing.
    _controller.clear();
    widget.onSend(text);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final editing = widget.editing != null;
    final reply = widget.replyTo;
    return SafeArea(
      top: false,
      child: Container(
        key: const Key('dm-composer'),
        decoration: const BoxDecoration(border: Border(top: BorderSide(color: SxColors.surface))),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (editing)
            Container(
              key: const Key('dm-edit-bar'),
              color: SxColors.surface,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Row(children: [
                const Icon(Icons.edit_outlined, size: 16),
                const SizedBox(width: 8),
                Expanded(child: Text(l10n.dmEditingBar, maxLines: 1, overflow: TextOverflow.ellipsis)),
                TextButton(key: const Key('dm-edit-cancel'), onPressed: widget.onCancelEdit, child: Text(l10n.dmCancel)),
                FilledButton(key: const Key('dm-edit-save'), onPressed: _canSend ? _submit : null, child: Text(l10n.dmSave)),
              ]),
            )
          else if (reply != null)
            Container(
              key: const Key('dm-reply-bar'),
              color: SxColors.surface,
              padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
              child: Row(children: [
                Expanded(
                  child: ReplyQuote(
                    reply: ReplyPreview(id: reply.id, senderName: null, body: _replyText(l10n, reply)),
                  ),
                ),
                IconButton(
                  key: const Key('dm-reply-close'),
                  tooltip: l10n.dmCloseReply,
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: widget.onCancelReply,
                ),
              ]),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
            child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              if (!editing) ...widget.trailing,
              Expanded(
                child: TextField(
                  key: const Key('dm-input'),
                  controller: _controller,
                  minLines: 1,
                  maxLines: 5,
                  maxLength: kMaxMessageChars,
                  keyboardType: TextInputType.multiline,
                  textInputAction: TextInputAction.newline,
                  textCapitalization: TextCapitalization.sentences,
                  buildCounter: (context, {required currentLength, required isFocused, required maxLength}) => currentLength >= kMaxMessageChars - 200
                      ? Text('$currentLength/$maxLength', key: const Key('dm-counter'), style: const TextStyle(fontSize: 11))
                      : null,
                  decoration: InputDecoration(hintText: l10n.dmComposerHint, border: InputBorder.none, isDense: true),
                ),
              ),
              if (!editing)
                IconButton(
                  key: const Key('dm-send'),
                  tooltip: l10n.dmSend,
                  icon: const Icon(Icons.send),
                  color: SxColors.primary,
                  onPressed: _canSend ? _submit : null,
                ),
            ]),
          ),
        ]),
      ),
    );
  }

  String _replyText(AppLocalizations l10n, DmMessage m) => switch (m.kind) {
        MessageKind.text => m.body ?? '',
        MessageKind.image => l10n.dmReplyPhoto,
        MessageKind.sticker => l10n.dmReplySticker,
        MessageKind.voice => l10n.dmReplyVoice,
        _ => l10n.dmPreviewOther,
      };
}
