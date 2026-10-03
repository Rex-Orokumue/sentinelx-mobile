import '../../core/l10n/gen/app_localizations.dart';

/// "5 minutes ago" style label. A timestamp in the future (clock skew between phone and server) reads as
/// "just now" rather than a negative duration.
String relativeTime(AppLocalizations l10n, DateTime created, DateTime now) {
  final diff = now.difference(created);
  if (diff.inSeconds < 60) return l10n.ntfTimeNow;
  if (diff.inMinutes < 60) return l10n.ntfTimeMinutes(diff.inMinutes);
  if (diff.inHours < 24) return l10n.ntfTimeHours(diff.inHours);
  return l10n.ntfTimeDays(diff.inDays);
}
