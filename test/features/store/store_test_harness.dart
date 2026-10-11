import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sentinelx_mobile/core/l10n/fallback_delegates.dart';
import 'package:sentinelx_mobile/core/l10n/gen/app_localizations.dart';
import 'package:sentinelx_mobile/core/providers.dart';
import 'package:sentinelx_mobile/features/store/store_providers.dart';

import '../../fakes/fake_store_repository.dart';

/// Pumps [home] at `/` in a real [GoRouter] whose `/login` is a text placeholder, with Riverpod's automatic retry
/// disabled so a failed load stays failed until the test taps Retry.
Future<GoRouter> pumpStore(
  WidgetTester tester,
  Widget home, {
  required FakeStoreRepository repo,
  Locale locale = const Locale('en'),
  double width = 375,
  double height = 800,
  String? viewer = 'u1',
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
      GoRoute(path: '/login', builder: (_, _) => const Scaffold(body: Text('page:/login'))),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      retry: (_, _) => null,
      overrides: [
        storeRepositoryProvider.overrideWithValue(repo),
        viewerIdProvider.overrideWith((ref) async => viewer),
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
