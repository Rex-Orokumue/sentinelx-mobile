import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/community_models.dart';
import '../../core/l10n/gen/app_localizations.dart';
import '../../core/providers.dart';
import '../../core/theme/sx_colors.dart';
import '../../core/utils/write_flow.dart';
import 'community_error_copy.dart';
import 'community_providers.dart';

extension PostViewReaction on PostView {
  /// Same-turn optimistic delta only (Global Constraints Ruling) — not a recomputation of
  /// server-aggregate logic, a trivially-correct ±1 for exactly the caller's own slot.
  PostView withMyReaction(ReactionType? next) {
    if (next == myReaction) return this;
    var counts = reactionCounts;
    if (myReaction != null) counts = counts.decrement(myReaction!);
    if (next != null) counts = counts.increment(next);
    return copyWith(reactionCounts: counts, myReaction: next, clearMyReaction: next == null);
  }
}

const _kReactionTypes = [ReactionType.fire, ReactionType.crown, ReactionType.strong, ReactionType.wow];

IconData _iconFor(ReactionType type) => switch (type) {
      ReactionType.fire => Icons.local_fire_department,
      ReactionType.crown => Icons.emoji_events,
      ReactionType.strong => Icons.fitness_center,
      ReactionType.wow => Icons.emoji_emotions,
    };

String _labelFor(AppLocalizations l10n, ReactionType type) => switch (type) {
      ReactionType.fire => l10n.cmtReactFire,
      ReactionType.crown => l10n.cmtReactCrown,
      ReactionType.strong => l10n.cmtReactStrong,
      ReactionType.wow => l10n.cmtReactWow,
    };

/// A 4-emoji reaction bar for a community post. Applies same-turn optimistic updates via
/// [onUpdate] (wired to the owning feed/detail notifier's `updatePost`) and rolls back on
/// failure. Gated on sign-in: signed-out taps never call the API and only invoke
/// [onSignInRequired]. Writes are idempotent and busy-guarded through [writeFlowProvider], scoped
/// per post so concurrent reactions on different posts never block each other.
class ReactionBar extends ConsumerWidget {
  const ReactionBar({super.key, required this.post, required this.onUpdate, required this.onSignInRequired});
  final PostView post;
  final void Function(PostView Function(PostView) transform) onUpdate;
  final VoidCallback onSignInRequired;

  Future<void> _tap(BuildContext context, WidgetRef ref, ReactionType tapped) async {
    if (ref.read(meProvider).asData?.value == null) {
      onSignInRequired();
      return;
    }
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final next = post.myReaction == tapped ? null : tapped;
    final before = post;
    onUpdate((_) => before.withMyReaction(next));
    final repo = ref.read(communityRepositoryProvider);
    final scope = 'react:${post.id}';
    final ok = await ref.read(writeFlowProvider(scope).notifier).run(
          (key) => next == null ? repo.removeReaction(post.id) : repo.setReaction(post.id, next, idempotencyKey: key),
          fingerprint: next?.wireName ?? 'remove',
        );
    if (ok) return;
    onUpdate((_) => before);
    if (!context.mounted) return;
    final code = ref.read(writeFlowProvider(scope)).errorCode ?? 'network';
    messenger.showSnackBar(SnackBar(content: Text(communityErrorCopy(l10n, code))));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watched (not just read-on-tap) so `meProvider` is already resolved by tap time — a bare
    // `ref.read` in `_tap` would otherwise instantiate it fresh on the first tap and see
    // `AsyncLoading`, which reads as "signed out" and wrongly skips the write.
    ref.watch(meProvider);
    final l10n = AppLocalizations.of(context);
    final scope = 'react:${post.id}';
    final busy = ref.watch(writeFlowProvider(scope)).busy;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final type in _kReactionTypes)
          Semantics(
            label: _labelFor(l10n, type),
            child: IconButton(
              key: Key('react-${type.wireName}'),
              onPressed: busy ? null : () => _tap(context, ref, type),
              icon: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(_iconFor(type), color: post.myReaction == type ? SxColors.warning : SxColors.textSecondary),
                  Text('${post.reactionCounts[type]}'),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
