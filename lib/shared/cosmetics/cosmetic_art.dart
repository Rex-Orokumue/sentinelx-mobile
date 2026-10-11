import 'package:flutter/widgets.dart';

/// Store artwork bundled in the app (`assets/store/`), matched by FILE NAME against whatever URL or path the
/// server sends. The server already resolves a player's equipped frame and bubble skin to a URL such as
/// `/coin-items/gold-crown.webp`, and the bundled files keep the web names, so frames and bubble skins render
/// instantly and offline with no API change. A name the app does not know yet (a store item added after this
/// build) falls back to the network URL, so new items never need an app update to appear.
class CosmeticArt {
  const CosmeticArt._();

  /// The 20 bundled files: identical to the web's `public/coin-items/*.webp`.
  static const Set<String> bundledNames = {
    // avatar frames
    'bronze-frame.webp',
    'purple-glow.webp',
    'gold-crown.webp',
    'champion-frame.webp',
    'cyber-core.webp',
    'diamond-edge.webp',
    'legendary-SX.webp',
    'mythic-sentinel.webp',
    'neon-pulse.webp',
    'shadow-flame.webp',
    // assistant bubble skins
    'bubble-mascot-classic.webp',
    'bubble-mascot-neon.webp',
    'bubble-mascot-gold.webp',
    // profile themes
    'theme-dark-void.webp',
    'theme-neon-grid.webp',
    'theme-lagos-skyline.webp',
    // username colours
    'username-purple.webp',
    'username-gold.webp',
    'username-red.webp',
    'username-teal.webp',
  };

  /// `assets/store/<name>` when [urlOrPath] ends in a bundled file name (query and fragment ignored), else null.
  static String? assetFor(String? urlOrPath) {
    if (urlOrPath == null || urlOrPath.isEmpty) return null;
    final uri = Uri.tryParse(urlOrPath);
    if (uri == null || uri.pathSegments.isEmpty) return null;
    final name = uri.pathSegments.last;
    return bundledNames.contains(name) ? 'assets/store/$name' : null;
  }

  /// The bundled asset when known, else the network image, else [fallback] (default: nothing).
  static Widget image(
    String? urlOrPath, {
    double? width,
    double? height,
    BoxFit fit = BoxFit.contain,
    Widget? fallback,
  }) {
    final empty = fallback ?? const SizedBox.shrink();
    final asset = assetFor(urlOrPath);
    if (asset != null) {
      return Image.asset(asset, width: width, height: height, fit: fit, errorBuilder: (_, _, _) => empty);
    }
    if (urlOrPath == null || urlOrPath.isEmpty) return empty;
    return Image.network(urlOrPath, width: width, height: height, fit: fit, errorBuilder: (_, _, _) => empty);
  }
}
