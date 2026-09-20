import 'package:flutter/material.dart';

import 'sx_colors.dart';

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: SxColors.primary,
    brightness: Brightness.dark,
  ).copyWith(
    primary: SxColors.primary,
    secondary: SxColors.accentText,
    surface: SxColors.surface,
    outline: SxColors.border,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme,
    scaffoldBackgroundColor: SxColors.background,
    appBarTheme: const AppBarTheme(
      backgroundColor: SxColors.background,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
    ),
    cardTheme: CardThemeData(
      color: SxColors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: SxColors.border),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: SxColors.primary,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(48), // 48dp touch target
      ),
    ),
  );
}
