import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api/api_client.dart';
import '../../core/api/match_models.dart';
import '../../core/l10n/gen/app_localizations.dart';
import '../../core/providers.dart';
import '../../core/theme/sx_colors.dart';
import 'load_error.dart';
import 'match_error_copy.dart';
import 'match_format.dart';
import 'match_providers.dart';
import 'match_reads_repository.dart';
import 'wager_sheet.dart';

/// Only http/https URLs are ever launched.
bool isLaunchableUrl(String url) {
  final u = Uri.tryParse(url);
  return u != null && (u.scheme == 'http' || u.scheme == 'https');
}

class MatchCentreScreen extends ConsumerWidget {
  const MatchCentreScreen({
    super.key,
    required this.matchId,
    required this.onLogin,
    required this.onSubmitResult,
    required this.onRate,
  });

  final String matchId;
  final VoidCallback onLogin;
  final void Function(MatchInfo match) onSubmitResult;
  final void Function(MatchInfo match) onRate;

  Future<void> _refresh(WidgetRef ref) async {
    ref.invalidate(matchInfoProvider(matchId));
    ref.invalidate(matchCentreProvider(matchId));
    try {
      await Future.wait([
        ref.read(matchInfoProvider(matchId).future),
        ref.read(matchCentreProvider(matchId).future),
      ]);
    } catch (_) {
      // the error state renders on its own
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final matchAsync = ref.watch(matchInfoProvider(matchId));
    final centreAsync = ref.watch(matchCentreProvider(matchId));
    final error = matchAsync.hasError || centreAsync.hasError;
    final loading = matchAsync.isLoading || centreAsync.isLoading;
    final match = matchAsync.asData?.value;
    final centre = centreAsync.asData?.value;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.mtcMatchTitle)),
      body: error
          ? LoadError(onRetry: () => _refresh(ref))
          : loading || match == null || centre == null
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: () => _refresh(ref),
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    children: [_Body(match: match, centre: centre, onLogin: onLogin, onSubmitResult: onSubmitResult, onRate: onRate)],
                  ),
                ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.match, required this.centre, required this.onLogin, required this.onSubmitResult, required this.onRate});

  final MatchInfo match;
  final MatchCentre centre;
  final VoidCallback onLogin;
  final void Function(MatchInfo match) onSubmitResult;
  final void Function(MatchInfo match) onRate;

  static const _submittableStatuses = {'scheduled', 'live', 'disputed'};

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final me = ref.watch(meProvider).asData?.value;
    final statusText = matchStatusText(l10n, match.status);
    final hasScore = match.status == 'completed' && match.scoreA != null && match.scoreB != null;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (match.tournamentTitle != null) Text(match.tournamentTitle!, style: Theme.of(context).textTheme.labelLarge),
      Text(roundLabel(match.round)),
      const SizedBox(height: 8),
      Row(children: [
        Expanded(child: Text(match.nameA, maxLines: 2, overflow: TextOverflow.ellipsis)),
        Text(l10n.mtcVs, style: const TextStyle(color: SxColors.textSecondary)),
        Expanded(child: Text(match.nameB, textAlign: TextAlign.end, maxLines: 2, overflow: TextOverflow.ellipsis)),
      ]),
      const SizedBox(height: 8),
      if (statusText != null) Chip(label: Text(statusText)),
      if (hasScore) Padding(padding: const EdgeInsets.only(top: 8), child: Text('${match.scoreA} – ${match.scoreB}', style: Theme.of(context).textTheme.headlineSmall)),
      Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text(scheduleText(l10n, centre.scheduledAt, isFullDay: centre.isFullDay)),
      ),
      Row(children: [
        if (match.streamUrl != null && isLaunchableUrl(match.streamUrl!))
          TextButton(onPressed: () => launchUrl(Uri.parse(match.streamUrl!), mode: LaunchMode.externalApplication), child: Text(l10n.mtcWatchLive)),
        if (match.replayUrl != null && isLaunchableUrl(match.replayUrl!))
          TextButton(onPressed: () => launchUrl(Uri.parse(match.replayUrl!), mode: LaunchMode.externalApplication), child: Text(l10n.mtcWatchReplay)),
      ]),
      const SizedBox(height: 8),
      if (me == null)
        _GuestWagerPrompt(onLogin: onLogin)
      else if (centre.isParticipant)
        _ParticipantSection(
          match: match,
          centre: centre,
          status: match.status,
          onSubmitResult: () => onSubmitResult(match),
          onRate: () => onRate(match),
          showSubmit: _submittableStatuses.contains(match.status),
          showRate: match.status == 'completed',
        )
      else
        _WagerCard(match: match, centre: centre),
      if (centre.noShowEligible) Padding(padding: const EdgeInsets.only(top: 12), child: Text(l10n.mtcNoShowInfo)),
    ]);
  }
}

