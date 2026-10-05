import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/messages_models.dart';
import '../../core/l10n/gen/app_localizations.dart';
import 'inbox_providers.dart';
import 'message_error_copy.dart';
import 'thread_providers.dart';

const kMaxReportChars = 1000;

/// Whether [text] can be submitted as a report reason: 1 to 1000 characters after trimming.
bool isValidReportReason(String text) {
  final n = text.trim().length;
  return n >= 1 && n <= kMaxReportChars;
}

/// Asks for the reason. Returns the trimmed text, or null when dismissed.
class ReportSheet extends StatefulWidget {
  const ReportSheet({super.key});

  @override
  State<ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends State<ReportSheet> {
  final _controller = TextEditingController();
  bool _submitted = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final length = _controller.text.trim().length;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(l10n.dmReportTitle, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            const SizedBox(height: 12),
            TextField(
              key: const Key('dm-report-input'),
              controller: _controller,
              minLines: 3,
              maxLines: 6,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(hintText: l10n.dmReportHint, border: const OutlineInputBorder()),
            ),
            Align(alignment: Alignment.centerRight, child: Text('$length/$kMaxReportChars', style: const TextStyle(fontSize: 11))),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                key: const Key('dm-report-submit'),
                onPressed: isValidReportReason(_controller.text) && !_submitted
                    ? () {
                        _submitted = true;
                        Navigator.pop(context, _controller.text.trim());
                      }
                    : null,
                child: Text(l10n.dmReportSubmit),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

final _inFlight = <String>{};

void _say(ScaffoldMessengerState messenger, String text) {
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(SnackBar(content: Text(text)));
}

void _refresh(WidgetRef ref, String threadId) {
  ref.invalidate(threadHeaderProvider(threadId));
  ref.invalidate(inboxProvider);
  ref.invalidate(requestsInboxProvider);
}

/// Confirm, then block. The server hides the thread from the inbox afterwards; the header refetch flips the
/// composer to the blocked banner. A second call while one is running does nothing. True when blocked.
Future<bool> confirmAndBlock(BuildContext context, WidgetRef ref, {required String threadId, required OtherPlayer other}) async {
  final key = 'block:$threadId';
  if (_inFlight.contains(key)) return false;
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final repo = ref.read(messagesRepositoryProvider);
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialog) => AlertDialog(
      title: Text(l10n.dmBlockConfirmTitle(other.displayName)),
      content: Text(l10n.dmBlockConfirmBody),
      actions: [
        TextButton(key: const Key('dm-block-cancel'), onPressed: () => Navigator.pop(dialog, false), child: Text(l10n.dmCancel)),
        FilledButton(key: const Key('dm-block-confirm'), onPressed: () => Navigator.pop(dialog, true), child: Text(l10n.dmBlock)),
      ],
    ),
  );
  if (confirmed != true) return false;
  if (!_inFlight.add(key)) return false;
  try {
    await repo.block(other.id);
    if (ref.context.mounted) _refresh(ref, threadId);
    return true;
  } catch (e) {
    _say(messenger, dmErrorCopy(l10n, e));
    return false;
  } finally {
    _inFlight.remove(key);
  }
}

Future<bool> unblockPlayer(BuildContext context, WidgetRef ref, {required String threadId, required OtherPlayer other}) async {
  final key = 'unblock:$threadId';
  if (!_inFlight.add(key)) return false;
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final repo = ref.read(messagesRepositoryProvider);
  try {
    await repo.unblock(other.id);
    if (ref.context.mounted) _refresh(ref, threadId);
    return true;
  } catch (e) {
    _say(messenger, dmErrorCopy(l10n, e));
    return false;
  } finally {
    _inFlight.remove(key);
  }
}

/// Asks for a reason and reports the thread (or one message of it). True when reported.
Future<bool> reportFlow(BuildContext context, WidgetRef ref, {required String threadId, String? messageId}) async {
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final repo = ref.read(messagesRepositoryProvider);
  final reason = await showModalBottomSheet<String>(context: context, isScrollControlled: true, builder: (_) => const ReportSheet());
  if (reason == null) return false;
  try {
    await repo.report(threadId, messageId: messageId, reason: reason);
    _say(messenger, l10n.dmReported);
    return true;
  } catch (e) {
    _say(messenger, dmErrorCopy(l10n, e));
    return false;
  }
}
