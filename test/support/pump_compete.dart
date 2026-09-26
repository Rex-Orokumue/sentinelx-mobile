import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/core/api/models.dart';
import 'package:sentinelx_mobile/core/config/remote_config.dart';
import 'package:sentinelx_mobile/core/l10n/gen/app_localizations.dart';
import 'package:sentinelx_mobile/core/providers.dart';

RemoteConfig testRemoteConfig() => RemoteConfig.fromJson(const {
      'minSupportedAppVersion': '1.0.0',
      'latestAppVersion': '1.4.0',
      'maintenance': null,
      'siteUrl': 'https://sentinelxesports.com.ng',
      'coins': {'coinsPerNaira': 2, 'nairaPerCoin': 0.5, 'coinsPerEntry': 1000, 'coinsHalfEntry': 500},
      'enforcePhoneVerification': false,
      'whatsappCommunityUrl': null,
      'features': {'wagering': true},
    });

MeResponse testMe({String? displayName = 'Ada', String? whatsapp = '+2348012345678', String? username = 'ada'}) => MeResponse(
      id: 'u1',
      email: 'ada@test.dev',
      roles: const [],
      isStaff: false,
      isAdmin: false,
      profile: MeProfile(
        username: username,
        displayName: displayName,
        avatarUrl: null,
        whatsappNumber: whatsapp,
        country: null,
        locale: 'en',
        membershipTier: null,
        kycVerified: false,
        deletionRequestedAt: null,
      ),
    );

/// Signed-in + remote-config overrides shared by the Compete widget tests.
List<Override> competeBaseOverrides({MeResponse? me, bool signedOut = false}) => [
      remoteConfigProvider.overrideWith((ref) async => testRemoteConfig()),
      meProvider.overrideWith((ref) async => signedOut ? null : (me ?? testMe())),
    ];

Future<void> pumpCompete(
  WidgetTester tester,
  Widget home, {
  List<Override> overrides = const [],
  Size size = const Size(375, 800),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    retry: (_, _) => null,
    overrides: overrides,
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: home),
    ),
  ));
}