class _GuestWagerPrompt extends StatelessWidget {
  const _GuestWagerPrompt({required this.onLogin});
  final VoidCallback onLogin;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Align(
          alignment: Alignment.centerLeft,
          child: TextButton(onPressed: onLogin, child: Text(l10n.mtcWagerLoginPrompt)),
        ),
      ),
    );
  }
}

class _ParticipantSection extends ConsumerStatefulWidget {
  const _ParticipantSection({
    required this.match,
    required this.centre,
    required this.status,
    required this.onSubmitResult,
    required this.onRate,
    required this.showSubmit,
    required this.showRate,
  });

  final MatchInfo match;
  final MatchCentre centre;
  final String status;
  final VoidCallback onSubmitResult;
  final VoidCallback onRate;
  final bool showSubmit;
  final bool showRate;

  @override
  ConsumerState<_ParticipantSection> createState() => _ParticipantSectionState();
}

class _ParticipantSectionState extends ConsumerState<_ParticipantSection> {
  bool _checkingIn = false;

  Future<void> _checkIn() async {
    if (_checkingIn) return;
    setState(() => _checkingIn = true);
    final l10n = AppLocalizations.of(context);
    try {
      await ref.read(matchRepositoryProvider).checkIn(widget.match.id);
      if (!mounted) return;
      ref.invalidate(matchCentreProvider(widget.match.id));
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.mtcCheckInSuccess)));
    } catch (e) {
      if (!mounted) return;
      final code = e is ApiException ? e.code : 'network';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(matchErrorCopy(l10n, code))));
    } finally {
      if (mounted) setState(() => _checkingIn = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = widget.centre;
    final aIn = widget.match.playerAId != null && c.checkedInPlayerIds.contains(widget.match.playerAId);
    final bIn = widget.match.playerBId != null && c.checkedInPlayerIds.contains(widget.match.playerBId);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(child: Text('${widget.match.nameA}: ${aIn ? l10n.mtcCheckedIn : l10n.mtcNotCheckedIn}')),
      ]),
      Row(children: [
        Expanded(child: Text('${widget.match.nameB}: ${bIn ? l10n.mtcCheckedIn : l10n.mtcNotCheckedIn}')),
      ]),
      if (c.canCheckIn)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: OutlinedButton(
            key: const Key('check-in-button'),
            onPressed: _checkingIn ? null : _checkIn,
            child: Text(l10n.mtcCheckIn),
          ),
        ),
      if (widget.showSubmit)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: FilledButton(key: const Key('submit-result-button'), onPressed: widget.onSubmitResult, child: Text(l10n.mtcSubmitResult)),
        ),
      if (widget.showRate)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: OutlinedButton(key: const Key('rate-button'), onPressed: widget.onRate, child: Text(l10n.mtcRateOpponent)),
        ),
    ]);
  }
}

class _WagerCard extends StatelessWidget {
  const _WagerCard({required this.match, required this.centre});
  final MatchInfo match;
  final MatchCentre centre;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final w = centre.wager;
    final noPicks = match.playerAId == null || match.playerBId == null;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(l10n.mtcWagerTitle, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(l10n.mtcWagerPool(w.poolA, w.poolB)),
          if (noPicks || !w.windowOpen)
            Padding(padding: const EdgeInsets.only(top: 8), child: Text(l10n.mtcWagerClosed))
          else ...[
            Text(l10n.mtcWagerFee(_pct(w.feeRate))),
            Text(l10n.mtcWagerEstimate(_num(w.estimatedPayoutIfIStakeA100))),
            if (w.myStakeCoins != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(l10n.mtcWagerYourPick(w.myStakeCoins!, w.myPickPlayerId == match.playerAId ? match.nameA : match.nameB)),
              ),
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: OutlinedButton(
                onPressed: () => showWagerSheet(context, match: match, centre: centre),
                child: Text(w.myStakeCoins != null ? l10n.mtcWagerChange : l10n.mtcWagerPlace),
              ),
            ),
          ],
        ]),
      ),
    );
  }
}

String _pct(double rate) {
  final v = rate * 100;
  return v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();
}

String _num(num v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();
