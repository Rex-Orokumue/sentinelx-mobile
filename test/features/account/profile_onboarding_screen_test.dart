import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/core/api/api_client.dart';
import 'package:sentinelx_mobile/core/api/models.dart';
import 'package:sentinelx_mobile/core/api/profile_onboarding_models.dart';
import 'package:sentinelx_mobile/core/auth/onboarding_gate.dart';
import 'package:sentinelx_mobile/core/l10n/gen/app_localizations.dart';
import 'package:sentinelx_mobile/core/providers.dart';
import 'package:sentinelx_mobile/features/account/profile_onboarding_providers.dart';
import 'package:sentinelx_mobile/features/account/profile_onboarding_screen.dart';
import 'package:sentinelx_mobile/features/compete/compete_models.dart';
import 'package:sentinelx_mobile/features/compete/compete_providers.dart';
import 'package:sentinelx_mobile/router/app_router.dart';
import 'package:sentinelx_mobile/router/auth_redirect.dart';

import '../../support/pump_compete.dart';

const _games = [
  GameSummary(id: 'game-1', name: 'COD Mobile', slug: 'codm', iconUrl: null),
];

MeResponse _me({required String? profileCompletedAt}) => MeResponse(
  id: 'player-1',
  email: null,
  roles: const [],
  isStaff: false,
  isAdmin: false,
  profile: MeProfile(
    username: 'player',
    displayName: null,
    avatarUrl: null,
    whatsappNumber: '+2348012345678',
    country: 'Nigeria',
    locale: 'en',
    membershipTier: null,
    kycVerified: false,
    deletionRequestedAt: null,
    profileCompletedAt: profileCompletedAt,
    consentWhatsappUpdates: false,
    gameInterests: const ['game-1'],
  ),
);

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

  testWidgets('waits for refreshed /me before leaving the onboarding gate', (
    tester,
  ) async {
    final refreshedMe = Completer<MeResponse?>();
    var meFetches = 0;
    var completed = false;
    await pumpCompete(
      tester,
      Consumer(
        builder: (context, ref, _) {
          ref.watch(meProvider);
          return ProfileOnboardingScreen(
            onCompleted: () => completed = true,
            onUnauthorized: () {},
          );
        },
      ),
      overrides: [
        meProvider.overrideWith((ref) {
          meFetches++;
          return meFetches == 1 ? Future.value(null) : refreshedMe.future;
        }),
        gamesProvider.overrideWith((ref) async => _games),
        profileOnboardingSubmitterProvider.overrideWithValue(
          (input) async => const ProfileOnboardingResult(
            profileCompletedAt: '2026-10-03T12:00:00Z',
          ),
        ),
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
    await tester.pump();

    expect(meFetches, 2);
    expect(completed, isFalse);

    refreshedMe.complete(
      const MeResponse(
        id: 'player-1',
        email: null,
        roles: [],
        isStaff: false,
        isAdmin: false,
        profile: MeProfile(
          username: 'player',
          displayName: null,
          avatarUrl: null,
          whatsappNumber: '+2348012345678',
          country: 'Nigeria',
          locale: 'en',
          membershipTier: null,
          kycVerified: false,
          deletionRequestedAt: null,
          profileCompletedAt: '2026-10-03T12:00:00Z',
          consentWhatsappUpdates: false,
          gameInterests: ['game-1'],
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(completed, isTrue);
  });

  testWidgets(
    'a failed POST stays on the form and leaves the profile incomplete',
    (tester) async {
      var completed = false;
      var meFetches = 0;
      await pumpCompete(
        tester,
        ProfileOnboardingScreen(
          onCompleted: () => completed = true,
          onUnauthorized: () {},
        ),
        overrides: [
          meProvider.overrideWith((ref) async {
            meFetches++;
            return null;
          }),
          gamesProvider.overrideWith((ref) async => _games),
          profileOnboardingSubmitterProvider.overrideWithValue(
            (input) async => throw const ApiException(
              status: 0,
              code: 'network',
              message: 'offline',
            ),
          ),
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

      expect(completed, isFalse);
      expect(
        meFetches,
        1,
        reason: 'a failed POST must not refresh or complete /me',
      );
      expect(
        find.text('Could not save your profile. Please try again.'),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('profile-onboarding-submit')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'first successful submit leaves the real onboarding route after refreshed /me',
    (tester) async {
      var meFetches = 0;
      var gate = OnboardingGate.profile;
      final router = buildAppRouter(
        initialLocation: '/onboarding/profile',
        authGate: () => AuthGateSnapshot(
          isLoading: false,
          isSignedIn: true,
          onboardingGate: gate,
        ),
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        ProviderScope(
          retry: (_, _) => null,
          overrides: [
            meProvider.overrideWith((ref) async {
              meFetches++;
              if (meFetches == 1) return _me(profileCompletedAt: null);
              gate = OnboardingGate.none;
              return _me(profileCompletedAt: '2026-10-03T12:00:00Z');
            }),
            gamesProvider.overrideWith((ref) async => _games),
            profileOnboardingSubmitterProvider.overrideWithValue(
              (input) async => const ProfileOnboardingResult(
                profileCompletedAt: '2026-10-03T12:00:00Z',
              ),
            ),
          ],
          child: MaterialApp.router(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            routerConfig: router,
          ),
        ),
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

      expect(meFetches, 2);
      expect(
        router.routerDelegate.currentConfiguration.last.matchedLocation,
        isNot('/onboarding/profile'),
      );
      expect(
        router.routerDelegate.currentConfiguration.last.matchedLocation,
        '/',
      );
    },
  );
}
