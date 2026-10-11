import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/shared/cosmetics/cosmetic_art.dart';

void main() {
  group('CosmeticArt.assetFor', () {
    test('matches a bundled file by name from a site path or an absolute URL, ignoring query and fragment', () {
      expect(CosmeticArt.assetFor('/coin-items/gold-crown.webp'), 'assets/store/gold-crown.webp');
      expect(CosmeticArt.assetFor('https://sentinelxesports.com.ng/coin-items/gold-crown.webp?v=2'), 'assets/store/gold-crown.webp');
      expect(CosmeticArt.assetFor('https://other.host/anything/bubble-mascot-neon.webp#x'), 'assets/store/bubble-mascot-neon.webp');
    });

    test('keeps the capital letters of legendary-SX.webp', () {
      expect(CosmeticArt.assetFor('/coin-items/legendary-SX.webp'), 'assets/store/legendary-SX.webp');
    });

    test('is null for a file we do not bundle, empty, null, and nonsense', () {
      expect(CosmeticArt.assetFor('/coin-items/new-frame.webp'), isNull);
      expect(CosmeticArt.assetFor(''), isNull);
      expect(CosmeticArt.assetFor(null), isNull);
      expect(CosmeticArt.assetFor('not a url'), isNull);
      expect(CosmeticArt.assetFor('/coin-items/gold-crown.jpeg'), isNull); // only the WebP is bundled
    });
  });

  group('bundle integrity', () {
    test('every declared name exists under assets/store and nothing else is in the folder', () {
      for (final name in CosmeticArt.bundledNames) {
        expect(File('assets/store/$name').existsSync(), isTrue, reason: '$name is declared but not bundled');
      }
      final onDisk = Directory('assets/store').listSync().whereType<File>().map((f) => f.uri.pathSegments.last).toSet();
      expect(onDisk, CosmeticArt.bundledNames, reason: 'assets/store and bundledNames must match exactly');
    });

    test('the store art is the 20 catalogue items', () {
      expect(CosmeticArt.bundledNames, hasLength(20));
    });

    test('pubspec.yaml lists the folder so the files ship in the app', () {
      expect(File('pubspec.yaml').readAsStringSync(), contains('assets/store/'));
    });
  });

  group('CosmeticArt.image', () {
    Widget host(Widget child) => MaterialApp(home: Scaffold(body: Center(child: child)));

    testWidgets('a bundled name renders from the asset bundle, not the network', (tester) async {
      await tester.pumpWidget(host(CosmeticArt.image('https://x.test/coin-items/gold-crown.webp', width: 40, height: 40)));
      final image = tester.widget<Image>(find.byType(Image));
      expect(image.image, isA<AssetImage>());
      expect((image.image as AssetImage).assetName, 'assets/store/gold-crown.webp');
    });

    testWidgets('an unknown name falls back to the network image, and its error shows the fallback', (tester) async {
      await tester.pumpWidget(host(CosmeticArt.image('https://x.test/coin-items/new-frame.webp', fallback: const Text('fallback'))));
      final image = tester.widget<Image>(find.byType(Image));
      expect(image.image, isA<NetworkImage>());
      expect(image.errorBuilder, isNotNull);
    });

    testWidgets('null or empty renders the fallback and builds no image', (tester) async {
      await tester.pumpWidget(host(CosmeticArt.image(null, fallback: const Text('fallback'))));
      expect(find.text('fallback'), findsOneWidget);
      expect(find.byType(Image), findsNothing);
      await tester.pumpWidget(host(CosmeticArt.image('', fallback: const Text('fallback'))));
      expect(find.text('fallback'), findsOneWidget);
    });
  });
}
