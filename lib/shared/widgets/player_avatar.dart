import 'package:flutter/material.dart';

import '../../core/theme/sx_colors.dart';

/// Circular avatar with an optional equipped frame overlay. Deleted accounts and missing images
/// render the same neutral placeholder — never a blank box or a broken-image icon.
class PlayerAvatar extends StatelessWidget {
  const PlayerAvatar({super.key, required this.avatarUrl, this.frameUrl, this.isDeleted = false, this.size = 40});

  final String? avatarUrl;
  final String? frameUrl;
  final bool isDeleted;
  final double size;

  @override
  Widget build(BuildContext context) {
    final showImage = !isDeleted && avatarUrl != null && avatarUrl!.isNotEmpty;
    final placeholder = Container(
      key: const Key('avatar-placeholder'),
      width: size,
      height: size,
      decoration: const BoxDecoration(color: SxColors.surface, shape: BoxShape.circle),
      child: Icon(Icons.person, size: size * 0.55, color: SxColors.textSecondary),
    );
    return SizedBox(
      width: size,
      height: size,
      child: Stack(alignment: Alignment.center, clipBehavior: Clip.none, children: [
        ClipOval(
          child: showImage
              ? Image.network(avatarUrl!, width: size, height: size, fit: BoxFit.cover, errorBuilder: (_, _, _) => placeholder)
              : placeholder,
        ),
        if (!isDeleted && frameUrl != null)
          IgnorePointer(
            child: Image.network(frameUrl!, width: size * 1.25, height: size * 1.25, errorBuilder: (_, _, _) => const SizedBox.shrink()),
          ),
      ]),
    );
  }
}

/// Web asset paths (frames, etc.) are site-relative (`/coin-items/x.webp`); absolute URLs pass through.
String? resolveAsset(String? path, String siteUrl) {
  if (path == null) return null;
  if (!path.startsWith('/')) return path;
  final base = siteUrl.endsWith('/') ? siteUrl.substring(0, siteUrl.length - 1) : siteUrl;
  return '$base$path';
}
