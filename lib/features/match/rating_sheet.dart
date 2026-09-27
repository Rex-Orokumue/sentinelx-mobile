import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/gen/app_localizations.dart';
import '../../core/theme/sx_colors.dart';
import '../../core/utils/write_flow.dart';
import 'match_error_copy.dart';
import 'match_providers.dart';
import 'match_reads_repository.dart';

Future<void> showRatingSheet(BuildContext context, {required MatchInfo match}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    // Dragging would bypass PopScope and orphan an in-flight rating; disabled unconditionally
    // (matches registration_sheet.dart / wager_sheet.dart).
    enableDrag: false,
    builder: (_) => _RatingSheetBody(match: match),
  );
}

class _RatingSheetBody extends ConsumerStatefulWidget {
  const _RatingSheetBody({required this.match});
  final MatchInfo match;

  @override
  ConsumerState<_RatingSheetBody> createState() => _RatingSheetBodyState();
}

class _RatingSheetBodyState extends ConsumerState<_RatingSheetBody> {
  int? _stars;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scope = 'rating:${widget.match.id}';
    final state = ref.watch(writeFlowProvider(scope));
    final busy = state.busy;
    final errorCopy = state.phase == WritePhase.failed ? matchErrorCopy(l10n, state.errorCode ?? '') : null;

    Future<void> submit() async {
      final stars = _stars;
      if (stars == null) return;
      final messenger = ScaffoldMessenger.of(context);
      final navigator = Navigator.of(context);
      final ok = await ref.read(writeFlowProvider(scope).notifier).run(
            (key) => ref.read(matchRepositoryProvider).rate(widget.match.id, stars: stars, idempotencyKey: key),
            fingerprint: stars,
          );
      if (!mounted) return;
      if (ok) {
        navigator.pop();
        messenger.showSnackBar(SnackBar(content: Text(l10n.mtcRated)));
      }
    }

    return PopScope(
      canPop: !busy,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(l10n.mtcRateOpponent, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            for (var i = 1; i <= 5; i++)
              Semantics(
                label: '$i star${i == 1 ? '' : 's'}',
                child: IconButton(
                  key: Key('star-$i'),
                  onPressed: busy ? null : () => setState(() => _stars = i),
                  icon: Icon(Icons.star, color: (_stars ?? 0) >= i ? SxColors.warning : SxColors.textSecondary),
                ),
              ),
          ]),
          if (errorCopy != null) Padding(padding: const EdgeInsets.only(top: 4), child: Text(errorCopy)),
          const SizedBox(height: 12),
          FilledButton(
            key: const Key('rating-submit'),
            onPressed: busy || _stars == null ? null : submit,
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              if (busy) ...[
                const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                const SizedBox(width: 8),
              ],
              Text(l10n.mtcRateOpponent),
            ]),
          ),
        ]),
      ),
    );
  }
}
