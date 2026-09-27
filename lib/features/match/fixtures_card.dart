import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/match_models.dart';
import '../../core/l10n/gen/app_localizations.dart';
import '../../core/theme/sx_colors.dart';
import 'match_format.dart';
import 'match_providers.dart';

/// The "needs your attention" surface: next fixture, submit prompt, qualify/eliminate banners and pending
/// payments. Renders nothing on load, error or an entirely empty summary — Home must never show an error
/// because of this card.
class FixturesCard extends ConsumerWidget {
  const FixturesCard({super.key, required this.onGoTo, required this.onOpenLobby});

  final void Function(String path) onGoTo;
  final void Function(String lobbyId, NextLobby lobby) onOpenLobby;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final summary = ref.watch(meSummaryProvider).asData?.value;
    if (summary == null || summary.isEmpty) return const SizedBox.shrink();

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(l10n.mtcFixturesTitle, style: Theme.of(context).textTheme.titleMedium),
          for (final b in summary.banners) _Banner(banner: b, l10n: l10n),
          if (summary.nextMatch != null)
            _NextMatchTile(match: summary.nextMatch!, hasSubmittableMatch: summary.hasSubmittableMatch, l10n: l10n, onGoTo: onGoTo),
          if (summary.nextLobby != null) _NextLobbyTile(lobby: summary.nextLobby!, l10n: l10n, onOpenLobby: onOpenLobby),
          for (final r in summary.registrations.where((r) => r.paymentStatus == 'pending'))
            _PendingRegistrationTile(registration: r, l10n: l10n, onGoTo: onGoTo),
        ]),
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.banner, required this.l10n});
  final SummaryBanner banner;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final round = roundLabel(banner.round).toLowerCase();
    final text = banner.kind == BannerKind.qualified
        ? l10n.mtcBannerQualified(banner.tournamentTitle, round)
        : l10n.mtcBannerEliminated(banner.tournamentTitle, round);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(text, maxLines: 3, overflow: TextOverflow.ellipsis),
        if (banner.kind == BannerKind.qualified && banner.awaitingOpponent)
          Text(l10n.mtcBannerAwaiting, style: const TextStyle(color: SxColors.textSecondary)),
      ]),
    );
  }
}

class _NextMatchTile extends StatelessWidget {
  const _NextMatchTile({required this.match, required this.hasSubmittableMatch, required this.l10n, required this.onGoTo});
  final NextMatch match;
  final bool hasSubmittableMatch;
  final AppLocalizations l10n;
  final void Function(String path) onGoTo;

  @override
  Widget build(BuildContext context) => ListTile(
        key: const Key('next-match-tile'),
        contentPadding: EdgeInsets.zero,
        title: Text(l10n.mtcNextMatch),
        subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${match.tournamentTitle} · ${roundLabel(match.round)}', maxLines: 2, overflow: TextOverflow.ellipsis),
          Text(scheduleText(l10n, match.scheduledAt, isFullDay: match.isFullDay)),
          if (hasSubmittableMatch) Text(l10n.mtcSubmitPrompt),
        ]),
        onTap: () => onGoTo('/matches/${match.id}'),
      );
}

class _NextLobbyTile extends StatelessWidget {
  const _NextLobbyTile({required this.lobby, required this.l10n, required this.onOpenLobby});
  final NextLobby lobby;
  final AppLocalizations l10n;
  final void Function(String lobbyId, NextLobby lobby) onOpenLobby;

  @override
  Widget build(BuildContext context) => ListTile(
        key: const Key('next-lobby-tile'),
        contentPadding: EdgeInsets.zero,
        title: Text(l10n.mtcNextLobby),
        subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${lobby.tournamentTitle} · ${lobby.stageName} · ${lobby.label}', maxLines: 2, overflow: TextOverflow.ellipsis),
          Text(scheduleText(l10n, lobby.scheduledAt, isFullDay: false)),
          if (lobby.hasRoomCode) Text(l10n.mtcRoomCodeReady),
          if (lobby.submitted) Text(l10n.mtcLobbySubmitted),
        ]),
        onTap: lobby.submitted ? null : () => onOpenLobby(lobby.lobbyId, lobby),
      );
}

class _PendingRegistrationTile extends StatelessWidget {
  const _PendingRegistrationTile({required this.registration, required this.l10n, required this.onGoTo});
  final SummaryRegistration registration;
  final AppLocalizations l10n;
  final void Function(String path) onGoTo;

  @override
  Widget build(BuildContext context) => ListTile(
        key: Key('registration-${registration.id}'),
        contentPadding: EdgeInsets.zero,
        title: Text(registration.tournamentTitle, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(l10n.mtcPaymentPending),
        onTap: () => onGoTo('/tournaments/${registration.tournamentSlug}'),
      );
}
