import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_providers.dart';
import '../../core/l10n/gen/app_localizations.dart';

class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({super.key, required this.onDone});

  final VoidCallback onDone;

  @override
  ConsumerState<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final _password = TextEditingController();
  bool _loading = false;

  Future<void> _submit() async {
    setState(() => _loading = true);
    try {
      await ref.read(authRepositoryProvider).resetPassword(_password.text);
      widget.onDone();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.authResetTitle)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ListView(
            children: [
              Text(l10n.authResetSubtitle),
              const SizedBox(height: 24),
              TextField(
                key: const Key('reset-password'),
                controller: _password,
                obscureText: true,
                decoration: InputDecoration(labelText: l10n.authResetNewPassword, helperText: l10n.authCommonAtLeast8),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                key: const Key('reset-submit'),
                onPressed: _loading ? null : _submit,
                child: Text(_loading ? l10n.authResetSubmitting : l10n.authResetSubmit),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
