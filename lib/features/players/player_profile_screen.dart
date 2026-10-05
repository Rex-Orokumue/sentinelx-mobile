import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/api/players_models.dart';
import '../../core/l10n/gen/app_localizations.dart';
import '../../core/providers.dart';
import '../messages/inbox_providers.dart';
import '../messages/message_error_copy.dart';
import 'players_providers.dart';
import 'profile_sections.dart';

class PlayerProfileScreen extends ConsumerWidget {
  const PlayerProfileScreen({
    super.key,
    required this.username,
    required this.onLogIn,
    required this.onOpenFollowers,
    required this.onOpenFollowing,
    required this.onMessage,
  });

  final String username;
  final VoidCallback onLogIn;
  final void Function(String username) onOpenFollowers;
  final void Function(String username) onOpenFollowing;

  /// Called with the thread id once a conversation with this player exists (started or already there).
  final void Function(String threadId) onMessage;

  Future<void> _toggle(BuildContext context, WidgetRef ref, ProfileHeader p, bool following) async {
    final notifier = ref.read(myFollowsProvider.notifier);
    final failure = following
        ? await notifier.unfollow(targetId: p.id, username: p.username)
        : await notifier.follow(targetId: p.id, username: p.username);
    if (failure == null || !context.mounted) return;
    if (failure == FollowFailure.unauthorized) return onLogIn();
    final l10n = AppLocalizations.of(context);
    final message = switch (failure) {
      FollowFailure.self => l10n.followErrorSelf,
      FollowFailure.blocked => l10n.followErrorBlocked,
      FollowFailure.notFound => l10n.followErrorNotFound,
      _ => l10n.followErrorGeneric,
    };
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final profile = ref.watch(playerProfileProvider(username));
    return Scaffold(
      appBar: AppBar(title: Text('@$username')),
      body: profile.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) {
          if (e is ApiException && e.status == 404) {
            return Center(key: const Key('player-not-found'), child: Text(l10n.playersNotFound));
          }
          return Center(
            child: TextButton(onPressed: () => ref.invalidate(playerProfileProvider(username)), child: Text(l10n.commonLoadError)),
          );
        },
        data: (p) => _ProfileBody(
          profile: p,
          onLogIn: onLogIn,
          onToggle: (following) => _toggle(context, ref, p.player, following),
          onOpenFollowers: () => onOpenFollowers(p.player.username),
          onOpenFollowing: () => onOpenFollowing(p.player.username),
          onMessage: onMessage,
        ),
      ),
    );
  }
}

class _ProfileBody extends ConsumerWidget {
  const _ProfileBody({
    required this.profile,
    required this.onLogIn,
    required this.onToggle,
    required this.onOpenFollowers,
    required this.onOpenFollowing,
    required this.onMessage,
  });

  final PlayerProfile profile;
  final VoidCallback onLogIn;
  final Future<void> Function(bool following) onToggle;
  final VoidCallback onOpenFollowers;
  final VoidCallback onOpenFollowing;
  final void Function(String threadId) onMessage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final p = profile.player;
    final me = ref.watch(meProvider).asData?.value;
    final follows = ref.watch(myFollowsProvider);
    final sets = follows.asData?.value;
    final delta = ref.watch(followerDeltaProvider)[p.id] ?? 0;
    final siteUrl = ref.watch(appConfigProvider).apiBaseUrl;
    final isOwn = me != null && me.id == p.id;
    final signedIn = me != null;
    final following = sets?.followingIds.contains(p.id) ?? false;
    final followsYou = sets?.followerIds.contains(p.id) ?? false;

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(playerProfileProvider(p.username));
        ref.invalidate(myFollowsProvider);
      },
      child: ListView(
        children: [
          ProfileHeaderSection(
            player: p,
            siteUrl: siteUrl,
            followerCount: profile.stats.followerCount + delta,
            followingCount: profile.stats.followingCount,
            onFollowers: onOpenFollowers,
            onFollowing: onOpenFollowing,
          ),
          if (!isOwn)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: following
                        ? FilledButton.tonal(
                            key: const Key('follow-button'),
                            onPressed: follows.isLoading ? null : () => onToggle(true),
                            child: Text(l10n.profileFollowing),
                          )
                        : FilledButton(
                            key: const Key('follow-button'),
                            // Signed out: Follow opens login instead of flipping any state.
                            onPressed: !signedIn ? onLogIn : (follows.isLoading ? null : () => onToggle(false)),
                            child: Text(l10n.profileFollow),
                          ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: _MessageButton(playerId: p.id, signedIn: signedIn, onLogIn: onLogIn, onOpen: onMessage)),
                ],
              ),
            ),
          if (!isOwn && followsYou)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Chip(key: const Key('follows-you-chip'), label: Text(l10n.profileFollowsYou)),
              ),
            ),
          const SizedBox(height: 8),
          ProfileStatsGrid(stats: profile.stats),
          CategoryStatsSection(stats: profile.stats.categoryStats),
          TitlesSection(titles: profile.titles),
          RecentMatchesSection(matches: profile.recentMatches),
          AchievementsSection(achievements: profile.achievements),
          PostsSection(posts: profile.posts),
          GallerySection(images: profile.gallery),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

/// Starts (or reopens) the conversation with this player through the API, then hands the thread id to
/// [onOpen]. Disabled while in flight, so a double tap starts one request.
class _MessageButton extends ConsumerStatefulWidget {
  const _MessageButton({required this.playerId, required this.signedIn, required this.onLogIn, required this.onOpen});

  final String playerId;
  final bool signedIn;
  final VoidCallback onLogIn;
  final void Function(String threadId) onOpen;

  @override
  ConsumerState<_MessageButton> createState() => _MessageButtonState();
}

class _MessageButtonState extends ConsumerState<_MessageButton> {
  bool _busy = false;

  Future<void> _tap() async {
    if (!widget.signedIn) return widget.onLogIn();
    if (_busy) return;
    final repo = ref.read(messagesRepositoryProvider);
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      final started = await repo.start(widget.playerId);
      if (mounted) widget.onOpen(started.threadId);
    } catch (e) {
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(SnackBar(content: Text(dmErrorCopy(l10n, e))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return OutlinedButton.icon(
      key: const Key('message-button'),
      onPressed: _busy ? null : _tap,
      icon: const Icon(Icons.mail_outline, size: 18),
      label: Text(l10n.dmMessageButton, maxLines: 1, overflow: TextOverflow.ellipsis),
    );
  }
}
