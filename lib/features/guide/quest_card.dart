import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/gen/app_localizations.dart';
import '../../core/lifecycle/app_lifecycle_provider.dart';
import '../../core/theme/sx_colors.dart';
import 'guide_providers.dart';
import 'guide_steps.dart';

/// Home card for the Battle Ready quest. Hidden while loading, on error, signed out, when the server has no such
/// quest and once the badge is claimed; it must never be a loading or error eyesore on the home screen.
class QuestCard extends ConsumerStatefulWidget {
  const QuestCard({super.key});

  @override
  ConsumerState<QuestCard> createState() => _QuestCardState();
}

class _QuestCardState extends ConsumerState<QuestCard> {
  StreamSubscription<AppLifecycleState>? _sub;

  @override
  void initState() {
    super.initState();
    _sub = ref.read(appLifecycleSourceProvider).changes.listen((s) {
      if (s == AppLifecycleState.resumed && mounted) ref.invalidate(questsProvider);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final quest = ref.watch(questsProvider).asData?.value;
    final q = quest == null ? null : battleReady(quest);
    if (q == null || q.claimed) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    final pending = q.steps.where((s) => !s.done).firstOrNull;
    final done = q.doneCount;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => GoRouter.of(context).push('/guide'),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(l10n.questBattleReadyTitle, style: Theme.of(context).textTheme.titleMedium)),
                Text(l10n.questProgress(done, q.totalCount), style: const TextStyle(color: SxColors.textSecondary)),
              ]),
              const SizedBox(height: 8),
              LinearProgressIndicator(value: q.totalCount == 0 ? 0 : done / q.totalCount),
              const SizedBox(height: 8),
              Text(q.allComplete ? l10n.questClaim : (pending == null ? '' : questStepLabel(l10n, pending.key)),
                  style: const TextStyle(color: SxColors.accentText)),
            ]),
          ),
        ),
      ),
    );
  }
}
