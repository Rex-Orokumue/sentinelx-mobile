import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_providers.dart';
import '../../core/auth/auth_repository.dart';
import '../../core/l10n/gen/app_localizations.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key, required this.onLoggedIn, required this.onForgotPassword, required this.onCreateAccount});

  final VoidCallback onLoggedIn;
  final VoidCallback onForgotPassword;
  final VoidCallback onCreateAccount;

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  String? _errorCode;
  bool _resending = false;

  String _errorText(AppLocalizations l10n, String code) => switch (code) {
        'invalid_email' => l10n.authErrorsInvalidEmail,
        'password_required' => l10n.authErrorsPasswordRequired,
        'invalid_credentials' => l10n.authErrorsInvalidCredentials,
        'email_not_confirmed' => l10n.authErrorsEmailNotConfirmed,
        _ => l10n.authErrorsSignupFailed,
      };

  Future<void> _submit() async {
    setState(() {
      _loading = true;
      _errorCode = null;
    });
    try {
      await ref.read(authRepositoryProvider).signInWithPassword(email: _email.text.trim(), password: _password.text);
      widget.onLoggedIn();
    } on AuthException catch (e) {
      setState(() => _errorCode = e.code);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resend() async {
    setState(() => _resending = true);
    try {
      await ref.read(authRepositoryProvider).resendConfirmation(_email.text.trim());
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.authLoginTitle)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ListView(
            children: [
              Text(l10n.authLoginSubtitle),
              const SizedBox(height: 24),
              TextField(
                key: const Key('login-email'),
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(labelText: l10n.authCommonEmail),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('login-password'),
                controller: _password,
                obscureText: true,
                decoration: InputDecoration(labelText: l10n.authCommonPassword),
              ),
              if (_errorCode != null) ...[
                const SizedBox(height: 12),
                Text(_errorText(l10n, _errorCode!), style: const TextStyle(color: Colors.redAccent)),
              ],
              if (_errorCode == 'email_not_confirmed') ...[
                const SizedBox(height: 8),
                TextButton(
                  key: const Key('login-resend'),
                  onPressed: _resending ? null : _resend,
                  child: Text(_resending ? l10n.authLoginResending : l10n.authLoginResend),
                ),
              ],
              const SizedBox(height: 16),
              ElevatedButton(
                key: const Key('login-submit'),
                onPressed: _loading ? null : _submit,
                child: Text(_loading ? l10n.authLoginSubmitting : l10n.authLoginSubmit),
              ),
              TextButton(onPressed: widget.onForgotPassword, child: Text(l10n.authLoginForgot)),
              TextButton(onPressed: widget.onCreateAccount, child: Text(l10n.authLoginCreateAccount)),
            ],
          ),
        ),
      ),
    );
  }
}
