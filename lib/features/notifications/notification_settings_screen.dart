import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_client.dart';
import '../../core/api/notifications_models.dart';
import '../../core/l10n/gen/app_localizations.dart';
import '../../core/theme/sx_colors.dart';
import 'notification_prefs_providers.dart';
import 'notifications_providers.dart';
import 'notifications_repository.dart';
import 'pref_labels.dart';
import 'push_permission_row.dart';

/// Settings → Notifications (`/account/notifications`): the same 17 push, 6 WhatsApp and 5
/// achievement-sharing preferences the website edits, plus a test notification and the permission row.
class NotificationSettingsScreen extends ConsumerStatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  ConsumerState<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends ConsumerState<NotificationSettingsScreen> {
  bool _testing = false;

  void _say(ScaffoldMessengerState messenger, String text) {
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _toggle(PrefSection section, String key, bool value) async {
    // Resolved before the await: the notifier, messenger and copy of a possibly disposed widget.
    final notifier = ref.read(notificationPrefsProvider.notifier);
    final messenger = ScaffoldMessenger.of(context);
    final failed = AppLocalizations.of(context).ntfSaveFailed;
    if (!await notifier.set(section, key, value)) _say(messenger, failed);
  }

  Future<void> _sendTest() async {
    final repo = ref.read(notificationsRepositoryProvider);
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    setState(() => _testing = true);
    String message;
    try {
      await repo.sendTestPush();
      message = l10n.ntfTestSent;
    } on ApiException catch (e) {
      message = e.code == 'not_found' ? l10n.ntfTestNoDevice : l10n.ntfTestFailed;
    } catch (_) {
      message = l10n.ntfTestFailed;
    }
    if (mounted) setState(() => _testing = false);
    _say(messenger, message);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final viewer = ref.watch(notificationsViewerIdProvider);
    final prefs = ref.watch(notificationPrefsProvider);

    Widget body;
    if (viewer.hasValue && viewer.value == null) {
      body = _centered([
        Text(l10n.ntfSignedOut, textAlign: TextAlign.center),
        const SizedBox(height: 12),
        FilledButton(key: const Key('ntf-login'), onPressed: () => context.push('/login'), child: Text(l10n.ntfLogIn)),
      ]);
    } else if (prefs.hasError && !prefs.hasValue) {
      body = _centered([
        Text(l10n.ntfLoadError, textAlign: TextAlign.center),
        const SizedBox(height: 12),
        OutlinedButton(key: const Key('ntf-retry'), onPressed: () => ref.invalidate(notificationPrefsProvider), child: Text(l10n.ntfRetry)),
      ]);
    } else if (prefs.asData?.value == null) {
      body = const Center(child: CircularProgressIndicator());
    } else {
      body = _form(l10n, prefs.asData!.value!);
    }
    return Scaffold(appBar: AppBar(title: Text(l10n.ntfSettingsTitle)), body: body);
  }

  Widget _centered(List<Widget> children) => Center(
        child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: children)),
      );

  Widget _section(String title, List<Widget> tiles) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
            child: Text(title, style: const TextStyle(color: SxColors.accentText, fontWeight: FontWeight.w700)),
          ),
          ...tiles,
        ],
      );

  Widget _switch(String keyPrefix, String key, String label, bool value, PrefSection section) => SwitchListTile(
        key: Key('$keyPrefix-$key'),
        title: Text(label),
        value: value,
        onChanged: (v) => _toggle(section, key, v),
      );

  Widget _form(AppLocalizations l10n, NotificationPrefs p) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PushPermissionRow(showWhenOn: true),
          _section(l10n.ntfSectionPush, [
            for (final k in kPushPrefKeys) _switch('ntf-push', k, pushPrefLabel(l10n, k), p.push[k] ?? true, PrefSection.push),
          ]),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: OutlinedButton.icon(
              key: const Key('ntf-test-push'),
              onPressed: _testing ? null : _sendTest,
              icon: const Icon(Icons.send_outlined),
              label: Text(l10n.ntfTestAction),
            ),
          ),
          _section(l10n.ntfSectionWhatsapp, [
            for (final k in kWhatsappPrefKeys) _switch('ntf-wa', k, whatsappPrefLabel(l10n, k), p.whatsapp[k] ?? false, PrefSection.whatsapp),
          ]),
          _section(l10n.ntfSectionSharing, [
            for (final k in kSharingPrefKeys) _switch('ntf-share', k, sharingPrefLabel(l10n, k), p.achievementSharing[k] ?? false, PrefSection.achievementSharing),
          ]),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
