import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/community_models.dart';
import '../../core/l10n/gen/app_localizations.dart';
import '../../core/providers.dart';
import '../../core/utils/write_flow.dart';
import '../../shared/widgets/player_avatar.dart';
import 'community_error_copy.dart';
import 'community_providers.dart';
import 'community_realtime.dart';
import 'post_card.dart';
import 'status_tray.dart';

/// The Community tab's landing screen: status tray, weekly challenges, Best Play, pinned then
/// regular posts, and a trailing "discover" block. Every side rail is backed by its own provider and
/// degrades independently — a loading, empty or failed rail simply isn't drawn, it never blanks the
/// feed or another rail.
class CommunityFeedScreen extends ConsumerWidget {
  const CommunityFeedScreen({
    super.key,
    required this.onCompose,
    required this.onPostTap,
    required this.onLogin,
    required this.onStatusTap,
    required this.onAddStatus,
    this.onEventTap,
  });
  final VoidCallback onCompose, onLogin, onAddStatus;
  final void Function(PostView post) onPostTap;
  final void Function(StatusRing ring) onStatusTap;
  final void Function(UpcomingEvent event)? onEventTap;

  Future<void> _refresh(WidgetRef ref) async {
    ref.invalidate(communityStatusRingsProvider);
    ref.invalidate(communityChallengesProvider);
    ref.invalidate(communityBestPlayProvider);
    ref.invalidate(communityTopMembersProvider);
    ref.invalidate(communityUpcomingEventsProvider);
    ref.invalidate(communityGalleryProvider);
    ref.invalidate(communityStatsProvider);
    await ref.read(communityFeedProvider.notifier).refresh();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final signedIn = ref.watch(meProvider).asData?.value != null;
    final feed = ref.watch(communityFeedProvider);

    ref.listen(communityFeedRealtimeProvider, (_, next) {
      if (!next.hasValue) return;
      ref.invalidate(communityFeedProvider);
      ref.invalidate(communityStatusRingsProvider);
    });

    // Rendered from the last good value so a background refetch (realtime, refresh) never swaps
    // the list for a spinner or loses the scroll position.
    final feedState = feed.value;
    final feedSlivers = <Widget>[
      if (feedState != null) ...[
        if (feedState.pinned.isEmpty && feedState.posts.isEmpty)
          SliverToBoxAdapter(
            child: Padding(padding: const EdgeInsets.all(24), child: Center(child: Text(l10n.cmtFeedEmpty, textAlign: TextAlign.center))),
          ),
        SliverList.builder(
          itemCount: feedState.pinned.length,
          itemBuilder: (_, i) => _card(feedState.pinned[i]),
        ),
        SliverList.builder(
          itemCount: feedState.posts.length,
          itemBuilder: (_, i) => _card(feedState.posts[i]),
        ),
        if (feedState.hasMore)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: feedState.loadingMore
                    ? const CircularProgressIndicator()
                    : TextButton(
                        key: const Key('feed-load-more'),
                        onPressed: () => ref.read(communityFeedProvider.notifier).loadMore(),
                        child: Text(l10n.cmtLoadMore),
                      ),
              ),
            ),
          ),
      ] else if (feed.hasError)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(children: [
              Text(l10n.cmtFeedLoadError, textAlign: TextAlign.center),
              const SizedBox(height: 8),
              FilledButton(key: const Key('feed-retry'), onPressed: () => ref.invalidate(communityFeedProvider), child: Text(l10n.cmtRetry)),
            ]),
          ),
        )
      else
        const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()))),
    ];

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        key: const Key('feed-compose-fab'),
        tooltip: l10n.cmtComposeFab,
        onPressed: signedIn ? onCompose : onLogin,
        child: const Icon(Icons.add),
      ),
      body: RefreshIndicator(
        onRefresh: () => _refresh(ref),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: StatusTray(onRingTap: onStatusTap, onAddYours: signedIn ? onAddStatus : onLogin),
            ),
            SliverToBoxAdapter(child: _ChallengesRail(onLogin: onLogin)),
            SliverToBoxAdapter(child: _BestPlayBanner(onLogin: onLogin)),
            ...feedSlivers,
            SliverToBoxAdapter(child: _Discover(onEventTap: onEventTap)),
            const SliverToBoxAdapter(child: SizedBox(height: 88)),
          ],
        ),
      ),
    );
  }

  Widget _card(PostView post) => PostCard(post: post, onTap: () => onPostTap(post), onSignInRequired: onLogin);
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;
  @override
  Widget build(BuildContext context) =>
      Padding(padding: const EdgeInsets.fromLTRB(16, 16, 16, 8), child: Text(text, style: Theme.of(context).textTheme.titleMedium));
}

class _ChallengesRail extends ConsumerWidget {
  const _ChallengesRail({required this.onLogin});
  final VoidCallback onLogin;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final me = ref.watch(meProvider);
    if (me.isLoading || me.hasError) return const SizedBox.shrink();
    if (me.value == null) {
      return Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 8), child: Text(l10n.cmtChallengesSignedOut));
    }
    final widget = ref.watch(communityChallengesProvider).asData?.value;
    if (widget == null || widget.challenges.isEmpty) return const SizedBox.shrink();
    return Column(key: const Key('challenges-rail'), crossAxisAlignment: CrossAxisAlignment.start, children: [
      _SectionTitle(l10n.cmtChallengesTitle),
      for (final c in widget.challenges)
        ListTile(
          dense: true,
          title: Text(c.title),
          subtitle: Text(c.description),
          trailing: c.completed
              ? Text(l10n.cmtChallengeCompleted, style: Theme.of(context).textTheme.labelMedium)
              : Text(l10n.cmtChallengeProgress(c.progress, c.goal)),
        ),
    ]);
  }
}

