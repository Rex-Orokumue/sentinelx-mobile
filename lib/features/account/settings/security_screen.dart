import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/auth/auth_providers.dart';
import '../../../core/l10n/gen/app_localizations.dart';
import 'account_error_copy.dart';
import 'account_repository.dart';

/// Settings -> Security (`/account/security`): change email (needs the current password; nothing changes
/// until the link in the new inbox is opened) and password reset (the link goes to the current inbox, which
/// proves ownership - there is no "set password" endpoint on purpose).
class SecurityScreen extends ConsumerStatefulWidget {
  const SecurityScreen({super.key});

  @override
  ConsumerState<SecurityScreen> createState() => _SecurityScreenState();
}

class _SecurityScreenState extends ConsumerState<SecurityScreen> {
  String? _sentTo;
  bool _resetBusy = false;
  String? _resetMessage;

  Future<void> _resetPassword(String email) async {
    final l10n = AppLocalizations.of(context);
    setState(() {
      _resetBusy = true;
      _resetMessage = null;
    });
    String message;
    try {
      await ref.read(authRepositoryProvider).requestReset(email);
      message = l10n.mobileSettingsSecurityResetSent;
    } catch (e) {
      message = genericAccountErrorCopy(l10n, e is ApiException ? e.code : 'unknown');
    }
    if (!mounted) return;
    setState(() {
      _resetBusy = false;
      _resetMessage = message;
    });
  }

  Future<void> _changeEmail() async {
    final sent = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _ChangeEmailSheet(),
    );
    if (sent != null && mounted) {
      setState(() => _sentTo = sent);
      ref.invalidate(myAccountProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final account = ref.watch(myAccountProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.mobileSettingsSecurityTitle)),
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
          final email = a.signIn.email;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(l10n.mobileSettingsSecurityEmailRow, style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 4),
              Text(email ?? ''),
              if (a.signIn.pendingEmail != null) ...[
                const SizedBox(height: 8),
                Text(l10n.emailChangePending(a.signIn.pendingEmail!)),
                Text(l10n.emailChangePendingHint, style: Theme.of(context).textTheme.bodySmall),
              ],
              if (_sentTo != null) ...[
                const SizedBox(height: 8),
                Text(l10n.emailChangeSent(_sentTo!), key: const Key('security-sent')),
                Text(l10n.emailChangeSentSpam, style: Theme.of(context).textTheme.bodySmall),
              ],
              const SizedBox(height: 8),
              OutlinedButton(
                key: const Key('security-change-email'),
                onPressed: _changeEmail,
                child: Text(l10n.mobileSettingsSecurityChangeEmail),
              ),
              const Divider(height: 32),
              Text(l10n.mobileSettingsSecurityPasswordRow, style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 4),
              Text(l10n.mobileSettingsSecuritySetPasswordHint, style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 8),
              OutlinedButton(
                key: const Key('security-reset-password'),
                onPressed: (_resetBusy || email == null) ? null : () => _resetPassword(email),
                child: Text(l10n.mobileSettingsSecuritySetPassword),
              ),
              if (_resetMessage != null) ...[
                const SizedBox(height: 8),
                Text(_resetMessage!, key: const Key('security-reset-message')),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _ChangeEmailSheet extends ConsumerStatefulWidget {
  const _ChangeEmailSheet();

  @override
  ConsumerState<_ChangeEmailSheet> createState() => _ChangeEmailSheetState();
}

class _ChangeEmailSheetState extends ConsumerState<_ChangeEmailSheet> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    final email = _email.text.trim();
    if (email.isEmpty || _password.text.isEmpty || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final sentTo = await ref.read(accountRepositoryProvider).changeEmail(email: email, password: _password.text);
      if (mounted) Navigator.of(context).pop(sentTo);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = emailChangeErrorCopy(l10n, e is ApiException ? e.code : 'unknown');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.emailChangeTitle, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            TextField(
              key: const Key('security-new-email'),
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              decoration: InputDecoration(labelText: l10n.emailChangeNewLabel),
            ),
            const SizedBox(height: 8),
            TextField(
              key: const Key('security-password'),
              controller: _password,
              obscureText: true,
              decoration: InputDecoration(labelText: l10n.emailChangePasswordLabel, helperText: l10n.emailChangePasswordHint, helperMaxLines: 4),
              onSubmitted: (_) => _submit(),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, key: const Key('security-error'), style: const TextStyle(color: Colors.redAccent)),
            ],
            const SizedBox(height: 12),
            // A Wrap, not a Row: translated labels ("Envoyer le lien de confirmation") are long and a Row
            // overflows on a narrow phone.
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              runSpacing: 8,
              children: [
                TextButton(onPressed: _busy ? null : () => Navigator.of(context).pop(), child: Text(l10n.emailChangeCancel)),
                FilledButton(
                  key: const Key('security-submit'),
                  onPressed: _busy ? null : _submit,
                  child: Text(_busy ? l10n.emailChangeSending : l10n.emailChangeSubmit),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
