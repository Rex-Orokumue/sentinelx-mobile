import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/gen/app_localizations.dart';
import '../../theme/sx_colors.dart';
import 'push_tap_router.dart';

/// Shows a push that arrives while the app is in the foreground (the OS displays nothing for those) as a
/// banner under the status bar. Mounted in `MaterialApp.builder`, above the Navigator, so it needs no
/// Scaffold. Tap opens the destination; it dismisses itself after 5 seconds.
class PushBannerHost extends ConsumerWidget {
  const PushBannerHost({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final message = ref.watch(foregroundPushProvider);
    return Stack(
      children: [
        child,
        if (message != null)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Material(
                  key: const Key('push-banner'),
                  color: SxColors.surface,
                  elevation: 6,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: SxColors.border),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {
                      ref.read(pushTapRouterProvider).onTap(message);
                      ref.read(foregroundPushProvider.notifier).dismiss();
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      child: Row(
                        children: [
                          const Icon(Icons.notifications_active_outlined, color: SxColors.accentText),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (message.title != null)
                                  Text(
                                    message.title!,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontWeight: FontWeight.w700),
                                  ),
                                if (message.body != null)
                                  Text(
                                    message.body!,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(color: SxColors.textSecondary),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            AppLocalizations.of(context).ntfBannerOpen,
                            style: const TextStyle(color: SxColors.accentText, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
