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
  String? _error;

  Future<void> _tap() async {
    setState(() { _loading = true; _error = null; });
    try {
      await ref.read(authRepositoryProvider).signInWithGoogle();
      widget.onSignedIn();
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      children: [
        OutlinedButton(
          key: const Key('google-sign-in'),
          onPressed: _loading ? null : _tap,
          child: Text(l10n.authCommonContinueWithGoogle),
        ),
        if (_error != null) Text(_error!, style: const TextStyle(color: Colors.redAccent)),
      ],
    );
  }
}
