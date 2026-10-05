import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/guide_models.dart';
import '../../core/l10n/gen/app_localizations.dart';
import '../../core/providers.dart';
import '../../core/theme/sx_colors.dart';
import 'guide_mascot.dart';
import 'guide_providers.dart';
import 'guide_steps.dart';
import 'quest_routes.dart';
import 'visitor_tour.dart';

class GuideScreen extends ConsumerWidget {
  const GuideScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final viewer = ref.watch(viewerIdProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.guideTitle)),
      body: viewer.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const _SignedOut(),
        data: (id) => id == null ? const _SignedOut() : const _SignedIn(),
      ),
    );
  }
}

class _AskTile extends StatelessWidget {
  const _AskTile();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ListTile(
      key: const Key('guide-ask-assistant'),
      leading: const Icon(Icons.chat_bubble_outline),
      title: Text(l10n.guideAskAssistant),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => GoRouter.of(context).push('/guide/chat'),
    );
  }
}

class _SignedOut extends StatelessWidget {
  const _SignedOut();

  @override
  Widget build(BuildContext context) => ListView(children: const [VisitorTour(), _AskTile()]);
}

class _SignedIn extends ConsumerWidget {
  const _SignedIn();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final username = ref.watch(meProvider).asData?.value?.profile?.username;
    final quests = ref.watch(questsProvider);
    final list = quests.asData?.value;
    final quest = list == null ? null : battleReady(list);
    return ListView(padding: const EdgeInsets.all(16), children: [
      Row(children: [
        const GuideMascot(size: 56),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            username == null || username.isEmpty ? l10n.guideHelloNoName : l10n.guideHello(username),
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
      ]),
      const SizedBox(height: 16),
      if (quests.isLoading && quest == null)
        const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
      else if (quest == null)
        Column(children: [
          Text(l10n.questLoadError, textAlign: TextAlign.center),
          TextButton(onPressed: () => ref.invalidate(questsProvider), child: Text(l10n.cmpRetry)),
        ])
      else
        _QuestChecklist(quest: quest),
      const SizedBox(height: 8),
      const _AskTile(),
    ]);
  }
}

class _QuestChecklist extends ConsumerWidget {
  const _QuestChecklist({required this.quest});

  final Quest quest;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final claim = ref.watch(claimBadgeProvider);
    final claiming = claim.phase == ClaimPhase.claiming;
    final earned = quest.claimed || claim.phase == ClaimPhase.claimed;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Expanded(child: Text(l10n.questBattleReadyTitle, style: Theme.of(context).textTheme.titleMedium)),
            Text(l10n.questProgress(quest.doneCount, quest.totalCount), style: const TextStyle(color: SxColors.textSecondary)),
          ]),
          const SizedBox(height: 8),
          LinearProgressIndicator(value: quest.totalCount == 0 ? 0 : quest.doneCount / quest.totalCount),
          const SizedBox(height: 8),
          for (final step in quest.steps) _StepRow(step: step),
          const SizedBox(height: 8),
          Text(l10n.questRewardLine(quest.rewardXp, quest.rewardCoins), style: const TextStyle(color: SxColors.accentText)),
          const SizedBox(height: 12),
          FilledButton(
            key: const Key('quest-claim'),
            onPressed: quest.allComplete && !earned && !claiming ? () => ref.read(claimBadgeProvider.notifier).claim() : null,
            child: claiming
                ? Row(mainAxisSize: MainAxisSize.min, children: [
                    const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                    const SizedBox(width: 8),
                    Text(l10n.questClaiming),
                  ])
                : Text(earned ? l10n.questBadgeEarned : l10n.questClaim),
          ),
          if (claim.phase == ClaimPhase.failed && claim.errorCode != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(questClaimError(l10n, claim.errorCode!), style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ),
        ]),
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({required this.step});

  final QuestStep step;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final route = step.done ? null : questStepRoute(step.target);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        step.done ? Icons.check_circle : Icons.radio_button_unchecked,
        color: step.done ? SxColors.success : SxColors.textSecondary,
      ),
      title: Text(questStepLabel(l10n, step.key)),
      trailing: route == null ? null : TextButton(onPressed: () => GoRouter.of(context).push(route), child: Text(l10n.questTakeMeThere)),
    );
  }
}
