import 'package:flutter/material.dart';

import '../../core/l10n/gen/app_localizations.dart';

/// Friendly load-failure message with a retry button; never shows the underlying exception.
class LoadError extends StatelessWidget {
  const LoadError({super.key, required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(l10n.cmpLoadError, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: onRetry, child: Text(l10n.cmpRetry)),
        ]),
      ),
    );
  }
}
