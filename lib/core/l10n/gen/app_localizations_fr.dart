// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get appName => 'Sentinel X';

  @override
  String get maintenanceTitle => 'Nous revenons tout de suite';

  @override
  String get updateRequiredTitle => 'Mise à jour requise';

  @override
  String updateRequiredBody(String minVersion) {
    return 'Veuillez mettre à jour Sentinel X vers la version $minVersion ou plus récente pour continuer.';
  }

  @override
  String get updateAction => 'Mettre à jour';
}
