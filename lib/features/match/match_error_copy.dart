import '../../core/l10n/gen/app_localizations.dart';

/// Maps a match/result/rating/wager API error code to localized copy. Server `message` strings are English
/// and never shown; unknown and server-internal (`*_failed`) codes fall back to the generic message.
String matchErrorCopy(AppLocalizations l10n, String code) => switch (code) {
      'network' => l10n.mtcEcNetwork,
      'unauthorized' => l10n.mtcEcSession,
      'idempotency_in_progress' => l10n.mtcEcInProgress,
      'upload_failed' => l10n.mtcEcUploadFailed,
      'match_not_found' => l10n.mtcEcMatchNotFound,
      'not_participant' || 'not_a_participant' => l10n.mtcEcNotParticipant,
      'not_match_day' => l10n.mtcEcNotMatchDay,
      'check_in_closed' => l10n.mtcEcCheckInClosed,
      'bye_no_result' => l10n.mtcEcBye,
      'match_cancelled' => l10n.mtcEcCancelled,
      'already_confirmed' => l10n.mtcEcAlreadyConfirmed,
      'submission_locked' => l10n.mtcEcSubmissionLocked,
      'screenshot_required' => l10n.mtcScreenshotRequired,
      'validation_failed' => l10n.mtcEcValidation,
      'result_not_confirmed_yet' => l10n.mtcEcResultNotConfirmed,
      'cannot_rate_self' => l10n.mtcEcCannotRateSelf,
      'not_ratable' => l10n.mtcEcNotRatable,
      'already_rated' => l10n.mtcEcAlreadyRated,
      'pending_deletion' => l10n.mtcEcPendingDeletion,
      'own_match' => l10n.mtcEcOwnMatch,
      'invalid_pick' => l10n.mtcEcInvalidPick,
      'window_closed' => l10n.mtcEcWindowClosed,
      'insufficient_coins' => l10n.mtcEcInsufficientCoins,
      'not_in_lobby' => l10n.mtcEcNotInLobby,
      'lobby_confirmed' => l10n.mtcEcLobbyConfirmed,
      'result_confirmed' => l10n.mtcEcResultConfirmed,
      _ => l10n.mtcEcGeneric,
    };
