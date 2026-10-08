import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/gen/app_localizations.dart';
import '../account/settings/phone_verify_form.dart';

/// The gate version of phone verification (`/onboarding/phone`), shown when `enforcePhoneVerification` is on
/// and the player's phone is not verified. Same form as Settings; no back button and no skip, because the
/// router redirects every other route here until it succeeds (the redirect then sends a verified user home).
class OnboardingPhoneScreen extends StatelessWidget {
  const OnboardingPhoneScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: AppBar(automaticallyImplyLeading: false, title: Text(l10n.authPhoneStepTitle)),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l10n.authPhoneStepSubtitle),
              const SizedBox(height: 16),
              // meProvider is refreshed by the form; the router's gate listener then redirects to '/'.
              PhoneVerifyForm(onVerified: () => context.go('/')),
            ],
          ),
        ),
      ),
    );
  }
}
