import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/gen/app_localizations.dart';
import '../../core/notifications/push/push_gateway.dart';
import '../../core/notifications/push/push_models.dart';
import '../../core/notifications/push/push_permission.dart';
import '../../core/theme/sx_colors.dart';

/// The passive permission entry point shared by the bell's empty state and Settings → Notifications.
/// Hidden when push is unavailable; hidden when authorized unless [showWhenOn] (settings shows a "on"
/// confirmation). Re-reads the OS status whenever the app resumes, so coming back from system settings
/// with notifications now enabled updates the row.
class PushPermissionRow extends ConsumerStatefulWidget {
  const PushPermissionRow({super.key, this.showWhenOn = false});

  final bool showWhenOn;

  @override
  ConsumerState<PushPermissionRow> createState() => _PushPermissionRowState();
}

class _PushPermissionRowState extends ConsumerState<PushPermissionRow> with WidgetsBindingObserver {
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) ref.invalidate(pushPermissionProvider);
  }

  Future<void> _enable() async {
    final prompter = ref.read(pushPermissionPrompterProvider);
    setState(() => _busy = true);
    try {
      await prompter.enableFromUser();
    } catch (_) {
      // a permission problem is not worth an error here; the row simply stays
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        ref.invalidate(pushPermissionProvider);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!ref.watch(pushGatewayProvider).isAvailable) return const SizedBox.shrink();
    final status = ref.watch(pushPermissionProvider).asData?.value;
    if (status == null) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);

    if (status == PushPermission.authorized) {
      if (!widget.showWhenOn) return const SizedBox.shrink();
      return ListTile(
        key: const Key('ntf-perm-row'),
        leading: const Icon(Icons.check_circle_outline, color: SxColors.success),
        title: Text(l10n.ntfPermOn),
      );
    }

    final blocked = status == PushPermission.deniedPermanently;
    return Card(
      key: const Key('ntf-perm-row'),
      color: SxColors.surface,
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.notifications_off_outlined, color: SxColors.accentText),
              const SizedBox(width: 8),
              Expanded(child: Text(l10n.ntfPermTitle, style: const TextStyle(fontWeight: FontWeight.w700))),
            ]),
            const SizedBox(height: 6),
            Text(blocked ? l10n.ntfPermBlocked : l10n.ntfPermBody, style: const TextStyle(color: SxColors.textSecondary)),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                key: Key(blocked ? 'ntf-perm-settings' : 'ntf-perm-enable'),
                onPressed: _busy ? null : _enable,
                child: Text(blocked ? l10n.ntfPermOpenSettings : l10n.ntfPermEnable),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
