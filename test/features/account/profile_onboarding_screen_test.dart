import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/core/api/api_client.dart';
import 'package:sentinelx_mobile/core/api/models.dart';
import 'package:sentinelx_mobile/core/api/profile_onboarding_models.dart';
import 'package:sentinelx_mobile/core/auth/auth_providers.dart';
import 'package:sentinelx_mobile/core/auth/onboarding_gate.dart';
import 'package:sentinelx_mobile/core/l10n/gen/app_localizations.dart';
import 'package:sentinelx_mobile/core/notifications/push/push_models.dart';
import 'package:sentinelx_mobile/core/notifications/push/push_tap_router.dart';
import 'package:sentinelx_mobile/core/providers.dart';
import 'package:sentinelx_mobile/features/account/profile_onboarding_providers.dart';
import 'package:sentinelx_mobile/features/account/profile_onboarding_screen.dart';
import 'package:sentinelx_mobile/features/compete/compete_models.dart';
import 'package:sentinelx_mobile/features/compete/compete_providers.dart';
import 'package:sentinelx_mobile/features/home/home_providers.dart';
import 'package:sentinelx_mobile/router/app_router.dart';

import '../../support/pump_compete.dart';
import '../auth_test_fakes.dart';

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

class _RecordingSignOut extends FakeAuthRepositoryForForgot {
  _RecordingSignOut(this.events);
  final List<String> events;

  @override
  Future<void> signOut() async => events.add('signOut');
}

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

  testWidgets(
    'database default false is not treated as an explicit consent answer',
    (tester) async {
      await pumpCompete(
        tester,
        ProfileOnboardingScreen(onCompleted: () {}, onUnauthorized: () {}),
        overrides: [
          meProvider.overrideWithValue(
            AsyncData(_me(profileCompletedAt: null)),
          ),
          gamesProvider.overrideWith((ref) async => _games),
        ],
      );
      await tester.pumpAndSettle();

      expect(
        tester.widget<Radio<bool>>(find.byType(Radio<bool>).first).groupValue,
        isNull,
      );
      expect(
        tester.widget<Radio<bool>>(find.byType(Radio<bool>).last).groupValue,
        isNull,
      );
      await tester.ensureVisible(
        find.byKey(const Key('profile-onboarding-submit')),
      );
      await tester.tap(find.byKey(const Key('profile-onboarding-submit')));
      await tester.pump();

      expect(find.text('Choose yes or no.'), findsOneWidget);
    },
  );

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

  testWidgets('a 401 signs out before navigating to login', (tester) async {
    final events = <String>[];
    var meFetches = 0;
    await pumpCompete(
      tester,
      Consumer(
        builder: (context, ref, _) {
          ref.watch(meProvider);
          return ProfileOnboardingScreen(
            onCompleted: () {},
            onUnauthorized: () => events.add('navigate'),
          );
        },
      ),
      overrides: [
        authRepositoryProvider.overrideWithValue(_RecordingSignOut(events)),
        meProvider.overrideWith((ref) async {
          meFetches++;
          return _me(profileCompletedAt: null);
        }),
        gamesProvider.overrideWith((ref) async => _games),
        profileOnboardingSubmitterProvider.overrideWithValue(
          (input) async => throw const ApiException(
            status: 401,
            code: 'unauthorized',
            message: 'expired',
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

    expect(events, ['signOut', 'navigate']);
    expect(meFetches, greaterThan(1));
  });

  testWidgets(
    'first successful submit waits for real routerProvider /me refresh and stays off onboarding',
    (tester) async {
      final initialMe = Completer<MeResponse?>();
      final refreshedMe = Completer<MeResponse?>();
      var meFetches = 0;
      var posts = 0;

      await tester.pumpWidget(
        ProviderScope(
          retry: (_, _) => null,
          overrides: [
            sessionProvider.overrideWith((ref) => Stream.value(testSession())),
            remoteConfigProvider.overrideWithValue(
              AsyncData(testRemoteConfig()),
            ),
            meProvider.overrideWith((ref) async {
              meFetches++;
              if (meFetches == 1) return initialMe.future;
              return refreshedMe.future;
            }),
            gamesProvider.overrideWith((ref) async => _games),
            homeProvider.overrideWith(
              (ref) async => throw Exception('unused home request'),
            ),
            profileOnboardingSubmitterProvider.overrideWithValue((input) async {
              posts++;
              return const ProfileOnboardingResult(
                profileCompletedAt: '2026-10-03T12:00:00Z',
              );
            }),
          ],
          child: Consumer(
            builder: (context, ref, _) => MaterialApp.router(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              routerConfig: ref.watch(routerProvider),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(meFetches, 1);
      initialMe.complete(_me(profileCompletedAt: null));
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(MaterialApp)),
      );
      final router = container.read(routerProvider);
      expect(container.read(onboardingGateProvider), OnboardingGate.profile);
      expect(
        router.routerDelegate.currentConfiguration.last.matchedLocation,
        '/onboarding/profile',
      );
      expect(find.byType(ProfileOnboardingScreen), findsOneWidget);

      container.read(pushTapRouterProvider)
        ..markReady()
        ..onTap(const PushMessage(url: '/notifications'));
      await tester.pumpAndSettle();
      expect(
        router.routerDelegate.currentConfiguration.last.matchedLocation,
        '/onboarding/profile',
        reason: 'an incomplete profile cannot bypass the gate via a push tap',
      );

      await tester.ensureVisible(find.byKey(const Key('profile-consent-no')));
      await tester.tap(find.byKey(const Key('profile-consent-no')));
      await tester.ensureVisible(
        find.byKey(const Key('profile-onboarding-submit')),
      );
      await tester.tap(find.byKey(const Key('profile-onboarding-submit')));
      await tester.pump();

      expect(posts, 1);
      expect(meFetches, 2);
      expect(find.byType(ProfileOnboardingScreen), findsOneWidget);

      refreshedMe.complete(_me(profileCompletedAt: '2026-10-03T12:00:00Z'));
      await tester.pumpAndSettle();

      expect(
        router.routerDelegate.currentConfiguration.last.matchedLocation,
        '/',
      );
      expect(find.byType(ProfileOnboardingScreen), findsNothing);
      await tester.pump();
      expect(
        router.routerDelegate.currentConfiguration.last.matchedLocation,
        '/',
        reason: 'the refreshed completed profile must not bounce back',
      );
    },
  );
}
