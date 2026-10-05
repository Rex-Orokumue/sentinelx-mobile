import 'package:flutter/material.dart';

import '../../core/api/messages_models.dart';
import '../../core/l10n/gen/app_localizations.dart';
import '../../core/theme/sx_colors.dart';

/// How the conversation behaves for a given header. `unknown` request states render as accepted (never hide the
/// composer behind a future state the app cannot name); `declined` renders as blocked-by-them: a decline must
/// look identical to a block to the sender, so "declined" never appears in the UI.
enum ThreadMode { open, incomingRequest, outgoingRequest, blocked }

ThreadMode threadModeFor(ThreadHeader h) {
  if (h.blockedByMe || h.blockedByThem || h.requestState == RequestState.declined) return ThreadMode.blocked;
  if (h.requestState == RequestState.pending) {
    if (h.direction == RequestDirection.incoming) return ThreadMode.incomingRequest;
    if (h.direction == RequestDirection.outgoing) return ThreadMode.outgoingRequest;
  }
  return ThreadMode.open;
}

/// The poll runs only while the thread is open and visible and the viewer is the one waiting.
const kOutgoingPendingPollInterval = Duration(seconds: 25);

class IncomingRequestPanel extends StatelessWidget {
  const IncomingRequestPanel({super.key, required this.name, required this.busy, required this.onAccept, required this.onDecline, required this.onBlockAndReport});

  final String name;
  final bool busy;
  final VoidCallback onAccept;
  final VoidCallback onDecline;
  final VoidCallback onBlockAndReport;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SafeArea(
      top: false,
      child: Container(
        key: const Key('dm-incoming-request'),
        width: double.infinity,
        color: SxColors.surface,
        padding: const EdgeInsets.all(16),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(l10n.dmIncomingTitle(name), style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(l10n.dmIncomingHint, style: const TextStyle(fontSize: 12, color: SxColors.textSecondary)),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: FilledButton(key: const Key('dm-accept'), onPressed: busy ? null : onAccept, child: Text(l10n.dmAccept))),
            const SizedBox(width: 8),
            Expanded(child: OutlinedButton(key: const Key('dm-decline'), onPressed: busy ? null : onDecline, child: Text(l10n.dmDecline))),
          ]),
          const SizedBox(height: 4),
          Center(child: TextButton(key: const Key('dm-block-report'), onPressed: busy ? null : onBlockAndReport, child: Text(l10n.dmBlockAndReport))),
        ]),
      ),
    );
  }
}

/// Replaces the composer once the viewer has sent their one message and is waiting for acceptance.
class WaitingBanner extends StatelessWidget {
  const WaitingBanner({super.key, required this.name});
  final String name;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SafeArea(
      top: false,
      child: Container(
        key: const Key('dm-waiting-banner'),
        width: double.infinity,
        color: SxColors.surface,
        padding: const EdgeInsets.all(16),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(l10n.dmWaitingFor(name), style: const TextStyle(fontWeight: FontWeight.w600), textAlign: TextAlign.center),
          const SizedBox(height: 2),
          Text(l10n.dmWaitingHint, style: const TextStyle(fontSize: 12, color: SxColors.textSecondary), textAlign: TextAlign.center),
        ]),
      ),
    );
  }
}
