import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/gen/app_localizations.dart';
import '../../core/notifications/unread_counts.dart';
import '../../core/theme/sx_colors.dart';

class SxTabAppBar extends ConsumerWidget implements PreferredSizeWidget {
  const SxTabAppBar({super.key, required this.title, required this.onLogoTap});

  final String title;
  final VoidCallback onLogoTap;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifCount = ref.watch(unreadNotificationCountProvider).asData?.value ?? 0;
    final dmCount = ref.watch(unreadMessageCountProvider).asData?.value ?? 0;
    final l10n = AppLocalizations.of(context);
    return AppBar(
      leading: IconButton(
        key: const Key('sx-logo'),
        icon: const Icon(Icons.sports_esports, color: SxColors.primary),
        onPressed: onLogoTap,
      ),
      title: Text(title),
      actions: [
        _BellIcon(
          key: const Key('bell-notifications'),
          icon: Icons.notifications_outlined,
          count: notifCount,
          tooltip: l10n.ntfUnreadCount(notifCount),
          onPressed: () => GoRouter.of(context).push('/notifications'),
        ),
        _BellIcon(
          key: const Key('bell-messages'),
          icon: Icons.mail_outline,
          count: dmCount,
          tooltip: l10n.dmUnreadCount(dmCount),
          onPressed: () => GoRouter.of(context).push('/messages'),
        ),
        const SizedBox(width: 8),
      ],
    );
  }
}

class _BellIcon extends StatelessWidget {
  const _BellIcon({super.key, required this.icon, required this.count, required this.onPressed, this.tooltip});
  final IconData icon;
  final int count;
  final VoidCallback onPressed;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(icon: Icon(icon), tooltip: tooltip, onPressed: onPressed),
        if (count > 0)
          Positioned(
            right: 6,
            top: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(color: Colors.redAccent, borderRadius: BorderRadius.circular(8)),
              child: Text('$count', style: const TextStyle(fontSize: 10, color: Colors.white)),
            ),
          ),
      ],
    );
  }
}
