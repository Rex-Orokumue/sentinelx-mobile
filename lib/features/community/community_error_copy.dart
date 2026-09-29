import 'package:sentinelx_mobile/core/l10n/gen/app_localizations.dart';

/// Maps community API error codes to localized error messages.
///
/// Returns a player-facing error string for the given code. Unknown codes
/// and server-internal errors (e.g. boost_failed, report_failed) fall through
/// to the generic error message.
String communityErrorCopy(AppLocalizations l10n, String code) {
  return switch (code) {
    'network' => l10n.cmtEcNetwork,
    'unauthorized' => l10n.cmtEcSession,
    'idempotency_in_progress' => l10n.cmtEcInProgress,
    'validation_failed' => l10n.cmtEcValidation,
    'not_found' => l10n.cmtEcNotFound,
    'forbidden' => l10n.cmtEcForbidden,
    'already_boosted' => l10n.cmtEcAlreadyBoosted,
    'active_boost_exists' => l10n.cmtEcActiveBoostExists,
    'insufficient_coins' => l10n.cmtEcInsufficientCoins,
    'voting_closed' => l10n.cmtEcVotingClosed,
    'already_voted' => l10n.cmtEcAlreadyVoted,
    'already_reported' => l10n.cmtEcAlreadyReported,
    'upload_failed' => l10n.cmtEcUploadFailed,
    _ => l10n.cmtEcGeneric,
  };
}
