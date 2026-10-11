import 'package:flutter/painting.dart';

/// Native styling for the store's non-image cosmetics: username colours and profile themes. The server sends
/// only the equipped item's SLUG; this maps it to a look. A slug the app does not know yet (a store item added
/// after this build) resolves to null, which callers treat as "nothing equipped" and never as an error.
class CosmeticStyle {
  const CosmeticStyle._();

  // The web's colours for these items (purple-text, amber-400, red-400, teal-400).
  static const _usernameColours = <String, Color>{
    'username_purple': Color(0xFFA78BFA),
    'username_gold': Color(0xFFFBBF24),
    'username_red': Color(0xFFF87171),
    'username_teal': Color(0xFF2DD4BF),
  };

  static Color? usernameColour(String? slug) => slug == null ? null : _usernameColours[slug];

  /// The look behind a profile header. The web paints `theme_neon_grid` as a CSS line grid; here it is a
  /// documented approximation (a violet-tinted slate gradient), since a BoxDecoration cannot draw a grid.
  static BoxDecoration? profileTheme(String? slug) {
    switch (slug) {
      case 'theme_dark_void':
        return const BoxDecoration(color: Color(0xFF000000));
      case 'theme_neon_grid':
        return const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1E1B4B), Color(0xFF020617)],
          ),
        );
      case 'theme_lagos_skyline':
        return const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF431407), Color(0xFF0F172A), Color(0xFF020617)],
          ),
        );
    }
    return null;
  }
}
