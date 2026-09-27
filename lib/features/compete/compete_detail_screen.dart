import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api/compete_models.dart';
import '../../core/l10n/gen/app_localizations.dart';
import '../../core/providers.dart';
import '../../core/theme/sx_colors.dart';
import '../match/match_providers.dart';
import 'compete_list_screen.dart' show statusLabel;
import 'compete_models.dart';
import 'compete_providers.dart';
import 'registration_sheet.dart';

class CompeteDetailScreen extends ConsumerWidget {
  const CompeteDetailScreen({
    super.key,
    required this.tournamentId,
    required this.onViewBracket,
    required this.onLogin,
    required this.onNeedsUsername,
    required this.onViewInvitations,
  });

  /// A tournament id (in-app routes) or slug (web links).
  final String tournamentId;
  /// Receives the RESOLVED tournament id (the route param may be a web slug).
  final void Function(String tournamentId) onViewBracket;
  final VoidCallback onLogin;
  final VoidCallback onNeedsUsername;
  final VoidCallback onViewInvitations;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final async = ref.watch(competeTournamentProvider(tournamentId));
    return Scaffold(
      appBar: AppBar(title: Text(l10n.navTournaments)),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => _RetryMessage(onRetry: () => ref.invalidate(competeTournamentProvider(tournamentId))),
        data: (t) => _Body(
          tournament: t,
          onViewBracket: onViewBracket,
          onLogin: onLogin,
          onNeedsUsername: onNeedsUsername,
          onViewInvitations: onViewInvitations,
        ),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({
    required this.tournament,
    required this.onViewBracket,
    required this.onLogin,
    required this.onNeedsUsername,
    required this.onViewInvitations,
  });

  final CompeteTournament tournament;
  final void Function(String tournamentId) onViewBracket;
  final VoidCallback onLogin;
  final VoidCallback onNeedsUsername;
  final VoidCallback onViewInvitations;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final t = tournament;
    final status = statusLabel(l10n, t.status);
    final siteUrl = ref.watch(remoteConfigProvider).asData?.value?.siteUrl;
    final reg = ref.watch(registrationStateProvider(t.id));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (t.bannerUrl != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              t.bannerUrl!,
              height: 160,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
          ),
        const SizedBox(height: 12),
        Text(t.title, style: Theme.of(context).textTheme.headlineSmall),
        if (t.gameName != null) Padding(padding: const EdgeInsets.only(top: 4), child: Text(t.gameName!)),
        if (status != null) Padding(padding: const EdgeInsets.only(top: 8), child: Chip(label: Text(status))),
        if (t.status == 'completed') _ChampionCard(tournamentId: t.id),
        const SizedBox(height: 12),
        Text('${l10n.cmpPrizePool}: ₦${t.prizePool}'),
        if (t.prizeSecond != null) Text('${l10n.cmpSecondPlace}: ₦${t.prizeSecond}'),
        if (t.prizeThird != null) Text('${l10n.cmpThirdPlace}: ₦${t.prizeThird}'),
        Text('${l10n.cmpEntryFee}: ${t.registrationFee == 0 ? l10n.cmpFree : '₦${t.registrationFee}'}'),
        if (t.maxPlayers != null) Text(l10n.cmpMaxPlayers(t.maxPlayers!)),
        if (t.description != null && t.description!.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(t.description!),
        ],
        if (t.rules != null && t.rules!.isNotEmpty)
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: Text(l10n.cmpRules),
            children: [Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(t.rules!))],
          ),
        const SizedBox(height: 16),
        reg.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => _RetryMessage(compact: true, onRetry: () => ref.invalidate(registrationStateProvider(t.id))),
          data: (state) => _RegistrationCta(
            tournament: t,
            state: state,
            onLogin: onLogin,
            onNeedsUsername: onNeedsUsername,
            onViewInvitations: onViewInvitations,
          ),
        ),
        const SizedBox(height: 16),
        OutlinedButton(key: const Key('view-bracket-button'), onPressed: () => onViewBracket(t.id), child: Text(l10n.cmpViewBracket)),
        if (siteUrl != null)
          TextButton.icon(
            key: const Key('share-whatsapp'),
            icon: const Icon(Icons.share),
            label: Text(l10n.cmpShareWhatsapp),
            onPressed: () {
              final text = l10n.cmpShareText(t.title, '$siteUrl/tournaments/${t.slug}');
              launchUrl(Uri.parse('https://wa.me/?text=${Uri.encodeComponent(text)}'), mode: LaunchMode.externalApplication);
            },
          ),
      ]),
    );
  }
}

