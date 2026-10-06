import 'package:flutter/material.dart';

import '../../core/api/chat_models.dart' show cleanChatText;
import '../../core/theme/sx_colors.dart';

/// One chat bubble. Everything here may have come from a model, so it is shown as a single plain, selectable
/// string: no parsed spans, no auto-linking, no tap handlers. Unsafe characters are stripped again here as a
/// second line of defence behind the notifier.
class ChatBubbleView extends StatelessWidget {
  const ChatBubbleView({super.key, required this.text, required this.fromUser, this.failed = false});

  final String text;
  final bool fromUser;
  final bool failed;

  @override
  Widget build(BuildContext context) {
    final bubble = Container(
      constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: fromUser ? SxColors.primary : SxColors.surface,
        border: fromUser ? null : Border.all(color: SxColors.border),
        borderRadius: BorderRadius.circular(16),
      ),
      child: SelectableText(cleanChatText(text)),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        mainAxisAlignment: fromUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (fromUser && failed) const Padding(padding: EdgeInsets.only(right: 6), child: Icon(Icons.error_outline, size: 16, color: Colors.redAccent)),
          Flexible(child: bubble),
        ],
      ),
    );
  }
}
