import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/core/l10n/gen/app_localizations.dart';
import 'package:sentinelx_mobile/data/tournaments_repository.dart';
import 'package:sentinelx_mobile/features/compete/compete_providers.dart';
import 'package:sentinelx_mobile/features/compete/compete_reads_repository.dart';
import 'package:sentinelx_mobile/features/tournaments/tournaments_providers.dart';
import 'package:sentinelx_mobile/router/app_router.dart';

import '../fakes/fake_compete_reads.dart';
import '../fakes/fake_registration_repository.dart';
import 'pump_compete.dart';

Future<void> pumpWithRepo(WidgetTester tester, TournamentsRepository repository, Widget home) {
  return tester.pumpWidget(ProviderScope(
    retry: (_, _) => null,
    overrides: [tournamentsRepositoryProvider.overrideWithValue(repository)],
    child: MaterialApp(home: home),
  ));
}

/// Pumps the real router. The bracket still reads through the old [TournamentsRepository] (Phase 2b
/// replaces it); the Compete list/detail read through [reads].
Future<void> pumpRouterWithRepo(
  WidgetTester tester,
  TournamentsRepository repository, {
  CompeteReadsRepository? reads,
  String initialLocation = '/tournaments',
}) {
  return tester.pumpWidget(ProviderScope(
    retry: (_, _) => null,
    overrides: [
      tournamentsRepositoryProvider.overrideWithValue(repository),
      competeReadsRepositoryProvider.overrideWithValue(reads ?? FakeCompeteReads()),
      registrationRepositoryProvider.overrideWithValue(FakeRegistrationRepository()),
      ...competeBaseOverrides(),
    ],
    child: MaterialApp.router(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: buildAppRouter(initialLocation: initialLocation),
    ),
  ));
}
