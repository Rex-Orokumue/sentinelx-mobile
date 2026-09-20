import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_providers.dart';
import '../../core/l10n/gen/app_localizations.dart';

class CheckEmailScreen extends ConsumerStatefulWidget {
  const CheckEmailScreen({super.key, required this.email, required this.onGoToLogin});

  final String email;
  final VoidCallback onGoToLogin;

  @override
  ConsumerState<CheckEmailScreen> createState() => _CheckEmailScreenState();
}

class _CheckEmailScreenState extends ConsumerState<CheckEmailScreen> {
  bool _resending = false;
  bool _sent = false;

  Future<void> _resend() async {
    setState(() => _resending = true);
    await ref.read(authRepositoryProvider).resendConfirmation(widget.email);
    if (mounted) setState(() { _resending = false; _sent = true; });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.authSignupCheckEmailTitle)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ListView(
            children: [
              Text(l10n.authSignupCheckEmailBody(widget.email)),
              const SizedBox(height: 16),
              Text(l10n.authSignupNothingYet),
              const SizedBox(height: 12),
              TextButton(
                key: const Key('check-email-resend'),
                onPressed: _resending ? null : _resend,
                child: Text(_resending ? l10n.authSignupResending : l10n.authSignupResend),
              ),
              if (_sent) Text(l10n.authNoticesResendSent),
              const SizedBox(height: 16),
              TextButton(onPressed: widget.onGoToLogin, child: Text(l10n.authCommonBackToLogin)),
            ],
          ),
        ),
      ),
    );
  }
}
