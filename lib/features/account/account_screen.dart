import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_providers.dart';
import '../../core/providers.dart';
import '../../shared/widgets/sx_tab_app_bar.dart';

class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key, required this.onLogIn, required this.onSignUp, required this.onLogoTap});

  final VoidCallback onLogIn;
  final VoidCallback onSignUp;
  final VoidCallback onLogoTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(meProvider).asData?.value;
    return Scaffold(
      appBar: SxTabAppBar(title: 'Account', onLogoTap: onLogoTap),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Center(
          child: me == null
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ElevatedButton(key: const Key('account-login'), onPressed: onLogIn, child: const Text('Log in')),
                    TextButton(key: const Key('account-signup'), onPressed: onSignUp, child: const Text('Create account')),
                  ],
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(me.profile?.displayName ?? me.profile?.username ?? me.email ?? ''),
                    TextButton(
                      key: const Key('account-sign-out'),
                      onPressed: () => ref.read(authRepositoryProvider).signOut(),
                      child: const Text('Sign out'),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
