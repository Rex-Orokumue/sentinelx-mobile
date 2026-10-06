import '../../core/l10n/gen/app_localizations.dart';

/// Label for a quest step key. A key a newer server added that this build does not know gets a generic label.
String questStepLabel(AppLocalizations l10n, String key) => switch (key) {
      'profile_complete' => l10n.questStepProfile_complete,
      'first_tournament_entered' => l10n.questStepFirst_tournament_entered,
      'first_match_completed' => l10n.questStepFirst_match_completed,
      _ => l10n.questStepGeneric,
    };

/// Claim failure code -> copy. Server text is never shown.
String questClaimError(AppLocalizations l10n, String code) => switch (code) {
      'quest_incomplete' => l10n.questErrorIncomplete,
      'claim_in_progress' => l10n.questErrorInProgress,
      'reward_unavailable' => l10n.questErrorUnavailable,
      _ => l10n.questErrorGeneric,
    };

