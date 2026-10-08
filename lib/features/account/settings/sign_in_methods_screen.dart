import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../../../core/api/api_client.dart';
import '../../../core/l10n/gen/app_localizations.dart';
import 'account_error_copy.dart';
import 'account_repository.dart';
import 'google_linker.dart';
import 'password_sheet.dart';

/// Settings -> Sign-in methods (`/account/sign-in-methods`).
class SignInMethodsScreen extends ConsumerStatefulWidget {
  const SignInMethodsScreen({super.key});

  @override
  ConsumerState<SignInMethodsScreen> createState() => _SignInMethodsScreenState();
}

class _SignInMethodsScreenState extends ConsumerState<SignInMethodsScreen> with WidgetsBindingObserver {
  bool _awaitingLink = false;
  String? _linkError;

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

  // Coming back from the browser round-trip (success, cancel or failure alike) refetches the account; the
  // Google row then shows whatever actually happened. A cancelled attempt leaves it "Not linked" with no
  // error, which is the intended quiet outcome.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _awaitingLink) {
      _awaitingLink = false;
      ref.invalidate(myAccountProvider);
    }
  }

  Future<void> _link() async {
    final l10n = AppLocalizations.of(context);
    setState(() => _linkError = null);
    try {
      _awaitingLink = true;
      await ref.read(googleLinkerProvider).link();
    } catch (e) {
      _awaitingLink = false;
      if (!mounted) return;
      final unavailable = e is supabase.AuthException && e.code == 'manual_linking_disabled';
      setState(() => _linkError = unavailable ? l10n.mobileSettingsLinkingUnavailable : l10n.signInMethodsLinkFailed);
    }
  }

  Future<void> _unlink() async {
    final l10n = AppLocalizations.of(context);
    final done = await askForPassword(
      context,
      title: l10n.signInMethodsUnlinkConfirm,
      passwordLabel: l10n.signInMethodsPasswordLabel,
      confirmLabel: l10n.signInMethodsUnlinkConfirm,
      cancelLabel: l10n.signInMethodsCancel,
      onSubmit: (password) async {
        try {
          await ref.read(accountRepositoryProvider).unlinkGoogle(password);
          return null;
        } catch (e) {
          return unlinkErrorCopy(l10n, e is ApiException ? e.code : 'unknown');
        }
      },
    );
    if (done) ref.invalidate(myAccountProvider);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final account = ref.watch(myAccountProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.signInMethodsTitle)),
      body: account.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(genericAccountErrorCopy(l10n, e is ApiException ? e.code : 'unknown')),
            TextButton(onPressed: () => ref.invalidate(myAccountProvider), child: Text(l10n.accountRetry)),
          ]),
        ),
        data: (a) {
          if (a == null) return Center(child: Text(l10n.ntfSignedOut));
          final google = a.signIn.google;
          // Mirrors the web: Google can only go if another way in is known to exist.
          final canUnlink = google && a.signIn.passwordIdentity;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(l10n.signInMethodsIntro),
              const SizedBox(height: 16),
              ListTile(
                title: Text(l10n.signInMethodsEmailPassword),
                subtitle: Text(a.signIn.passwordIdentity ? l10n.signInMethodsLinked : l10n.signInMethodsNotSet),
              ),
              ListTile(
                title: Text(l10n.signInMethodsGoogle),
                subtitle: Text(google ? l10n.signInMethodsLinked : l10n.signInMethodsNotLinked),
                trailing: google
                    ? (canUnlink
                        ? TextButton(key: const Key('signin-unlink-google'), onPressed: _unlink, child: Text(l10n.signInMethodsUnlink))
                        : null)
                    : FilledButton(key: const Key('signin-link-google'), onPressed: _link, child: Text(l10n.signInMethodsLink)),
              ),
              if (google && !canUnlink) Text(l10n.signInMethodsOnlyMethod),
              if (google && canUnlink) ...[
                const SizedBox(height: 8),
                Text(l10n.signInMethodsUnlinkExplain, style: Theme.of(context).textTheme.bodySmall),
              ],
              if (_linkError != null) ...[
                const SizedBox(height: 8),
                Text(_linkError!, key: const Key('signin-link-error'), style: const TextStyle(color: Colors.redAccent)),
              ],
            ],
          );
        },
      ),
    );
  }
}
