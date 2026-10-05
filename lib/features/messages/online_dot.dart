import 'package:flutter/material.dart';

import '../../core/l10n/gen/app_localizations.dart';
import '../../shared/widgets/player_avatar.dart';

/// An avatar with a small green "online" dot at its bottom-right corner when [online]. The dot carries a
/// semantics label so it is not colour-only information.
class AvatarWithPresence extends StatelessWidget {
  const AvatarWithPresence({super.key, required this.avatarUrl, required this.online, required this.dotKey, this.size = 44});

  final String? avatarUrl;
  final bool online;
  final Key dotKey;
  final double size;

  @override
  Widget build(BuildContext context) {
    final dot = size * 0.28;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(clipBehavior: Clip.none, children: [
        PlayerAvatar(avatarUrl: avatarUrl, size: size),
        if (online)
          Positioned(
            right: -1,
            bottom: -1,
            child: Semantics(
              label: AppLocalizations.of(context).dmOnline,
              child: ExcludeSemantics(
                child: Container(
                  key: dotKey,
                  width: dot,
                  height: dot,
                  decoration: BoxDecoration(
                    color: Colors.greenAccent.shade700,
                    shape: BoxShape.circle,
                    border: Border.all(color: Theme.of(context).scaffoldBackgroundColor, width: 2),
                  ),
                ),
              ),
            ),
          ),
      ]),
    );
  }
}
