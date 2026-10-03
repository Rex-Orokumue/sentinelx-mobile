import '../../core/l10n/gen/app_localizations.dart';

// Labels for the preference toggles. An unknown key (a newer server added one) returns itself rather than
// throwing, so the screen still renders a usable row.

String pushPrefLabel(AppLocalizations l, String key) => switch (key) {
      'match_reminder' => l.ntfPushMatchReminder,
      'result_confirmed' => l.ntfPushResultConfirmed,
      'achievement_unlocked' => l.ntfPushAchievementUnlocked,
      'challenge_completed' => l.ntfPushChallengeCompleted,
      'new_announcement' => l.ntfPushNewAnnouncement,
      'tournament_announced' => l.ntfPushTournamentAnnounced,
      'wager_settled' => l.ntfPushWagerSettled,
      'referral_converted' => l.ntfPushReferralConverted,
      'post_comment' => l.ntfPushPostComment,
      'post_reaction' => l.ntfPushPostReaction,
      'bracket_released' => l.ntfPushBracketReleased,
      'match_assigned' => l.ntfPushMatchAssigned,
      'prize_credited' => l.ntfPushPrizeCredited,
      'status_from_friend' => l.ntfPushStatusFromFriend,
      'status_viewed' => l.ntfPushStatusViewed,
      'new_follower' => l.ntfPushNewFollower,
      'direct_message' => l.ntfPushDirectMessage,
      _ => key,
    };

String whatsappPrefLabel(AppLocalizations l, String key) => switch (key) {
      'match_reminder' => l.ntfWaMatchReminder,
      'result_confirmed' => l.ntfWaResultConfirmed,
      'prize_credited' => l.ntfWaPrizeCredited,
      'challenge_completed' => l.ntfWaChallengeCompleted,
      'achievement_unlocked' => l.ntfWaAchievementUnlocked,
      'registration_confirmed' => l.ntfWaRegistrationConfirmed,
      _ => key,
    };

String sharingPrefLabel(AppLocalizations l, String key) => switch (key) {
      'tournament' => l.ntfShareTournament,
      'milestone' => l.ntfShareMilestone,
      'streak' => l.ntfShareStreak,
      'social' => l.ntfShareSocial,
      'other' => l.ntfShareOther,
      _ => key,
    };
