import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_providers.dart';
import '../../core/l10n/gen/app_localizations.dart';
import '../../core/providers.dart';
import '../../shared/widgets/sx_tab_app_bar.dart';

class AccountScreen extends ConsumerStatefulWidget {
  const AccountScreen({super.key, required this.onLogIn, required this.onSignUp, required this.onLogoTap});

  final VoidCallback onLogIn;
  final VoidCallback onSignUp;
  final VoidCallback onLogoTap;

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
      await ref.read(authRepositoryProvider).signOut();
    } catch (_) {
      if (mounted) setState(() => _signOutFailed = true);
    } finally {
      if (mounted) setState(() => _signingOut = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final me = ref.watch(meProvider).asData?.value;
    return Scaffold(
      appBar: SxTabAppBar(title: l10n.accountTitle, onLogoTap: widget.onLogoTap),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Center(
          child: me == null
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
    );
  }
}
