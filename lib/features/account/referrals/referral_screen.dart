import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/api/referrals_models.dart';
import '../../../core/l10n/gen/app_localizations.dart';
import '../../../core/theme/sx_colors.dart';
import '../../../core/utils/date_locale.dart';
import 'referral_providers.dart';
import 'referral_sharing.dart';

class ReferralScreen extends ConsumerWidget {
  const ReferralScreen({super.key});

  Future<void> _copy(BuildContext context, WidgetRef ref, String link) async {
    final l10n = AppLocalizations.of(context);
    try {
      await ref.read(referralCopyProvider)(link);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.referralShareFailed)));
      }
      return;
    }
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.referralCopied)));
  }

  Future<void> _share(
    BuildContext context,
    WidgetRef ref,
    String link, {
    required bool whatsapp,
  }) async {
    final l10n = AppLocalizations.of(context);
    final text = '${l10n.referralSubtitle}\n$link';
    try {
      await ref.read(
        whatsapp ? referralWhatsAppProvider : referralShareProvider,
      )(text);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.referralShareFailed)));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final overview = ref.watch(referralOverviewProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.referralTitle)),
      body: overview.when(
        loading: () => const Center(
          child: CircularProgressIndicator(key: Key('referral-loading')),
        ),
        error: (_, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l10n.referralLoadFailed),
              TextButton(
                key: const Key('referral-retry'),
                onPressed: () => ref.invalidate(referralOverviewProvider),
                child: Text(l10n.referralRetry),
              ),
            ],
          ),
        ),
        data: (data) => data == null
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(l10n.referralSignedOut),
                    TextButton(
                      key: const Key('referral-login'),
                      onPressed: () => context.push('/login'),
                      child: Text(l10n.accountLogIn),
                    ),
                  ],
                ),
              )
            : _body(context, ref, data, l10n),
      ),
    );
  }

  Widget _body(
    BuildContext context,
    WidgetRef ref,
    ReferralOverview data,
    AppLocalizations l10n,
  ) {
    final locale = Localizations.localeOf(context).languageCode;
    final number = NumberFormat.decimalPattern(numberLocale(locale));
    final date = DateFormat.MMMd(dateLocale(locale));
    final link = data.shareUrl;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          l10n.referralSubtitle,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 16),
        _panel(
          children: [
            Text(
              l10n.referralCode,
              style: Theme.of(context).textTheme.labelMedium,
            ),
            const SizedBox(height: 4),
            Text(
              data.username ?? '—',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Text(
              l10n.referralLink,
              style: Theme.of(context).textTheme.labelMedium,
            ),
            const SizedBox(height: 4),
            if (link == null)
              Text(l10n.referralNoCode)
            else ...[
              SelectableText(link, key: const Key('referral-link')),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    key: const Key('referral-copy'),
                    onPressed: () => _copy(context, ref, link),
                    icon: const Icon(Icons.copy),
                    label: Text(l10n.referralCopy),
                  ),
                  FilledButton.icon(
                    key: const Key('referral-share'),
                    onPressed: () =>
                        _share(context, ref, link, whatsapp: false),
                    icon: const Icon(Icons.share),
                    label: Text(l10n.referralShare),
                  ),
                  OutlinedButton(
                    key: const Key('referral-whatsapp'),
                    onPressed: () => _share(context, ref, link, whatsapp: true),
                    child: Text(l10n.referralWhatsApp),
                  ),
                ],
              ),
            ],
          ],
        ),
        const SizedBox(height: 16),
        _panel(
          children: [
            _stat(l10n.referralTotal, number.format(data.totalReferrals)),
            _stat(l10n.referralConverted, number.format(data.convertedCount)),
            _stat(l10n.referralEarned, number.format(data.totalCoinsEarned)),
          ],
        ),
        const SizedBox(height: 16),
        _panel(
          children: [
            Text(
              l10n.referralNextMilestone,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            if (data.nextMilestone == null)
              Text(l10n.referralAllMilestones)
            else ...[
              LinearProgressIndicator(
                value: (data.convertedCount / data.nextMilestone!.count)
                    .clamp(0, 1)
                    .toDouble(),
              ),
              const SizedBox(height: 8),
              Text(
                '${number.format(data.convertedCount)} / ${number.format(data.nextMilestone!.count)} ${l10n.referralConverted}',
              ),
              if (data.nextMilestone!.bonusCoins case final bonus?)
                Text('+${number.format(bonus)} ${l10n.referralBonus}'),
            ],
          ],
        ),
        const SizedBox(height: 20),
        Text(
          l10n.referralInvited,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        if (data.invited.isEmpty)
          _panel(children: [Text(l10n.referralEmpty)])
        else
          for (final player in data.invited) ...[
            _player(context, player, date, number, l10n, link),
            const SizedBox(height: 8),
          ],
        if (data.milestoneHistory.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            l10n.referralHistory,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          for (final entry in data.milestoneHistory) ...[
            _panel(
              children: [
                Text(entry.description),
                Text(
                  '+${number.format(entry.coins)} ${l10n.referralCoins} · ${date.format(entry.date)}',
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ],
      ],
    );
  }

  Widget _stat(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        Expanded(child: Text(label)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
      ],
    ),
  );

  Widget _player(
    BuildContext context,
    ReferredPlayer player,
    DateFormat date,
    NumberFormat number,
    AppLocalizations l10n,
    String? link,
  ) {
    final frame = player.frameUrl == null || link == null
        ? null
        : Uri.parse(link).resolve(player.frameUrl!).toString();
    final avatar = player.avatarUrl;
    final status = switch (player.status) {
      'converted' => l10n.referralConverted,
      'pending' => l10n.referralPending,
      _ => l10n.referralInvalid,
    };
    return _panel(
      children: [
        Row(
          children: [
            SizedBox(
              width: 44,
              height: 44,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircleAvatar(
                    backgroundImage: avatar == null
                        ? null
                        : NetworkImage(avatar),
                    child: avatar == null
                        ? Text(player.name.isEmpty ? '?' : player.name[0])
                        : null,
                  ),
                  if (frame != null)
                    Image.network(
                      frame,
                      errorBuilder: (_, _, _) => const SizedBox.shrink(),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    player.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '$status · ${date.format(player.date)}',
                    style: const TextStyle(color: SxColors.textSecondary),
                  ),
                  if (player.coinsAwarded case final coins?)
                    Text(
                      '+${number.format(coins)} ${l10n.referralCoins}',
                      style: const TextStyle(color: SxColors.accentText),
                    ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _panel({required List<Widget> children}) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: SxColors.surface,
      border: Border.all(color: SxColors.border),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    ),
  );
}
