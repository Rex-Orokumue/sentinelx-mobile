import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_providers.dart';
import '../../core/l10n/gen/app_localizations.dart';
import '../../core/notifications/push/push_registration.dart';
import '../../core/providers.dart';
import '../../shared/widgets/sx_tab_app_bar.dart';

class AccountScreen extends ConsumerStatefulWidget {
  const AccountScreen({
    super.key,
    required this.onLogIn,
    required this.onSignUp,
    required this.onLogoTap,
    this.onEditProfile,
    this.onOpenProgress,
    this.onOpenNotifications,
  });

  final VoidCallback onLogIn;
  final VoidCallback onSignUp;
  final VoidCallback onLogoTap;
  final VoidCallback? onEditProfile;
  final VoidCallback? onOpenProgress;
  final VoidCallback? onOpenNotifications;

  @override
  ConsumerState<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends ConsumerState<AccountScreen> {
  bool _signingOut = false;
  bool _signOutFailed = false;

  Future<void> _signOut() async {
    setState(() {
      _signingOut = true;
      _signOutFailed = false;
    });
    try {
      // Stop pushes to this phone before the session goes. Best-effort: push trouble must never block
      // signing out, so any failure (including push being unavailable) is swallowed.
      try {
        await ref.read(pushRegistrationProvider).unregister();
      } catch (_) {}
      await ref.read(authRepositoryProvider).signOut();
    } catch (_) {
      // Still signed in: put the device registration back.
      try {
        await ref.read(pushRegistrationProvider).reregister();
      } catch (_) {}
      if (mounted) setState(() => _signOutFailed = true);
    } finally {
      if (mounted) setState(() => _signingOut = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final me = ref.watch(meProvider);
    return Scaffold(
      appBar: SxTabAppBar(title: l10n.accountTitle, onLogoTap: widget.onLogoTap),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Center(
          child: me.when(
            loading: () => const CircularProgressIndicator(key: Key('account-loading')),
            error: (_, _) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(l10n.accountLoadFailed, textAlign: TextAlign.center),
                const SizedBox(height: 12),
                ElevatedButton(
                  key: const Key('account-retry'),
                  onPressed: () => ref.invalidate(meProvider),
                  child: Text(l10n.accountRetry),
                ),
              ],
            ),
            data: (me) => me == null
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ElevatedButton(key: const Key('account-login'), onPressed: widget.onLogIn, child: Text(l10n.accountLogIn)),
                      TextButton(key: const Key('account-signup'), onPressed: widget.onSignUp, child: Text(l10n.accountCreateAccount)),
                    ],
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(me.profile?.displayName ?? me.profile?.username ?? me.email ?? ''),
                      if (widget.onEditProfile != null)
                        TextButton(
                          key: const Key('account-edit-profile'),
                          onPressed: widget.onEditProfile,
                          child: Text(l10n.cmpAccountEditProfile),
                        ),
                      if (widget.onOpenProgress != null)
                        ListTile(
                          key: const Key('account-progress'),
                          title: Text(l10n.accountMyProgress),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: widget.onOpenProgress,
                        ),
                      if (widget.onOpenNotifications != null)
                        ListTile(
                          key: const Key('account-notifications'),
                          title: Text(l10n.ntfSettingsEntry),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: widget.onOpenNotifications,
                        ),
                      TextButton(
                        key: const Key('account-sign-out'),
                        onPressed: _signingOut ? null : _signOut,
                        child: Text(_signingOut ? l10n.accountSigningOut : l10n.accountSignOut),
                      ),
                      if (_signOutFailed) ...[
                        const SizedBox(height: 8),
                        Text(l10n.accountSignOutFailed, style: const TextStyle(color: Colors.redAccent)),
                      ],
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
