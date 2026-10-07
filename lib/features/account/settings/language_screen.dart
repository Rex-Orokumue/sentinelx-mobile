import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/gen/app_localizations.dart';
import 'locale_providers.dart';

/// Settings -> Language (`/account/language`). The language names are shown in their own language on
/// purpose, so someone who cannot read the current one can still find theirs.
class LanguageScreen extends ConsumerWidget {
  const LanguageScreen({super.key});

  Future<void> _choose(BuildContext context, WidgetRef ref, String code) async {
    final messenger = ScaffoldMessenger.of(context);
    final failed = AppLocalizations.of(context).mobileSettingsLanguageSaveFailed;
    final ok = await ref.read(localeProvider.notifier).select(code);
    if (!ok) {
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(SnackBar(content: Text(failed)));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final current = ref.watch(localeProvider)?.languageCode ?? Localizations.localeOf(context).languageCode;
    final options = <(String, String)>[
      ('en', l10n.mobileSettingsLanguageEnglish),
      ('fr', l10n.mobileSettingsLanguageFrench),
      ('pcm', l10n.mobileSettingsLanguagePidgin),
    ];
    return Scaffold(
      appBar: AppBar(title: Text(l10n.mobileSettingsLanguageTitle)),
      body: RadioGroup<String>(
        groupValue: current,
        onChanged: (code) {
          if (code != null) _choose(context, ref, code);
        },
        child: ListView(
          children: [
            for (final (code, label) in options)
              RadioListTile<String>(key: Key('language-$code'), value: code, title: Text(label)),
          ],
        ),
      ),
    );
  }
}
