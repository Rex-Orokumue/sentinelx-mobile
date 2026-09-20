// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'Sentinel X';

  @override
  String get maintenanceTitle => 'We\'ll be right back';

  @override
  String get updateRequiredTitle => 'Update required';

  @override
  String updateRequiredBody(String minVersion) {
    return 'Please update Sentinel X to version $minVersion or newer to continue.';
  }

  @override
  String get updateAction => 'Update now';
}
