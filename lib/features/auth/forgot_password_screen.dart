import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_providers.dart';
import '../../core/l10n/gen/app_localizations.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _email = TextEditingController();
  bool _loading = false;
  bool _sent = false;
  bool _error = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _loading = true;
      _sent = false;
      _error = false;
    });
    try {
      await ref.read(authRepositoryProvider).requestReset(_email.text.trim());
      if (mounted) setState(() => _sent = true);
    } catch (_) {
      if (mounted) setState(() => _error = true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.authForgotTitle)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ListView(
            children: [
              Text(l10n.authForgotSubtitle),
              const SizedBox(height: 24),
              TextField(
                key: const Key('forgot-email'),
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(labelText: l10n.authCommonEmail),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                key: const Key('forgot-submit'),
                onPressed: _loading ? null : _submit,
                child: Text(_loading ? l10n.authForgotSubmitting : l10n.authForgotSubmit),
              ),
              if (_sent) ...[
                const SizedBox(height: 16),
                Text(l10n.authNoticesResetSent),
              ],
              if (_error) ...[
                const SizedBox(height: 16),
                Text(l10n.authErrorsForgotFailed, style: const TextStyle(color: Colors.redAccent)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
