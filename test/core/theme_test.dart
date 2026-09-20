import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/core/theme/sx_colors.dart';
import 'package:sentinelx_mobile/core/theme/theme.dart';

void main() {
  test('uses the web palette: near-black ground, violet primary', () {
    final theme = buildTheme();
    expect(theme.brightness, Brightness.dark);
    expect(theme.scaffoldBackgroundColor, SxColors.background);
    expect(theme.colorScheme.primary, SxColors.primary);
    expect(SxColors.background, const Color(0xFF0B0B0F));
    expect(SxColors.primary, const Color(0xFF7C3AED));
    expect(SxColors.accentText, const Color(0xFFA78BFA));
  });
}
