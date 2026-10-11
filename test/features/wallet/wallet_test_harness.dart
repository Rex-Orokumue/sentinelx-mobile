import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sentinelx_mobile/core/l10n/fallback_delegates.dart';
import 'package:sentinelx_mobile/core/l10n/gen/app_localizations.dart';
import 'package:sentinelx_mobile/core/providers.dart';
import 'package:sentinelx_mobile/features/compete/registration_flow.dart';
import 'package:sentinelx_mobile/features/wallet/wallet_providers.dart';

import '../../fakes/fake_wallet_repository.dart';

const walletRoutes = [
  '/account/wallet/deposit',
  '/account/wallet/withdraw',
  '/account/wallet/transactions',
  '/account/wallet/payout-account',
];

/// Pumps [home] at `/` inside a real [GoRouter] whose wallet sub-routes are text placeholders, so a tap on a
/// navigation button can be asserted by `find.text('page:/account/wallet/deposit')`.
Future<GoRouter> pumpWallet(
  WidgetTester tester,
  Widget home, {
  required FakeWalletRepository repo,
  Locale locale = const Locale('en'),
  double width = 375,
  double height = 800,
  String? viewer = 'u1',
  Future<bool> Function(String url)? paystack,
  List<Override> overrides = const [],
  bool settle = true,
}) async {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (_, _) => home),
      GoRoute(path: '/account', builder: (_, _) => const Scaffold(body: Text('page:/account'))),
      GoRoute(path: '/login', builder: (_, _) => const Scaffold(body: Text('page:/login'))),
      for (final r in walletRoutes) GoRoute(path: r, builder: (_, _) => Scaffold(body: Text('page:$r'))),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      retry: (_, _) => null, // no automatic retries: a failed load must stay failed until the test taps Retry
      overrides: [
        walletRepositoryProvider.overrideWithValue(repo),
        viewerIdProvider.overrideWith((ref) async => viewer),
        paystackLauncherProvider.overrideWithValue(paystack ?? (_) async => true),
        ...overrides,
      ],
      child: MaterialApp.router(
        routerConfig: router,
        locale: locale,
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
  return router;
}
