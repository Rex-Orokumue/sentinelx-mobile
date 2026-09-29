import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/community_models.dart';
import '../../core/l10n/gen/app_localizations.dart';
import '../../core/theme/sx_colors.dart';
import 'community_providers.dart';

const _kTileWidth = 72.0;
const _kAvatarRadius = 28.0;

/// A horizontal row of story-ring avatars ("Instagram-style" statuses), with an always-present
/// "add yours" tile first. Sign-in gating for [onAddYours] (e.g. redirecting to `/login` before
/// opening the compose screen) is the caller's responsibility — the tray itself never reads
/// `meProvider` and always calls [onAddYours] on tap, signed in or not, same contract as the rest
/// of Community (`ReactionBar.onSignInRequired`).
///
/// The tray never infers seen/unseen client-side: [StatusRing.hasUnseen] comes straight from the
/// server and drives the ring border directly. An empty, loading, or errored rings list still
/// renders the "add yours" tile — an empty tray is a valid, common state, not a failure.
class StatusTray extends ConsumerWidget {
  const StatusTray({super.key, required this.onRingTap, required this.onAddYours});
  final void Function(StatusRing ring) onRingTap;
  final VoidCallback onAddYours;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final rings = ref.watch(communityStatusRingsProvider).asData?.value ?? const <StatusRing>[];
    return SizedBox(
      height: 104,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        children: [
          _AddYoursTile(label: l10n.cmtStatusAddYours, onTap: onAddYours),
          for (final ring in rings) _RingTile(ring: ring, onTap: () => onRingTap(ring)),
        ],
      ),
    );
  }
}

class _AddYoursTile extends StatelessWidget {
  const _AddYoursTile({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: const Key('status-add-yours'),
      onTap: onTap,
      child: SizedBox(
        width: _kTileWidth,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          CircleAvatar(
            radius: _kAvatarRadius,
            backgroundColor: SxColors.surface,
            child: const Icon(Icons.add, color: SxColors.textSecondary),
          ),
          const SizedBox(height: 4),
          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.labelSmall),
        ]),
      ),
    );
  }
}

class _RingTile extends StatelessWidget {
  const _RingTile({required this.ring, required this.onTap});
  final StatusRing ring;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final borderColor = ring.hasUnseen ? SxColors.primary : SxColors.border;
    return GestureDetector(
      key: Key(ring.hasUnseen ? 'status-ring-unseen-${ring.playerId}' : 'status-ring-seen-${ring.playerId}'),
      onTap: onTap,
      child: SizedBox(
        width: _kTileWidth,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: borderColor, width: 2)),
            child: CircleAvatar(
              radius: _kAvatarRadius,
              backgroundImage: ring.authorAvatarUrl != null ? NetworkImage(ring.authorAvatarUrl!) : null,
              child: ring.authorAvatarUrl == null
                  ? Text(ring.authorName.isNotEmpty ? ring.authorName[0].toUpperCase() : '?')
                  : null,
            ),
          ),
          const SizedBox(height: 4),
          Text(ring.authorName, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.labelSmall),
        ]),
      ),
    );
  }
}
