import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/gate/app_gate.dart';
import 'core/l10n/fallback_delegates.dart';
import 'core/l10n/gen/app_localizations.dart';
import 'core/notifications/push/push_banner_host.dart';
import 'core/theme/theme.dart';
import 'router/app_router.dart';

class SentinelXApp extends ConsumerWidget {
  const SentinelXApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'SentinelX Esports',
      theme: buildTheme(),
      routerConfig: ref.watch(routerProvider),
      localizationsDelegates: appLocalizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => AppGate(child: PushBannerHost(child: child ?? const SizedBox.shrink())),
    );
  }
}
