import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/api/community_models.dart';
import '../../core/l10n/gen/app_localizations.dart';
import '../../core/utils/write_flow.dart';
import '../../shared/widgets/player_avatar.dart';
import 'boost_sheet.dart';
import 'community_error_copy.dart';
import 'community_providers.dart';
import 'reaction_bar.dart';

enum _PostAction { boost, delete }

bool _isBoosted(PostView post) {
  final until = post.boostedUntil == null ? null : DateTime.tryParse(post.boostedUntil!);
  return until != null && until.isAfter(DateTime.now());
}

/// A single post in the feed. Delete/boost entries are driven solely by the server's
/// [PostView.canDelete]/[PostView.canBoost] (never inferred from `postType`) and are absent, not
/// disabled, when not allowed. [compact] strips the interactive footer and menu for the gallery grid.
class PostCard extends ConsumerWidget {
  const PostCard({super.key, required this.post, required this.onTap, required this.onSignInRequired, this.compact = false});
  final PostView post;
  final VoidCallback onTap, onSignInRequired;
  final bool compact;

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Text(l10n.cmtDeletePostConfirm),
        actions: [
          TextButton(key: const Key('post-delete-cancel'), onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.cmtDeleteConfirmCancel)),
          TextButton(key: const Key('post-delete-confirm'), onPressed: () => Navigator.pop(ctx, true), child: Text(l10n.cmtDeleteConfirmYes)),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final scope = 'delete-post:${post.id}';
    final ok = await ref.read(writeFlowProvider(scope).notifier).run((_) => ref.read(communityRepositoryProvider).deletePost(post.id));
    if (!context.mounted) return;
    if (ok) {
      ref.read(communityFeedProvider.notifier).removePost(post.id);
      return;
    }
    final code = ref.read(writeFlowProvider(scope)).errorCode ?? 'network';
    messenger.showSnackBar(SnackBar(content: Text(communityErrorCopy(l10n, code))));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final created = DateTime.tryParse(post.createdAt)?.toLocal();
    final when = created == null ? post.createdAt : DateFormat.yMMMd(l10n.localeName).add_Hm().format(created);
    final boosted = _isBoosted(post);
    final hasMenu = !compact && (post.canDelete || post.canBoost);
    final extraImages = post.imageUrls.where((u) => u != post.imageUrl).toList();

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              PlayerAvatar(avatarUrl: post.author.avatarUrl, frameUrl: post.author.frameUrl),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(post.author.displayName ?? post.author.username ?? '', style: theme.textTheme.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text(when, style: theme.textTheme.bodySmall),
                ]),
              ),
              if (hasMenu)
                PopupMenuButton<_PostAction>(
                  key: Key('post-menu-${post.id}'),
                  onSelected: (action) => switch (action) {
                    _PostAction.boost => showBoostSheet(context, post: post),
                    _PostAction.delete => _confirmDelete(context, ref),
                  },
                  itemBuilder: (_) => [
                    if (post.canBoost) PopupMenuItem(key: Key('post-boost-${post.id}'), value: _PostAction.boost, child: Text(l10n.cmtBoostAction)),
                    if (post.canDelete) PopupMenuItem(key: Key('post-delete-${post.id}'), value: _PostAction.delete, child: Text(l10n.cmtDeletePost)),
                  ],
                ),
            ]),
            if (post.isPinned || boosted)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Wrap(spacing: 6, children: [
                  if (post.isPinned) Chip(label: Text(l10n.cmtPinnedLabel), visualDensity: VisualDensity.compact),
                  if (boosted) Chip(label: Text(l10n.cmtBoostedLabel), visualDensity: VisualDensity.compact),
                ]),
              ),
            if (post.content.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Text(post.content)),
            if (post.imageUrl != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Image.network(post.imageUrl!, key: const Key('post-image'), errorBuilder: (_, _, _) => const SizedBox.shrink()),
              ),
            if (!compact && extraImages.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: SizedBox(
                  height: 72,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: extraImages.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 6),
                    itemBuilder: (_, i) => Image.network(extraImages[i], key: Key('post-thumb-$i'), width: 72, height: 72, fit: BoxFit.cover, errorBuilder: (_, _, _) => const SizedBox(width: 72, height: 72)),
                  ),
                ),
              ),
            if (!compact)
              Wrap(alignment: WrapAlignment.spaceBetween, crossAxisAlignment: WrapCrossAlignment.center, children: [
                ReactionBar(
                  post: post,
                  onUpdate: (transform) => ref.read(communityFeedProvider.notifier).updatePost(post.id, transform),
                  onSignInRequired: onSignInRequired,
                ),
                TextButton(onPressed: onTap, child: Text(l10n.cmtCommentCount(post.commentCount))),
              ]),
          ]),
        ),
      ),
    );
  }
}
