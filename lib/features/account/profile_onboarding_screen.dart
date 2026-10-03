import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/api/profile_onboarding_models.dart';
import '../../core/l10n/gen/app_localizations.dart';
import '../../core/providers.dart';
import '../compete/compete_providers.dart';
import 'country_field.dart';
import 'game_interests_field.dart';
import 'profile_onboarding_providers.dart';

class ProfileOnboardingScreen extends ConsumerStatefulWidget {
  const ProfileOnboardingScreen({
    super.key,
    required this.onCompleted,
    required this.onUnauthorized,
  });

  final VoidCallback onCompleted;
  final VoidCallback onUnauthorized;

  @override
  ConsumerState<ProfileOnboardingScreen> createState() =>
      _ProfileOnboardingScreenState();
}

class _ProfileOnboardingScreenState
    extends ConsumerState<ProfileOnboardingScreen> {
  late final TextEditingController _whatsapp;
  String? _country;
  late Set<String> _gameIds;
  bool? _consent;
  bool _saving = false;
  bool _submitted = false;
  String? _genericError;
  Map<String, String> _serverFields = const {};

  @override
  void initState() {
    super.initState();
    final profile = ref.read(meProvider).asData?.value?.profile;
    _country = profile?.country;
    _whatsapp = TextEditingController(text: profile?.whatsappNumber ?? '');
    _gameIds = {...?profile?.gameInterests};
    _consent = profile?.consentWhatsappUpdates;
  }

  @override
  void dispose() {
    _whatsapp.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_saving) return;
    setState(() {
      _submitted = true;
      _genericError = null;
      _serverFields = const {};
    });
    if ((_country ?? '').isEmpty ||
        _whatsapp.text.trim().isEmpty ||
        _gameIds.isEmpty ||
        _consent == null ||
        !ref.read(gamesProvider).hasValue) {
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(profileOnboardingSubmitterProvider)(
        ProfileOnboardingInput(
          country: _country!,
          whatsapp: _whatsapp.text.trim(),
          consentWhatsappUpdates: _consent!,
          gameInterests: _gameIds.toList(),
        ),
      );
      if (!mounted) return;
      ref.invalidate(meProvider);
      try {
        await ref.read(meProvider.future);
      } catch (_) {
        // A failed refresh must not undo a successful profile submission.
      }
      if (mounted) widget.onCompleted();
    } catch (error) {
      if (!mounted) return;
      if (error is ApiException && error.isUnauthorized) {
        widget.onUnauthorized();
        return;
      }
      setState(() {
        _serverFields = error is ApiException ? error.fields : const {};
        if (_serverFields.isEmpty) {
          _genericError = AppLocalizations.of(context).profileSaveFailed;
        }
      });
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final games = ref.watch(gamesProvider);
    final countryError = _serverFields.containsKey('country')
        ? l10n.profileCountryInvalid
        : _submitted && (_country ?? '').isEmpty
        ? l10n.profileCountryRequired
        : null;
    final whatsappError = _serverFields.containsKey('whatsapp')
        ? l10n.profileWhatsappInvalid
        : _submitted && _whatsapp.text.trim().isEmpty
        ? l10n.profileWhatsappRequired
        : null;
    final gamesError = _serverFields.containsKey('gameInterests')
        ? l10n.profileGameUnavailable
        : _submitted && _gameIds.isEmpty
        ? l10n.profileGamesRequired
        : null;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.authProfileStepTitle,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              Text(l10n.authProfileStepSubtitle),
              const SizedBox(height: 24),
              CountryField(
                label: l10n.profileCountryLabel,
                placeholder: l10n.profileCountryPlaceholder,
                value: _country,
                enabled: !_saving,
                errorText: countryError,
                onChanged: (value) => setState(() => _country = value),
              ),
              const SizedBox(height: 16),
              TextField(
                key: const Key('profile-onboarding-whatsapp'),
                controller: _whatsapp,
                enabled: !_saving,
                keyboardType: TextInputType.phone,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: l10n.profileWhatsappLabel,
                  hintText: l10n.profileWhatsappHint,
                  errorText: whatsappError,
                ),
              ),
              const SizedBox(height: 16),
              GameInterestsField(
                label: l10n.profileGamesLabel,
                games: games,
                selectedIds: _gameIds,
                enabled: !_saving,
                errorText: gamesError,
                loadingText: l10n.profileGamesLoading,
                retryText: l10n.profileGamesRetry,
                onRetry: () => ref.invalidate(gamesProvider),
                onChanged: (ids) => setState(() => _gameIds = ids),
              ),
              const SizedBox(height: 16),
              Text(l10n.profileConsentLabel),
              RadioGroup<bool>(
                groupValue: _consent,
                onChanged: _saving
                    ? (_) {}
                    : (value) => setState(() => _consent = value),
                child: Row(
                  children: [
                    Expanded(
                      child: RadioListTile<bool>(
                        key: const Key('profile-consent-yes'),
                        title: Text(l10n.profileConsentYes),
                        value: true,
                        enabled: !_saving,
                      ),
                    ),
                    Expanded(
                      child: RadioListTile<bool>(
                        key: const Key('profile-consent-no'),
                        title: Text(l10n.profileConsentNo),
                        value: false,
                        enabled: !_saving,
                      ),
                    ),
                  ],
                ),
              ),
              if ((_submitted && _consent == null) ||
                  _serverFields.containsKey('consentWhatsappUpdates'))
                Text(
                  l10n.profileConsentRequired,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              const SizedBox(height: 16),
              FilledButton(
                key: const Key('profile-onboarding-submit'),
                onPressed: _saving || games.isLoading || games.hasError
                    ? null
                    : _submit,
                child: Text(
                  _saving ? l10n.profileSaving : l10n.profileContinue,
                ),
              ),
              if (_genericError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    _genericError!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
