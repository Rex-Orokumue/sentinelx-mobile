import '../../core/l10n/gen/app_localizations.dart';

/// Fallback for a code the app does not know yet: a new DB value must never blank or break a row.
String humanizeCode(String code) {
  final words = code.split('_').where((w) => w.isNotEmpty).toList();
  if (words.isEmpty) return '—';
  final s = words.join(' ');
  return '${s[0].toUpperCase()}${s.substring(1)}';
}

String xpSourceLabel(AppLocalizations l, String code) => switch (code) {
      'match_played' => l.xpSourceMatchPlayed,
      'match_won' => l.xpSourceMatchWon,
      'tournament_entered' => l.xpSourceTournamentEntered,
      'tournament_completed' => l.xpSourceTournamentCompleted,
      'tournament_placement' => l.xpSourceTournamentPlacement,
      'achievement_unlocked' => l.xpSourceAchievementUnlocked,
      'daily_login' => l.xpSourceDailyLogin,
      'login_streak' => l.xpSourceLoginStreak,
      'community_activity' => l.xpSourceCommunityActivity,
      'admin_grant' => l.xpSourceAdminGrant,
      _ => humanizeCode(code),
    };

String scoreEventLabel(AppLocalizations l, String code) => switch (code) {
      'match_completed' => l.scoreEventMatchCompleted,
      'no_show' => l.scoreEventNoShow,
      'rage_quit' => l.scoreEventRageQuit,
      'dispute_lost' => l.scoreEventDisputeLost,
      'rating_received' => l.scoreEventRatingReceived,
      'admin_flag_conduct' => l.scoreEventAdminFlagConduct,
      'admin_flag_cheat' => l.scoreEventAdminFlagCheat,
      _ => humanizeCode(code),
    };

String coinSourceLabel(AppLocalizations l, String code) => switch (code) {
      'match_played' => l.coinSourceMatchPlayed,
      'match_won' => l.coinSourceMatchWon,
      'tournament_placement' => l.coinSourceTournamentPlacement,
      'daily_login' => l.coinSourceDailyLogin,
      'login_streak' => l.coinSourceLoginStreak,
      'achievement_unlocked' => l.coinSourceAchievementUnlocked,
      'store_purchase' => l.coinSourceStorePurchase,
      'community_activity' => l.coinSourceCommunityActivity,
      'admin_grant' => l.coinSourceAdminGrant,
      'admin_deduct' => l.coinSourceAdminDeduct,
      'weekly_challenge' => l.coinSourceWeeklyChallenge,
      'best_play_winner' => l.coinSourceBestPlayWinner,
      'best_play_runner_up' => l.coinSourceBestPlayRunnerUp,
      'entry_discount' => l.coinSourceEntryDiscount,
      'entry_discount_refund' => l.coinSourceEntryDiscountRefund,
      'wager_stake' => l.coinSourceWagerStake,
      'wager_won' => l.coinSourceWagerWon,
      'wager_refund' => l.coinSourceWagerRefund,
      'post_boost' => l.coinSourcePostBoost,
      'referral_reward' => l.coinSourceReferralReward,
      'referral_milestone' => l.coinSourceReferralMilestone,
      'friendly_stake' => l.coinSourceFriendlyStake,
      'friendly_stake_payout' => l.coinSourceFriendlyStakePayout,
      _ => humanizeCode(code),
    };

String tierLabel(AppLocalizations l, String code) => switch (code) {
      'recruit' => l.tierRecruit,
      'guardian' => l.tierGuardian,
      'elite' => l.tierElite,
      'sentinel' => l.tierSentinel,
      'legend' => l.tierLegend,
      _ => humanizeCode(code),
    };
