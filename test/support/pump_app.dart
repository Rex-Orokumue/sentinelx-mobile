import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/core/l10n/gen/app_localizations.dart';
import 'package:sentinelx_mobile/data/tournaments_repository.dart';
import 'package:sentinelx_mobile/features/tournaments/tournaments_providers.dart';
import 'package:sentinelx_mobile/router/app_router.dart';

Future<void> pumpWithRepo(WidgetTester tester, TournamentsRepository repository, Widget home) {
  return tester.pumpWidget(ProviderScope(
    retry: (_, _) => null,
    overrides: [tournamentsRepositoryProvider.overrideWithValue(repository)],
    child: MaterialApp(home: home),
  ));
}

Future<void> pumpRouterWithRepo(WidgetTester tester, TournamentsRepository repository) {
  return tester.pumpWidget(ProviderScope(
    retry: (_, _) => null,
    overrides: [tournamentsRepositoryProvider.overrideWithValue(repository)],
    child: MaterialApp.router(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: buildAppRouter(initialLocation: '/tournaments'),
    ),
  ));
}
