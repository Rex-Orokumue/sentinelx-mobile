import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/community_models.dart';
import '../../core/l10n/gen/app_localizations.dart';
import '../../core/utils/write_flow.dart';
import 'community_error_copy.dart';
import 'community_providers.dart';

/// Confirm-and-submit sheet for boosting a post (200 SX Coins, pins it to the top of the feed for
/// 24 hours). Idempotent write through [CommunityRepository.boostPost]; no varying payload, so no
/// fingerprint is passed to [WriteFlow.run] — the same idempotency key is safe to reuse across
/// retries of the same tap.
Future<void> showBoostSheet(BuildContext context, {required PostView post}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    isDismissible: true, // narrowed to !busy inside via PopScope
    // Dragging would bypass PopScope and orphan an in-flight boost; disabled unconditionally
    // (matches wager_sheet.dart / rating_sheet.dart) rather than only while busy, since a mid-drag
    // can start before the busy flag is set.
    enableDrag: false,
    builder: (_) => _BoostSheetBody(post: post),
  );
}

class _BoostSheetBody extends ConsumerWidget {
  const _BoostSheetBody({required this.post});
  final PostView post;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final scope = 'boost:${post.id}';
    final state = ref.watch(writeFlowProvider(scope));
    final busy = state.busy;
    final errorCopy = state.phase == WritePhase.failed ? communityErrorCopy(l10n, state.errorCode ?? '') : null;

    Future<void> submit() async {
      final messenger = ScaffoldMessenger.of(context);
      final navigator = Navigator.of(context);
      final ok = await ref.read(writeFlowProvider(scope).notifier).run(
            (key) => ref.read(communityRepositoryProvider).boostPost(post.id, idempotencyKey: key),
          );
      if (!context.mounted) return;
      if (ok) {
        ref.invalidate(communityFeedProvider);
        ref.invalidate(communityPostDetailProvider(post.id));
        navigator.pop();
        messenger.showSnackBar(SnackBar(content: Text(l10n.cmtBoostSuccess)));
      }
    }

    return PopScope(
      canPop: !busy,
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(l10n.cmtBoostConfirmTitle, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(l10n.cmtBoostConfirmBody),
          if (errorCopy != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(errorCopy)),
          const SizedBox(height: 16),
          FilledButton(
            key: const Key('boost-confirm'),
            onPressed: busy ? null : submit,
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              if (busy) ...[
                const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                const SizedBox(width: 8),
              ],
              Text(l10n.cmtBoostConfirm),
            ]),
          ),
        ]),
      ),
    );
  }
}