class _RegistrationCta extends ConsumerWidget {
  const _RegistrationCta({
    required this.tournament,
    required this.state,
    required this.onLogin,
    required this.onNeedsUsername,
    required this.onViewInvitations,
  });

  final CompeteTournament tournament;
  final RegistrationState state;
  final VoidCallback onLogin;
  final VoidCallback onNeedsUsername;
  final VoidCallback onViewInvitations;

  void _openSheet(BuildContext context, SheetMode mode) => showRegistrationSheet(
        context,
        tournament: tournament,
        state: state,
        mode: mode,
        onNeedsUsername: onNeedsUsername,
      );

  /// `complete_payment`: the old Paystack page cannot be reopened (the API never returns the
  /// authorization URL), so check the stored reference once and otherwise re-run the form, which
  /// mints a fresh reference — the same thing the website does.
  Future<void> _resume(BuildContext context, WidgetRef ref) async {
    try {
      final me = await ref.read(meProvider.future);
      if (me != null) {
        final reference = await ref.read(competeReadsRepositoryProvider).fetchMyPendingReference(tournament.id, me.id);
        if (reference != null) {
          final paid = await ref.read(registrationRepositoryProvider).paymentStatus(reference);
          if (paid.isPaid) {
            ref.invalidate(registrationStateProvider(tournament.id));
            return;
          }
        }
      }
    } catch (_) {
      // Fall through to the form.
    }
    if (context.mounted) _openSheet(context, SheetMode.register);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    Widget button(String label, VoidCallback onPressed) =>
        FilledButton(key: const Key('reg-cta'), onPressed: onPressed, child: Text(label));

    return switch (state.view) {
      RegView.guest => button(l10n.cmpCtaLogin, onLogin),
      RegView.canRegister => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (state.hasWaiver) Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(l10n.cmpFeeWaived)),
          button(l10n.cmpCtaRegister, () => _openSheet(context, SheetMode.register)),
        ]),
      RegView.completePayment => button(l10n.cmpCtaResume, () => _resume(context, ref)),
      RegView.registered => Text(l10n.cmpStateRegistered),
      RegView.waitlisted => Text(l10n.cmpStateWaitlisted),
      // `full` is not `closed`: the server only accepts waitlist joins once registration has closed.
      RegView.full => Text(l10n.cmpStateFull),
      RegView.closed => button(l10n.cmpCtaJoinWaitlist, () => _openSheet(context, SheetMode.waitlist)),
      RegView.ended => Text(l10n.cmpStateEnded),
      RegView.invitationOnly => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(l10n.cmpStateInvitationOnly),
          const SizedBox(height: 8),
          OutlinedButton(onPressed: onViewInvitations, child: Text(l10n.cmpViewInvitations)),
        ]),
    };
  }
}

class _RetryMessage extends StatelessWidget {
  const _RetryMessage({required this.onRetry, this.compact = false});
  final VoidCallback onRetry;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final content = Column(mainAxisSize: MainAxisSize.min, children: [
      Text(l10n.cmpLoadError, textAlign: TextAlign.center),
      const SizedBox(height: 12),
      OutlinedButton(onPressed: onRetry, child: Text(l10n.cmpRetry)),
    ]);
    return compact ? content : Center(child: Padding(padding: const EdgeInsets.all(24), child: content));
  }
}

/// Champion (or "closed without a winner") for a completed tournament. A failed read shows nothing:
/// this card must never block the page.
class _ChampionCard extends ConsumerWidget {
  const _ChampionCard({required this.tournamentId});
  final String tournamentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final results = ref.watch(tournamentResultsProvider(tournamentId)).asData?.value;
    if (results == null) return const SizedBox.shrink();
    final c = results.champion;
    if (c == null) {
      return results.noWinner ? Padding(padding: const EdgeInsets.only(top: 12), child: Text(l10n.mtcNoWinner)) : const SizedBox.shrink();
    }
    return Card(
      key: const Key('champion-card'),
      margin: const EdgeInsets.only(top: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(children: [
          const Icon(Icons.emoji_events, color: SxColors.warning),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(l10n.mtcChampion, style: Theme.of(context).textTheme.labelSmall),
              Text(c.champion.name, style: Theme.of(context).textTheme.titleMedium, maxLines: 2, overflow: TextOverflow.ellipsis),
              if (c.runnerUp != null) Text('${l10n.cmpSecondPlace}: ${c.runnerUp!.name}', maxLines: 2, overflow: TextOverflow.ellipsis),
              if (c.prizePool != null) Text('${l10n.cmpPrizePool}: ₦${c.prizePool}'),
            ]),
          ),
        ]),
      ),
    );
  }
}
