import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/l10n/gen/app_localizations.dart';
import '../../core/providers.dart';
import '../../shared/widgets/player_avatar.dart';
import '../progress/history_labels.dart';
import 'players_providers.dart';

class FollowListScreen extends ConsumerWidget {
  const FollowListScreen({super.key, required this.username, required this.kind, required this.onPlayerTap});

  final String username;
  final FollowListKind kind;
  final void Function(String username) onPlayerTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final args = (username, kind);
    final list = ref.watch(followListProvider(args));
    final me = ref.watch(meProvider).asData?.value;
    // Viewer state comes only from /me/follows; signed out means null and no request.
    final sets = ref.watch(myFollowsProvider).asData?.value;
    final isFollowers = kind == FollowListKind.followers;
    return Scaffold(
      appBar: AppBar(title: Text(isFollowers ? l10n.followersTitle : l10n.followingTitle)),
      body: list.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => e is ApiException && e.status == 404
            ? Center(child: Text(l10n.playersNotFound))
            : Center(child: TextButton(onPressed: () => ref.invalidate(followListProvider(args)), child: Text(l10n.commonLoadError))),
        data: (entries) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(followListProvider(args)),
          child: entries.isEmpty
              ? ListView(children: [Padding(padding: const EdgeInsets.all(24), child: Center(child: Text(isFollowers ? l10n.followersEmpty : l10n.followingEmpty)))])
              : ListView.builder(
                  itemCount: entries.length,
                  itemBuilder: (context, i) {
                    final e = entries[i];
                    final isMe = me != null && me.id == e.id;
                    final iFollow = !isMe && (sets?.followingIds.contains(e.id) ?? false);
                    final followsMe = !isMe && (sets?.followerIds.contains(e.id) ?? false);
                    return ListTile(
                      leading: PlayerAvatar(avatarUrl: e.avatarUrl, isDeleted: e.isDeleted, size: 40),
                      title: Text(e.isDeleted ? l10n.commonDeletedPlayer : e.label, maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text(tierLabel(l10n, e.membershipTier)),
                      trailing: Wrap(spacing: 4, children: [
                        if (iFollow) Chip(key: Key('chip-following-${e.id}'), label: Text(l10n.profileFollowing)),
                        if (followsMe) Chip(key: Key('chip-follows-you-${e.id}'), label: Text(l10n.profileFollowsYou)),
                      ]),
                      // A tombstone has no profile to open.
                      onTap: e.isDeleted ? null : () => onPlayerTap(e.username!),
                    );
                  },
                ),
        ),
      ),
    );
  }
}
