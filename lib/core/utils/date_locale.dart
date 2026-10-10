import 'package:intl/intl.dart';

/// `DateFormat` has no data for Pidgin (`pcm`) and throws `Invalid locale` if asked. Dates in Pidgin render
/// with English formats. Use this around every `AppLocalizations.localeName` passed to a DateFormat.
///
/// Never throws: before any date data is initialised `localeExists` itself throws, and English is the one
/// locale that is always safe then.
String dateLocale(String localeName) {
  try {
    return DateFormat.localeExists(localeName) ? localeName : 'en';
  } catch (_) {
    return 'en';
  }
}

/// NumberFormat has no Pidgin data. Keep supported number grouping and use English otherwise.
String numberLocale(String localeName) {
  try {
    return NumberFormat.localeExists(localeName) ? localeName : 'en';
  } catch (_) {
    return 'en';
  }
}
