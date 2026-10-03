import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/core/api/profile_onboarding_models.dart';
import 'package:sentinelx_mobile/core/providers.dart';
import 'package:sentinelx_mobile/features/account/profile_onboarding_providers.dart';
import 'package:sentinelx_mobile/features/account/profile_onboarding_screen.dart';
import 'package:sentinelx_mobile/features/compete/compete_models.dart';
import 'package:sentinelx_mobile/features/compete/compete_providers.dart';

import '../../support/pump_compete.dart';

const _games = [
  GameSummary(id: 'game-1', name: 'COD Mobile', slug: 'codm', iconUrl: null),
];

void main() {
  testWidgets('requires every field and an explicit consent answer', (
    tester,
  ) async {
    await pumpCompete(
      tester,
      ProfileOnboardingScreen(onCompleted: () {}, onUnauthorized: () {}),
      overrides: [
        meProvider.overrideWith((ref) async => null),
        gamesProvider.overrideWith((ref) async => _games),
      ],
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const Key('profile-onboarding-submit')),
    );
    await tester.tap(find.byKey(const Key('profile-onboarding-submit')));
    await tester.pump();
    expect(find.text('Select your country.'), findsOneWidget);
    expect(find.text('Enter your WhatsApp number.'), findsOneWidget);
    expect(find.text('Choose at least one game.'), findsOneWidget);
    expect(find.text('Choose yes or no.'), findsOneWidget);
  });

  testWidgets('submits the exact profile body and accepts consent false', (
    tester,
  ) async {
    ProfileOnboardingInput? sent;
    var completed = false;
    await pumpCompete(
      tester,
      ProfileOnboardingScreen(
        onCompleted: () => completed = true,
        onUnauthorized: () {},
      ),
      overrides: [
        meProvider.overrideWith((ref) async => null),
        gamesProvider.overrideWith((ref) async => _games),
        profileOnboardingSubmitterProvider.overrideWithValue((input) async {
          sent = input;
          return const ProfileOnboardingResult(
            profileCompletedAt: '2026-10-03T12:00:00Z',
          );
        }),
      ],
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('country-field')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(EditableText).last, 'Nigeria');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nigeria').last);
    await tester.enterText(
      find.byKey(const Key('profile-onboarding-whatsapp')),
      '+2348012345678',
    );
    await tester.tap(find.byKey(const Key('game-interest-game-1')));
    await tester.ensureVisible(find.byKey(const Key('profile-consent-no')));
    await tester.tap(find.byKey(const Key('profile-consent-no')));
    await tester.ensureVisible(
      find.byKey(const Key('profile-onboarding-submit')),
    );
    await tester.tap(find.byKey(const Key('profile-onboarding-submit')));
    await tester.pumpAndSettle();

    expect(sent?.toJson(), {
      'country': 'Nigeria',
      'whatsapp': '+2348012345678',
      'consentWhatsappUpdates': false,
      'gameInterests': ['game-1'],
    });
    expect(completed, isTrue);
  });
}
