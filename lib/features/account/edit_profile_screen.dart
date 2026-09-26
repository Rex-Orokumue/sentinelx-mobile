import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/api/compete_models.dart';
import '../../core/api/models.dart';
import '../../core/l10n/gen/app_localizations.dart';
import '../../core/providers.dart';
import '../compete/error_copy.dart';
import '../compete/registration_sheet.dart' show RegistrationValidators;
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
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text(l10n.cmpLoadError, textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    OutlinedButton(onPressed: () => ref.invalidate(ownBioProvider), child: Text(l10n.cmpRetry)),
                  ]),
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
  late final TextEditingController _country;
  late final TextEditingController _bio;
  late final String _originalUsername;
  bool _saving = false;
  String? _errorCode;

  @override
  void initState() {
    super.initState();
    final p = widget.me.profile;
    _originalUsername = p?.username ?? '';
    _name = TextEditingController(text: p?.displayName ?? '');
    _username = TextEditingController(text: _originalUsername);
    _whatsapp = TextEditingController(text: p?.whatsappNumber ?? '');
    _country = TextEditingController(text: p?.country ?? '');
    _bio = TextEditingController(text: widget.bio);
  }

  @override
  void dispose() {
    _name.dispose();
    _username.dispose();
    _whatsapp.dispose();
    _country.dispose();
    _bio.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final username = _username.text.trim();
    setState(() {
      _saving = true;
      _errorCode = null;
    });
    try {
      await ref.read(profileEditorProvider)(ProfileEdit(
        displayName: _name.text.trim(),
        // The server treats '' as "no username change"; the one-time change is enforced there.
        username: username == _originalUsername ? '' : username,
        whatsapp: _whatsapp.text.trim(),
        country: _country.text.trim(),
        bio: _bio.text.trim(),
      ));
      if (!mounted) return;
      ref.invalidate(meProvider);
      ref.invalidate(ownBioProvider);
      messenger.showSnackBar(SnackBar(content: Text(l10n.cmpSaved)));
      if (navigator.canPop()) navigator.pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorCode = e is ApiException ? (e.isUnauthorized ? 'unauthorized' : e.code) : 'network');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          TextFormField(
            key: const Key('profile-display-name'),
            controller: _name,
            enabled: !_saving,
            decoration: InputDecoration(labelText: l10n.cmpFieldDisplayName),
            validator: (v) => RegistrationValidators.displayName(v ?? '') ? null : l10n.cmpValDisplayName,
          ),
          TextFormField(
            key: const Key('profile-username'),
            controller: _username,
            enabled: !_saving,
            decoration: InputDecoration(labelText: l10n.cmpFieldUsername),
          ),
          TextFormField(
            key: const Key('profile-whatsapp'),
            controller: _whatsapp,
            enabled: !_saving,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(labelText: l10n.cmpFieldWhatsapp),
            validator: (v) {
              final t = (v ?? '').trim();
              return t.isEmpty || RegistrationValidators.whatsapp(t) ? null : l10n.cmpValWhatsapp;
            },
          ),
          TextFormField(
            key: const Key('profile-country'),
            controller: _country,
            enabled: !_saving,
            decoration: InputDecoration(labelText: l10n.cmpFieldCountry),
            validator: (v) => (v ?? '').trim().length <= 60 ? null : l10n.cmpValCountry,
          ),
          TextFormField(
            key: const Key('profile-bio'),
            controller: _bio,
            enabled: !_saving,
            maxLines: 4,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(labelText: l10n.cmpFieldBio, counterText: '${_bio.text.length}/280'),
            validator: (v) => (v ?? '').trim().length <= 280 ? null : l10n.cmpValBio,
          ),
          const SizedBox(height: 16),
          FilledButton(
            key: const Key('profile-save'),
            onPressed: _saving ? null : _save,
            child: Text(_saving ? l10n.cmpSubmitting : l10n.cmpSave),
          ),
          if (_errorCode != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(errorCopy(l10n, _errorCode!), style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ),
        ]),
      ),
    );
  }
}
