import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/core/l10n/gen/app_localizations.dart';
import 'package:sentinelx_mobile/features/compete/compete_providers.dart';
import 'package:sentinelx_mobile/features/compete/compete_reads_repository.dart';
import 'package:sentinelx_mobile/features/match/evidence.dart';
import 'package:sentinelx_mobile/features/match/match_providers.dart';
import 'package:sentinelx_mobile/router/app_router.dart';

import '../fakes/fake_compete_reads.dart';
import '../fakes/fake_evidence.dart';
import '../fakes/fake_match_repositories.dart';
import '../fakes/fake_registration_repository.dart';
import 'pump_compete.dart';

/// Pumps the real router. The Compete list/detail read through [reads]; the bracket, Match Centre and
/// dashboard fixtures read through [matchRepo] (the Phase 2b API-backed repository) and, for the match
/// row itself, [matchReads] (the T1 Supabase read).
Future<void> pumpRouterWithRepo(
  WidgetTester tester, {
  CompeteReadsRepository? reads,
  FakeMatchRepository? matchRepo,
  FakeMatchReads? matchReads,
  String initialLocation = '/tournaments',
  List<Override> overrides = const [],
}) {
  return tester.pumpWidget(ProviderScope(
    retry: (_, _) => null,
    overrides: [
      competeReadsRepositoryProvider.overrideWithValue(reads ?? FakeCompeteReads()),
      registrationRepositoryProvider.overrideWithValue(FakeRegistrationRepository()),
      matchRepositoryProvider.overrideWithValue(matchRepo ?? FakeMatchRepository()),
      matchReadsRepositoryProvider.overrideWithValue(matchReads ?? FakeMatchReads()),
      evidenceUploaderProvider.overrideWithValue(FakeUploader()),
      imagePickerProvider.overrideWithValue(FakePicker()),
      ...competeBaseOverrides(),
      ...overrides,
    ],
    child: MaterialApp.router(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: buildAppRouter(initialLocation: initialLocation),
    ),
  ));
}