class _BestPlayBanner extends ConsumerWidget {
  const _BestPlayBanner({required this.onLogin});
  final VoidCallback onLogin;

  static const _scope = 'bestplay-vote';

  Future<void> _vote(BuildContext context, WidgetRef ref, String nominationId, {required bool signedIn}) async {
    if (!signedIn) {
      onLogin();
      return;
    }
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final ok = await ref.read(writeFlowProvider(_scope).notifier).run(
          (key) => ref.read(communityRepositoryProvider).voteBestPlay(nominationId, idempotencyKey: key),
          fingerprint: nominationId,
        );
    if (!ok || !context.mounted) return;
    ref.invalidate(communityBestPlayProvider);
    messenger.showSnackBar(SnackBar(content: Text(l10n.cmtBestPlayVoteSuccess)));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final banner = ref.watch(communityBestPlayProvider).asData?.value;
    if (banner == null) return const SizedBox.shrink();
    final signedIn = ref.watch(meProvider).asData?.value != null;
    final flow = ref.watch(writeFlowProvider(_scope));
    final voted = banner.myVoteNominationId != null;
    return Column(key: const Key('bestplay-banner'), crossAxisAlignment: CrossAxisAlignment.start, children: [
      _SectionTitle(l10n.cmtBestPlayTitle),
      if (banner.nominations.isEmpty)
        Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Text(l10n.cmtBestPlayEmpty)),
      for (final n in banner.nominations)
        ListTile(
          dense: true,
          title: Text(n.content, maxLines: 2, overflow: TextOverflow.ellipsis),
          subtitle: Text(n.authorName),
          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
            Text('${n.voteCount}'),
            const SizedBox(width: 8),
            OutlinedButton(
              key: Key('bestplay-vote-${n.nominationId}'),
              onPressed: voted || flow.busy ? null : () => _vote(context, ref, n.nominationId, signedIn: signedIn),
              child: Text(banner.myVoteNominationId == n.nominationId ? l10n.cmtBestPlayVoted : l10n.cmtBestPlayVote),
            ),
          ]),
        ),
      if (flow.phase == WritePhase.failed)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
          child: Text(communityErrorCopy(l10n, flow.errorCode ?? ''), style: TextStyle(color: Theme.of(context).colorScheme.error)),
        ),
    ]);
  }
}

class _Discover extends ConsumerWidget {
  const _Discover({this.onEventTap});
  final void Function(UpcomingEvent event)? onEventTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final members = ref.watch(communityTopMembersProvider).asData?.value ?? const <TopMember>[];
    final events = ref.watch(communityUpcomingEventsProvider).asData?.value ?? const <UpcomingEvent>[];
    final gallery = ref.watch(communityGalleryProvider).asData?.value;
    final stats = ref.watch(communityStatsProvider).asData?.value;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (members.isNotEmpty) ...[
        _SectionTitle(l10n.cmtTopMembersTitle),
        for (final m in members)
          ListTile(
            dense: true,
            leading: Row(mainAxisSize: MainAxisSize.min, children: [
              SizedBox(width: 24, child: Text('${m.rank}')),
              PlayerAvatar(avatarUrl: m.avatarUrl, frameUrl: m.frameUrl, size: 32),
            ]),
            title: Text(m.displayName ?? m.username ?? ''),
            trailing: Text('${m.xp}'),
          ),
      ],
      if (events.isNotEmpty) ...[
        _SectionTitle(l10n.cmtUpcomingEventsTitle),
        for (final e in events)
          ListTile(
            dense: true,
            title: Text(e.title),
            subtitle: Text('${e.date} · ${e.time}'),
            trailing: onEventTap == null ? null : Text(e.ctaLabel),
            onTap: onEventTap == null ? null : () => onEventTap!(e),
          ),
      ],
      if (gallery != null && gallery.items.isNotEmpty) ...[
        _SectionTitle(l10n.cmtGalleryTitle),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: GridView.count(
            crossAxisCount: 4,
            mainAxisSpacing: 4,
            crossAxisSpacing: 4,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              for (final g in gallery.items)
                Image.network(g.imageUrl, key: Key('gallery-${g.id}'), fit: BoxFit.cover, errorBuilder: (_, _, _) => const ColoredBox(color: Colors.black12)),
            ],
          ),
        ),
      ],
      if (stats != null)
        Padding(
          padding: const EdgeInsets.all(16),
          child: Wrap(spacing: 16, runSpacing: 4, children: [
            Text(l10n.cmtStatsMembers(stats.memberCount)),
            Text(l10n.cmtStatsCountries(stats.countryCount)),
            Text(l10n.cmtStatsTournaments(stats.tournamentCount)),
          ]),
        ),
    ]);
  }
}
