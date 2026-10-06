import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../shared/widgets/player_avatar.dart' show resolveAsset;

const _fallbackAsset = 'assets/mascot/mascot-bubble.png';

/// The assistant's face: the signed-in player's equipped bubble skin, else the bundled default.
class GuideMascot extends ConsumerWidget {
  const GuideMascot({super.key, this.size = 40});

  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final skin = ref.watch(meProvider).asData?.value?.profile?.bubbleSkinUrl;
    final url = resolveAsset(skin, ref.watch(appConfigProvider).apiBaseUrl);
    final fallback = Image.asset(_fallbackAsset, width: size, height: size, fit: BoxFit.contain);
    if (url == null) return fallback;
    return Image.network(url, width: size, height: size, fit: BoxFit.contain, errorBuilder: (_, _, _) => fallback);
  }
}
