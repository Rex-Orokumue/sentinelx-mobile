import 'package:flutter/material.dart';

import '../../core/api/players_models.dart';
import '../../core/l10n/gen/app_localizations.dart';
import '../../core/theme/sx_colors.dart';
import '../../shared/widgets/player_avatar.dart';
import '../progress/history_labels.dart';

class ProfileHeaderSection extends StatelessWidget {
  const ProfileHeaderSection({
    super.key,
    required this.player,
    required this.siteUrl,
    required this.followerCount,
    required this.followingCount,
    required this.onFollowers,
    required this.onFollowing,
  });

  final ProfileHeader player;
  final String siteUrl;
  final int followerCount;
  final int followingCount;
  final VoidCallback onFollowers;
  final VoidCallback onFollowing;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              PlayerAvatar(avatarUrl: player.avatarUrl, frameUrl: resolveAsset(player.frameUrl, siteUrl), size: 72),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(player.label, style: theme.textTheme.titleLarge, maxLines: 2, overflow: TextOverflow.ellipsis),
                    Text('@${player.username}', style: theme.textTheme.bodyMedium?.copyWith(color: SxColors.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              Chip(label: Text(tierLabel(l10n, player.membershipTier))),
              if (player.sentinelTier != null) Chip(label: Text(humanizeCode(player.sentinelTier!))),
              if (player.country != null) Chip(label: Text(player.country!)),
              Chip(label: Text(l10n.profileSxScore(player.sxScore))),
            ],
          ),
          if (player.bio != null && player.bio!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(player.bio!),
          ],
          const SizedBox(height: 8),
          Wrap(
            spacing: 16,
            children: [
              TextButton(key: const Key('profile-followers'), onPressed: onFollowers, child: Text(l10n.profileFollowersCount(followerCount))),
              TextButton(key: const Key('profile-following'), onPressed: onFollowing, child: Text(l10n.profileFollowingCount(followingCount))),
            ],
          ),
        ],
      ),
    );
  }
}

class SectionHeading extends StatelessWidget {
  const SectionHeading(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Text(text, style: Theme.of(context).textTheme.titleMedium),
      );
}

class ProfileStatsGrid extends StatelessWidget {
  const ProfileStatsGrid({super.key, required this.stats});
  final ProfileStats stats;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final rank = stats.rank == null ? l10n.profileRankUnranked : l10n.profileRankOf(stats.rank!, stats.totalRankedPlayers ?? stats.rank!);
    final tiles = <(String, String)>[
      (l10n.profileStatRank, rank),
      (l10n.profileStatMatches, '${stats.totalMatches}'),
      (l10n.profileStatWins, '${stats.wins}'),
      (l10n.profileStatLosses, '${stats.losses}'),
      (l10n.profileStatGoalsFor, '${stats.goalsScored}'),
      (l10n.profileStatGoalsAgainst, '${stats.goalsConceded}'),
      (l10n.profileStatTitles, '${stats.totalTitles}'),
      (l10n.profileStatTournaments, '${stats.tournamentsPlayed}'),
      (l10n.profileStatStreak, '${stats.currentStreak}'),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final t in tiles)
            Container(
              width: 104,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: SxColors.surface, borderRadius: BorderRadius.circular(8), border: Border.all(color: SxColors.border)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t.$2, style: Theme.of(context).textTheme.titleMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text(t.$1, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: SxColors.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class CategoryStatsSection extends StatelessWidget {
  const CategoryStatsSection({super.key, required this.stats});
  final List<CategoryStat> stats;

  @override
  Widget build(BuildContext context) {
    if (stats.isEmpty) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeading(l10n.profileCategoryStats),
        for (final c in stats)
          ListTile(dense: true, title: Text(humanizeCode(c.category)), trailing: Text('${c.scored} / ${c.conceded}')),
      ],
    );
  }
}

class TitlesSection extends StatelessWidget {
  const TitlesSection({super.key, required this.titles});
  final List<ProfileTitle> titles;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeading(l10n.profileTitlesHeading),
        if (titles.isEmpty)
          Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Text(l10n.profileNoTitles))
        else
          for (final t in titles)
            ListTile(
              dense: true,
              leading: const Icon(Icons.emoji_events_outlined, color: SxColors.warning),
              title: Text(t.tournamentTitle, maxLines: 2, overflow: TextOverflow.ellipsis),
              subtitle: Text([if (t.gameName != null) t.gameName!, if (t.date != null) t.date!].join(' · ')),
            ),
      ],
    );
  }
}

