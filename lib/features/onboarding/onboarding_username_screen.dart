import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_providers.dart';
import '../../core/auth/auth_repository.dart';
import '../../core/l10n/gen/app_localizations.dart';
import '../../core/providers.dart';

class OnboardingUsernameScreen extends ConsumerStatefulWidget {
  const OnboardingUsernameScreen({super.key, required this.onClaimed});

  final VoidCallback onClaimed;

  @override
  ConsumerState<OnboardingUsernameScreen> createState() => _OnboardingUsernameScreenState();
}

class _OnboardingUsernameScreenState extends ConsumerState<OnboardingUsernameScreen> {
  final _username = TextEditingController();
  bool _loading = false;
  String? _errorCode;

  @override
  void dispose() {
    _username.dispose();
    super.dispose();
  }

  String _errorText(AppLocalizations l10n, String code) => switch (code) {
        'username_too_short' => l10n.authErrorsUsernameTooShort,
        'username_too_long' => l10n.authErrorsUsernameTooLong,
        'username_charset' => l10n.authErrorsUsernameCharset,
        'username_taken' => l10n.authErrorsUsernameTaken,
        _ => l10n.authErrorsUsernameSaveFailed,
      };

  Future<void> _submit() async {
    setState(() { _loading = true; _errorCode = null; });
    try {
      await ref.read(authRepositoryProvider).claimUsername(_username.text.trim());
      // The router's onboarding guard reads /me; refresh it before leaving so it
      // sees the new username instead of bouncing the user straight back here.
      ref.invalidate(meProvider);
      try {
        await ref.read(meProvider.future);
      } catch (_) {
        // A failed refresh must not undo a successful claim.
      }
      if (mounted) widget.onClaimed();
    } on AuthException catch (e) {
      if (mounted) setState(() => _errorCode = e.code);
    } catch (_) {
      if (mounted) setState(() => _errorCode = 'unexpected');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.authUsernameStepTitle)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ListView(
            children: [
              Text(l10n.authUsernameStepSubtitle),
              const SizedBox(height: 16),
              TextField(
                key: const Key('onboarding-username'),
                controller: _username,
                decoration: InputDecoration(labelText: l10n.authCommonUsername),
              ),
              if (_errorCode != null) ...[
                const SizedBox(height: 12),
                Text(_errorText(l10n, _errorCode!), style: const TextStyle(color: Colors.redAccent)),
              ],
              const SizedBox(height: 16),
              ElevatedButton(
                key: const Key('onboarding-username-submit'),
                onPressed: _loading ? null : _submit,
                child: Text(_loading ? l10n.authUsernameStepSubmitting : l10n.authUsernameStepSubmit),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
