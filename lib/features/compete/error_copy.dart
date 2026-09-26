import '../../core/l10n/gen/app_localizations.dart';

/// Maps an API error code to localized copy. Server `message` strings are English and never shown.
String errorCopy(AppLocalizations l10n, String code) => switch (code) {
      'network' => l10n.cmpEcNetwork,
      'unauthorized' => l10n.cmpEcSession,
      'tournament_not_found' => l10n.cmpEcTournamentNotFound,
      'rules_agreement_required' => l10n.cmpEcRulesRequired,
      'already_registered' => l10n.cmpEcAlreadyRegistered,
      'tournament_full' => l10n.cmpEcTournamentFull,
      'invitation_only' => l10n.cmpEcInvitationOnly,
      'registration_closed' => l10n.cmpEcRegistrationClosed,
      'insufficient_coins' => l10n.cmpEcInsufficientCoins,
      'payment_init_failed' => l10n.cmpEcPaymentInit,
      'waitlist_not_open' => l10n.cmpEcWaitlistNotOpen,
      'already_on_waitlist' => l10n.cmpEcAlreadyWaitlisted,
      'idempotency_in_progress' => l10n.cmpEcInProgress,
      'invitation_not_found' => l10n.cmpEcInvitationNotFound,
      'invitation_no_longer_available' => l10n.cmpEcInvitationGone,
      'invitation_expired' => l10n.cmpEcInvitationExpired,
      'username_taken' => l10n.cmpEcUsernameTaken,
      'username_locked' => l10n.cmpEcUsernameLocked,
      'save_failed' => l10n.cmpEcSaveFailed,
      _ => l10n.cmpEcGeneric,
    };
