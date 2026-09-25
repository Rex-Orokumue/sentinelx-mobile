import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/core/auth/auth_providers.dart';
import 'package:sentinelx_mobile/core/l10n/gen/app_localizations.dart';
import 'package:sentinelx_mobile/core/providers.dart';
import 'package:sentinelx_mobile/features/onboarding/onboarding_username_screen.dart';

import 'auth_test_fakes.dart';

class _RecordingClaim extends FakeAuthRepositoryForForgot {
  String? claimed;
  Object? throwOnClaim;

  @override
  Future<String> claimUsername(String username) async {
    claimed = username;
    if (throwOnClaim != null) throw throwOnClaim!;
    return username;
  }
}

void main() {
  testWidgets('claims a username and calls onClaimed', (tester) async {
    final repo = _RecordingClaim();
    var claimed = false;
    await tester.pumpWidget(ProviderScope(
      retry: (_, _) => null,
      overrides: [authRepositoryProvider.overrideWithValue(repo)],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: OnboardingUsernameScreen(onClaimed: () => claimed = true),
      ),
    ));

    await tester.enterText(find.byKey(const Key('onboarding-username')), 'BrandNew');
    await tester.tap(find.byKey(const Key('onboarding-username-submit')));
    await tester.pumpAndSettle();

    expect(repo.claimed, 'BrandNew');
    expect(claimed, isTrue);
  });

  testWidgets('refreshes /me before onClaimed so the router guard sees the new username', (tester) async {
    final repo = _RecordingClaim();
    var meFetches = 0;
    int? fetchesWhenClaimed;
    await tester.pumpWidget(ProviderScope(
      retry: (_, _) => null,
      overrides: [
        authRepositoryProvider.overrideWithValue(repo),
        meProvider.overrideWith((ref) async {
          meFetches++;
          return null;
        }),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Consumer(builder: (context, ref, _) {
          ref.watch(meProvider); // keep it alive, as the router's ref.listen does
          return OnboardingUsernameScreen(onClaimed: () => fetchesWhenClaimed = meFetches);
        }),
      ),
    ));
    await tester.pumpAndSettle();
    expect(meFetches, 1);

    await tester.enterText(find.byKey(const Key('onboarding-username')), 'BrandNew');
    await tester.tap(find.byKey(const Key('onboarding-username-submit')));
    await tester.pumpAndSettle();

    expect(fetchesWhenClaimed, 2);
  });
}
