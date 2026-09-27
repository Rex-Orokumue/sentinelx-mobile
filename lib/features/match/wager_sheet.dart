import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/match_models.dart';
import '../../core/l10n/gen/app_localizations.dart';
import '../../core/utils/write_flow.dart';
import 'match_error_copy.dart';
import 'match_providers.dart';
import 'match_reads_repository.dart';

Future<void> showWagerSheet(BuildContext context, {required MatchInfo match, required MatchCentre centre}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    isDismissible: true, // narrowed to !busy inside via PopScope
    builder: (_) => _WagerSheetBody(match: match, centre: centre),
  );
}

class _WagerSheetBody extends ConsumerStatefulWidget {
  const _WagerSheetBody({required this.match, required this.centre});
  final MatchInfo match;
  final MatchCentre centre;

  @override
  ConsumerState<_WagerSheetBody> createState() => _WagerSheetBodyState();
}

class _WagerSheetBodyState extends ConsumerState<_WagerSheetBody> {
  String? _pick;
  late final TextEditingController _stake;
  String? _stakeError;

  @override
  void initState() {
    super.initState();
    _pick = widget.centre.wager.myPickPlayerId;
    _stake = TextEditingController(text: widget.centre.wager.myStakeCoins?.toString() ?? '');
  }

  @override
  void dispose() {
    _stake.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final match = widget.match;
    final wager = widget.centre.wager;
    final aId = match.playerAId, bId = match.playerBId;
    final scope = 'wager:${match.id}';
    final state = ref.watch(writeFlowProvider(scope));
    final busy = state.busy;

    if (aId == null || bId == null) {
      return Padding(padding: const EdgeInsets.all(24), child: Text(l10n.mtcWagerClosed));
    }

    Future<void> submit() async {
      setState(() => _stakeError = null);
      final pick = _pick;
      final stake = int.tryParse(_stake.text.trim());
      if (pick == null || stake == null || stake < wager.minStake || stake > wager.maxStake) {
        setState(() => _stakeError = l10n.mtcWagerStakeRange(wager.minStake, wager.maxStake));
        return;
      }
      final messenger = ScaffoldMessenger.of(context);
      final navigator = Navigator.of(context);
      final ok = await ref.read(writeFlowProvider(scope).notifier).run(
            (key) => ref.read(matchRepositoryProvider).wager(match.id, pickPlayerId: pick, stakeCoins: stake, idempotencyKey: key),
          );
      if (!mounted) return;
      if (ok) {
        ref.invalidate(matchCentreProvider(match.id));
        navigator.pop();
        messenger.showSnackBar(SnackBar(content: Text(l10n.mtcWagerPlaced)));
      }
    }

    final errorCopy = state.phase == WritePhase.failed ? matchErrorCopy(l10n, state.errorCode ?? '') : null;

    return PopScope(
      canPop: !busy,
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(l10n.mtcWagerTitle, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(l10n.mtcWagerPool(wager.poolA, wager.poolB)),
          Text(l10n.mtcWagerFee(_pct(wager.feeRate))),
          Text(l10n.mtcWagerEstimate(_num(wager.estimatedPayoutIfIStakeA100))),
          const SizedBox(height: 12),
          RadioGroup<String>(
            groupValue: _pick,
            onChanged: (v) {
              if (!busy) setState(() => _pick = v);
            },
            child: Column(children: [
              RadioListTile<String>(value: aId, title: Text(match.nameA)),
              RadioListTile<String>(value: bId, title: Text(match.nameB)),
            ]),
          ),
          const SizedBox(height: 8),
          Builder(builder: (context) {
            // The hint stays in the tree (just invisible) once the field has text or an error is shown,
            // so it must never share its string with the error — the two "Between … coins." finders
            // would otherwise both match.
            final fieldError = _stakeError ?? (errorCopy != null && state.errorCode != 'own_match' ? errorCopy : null);
            return TextField(
              key: const Key('wager-stake'),
              controller: _stake,
              enabled: !busy,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: l10n.mtcWagerStake,
                hintText: fieldError == null ? l10n.mtcWagerStakeRange(wager.minStake, wager.maxStake) : null,
                errorText: fieldError,
              ),
            );
          }),
          if (errorCopy != null && state.errorCode == 'own_match') Padding(padding: const EdgeInsets.only(top: 4), child: Text(errorCopy)),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: busy ? null : submit,
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              if (busy) ...[
                const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                const SizedBox(width: 8),
              ],
              Text(widget.centre.wager.myStakeCoins != null ? l10n.mtcWagerChange : l10n.mtcWagerPlace),
            ]),
          ),
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