class RecentMatchesSection extends StatelessWidget {
  const RecentMatchesSection({super.key, required this.matches});
  final List<ProfileMatch> matches;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    String outcome(String o) => switch (o) {
          'win' => l10n.profileOutcomeWin,
          'loss' => l10n.profileOutcomeLoss,
          'draw' => l10n.profileOutcomeDraw,
          _ => humanizeCode(o),
        };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeading(l10n.profileRecentMatches),
        if (matches.isEmpty)
          Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Text(l10n.profileNoMatches))
        else
          for (final m in matches)
            ListTile(
              key: Key('match-row-${m.id}'),
              dense: true,
              leading: Text(outcome(m.outcome), style: TextStyle(color: m.outcome == 'win' ? SxColors.success : SxColors.textSecondary)),
              title: Text('vs ${m.opponentName}', maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: m.tournamentTitle == null ? null : Text(m.tournamentTitle!, maxLines: 1, overflow: TextOverflow.ellipsis),
              trailing: Text('${m.playerScore}–${m.opponentScore}'),
            ),
      ],
    );
  }
}

class AchievementsSection extends StatelessWidget {
  const AchievementsSection({super.key, required this.achievements});
  final Achievements achievements;

  @override
  Widget build(BuildContext context) {
    if (achievements.total == 0) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    final bySlug = {for (final a in achievements.unlocked) a.slug: a};
    final showcase = [for (final s in achievements.showcase) if (bySlug[s] != null) bySlug[s]!];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeading(l10n.profileAchievements),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(l10n.profileAchievementsProgress(achievements.unlockedCount, achievements.total)),
        ),
        if (showcase.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Wrap(spacing: 8, runSpacing: 8, children: [
              for (final a in showcase) Chip(key: Key('showcase-${a.slug}'), avatar: const Icon(Icons.star, size: 16, color: SxColors.warning), label: Text(a.name)),
            ]),
          ),
        // Server (rarity) order — never re-sorted here.
        for (final a in achievements.unlocked)
          ListTile(
            key: Key('achievement-${a.slug}'),
            dense: true,
            leading: const Icon(Icons.military_tech_outlined, color: SxColors.accentText),
            title: Text(a.name, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text(a.description, maxLines: 2, overflow: TextOverflow.ellipsis),
          ),
        // Locked ones are only a count: the API never sends their names, so there is nothing to show but a lock.
        if (achievements.lockedCount > 0)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Wrap(spacing: 8, runSpacing: 8, children: [
              for (var i = 0; i < achievements.lockedCount; i++)
                Container(
                  key: Key('locked-tile-$i'),
                  width: 72,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(color: SxColors.surface, borderRadius: BorderRadius.circular(8), border: Border.all(color: SxColors.border)),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.lock_outline, color: SxColors.textSecondary),
                    Text(l10n.profileAchievementLocked, style: Theme.of(context).textTheme.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                  ]),
                ),
            ]),
          ),
      ],
    );
  }
}

class PostsSection extends StatelessWidget {
  const PostsSection({super.key, required this.posts});
  final List<ProfilePost> posts;

  @override
  Widget build(BuildContext context) {
    if (posts.isEmpty) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeading(l10n.profilePosts),
        for (final p in posts)
          ListTile(dense: true, title: Text(p.content, maxLines: 3, overflow: TextOverflow.ellipsis)),
      ],
    );
  }
}

class GallerySection extends StatelessWidget {
  const GallerySection({super.key, required this.images});
  final List<GalleryImage> images;

  @override
  Widget build(BuildContext context) {
    if (images.isEmpty) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeading(l10n.profileGallery),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: GridView.count(
            crossAxisCount: 3,
            mainAxisSpacing: 4,
            crossAxisSpacing: 4,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              for (final g in images)
                Image.network(g.imageUrl, fit: BoxFit.cover, errorBuilder: (_, _, _) => const ColoredBox(color: SxColors.surface)),
            ],
          ),
        ),
      ],
    );
  }
}
