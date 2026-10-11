import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/shared/cosmetics/cosmetic_style.dart';

void main() {
  group('CosmeticStyle.usernameColour', () {
    test('maps the four store colours to the web palette', () {
      expect(CosmeticStyle.usernameColour('username_purple'), const Color(0xFFA78BFA));
      expect(CosmeticStyle.usernameColour('username_gold'), const Color(0xFFFBBF24));
      expect(CosmeticStyle.usernameColour('username_red'), const Color(0xFFF87171));
      expect(CosmeticStyle.usernameColour('username_teal'), const Color(0xFF2DD4BF));
    });

    test('is null for nothing equipped and for any slug the app does not know', () {
      expect(CosmeticStyle.usernameColour(null), isNull);
      expect(CosmeticStyle.usernameColour(''), isNull);
      expect(CosmeticStyle.usernameColour('username_pink'), isNull);
      expect(CosmeticStyle.usernameColour('theme_dark_void'), isNull);
    });
  });

  group('CosmeticStyle.profileTheme', () {
    test('returns a decoration for each of the three themes', () {
      expect(CosmeticStyle.profileTheme('theme_dark_void'), isA<BoxDecoration>());
      expect(CosmeticStyle.profileTheme('theme_neon_grid'), isA<BoxDecoration>());
      expect(CosmeticStyle.profileTheme('theme_lagos_skyline'), isA<BoxDecoration>());
    });

    test('dark void is flat black; lagos skyline is a gradient; neon grid is distinct from both', () {
      expect(CosmeticStyle.profileTheme('theme_dark_void')!.color, const Color(0xFF000000));
      expect(CosmeticStyle.profileTheme('theme_lagos_skyline')!.gradient, isA<LinearGradient>());
      expect(CosmeticStyle.profileTheme('theme_neon_grid').toString(), isNot(CosmeticStyle.profileTheme('theme_dark_void').toString()));
    });

    test('is null for nothing equipped and for any slug the app does not know', () {
      expect(CosmeticStyle.profileTheme(null), isNull);
      expect(CosmeticStyle.profileTheme(''), isNull);
      expect(CosmeticStyle.profileTheme('theme_unknown'), isNull);
      expect(CosmeticStyle.profileTheme('username_gold'), isNull);
    });
  });
}
