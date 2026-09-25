import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_providers.dart';
import '../../core/auth/auth_repository.dart';
import '../../core/l10n/gen/app_localizations.dart';

class GoogleSignInButton extends ConsumerStatefulWidget {
  const GoogleSignInButton({super.key, required this.onSignedIn});

  final VoidCallback onSignedIn;

  @override
  ConsumerState<GoogleSignInButton> createState() => _GoogleSignInButtonState();
}

class _GoogleSignInButtonState extends ConsumerState<GoogleSignInButton> {
  bool _loading = false;
  String? _errorCode;

  // null = show nothing (the user backed out of the account picker).
  String? _errorText(AppLocalizations l10n, String code) => switch (code) {
        'google_canceled' => null,
        'google_not_configured' => l10n.authErrorsGoogleNotConfigured,
        _ => l10n.authErrorsGoogleFailed,
      };

  Future<void> _tap() async {
    setState(() { _loading = true; _errorCode = null; });
    try {
      await ref.read(authRepositoryProvider).signInWithGoogle();
      if (mounted) widget.onSignedIn();
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
    final message = _errorCode == null ? null : _errorText(l10n, _errorCode!);
    return Column(
      children: [
        OutlinedButton(
          key: const Key('google-sign-in'),
          onPressed: _loading ? null : _tap,
          child: Text(l10n.authCommonContinueWithGoogle),
        ),
        if (message != null) Text(message, style: const TextStyle(color: Colors.redAccent)),
      ],
    );
  }
}
