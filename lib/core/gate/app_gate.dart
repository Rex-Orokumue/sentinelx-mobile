import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/remote_config.dart';
import '../l10n/gen/app_localizations.dart';
import '../providers.dart';
import '../theme/sx_colors.dart';

const _playStoreUrl = 'https://play.google.com/store/apps/details?id=ng.com.sentinelxesports.app';

class AppGate extends ConsumerWidget {
  const AppGate({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(remoteConfigProvider).asData?.value; // null while loading or on failure -> open
    final gate = evaluateGate(config, ref.watch(installedVersionProvider));
    switch (gate.kind) {
      case GateKind.open:
        return child;
      case GateKind.maintenance:
        return _Blocker(title: AppLocalizations.of(context).maintenanceTitle, body: gate.message ?? '');
      case GateKind.updateRequired:
        final l10n = AppLocalizations.of(context);
        return _Blocker(
          title: l10n.updateRequiredTitle,
          body: l10n.updateRequiredBody(gate.minVersion ?? ''),
          actionLabel: l10n.updateAction,
          onAction: () => launchUrl(Uri.parse(_playStoreUrl), mode: LaunchMode.externalApplication),
        );
    }
  }
}

class _Blocker extends StatelessWidget {
  const _Blocker({required this.title, required this.body, this.actionLabel, this.onAction});

  final String title;
  final String body;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SxColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: Theme.of(context).textTheme.headlineSmall, textAlign: TextAlign.center),
                const SizedBox(height: 12),
                Text(body, textAlign: TextAlign.center, style: const TextStyle(color: SxColors.textSecondary)),
                if (actionLabel != null) ...[
                  const SizedBox(height: 24),
                  ElevatedButton(onPressed: onAction, child: Text(actionLabel!)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
