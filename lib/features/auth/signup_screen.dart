import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_providers.dart';
import '../../core/auth/auth_repository.dart';
import '../../core/l10n/gen/app_localizations.dart';

class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key, required this.onSignedUp, required this.onLogIn, this.initialRef});

  final void Function(String email) onSignedUp;
  final VoidCallback onLogIn;
  final String? initialRef;

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final _username = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  int _step = 1;
  bool _loading = false;
  String? _errorCode;

  String _errorText(AppLocalizations l10n, String code) => switch (code) {
        'invalid_email' => l10n.authErrorsInvalidEmail,
        'password_too_short' => l10n.authErrorsPasswordTooShort,
        'username_too_short' => l10n.authErrorsUsernameTooShort,
        'username_too_long' => l10n.authErrorsUsernameTooLong,
        'username_charset' => l10n.authErrorsUsernameCharset,
        'blocked_details' => l10n.authErrorsBlockedDetails,
        'username_taken' => l10n.authErrorsUsernameTaken,
        'username_taken_go_back' => l10n.authErrorsUsernameTakenGoBack,
        _ => l10n.authErrorsSignupFailed,
      };

  Future<void> _submit() async {
    setState(() { _loading = true; _errorCode = null; });
    try {
      final locale = Localizations.localeOf(context).languageCode;
      await ref.read(authRepositoryProvider).signUp(
            username: _username.text.trim(),
            email: _email.text.trim(),
            password: _password.text,
            ref: widget.initialRef,
            locale: locale,
          );
      widget.onSignedUp(_email.text.trim());
    } on AuthException catch (e) {
      setState(() => _errorCode = e.code);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(_step == 1 ? l10n.authSignupStep1Title : l10n.authSignupStep2Title)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ListView(
            children: _step == 1
                ? [
                    Text(l10n.authSignupStep1Subtitle),
                    const SizedBox(height: 16),
                    TextField(
                      key: const Key('signup-username'),
                      controller: _username,
                      decoration: InputDecoration(labelText: l10n.authCommonUsername),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      key: const Key('signup-continue-email'),
                      onPressed: () => setState(() => _step = 2),
                      child: Text(l10n.authSignupContinueWithEmail),
                    ),
                    TextButton(onPressed: widget.onLogIn, child: Text(l10n.authSignupLogIn)),
                  ]
                : [
                    Text(l10n.authSignupSigningUpAs(_username.text)),
                    const SizedBox(height: 16),
                    TextField(
                      key: const Key('signup-email'),
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(labelText: l10n.authCommonEmail),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      key: const Key('signup-password'),
                      controller: _password,
                      obscureText: true,
                      decoration: InputDecoration(labelText: l10n.authCommonPassword, helperText: l10n.authCommonAtLeast8),
                    ),
                    if (_errorCode != null) ...[
                      const SizedBox(height: 12),
                      Text(_errorText(l10n, _errorCode!), style: const TextStyle(color: Colors.redAccent)),
                    ],
                    const SizedBox(height: 16),
                    ElevatedButton(
                      key: const Key('signup-submit'),
                      onPressed: _loading ? null : _submit,
                      child: Text(_loading ? l10n.authSignupSubmitting : l10n.authSignupSubmit),
                    ),
                    TextButton(onPressed: () => setState(() => _step = 1), child: Text(l10n.authCommonBack)),
                  ],
          ),
        ),
      ),
    );
  }
}
