import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/core/api/models.dart';
import 'package:sentinelx_mobile/core/providers.dart';
import 'package:sentinelx_mobile/features/guide/guide_mascot.dart';

MeResponse _me(String? bubbleSkinUrl) => MeResponse(
      id: 'u1',
      email: 'a@b.c',
      roles: const [],
      isStaff: false,
      isAdmin: false,
      profile: MeProfile(
        username: 'ada', displayName: 'Ada', avatarUrl: null, whatsappNumber: null, country: null, locale: 'en',
        membershipTier: 'guardian', kycVerified: false, deletionRequestedAt: null, bubbleSkinUrl: bubbleSkinUrl,
      ),
    );

Future<ImageProvider> _pumpAndGet(WidgetTester tester, String? skin) async {
  await tester.pumpWidget(ProviderScope(
    overrides: [meProvider.overrideWith((ref) async => _me(skin))],
    child: const MaterialApp(home: Scaffold(body: GuideMascot(size: 40))),
  ));
  await tester.pumpAndSettle();
  return tester.widget<Image>(find.byType(Image)).image;
}

void main() {
  testWidgets('no equipped skin shows the bundled default mascot', (tester) async {
    final image = await _pumpAndGet(tester, null);
    expect((image as AssetImage).assetName, 'assets/mascot/mascot-bubble.png');
  });

  testWidgets('a known bubble skin renders from the bundled store art', (tester) async {
    final image = await _pumpAndGet(tester, '/coin-items/bubble-mascot-neon.webp');
    expect((image as AssetImage).assetName, 'assets/store/bubble-mascot-neon.webp');
  });

  testWidgets('an unknown skin is requested from the network (the bundled default only shows if that fails)', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [meProvider.overrideWith((ref) async => _me('/coin-items/bubble-mascot-future.webp'))],
      child: const MaterialApp(home: Scaffold(body: GuideMascot(size: 40))),
    ));
    // One frame resolves /me and builds the network image; the (test-environment) network failure arrives later.
    await tester.pump();
    final image = tester.widget<Image>(find.byType(Image));
    expect(image.image, isA<NetworkImage>());
    expect(image.errorBuilder, isNotNull);
  });
}
