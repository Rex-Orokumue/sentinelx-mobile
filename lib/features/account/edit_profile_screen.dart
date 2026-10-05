import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/api/compete_models.dart';
import '../../core/api/models.dart';
import '../../core/l10n/gen/app_localizations.dart';
import '../../core/providers.dart';
import '../compete/error_copy.dart';
import '../compete/compete_providers.dart';
import '../compete/registration_sheet.dart' show RegistrationValidators;
import 'country_field.dart';
import 'game_interests_field.dart';
import 'profile_providers.dart';

class EditProfileScreen extends ConsumerWidget {
  const EditProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final me = ref.watch(meProvider).asData?.value;
    final bio = ref.watch(ownBioProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.cmpEditProfile)),
      // Signed out (or /me still loading): no form. The route is only linked when signed in.
      body: me == null
          ? const SizedBox.shrink()
          : bio.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              // Saving without knowing the current bio would erase it, so no form until it loads.
              error: (_, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(l10n.cmpLoadError, textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      OutlinedButton(
                        onPressed: () => ref.invalidate(ownBioProvider),
                        child: Text(l10n.cmpRetry),
                      ),
                    ],
                  ),
                ),
              ),
              data: (b) => _EditForm(me: me, bio: b),
            ),
    );
  }
}

class _EditForm extends ConsumerStatefulWidget {
  const _EditForm({required this.me, required this.bio});
  final MeResponse me;
  final String bio;

  @override
  ConsumerState<_EditForm> createState() => _EditFormState();
}

class _EditFormState extends ConsumerState<_EditForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _username;
  late final TextEditingController _whatsapp;
  String? _country;
  late Set<String> _gameInterests;
  late bool _consentWhatsappUpdates;
  late final TextEditingController _bio;
  late final String _originalUsername;
  bool _saving = false;
  String? _errorCode;
  Map<String, String> _serverFields = const {};

  @override
  void initState() {
    super.initState();
    final p = widget.me.profile;
    _originalUsername = p?.username ?? '';
    _name = TextEditingController(text: p?.displayName ?? '');
    _username = TextEditingController(text: _originalUsername);
    _whatsapp = TextEditingController(text: p?.whatsappNumber ?? '');
    _country = p?.country;
    _gameInterests = {...?p?.gameInterests};
    _consentWhatsappUpdates = p?.consentWhatsappUpdates ?? false;
    _bio = TextEditingController(text: widget.bio);
  }

  @override
  void dispose() {
    _name.dispose();
    _username.dispose();
    _whatsapp.dispose();
    _bio.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    if (_gameInterests.isEmpty) {
      setState(() => _serverFields = const {'gameInterests': 'required'});
      return;
    }
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final username = _username.text.trim();
    setState(() {
      _saving = true;
      _errorCode = null;
      _serverFields = const {};
    });
    try {
      await ref.read(profileEditorProvider)(
        ProfileEdit(
          displayName: _name.text.trim(),
          // The server treats '' as "no username change"; the one-time change is enforced there.
          username: username == _originalUsername ? '' : username,
          whatsapp: _whatsapp.text.trim(),
          country: _country?.trim() ?? '',
          bio: _bio.text.trim(),
          gameInterests: _gameInterests.toList(),
          consentWhatsappUpdates: _consentWhatsappUpdates,
        ),
      );
      if (!mounted) return;
      ref.invalidate(meProvider);
      ref.invalidate(ownBioProvider);
      messenger.showSnackBar(SnackBar(content: Text(l10n.cmpSaved)));
      if (navigator.canPop()) navigator.pop();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorCode = e is ApiException
            ? (e.isUnauthorized ? 'unauthorized' : e.code)
            : 'network';
        _serverFields = e is ApiException ? e.fields : const {};
      });
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final games = ref.watch(gamesProvider);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              key: const Key('profile-display-name'),
              controller: _name,
              enabled: !_saving,
              decoration: InputDecoration(labelText: l10n.cmpFieldDisplayName),
              validator: (v) => RegistrationValidators.displayName(v ?? '')
                  ? null
                  : l10n.cmpValDisplayName,
            ),
            TextFormField(
              key: const Key('profile-username'),
              controller: _username,
              enabled: !_saving,
              decoration: InputDecoration(
                labelText: l10n.cmpFieldUsername,
                errorText: _serverFields.containsKey('username')
                    ? l10n.cmpValUsername
                    : null,
              ),
            ),
            TextFormField(
              key: const Key('profile-whatsapp'),
              controller: _whatsapp,
              enabled: !_saving,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: l10n.cmpFieldWhatsapp,
                errorText: _serverFields.containsKey('whatsapp')
                    ? l10n.profileWhatsappInvalid
                    : null,
              ),
              validator: (v) {
                final t = (v ?? '').trim();
                return t.isEmpty || RegistrationValidators.whatsapp(t)
                    ? null
                    : l10n.cmpValWhatsapp;
              },
            ),
            CountryField(
              key: const Key('profile-country'),
              label: l10n.profileCountryLabel,
              placeholder: l10n.profileCountryPlaceholder,
              value: _country,
              enabled: !_saving,
              errorText: _serverFields.containsKey('country')
                  ? l10n.profileCountryInvalid
                  : null,
              onChanged: (value) => setState(() => _country = value),
            ),
            const SizedBox(height: 16),
            GameInterestsField(
              label: l10n.profileGamesLabel,
              games: games,
              selectedIds: _gameInterests,
              enabled: !_saving,
              errorText: _serverFields.containsKey('gameInterests')
                  ? l10n.profileGamesRequired
                  : null,
              loadingText: l10n.profileGamesLoading,
              retryText: l10n.profileGamesRetry,
              onRetry: () => ref.invalidate(gamesProvider),
              onChanged: (ids) => setState(() {
                _gameInterests = ids;
                _serverFields = {..._serverFields}..remove('gameInterests');
              }),
            ),
            SwitchListTile(
              key: const Key('profile-consent-whatsapp'),
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.profileConsentLabel),
              value: _consentWhatsappUpdates,
              onChanged: _saving
                  ? null
                  : (value) => setState(() => _consentWhatsappUpdates = value),
            ),
            TextFormField(
              key: const Key('profile-bio'),
              controller: _bio,
              enabled: !_saving,
              maxLines: 4,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: l10n.cmpFieldBio,
                counterText: '${_bio.text.length}/280',
              ),
              validator: (v) =>
                  (v ?? '').trim().length <= 280 ? null : l10n.cmpValBio,
            ),
            const SizedBox(height: 16),
            FilledButton(
              key: const Key('profile-save'),
              onPressed: _saving ? null : _save,
              child: Text(_saving ? l10n.cmpSubmitting : l10n.cmpSave),
            ),
            if (_errorCode != null &&
                !(_errorCode == 'validation_failed' &&
                    _serverFields.keys.any(
                      const {
                        'username',
                        'whatsapp',
                        'country',
                        'gameInterests',
                      }.contains,
                    )))
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  errorCopy(l10n, _errorCode!),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
