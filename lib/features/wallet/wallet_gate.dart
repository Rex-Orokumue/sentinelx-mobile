import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/gen/app_localizations.dart';
import '../../core/providers.dart';

/// Wraps every `/account/wallet/**` route. A signed-out visitor gets a log-in prompt and a moderator is sent back
/// to the Account tab (staff accounts have no player wallet in the app). The API enforces the same ownership on
/// every call, so this only decides what the UI shows.
class WalletGate extends ConsumerWidget {
  const WalletGate({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final viewer = ref.watch(viewerIdProvider);
    if (viewer.isLoading && !viewer.hasValue) return const _Waiting();
    if (viewer.asData?.value == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.walletTitle)),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l10n.walletSignedOut),
              TextButton(
                key: const Key('wallet-gate-login'),
                onPressed: () => context.push('/login'),
                child: Text(l10n.accountLogIn),
              ),
            ],
          ),
        ),
      );
    }
    final me = ref.watch(meProvider);
    if (me.isLoading && !me.hasValue) return const _Waiting();
    if (ref.watch(roleProvider) == AppRole.moderator) return const _SendToAccount();
    return child;
  }
}

class _Waiting extends StatelessWidget {
  const _Waiting();

  @override
  Widget build(BuildContext context) => const Scaffold(body: Center(child: CircularProgressIndicator(key: Key('wallet-gate-loading'))));
}

class _SendToAccount extends StatefulWidget {
  const _SendToAccount();

  @override
  State<_SendToAccount> createState() => _SendToAccountState();
}

class _SendToAccountState extends State<_SendToAccount> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.go('/account');
    });
  }

  @override
  Widget build(BuildContext context) => const Scaffold(body: SizedBox.shrink());
}
