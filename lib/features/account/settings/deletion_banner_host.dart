import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/l10n/gen/app_localizations.dart';
import '../../../core/providers.dart';
import '../../../core/theme/sx_colors.dart';
import '../../../core/utils/date_locale.dart';
import 'account_repository.dart';

/// A persistent "your account is scheduled for deletion" banner above the whole app, with Cancel. Mounted in
/// `MaterialApp.builder`.
///
/// The child sits at the same position in the tree whether or not the banner is showing (a Column with the
/// banner slot first and the child in an Expanded, always). Swapping between `child` and `Column(child)`
/// would give the Navigator a new parent and reset the whole navigation stack every time the banner
/// toggled.
class DeletionBannerHost extends ConsumerWidget {
  const DeletionBannerHost({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pending = ref.watch(meProvider.select((m) => m.asData?.value?.profile?.deletionRequestedAt != null));
    return Column(
      children: [
        if (pending) const _Banner() else const SizedBox.shrink(),
        Expanded(
          child: MediaQuery.removePadding(context: context, removeTop: pending, child: child),
        ),
      ],
    );
  }
}

class _Banner extends ConsumerStatefulWidget {
  const _Banner();

  @override
  ConsumerState<_Banner> createState() => _BannerState();
}

class _BannerState extends ConsumerState<_Banner> {
  bool _cancelling = false;

  Future<void> _cancel() async {
    setState(() => _cancelling = true);
    try {
      await ref.read(accountRepositoryProvider).cancelDeletion();
      ref.invalidate(myAccountProvider);
      ref.invalidate(meProvider);
    } catch (_) {
      if (mounted) setState(() => _cancelling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final deletion = ref.watch(myAccountProvider).asData?.value?.deletion;
    final text = deletion == null
        ? l10n.accountDeletionPendingHeading
        : l10n.accountDeletionBannerText(
            DateFormat.yMMMd(dateLocale(l10n.localeName)).format(deletion.dueAt.toLocal()),
            '${deletion.daysRemaining}',
          );
    return Material(
      key: const Key('deletion-banner'),
      color: SxColors.surface,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Colors.amber),
                  const SizedBox(width: 8),
                  Expanded(child: Text(text, style: Theme.of(context).textTheme.bodySmall)),
                ],
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  key: const Key('deletion-banner-cancel'),
                  onPressed: _cancelling ? null : _cancel,
                  child: Text(_cancelling ? l10n.accountDeletionBannerCancelling : l10n.accountDeletionBannerCancel),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
