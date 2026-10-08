import 'package:intl/intl.dart';

import '../../core/l10n/gen/app_localizations.dart';
import '../../core/utils/date_locale.dart';

/// Localized status text; null for a status the app doesn't know (the chip is then hidden, never blank).
String? matchStatusText(AppLocalizations l10n, String status) => switch (status) {
      'scheduled' => l10n.mtcStatusScheduled,
      'live' => l10n.mtcStatusLive,
      'completed' => l10n.mtcStatusCompleted,
      'disputed' => l10n.mtcStatusDisputed,
      'cancelled' => l10n.mtcStatusCancelled,
      'bye' => l10n.mtcStatusBye,
      'forfeited' => l10n.mtcStatusForfeited,
      _ => null,
    };

/// `quarter_final` → `Quarter Final`. The API supplies proper labels where it can; this is only for raw round codes.
String roundLabel(String code) => code
    .split('_')
    .where((w) => w.isNotEmpty)
    .map((w) => '${w[0].toUpperCase()}${w.substring(1)}')
    .join(' ');

/// Schedule text: date only for full-day matches, date and time otherwise, `mtcTbd` when unscheduled/unparseable.
String scheduleText(AppLocalizations l10n, String? iso, {required bool isFullDay}) {
  final at = iso == null ? null : DateTime.tryParse(iso)?.toLocal();
  if (at == null) return l10n.mtcTbd;
  final f = DateFormat.yMMMd(dateLocale(l10n.localeName));
  return isFullDay ? f.format(at) : f.add_jm().format(at);
}
