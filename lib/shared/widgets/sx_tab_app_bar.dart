import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/notifications/unread_counts.dart';
import '../../core/theme/sx_colors.dart';
import 'coming_soon_screen.dart';

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
    return AppBar(
      leading: IconButton(
        key: const Key('sx-logo'),
        icon: const Icon(Icons.sports_esports, color: SxColors.primary),
        onPressed: onLogoTap,
      ),
      title: Text(title),
      actions: [
        _BellIcon(key: const Key('bell-notifications'), icon: Icons.notifications_outlined, count: notifCount),
        _BellIcon(key: const Key('bell-messages'), icon: Icons.mail_outline, count: dmCount),
        const SizedBox(width: 8),
      ],
    );
  }
}

class _BellIcon extends StatelessWidget {
  const _BellIcon({super.key, required this.icon, required this.count});
  final IconData icon;
  final int count;

  // Both bells route through the coming-soon pattern until Phase 5 builds
  // the real drawer/inbox (spec §4.5) — one deferred-feature UI, not two.
  // Pushed imperatively (not via go_router) since this is a one-off overlay,
  // not a shell/tab destination — go_router has no named-route table to
  // resolve a bare Navigator.pushNamed against.
  void _openComingSoon(BuildContext context) {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => ComingSoonScreen(title: 'Coming soon', onLogoTap: () => Navigator.of(context).pop()),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(icon: Icon(icon), onPressed: () => _openComingSoon(context)),
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
