import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/l10n/gen/app_localizations.dart';
import 'compete_models.dart';
import 'compete_providers.dart';
import 'error_copy.dart';
import 'registration_flow.dart';

class InvitationsScreen extends ConsumerWidget {
  const InvitationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final async = ref.watch(myInvitationsProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.cmpInvTitle)),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(l10n.cmpLoadError, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              OutlinedButton(onPressed: () => ref.invalidate(myInvitationsProvider), child: Text(l10n.cmpRetry)),
            ]),
          ),
        ),
        data: (items) => items.isEmpty
            ? Center(child: Text(l10n.cmpInvEmpty))
            : ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: items.length,
                itemBuilder: (_, i) => _InvitationTile(key: ValueKey(items[i].id), invitation: items[i]),
              ),
      ),
    );
  }
}

class _InvitationTile extends ConsumerStatefulWidget {
  const _InvitationTile({super.key, required this.invitation});
  final PendingInvitation invitation;

  @override
  ConsumerState<_InvitationTile> createState() => _InvitationTileState();
}

class _InvitationTileState extends ConsumerState<_InvitationTile> {
  bool _declining = false;

  Future<void> _decline() async {
    if (_declining) return;
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _declining = true);
    try {
      await ref.read(registrationRepositoryProvider).declineInvitation(widget.invitation.id);
      if (!mounted) return;
      ref.invalidate(myInvitationsProvider);
      messenger.showSnackBar(SnackBar(content: Text(l10n.cmpInvDeclined)));
    } catch (e) {
      if (!mounted) return;
      final code = e is ApiException ? (e.isUnauthorized ? 'unauthorized' : e.code) : 'network';
      messenger.showSnackBar(SnackBar(content: Text(errorCopy(l10n, code))));
    } finally {
      if (mounted) setState(() => _declining = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final inv = widget.invitation;
    final flowProvider = registrationFlowProvider(inv.tournamentId);

    ref.listen<FlowState>(flowProvider, (prev, next) {
      if (prev?.phase == next.phase && prev?.errorCode == next.errorCode) return;
      final messenger = ScaffoldMessenger.of(context);
      String? message;
      switch (next.phase) {
        case FlowPhase.confirmed:
          final paid = prev?.phase == FlowPhase.confirming || prev?.phase == FlowPhase.awaitingPayment;
          message = paid ? l10n.cmpPaySuccess : l10n.cmpConfirmedFree;
          ref.invalidate(myInvitationsProvider);
        // The invitation is claimed server-side before payment starts, so after any of these the
        // list must be re-read, and no copy may promise an in-app resume (there is none).
        case FlowPhase.notConfirmed:
          message = l10n.cmpPayNotConfirmed;
          ref.invalidate(myInvitationsProvider);
        case FlowPhase.cancelled:
          message = l10n.cmpInvPayCancelled;
          ref.invalidate(myInvitationsProvider);
        case FlowPhase.failed:
          message = errorCopy(l10n, next.errorCode ?? '');
          ref.invalidate(myInvitationsProvider);
        default:
      }
      if (message != null) messenger.showSnackBar(SnackBar(content: Text(message)));
    });

    final busy = ref.watch(flowProvider).busy || _declining;
    final date = MaterialLocalizations.of(context).formatMediumDate(inv.expiresAt.toLocal());
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(inv.tournamentTitle, style: Theme.of(context).textTheme.titleMedium, maxLines: 2, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 4),
          Text('${l10n.cmpEntryFee}: ${inv.registrationFee == 0 ? l10n.cmpFree : '₦${inv.registrationFee}'}'),
          Text(l10n.cmpInvExpires(date)),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: FilledButton(
                key: Key('inv-accept-${inv.id}'),
                onPressed: busy ? null : () => ref.read(flowProvider.notifier).submitInvitationAccept(inv.id),
                child: Text(l10n.cmpInvAccept),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton(
                key: Key('inv-decline-${inv.id}'),
                onPressed: busy ? null : _decline,
                child: Text(l10n.cmpInvDecline),
              ),
            ),
          ]),
        ]),
      ),
    );
  }
}
