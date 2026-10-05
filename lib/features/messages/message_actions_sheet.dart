import 'package:flutter/material.dart';

import '../../core/api/messages_models.dart';
import '../../core/l10n/gen/app_localizations.dart';

enum MessageAction { reply, copy, forward, edit, unsend, report }

/// Which actions a message offers. Edit and Unsend exist only on the viewer's own non-removed messages inside
/// the 10-minute window (the device clock offers, the server decides: Ruling 8), and Edit is text only.
List<MessageAction> availableActions(
  DmMessage m, {
  required bool mine,
  required bool withinWindow,
  bool canForward = false,
  bool canReport = false,
}) {
  if (m.kind == MessageKind.removed) return const [];
  return [
    MessageAction.reply,
    if (m.kind == MessageKind.text) MessageAction.copy,
    if (canForward) MessageAction.forward,
    if (mine && withinWindow && m.kind == MessageKind.text) MessageAction.edit,
    if (mine && withinWindow) MessageAction.unsend,
    if (!mine && canReport) MessageAction.report,
  ];
}

class MessageActionsSheet extends StatelessWidget {
  const MessageActionsSheet({super.key, required this.actions});

  final List<MessageAction> actions;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    String label(MessageAction a) => switch (a) {
          MessageAction.reply => l10n.dmActionReply,
          MessageAction.copy => l10n.dmActionCopy,
          MessageAction.forward => l10n.dmActionForward,
          MessageAction.edit => l10n.dmActionEdit,
          MessageAction.unsend => l10n.dmActionUnsend,
          MessageAction.report => l10n.dmActionReport,
        };
    IconData icon(MessageAction a) => switch (a) {
          MessageAction.reply => Icons.reply,
          MessageAction.copy => Icons.copy,
          MessageAction.forward => Icons.forward,
          MessageAction.edit => Icons.edit_outlined,
          MessageAction.unsend => Icons.delete_outline,
          MessageAction.report => Icons.flag_outlined,
        };
    return SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        for (final a in actions)
          ListTile(
            key: Key('dm-action-${a.name}'),
            leading: Icon(icon(a)),
            title: Text(label(a)),
            onTap: () => Navigator.pop(context, a),
          ),
      ]),
    );
  }
}
