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

  @override
  String get commonSiteName => 'SentinelX';

  @override
  String get commonViewAll => 'View all';

  @override
  String get commonMenu => 'Menu';

  @override
  String get commonCloseMenu => 'Close menu';

  @override
  String get commonJoinWhatsapp => 'Join WhatsApp Community';

  @override
  String get commonAdmin => 'Admin';

  @override
  String get commonModerator => 'Moderator';

  @override
  String get navHome => 'Home';

  @override
  String get navTournaments => 'Tournaments';

  @override
  String get navGames => 'Games';

  @override
  String get navRankings => 'Leaderboards';

  @override
  String get navSeasons => 'Seasons';

  @override
  String get navExchange => 'Exchange';

  @override
  String get navStore => 'Store';

  @override
  String get navCommunity => 'Community';

  @override
  String get navAbout => 'About Us';

  @override
  String get navTv => 'TV';

  @override
  String get navMore => 'More';

  @override
  String get homeUpcomingHeading => 'Upcoming';

  @override
  String get homeLoadError => 'Something went wrong loading this page.';

  @override
  String get accountTitle => 'Account';

  @override
  String get accountLogIn => 'Log in';

  @override
  String get accountCreateAccount => 'Create account';

  @override
  String get accountSignOut => 'Sign out';

  @override
  String get accountSigningOut => 'Signing out…';

  @override
  String get accountSignOutFailed => 'Could not sign out. Please try again.';

  @override
  String get homeTopPlayersHeading => 'Top Players';

  @override
  String get homeFullRankingsLink => 'Full Rankings';

  @override
  String get authMetaLogin => 'Log in · SentinelX Esports';

  @override
  String get authMetaSignup => 'Sign up · SentinelX Esports';

  @override
  String get authMetaForgotPassword => 'Forgot password · SentinelX Esports';

  @override
  String get authMetaResetPassword => 'Set new password · SentinelX Esports';

  @override
  String get authMetaUsername => 'Choose your username · SentinelX Esports';

  @override
  String get authMetaPhone => 'Verify your phone · SentinelX Esports';

  @override
  String get authCommonEmail => 'Email';

  @override
  String get authCommonPassword => 'Password';

  @override
  String get authCommonUsername => 'Username';

  @override
  String get authCommonOr => 'OR';

  @override
  String get authCommonBackToLogin => 'Back to log in';

  @override
  String get authCommonShowPassword => 'Show password';

  @override
  String get authCommonHidePassword => 'Hide password';

  @override
  String get authCommonAtLeast8 => 'At least 8 characters.';

  @override
  String get authCommonContinueWithGoogle => 'Continue with Google';

  @override
  String get authCommonBack => 'Back';

  @override
  String get authLoginTitle => 'Welcome back';

  @override
  String get authLoginSubtitle => 'Log in to your SentinelX Esports account.';

  @override
  String get authLoginSubmit => 'Log in';

  @override
  String get authLoginSubmitting => 'Signing in…';

  @override
  String get authLoginResend => 'Resend confirmation email';

  @override
  String get authLoginResending => 'Sending…';

  @override
  String get authLoginResendHint =>
      'Didn\'t get the first one? Check spam — or use Google sign-in below, which skips email confirmation.';

  @override
  String get authLoginForgot => 'Forgot password?';

  @override
  String get authLoginCreateAccount => 'Create account';

  @override
  String get authSignupStep1Title => 'Join SentinelX Esports';

  @override
  String get authSignupStep1Subtitle =>
      'Fastest way in — no email confirmation needed:';

  @override
  String get authSignupContinueWithEmail => 'Continue with email';

  @override
  String get authSignupHaveAccount => 'Already have an account?';

  @override
  String get authSignupLogIn => 'Log in';

  @override
  String get authSignupStep2Title => 'Create your account';

  @override
  String get authSignupSubmit => 'Create account';

  @override
  String get authSignupSubmitting => 'Creating account…';

  @override
  String get authSignupCheckEmailTitle => 'Check your email';

  @override
  String authSignupCheckEmailBody(String email) {
    return 'We sent a confirmation link to $email. Click it to activate your account, then log in and pick your handle.';
  }

  @override
  String get authSignupNothingYet =>
      'Nothing after a few minutes? Check your spam folder, then:';

  @override
  String get authSignupResend => 'Resend it';

  @override
  String get authSignupResending => 'Sending…';

  @override
  String get authSignupGoogleTipBefore =>
      'Email links sometimes get held up. Signing up with Google skips confirmation entirely — ';

  @override
  String get authSignupStartOver => 'start over';

  @override
  String get authSignupGoogleTipAfter => ' and use the Google button.';

  @override
  String get authSignupOrSignUpWithEmail => 'OR SIGN UP WITH EMAIL';

  @override
  String authSignupSigningUpAs(String username) {
    return 'Signing up as $username.';
  }

  @override
  String get authForgotTitle => 'Reset your password';

  @override
  String get authForgotSubtitle =>
      'Enter your email and we\'ll send a reset link.';

  @override
  String get authForgotSubmit => 'Send reset link';

  @override
  String get authForgotSubmitting => 'Sending…';

  @override
  String get authResetTitle => 'Set a new password';

  @override
  String get authResetSubtitle => 'Choose a new password for your account.';

  @override
  String get authResetNewPassword => 'New password';

  @override
  String get authResetSubmit => 'Set new password';

  @override
  String get authResetSubmitting => 'Updating…';

  @override
  String get authUsernameStepTitle => 'Choose your handle';

  @override
  String get authUsernameStepSubtitle =>
      'This is your public username on SentinelX Esports.';

  @override
  String get authUsernameStepSubmit => 'Continue';

  @override
  String get authUsernameStepSubmitting => 'Saving…';

  @override
  String get authPhoneStepTitle => 'Verify your phone';

  @override
  String get authPhoneStepSubtitle =>
      'We\'ll send a 6-digit code on WhatsApp so we can reach you about fixtures and results.';

  @override
  String get authAvailabilityTaken => 'That username is taken.';

  @override
  String get authAvailabilityInvalid =>
      '3–20 characters: letters, numbers, underscores.';

  @override
  String get authAvailabilityUnknown =>
      'Couldn\'t verify right now — you can still continue.';

  @override
  String get authNoticesCheckEmail =>
      'Check your email for a confirmation link.';

  @override
  String get authNoticesResendSent =>
      'If that address still needs confirming, a fresh link is on its way. Check your spam folder — and Google sign-in skips email entirely.';

  @override
  String get authNoticesResetSent =>
      'If an account exists for that email, we\'ve sent a reset link.';

  @override
  String get authErrorsInvalidEmail => 'Enter a valid email address.';

  @override
  String get authErrorsPasswordRequired => 'Password is required.';

  @override
  String get authErrorsPasswordTooShort =>
      'Password must be at least 8 characters.';

  @override
  String get authErrorsUsernameTooShort =>
      'Username must be at least 3 characters.';

  @override
  String get authErrorsUsernameTooLong =>
      'Username must be at most 20 characters.';

  @override
  String get authErrorsUsernameCharset =>
      'Only letters, numbers, and underscores.';

  @override
  String get authErrorsInvalidCredentials => 'Invalid email or password.';

  @override
  String get authErrorsEmailNotConfirmed =>
      'Your email isn\'t confirmed yet — check your inbox (and spam) for the link.';

  @override
  String get authErrorsBlockedDetails =>
      'We could not create an account with those details.';

  @override
  String get authErrorsUsernameTaken => 'That username is taken — try another.';

  @override
  String get authErrorsUsernameTakenGoBack =>
      'That username is taken — go back and pick another.';

  @override
  String get authErrorsSignupFailed =>
      'Something went wrong creating your account. Please try again.';

  @override
  String get authErrorsUsernameSaveFailed =>
      'Could not save your username. Please try again.';

  @override
  String get authErrorsLinkExpired =>
      'Your reset link has expired. Please request a new one.';

  @override
  String get authErrorsResetFailed =>
      'Could not update your password. Please try again.';

  @override
  String get authErrorsForgotFailed =>
      'Could not send the reset link. Please try again.';

  @override
  String get authErrorsResendFailed =>
      'Could not resend the confirmation link. Please try again.';

  @override
  String get authErrorsGoogleNotConfigured =>
      'Google sign-in isn\'t set up yet.';

  @override
  String get authErrorsGoogleFailed =>
      'Google sign-in failed. Please try again.';

  @override
  String get termsEyebrow => 'Legal';

  @override
  String get termsTitle => 'Terms of Service';

  @override
  String get termsSubtitle =>
      'The terms that govern your use of the SentinelX platform.';

  @override
  String get termsMetaUpdated => 'Last updated September 2026';

  @override
  String get termsSummary =>
      'The short version: you must be 13 or older, one account per person, and you play fair — real results, backed by proof. Prize money pays to your bank through Paystack after an ID check. SX Coins are platform points with no cash value. Nigerian law applies. This summary is not the legal text — the sections below are.';

  @override
  String get termsMetaTitle => 'Terms of Service';

  @override
  String get termsMetaDescription =>
      'The terms that govern using the SentinelX Esports platform.';

  @override
  String get termsS1Heading => '1. Who We Are';

  @override
  String get termsS1P1 =>
      'SentinelX Esports is a mobile esports platform operated by Samuel Chinoyerem Akpoke (“we”, “us”, “our”). We are based in Nigeria and our platform is available at sentinelxesports.com.ng.';

  @override
  String get termsS1P2 =>
      'By creating an account or using any part of SentinelX, you agree to these Terms of Service. If you do not agree, please do not use the platform.';

  @override
  String get termsS2Heading => '2. Eligibility';

  @override
  String get termsS2P1 =>
      'You must be at least 13 years old to create an account. If you are under 18, you confirm that you have permission from a parent or guardian to use the platform. Players under 18 may not withdraw prize money without verifiable parental or guardian consent.';

  @override
  String get termsS2P2 =>
      'You may only hold one account. Creating multiple accounts to gain an unfair advantage is prohibited and will result in a permanent ban.';

  @override
  String get termsS3Heading => '3. Your Account';

  @override
  String get termsS3P1 =>
      'You are responsible for keeping your login details secure. Do not share your password with anyone. You are responsible for all activity that takes place under your account.';

  @override
  String get termsS3P2 =>
      'If you believe your account has been compromised, contact us immediately at <email>sentinelxesports@gmail.com</email>.';

  @override
  String get termsS4Heading => '4. Tournaments and Entry Fees';

  @override
  String get termsS4P1 =>
      'Tournament entry fees are set per event and displayed clearly before registration. The current standard fee is ₦500. By registering and completing payment, you confirm your intent to participate.';

  @override
  String get termsS4P2 =>
      'Entry fees are processed securely by Paystack. We do not store your card details.';

  @override
  String get termsS4P3 =>
      'SX Coins may be used to reduce or eliminate entry fees where that option is offered. See the <link>Refund Policy</link> for how cancellations are handled.';

  @override
  String get termsS5Heading => '5. Match Rules and Fair Play';

  @override
  String get termsS5Intro =>
      'All players must compete honestly. The following are prohibited:';

  @override
  String get termsS5List =>
      '<li>Submitting false or manipulated match results</li><li>Using external tools, scripts, or exploits to gain an advantage</li><li>Colluding with an opponent to produce a predetermined result</li><li>Threatening, harassing, or abusing opponents</li>';

  @override
  String get termsS5P2 =>
      'Match results must be submitted with supporting evidence (screenshot and screen recording). Admin decisions on disputed results are final. Full conduct and match rules are in the <link>Tournament Rules</link>.';

  @override
  String get termsS5P3 =>
      'A no-show — failing to appear for your scheduled match without notice — results in a forfeit and a penalty to your SX Score.';

  @override
  String get termsS6Heading => '6. Prizes and Withdrawals';

  @override
  String get termsS6P1 =>
      'Prize money is paid to the bank account you link to your player dashboard via Paystack. You must complete identity verification before your first withdrawal.';

  @override
  String get termsS6P2 =>
      'We aim to process approved withdrawals within 1–5 business days. We are not responsible for delays caused by your bank.';

  @override
  String get termsS7Heading => '7. SX Coins';

  @override
  String get termsS7P1 =>
      'SX Coins are a virtual in-platform currency. They are earned by competing and spending time on the platform. SX Coins have no monetary value and cannot be exchanged for cash. They may be used within the platform for entry fee discounts, community features, and the in-platform store. SX Coins may also be staked in community wagering (see section 8), and can be lost if your wager does not win.';

  @override
  String get termsS8Heading => '8. Community Wagering (SX Coins)';

  @override
  String get termsS8P1 =>
      'You may stake SX Coins on the outcome of a match you are not playing in. Wagering is optional and uses SX Coins only.';

  @override
  String get termsS8List =>
      '<li>Wagering opens once both players are confirmed for a scheduled match and closes 15 minutes before the scheduled start time. For matches scheduled across a full day, it closes 24 hours after that day begins.</li><li>A 5% platform fee is taken from the losing pool. Winnings are paid in SX Coins only.</li><li>Wagers settle automatically from the admin-confirmed match result, and that settlement is final.</li><li>If a match is voided or a result is overturned, every stake is returned in full.</li>';

  @override
  String get termsS8P2 =>
      'Because SX Coins have no monetary value and cannot be exchanged for cash, community wagering is not betting for money.';

  @override
  String get termsS9Heading => '9. Gaming Exchange';

  @override
  String get termsS9P1 =>
      'The Gaming Exchange (powered by Zolarux escrow) allows players to buy and sell gaming accounts and in-game items. SentinelX provides the platform and escrow infrastructure. We are not party to the transaction between buyer and seller and are not liable for disputes that arise from transactions conducted outside the platform\'s escrow system. See <link>how escrow works</link> for the step-by-step.';

  @override
  String get termsS10Heading => '10. Community Standards';

  @override
  String get termsS10P1 =>
      'You agree to treat all other members of the SentinelX community with respect. Hate speech, discrimination, threats, and harassment are not tolerated and will result in suspension or permanent ban. See our <link>Community Rules</link> for the full standards.';

  @override
  String get termsS11Heading => '11. Intellectual Property';

  @override
  String get termsS11P1 =>
      'All SentinelX branding, design, and original content is owned by SentinelX Esports. You may not reproduce, copy, or distribute our content without written permission. Content you post (match screenshots, community posts) remains yours, but you grant us a licence to display it on the platform.';

  @override
  String get termsS12Heading => '12. Limitation of Liability';

  @override
  String get termsS12P1 =>
      'SentinelX Esports is not liable for indirect, incidental, or consequential losses arising from your use of the platform. Our total liability to you for any claim shall not exceed the total entry fees you have paid to us in the 3 months prior to the claim.';

  @override
  String get termsS12P2 =>
      'We do not guarantee uninterrupted access to the platform. We will make reasonable efforts to restore service promptly in the event of downtime.';

  @override
  String get termsS13Heading => '13. Changes to These Terms';

  @override
  String get termsS13P1 =>
      'We may update these Terms from time to time. We will notify you via the platform or email when significant changes are made. Continuing to use SentinelX after changes are posted means you accept the updated terms.';

  @override
  String get termsS14Heading => '14. Governing Law';

  @override
  String get termsS14P1 =>
      'These Terms are governed by the laws of the Federal Republic of Nigeria. Any disputes shall be subject to the jurisdiction of Nigerian courts.';

  @override
  String get termsS15Heading => '15. Contact';

  @override
  String get termsS15P1 =>
      'Questions about these Terms? Email us at <email>sentinelxesports@gmail.com</email> or message us on WhatsApp: <whatsapp>+234 903 239 5685</whatsapp>.';

  @override
  String get cmpTabAll => 'All';

  @override
  String get cmpTabLive => 'Live';

  @override
  String get cmpTabUpcoming => 'Upcoming';

  @override
  String get cmpTabCompleted => 'Completed';

  @override
  String get cmpAllGames => 'All games';

  @override
  String get cmpEmpty => 'No tournaments here yet.';

  @override
  String get cmpLoadError =>
      'Couldn\'t load this. Check your connection and try again.';

  @override
  String get cmpRetry => 'Try again';

  @override
  String get cmpLoadMore => 'Load more';

  @override
  String get cmpEntryFee => 'Entry fee';

  @override
  String get cmpFree => 'Free';

  @override
  String get cmpPrizePool => 'Prize pool';

  @override
  String get cmpSecondPlace => '2nd place';

  @override
  String get cmpThirdPlace => '3rd place';

  @override
  String cmpMaxPlayers(int count) {
    return '$count players max';
  }

  @override
  String get cmpRules => 'Rules';

  @override
  String get cmpViewBracket => 'View bracket';

  @override
  String get cmpShareWhatsapp => 'Share on WhatsApp';

  @override
  String cmpShareText(String title, String url) {
    return 'Join $title on Sentinel X: $url';
  }

  @override
  String get cmpCtaRegister => 'Register';

  @override
  String get cmpCtaResume => 'Resume payment';

  @override
  String get cmpCtaLogin => 'Log in to register';

  @override
  String get cmpCtaJoinWaitlist => 'Join waitlist';

  @override
  String get cmpViewInvitations => 'View my invitations';

  @override
  String get cmpStateRegistered => 'You\'re registered.';

  @override
  String get cmpStateWaitlisted => 'You\'re on the waitlist.';

  @override
  String get cmpStateFull => 'This tournament is full.';

  @override
  String get cmpStateEnded => 'This tournament has ended.';

  @override
  String get cmpStateInvitationOnly => 'This tournament is invitation-only.';

  @override
  String get cmpFeeWaived => 'Free entry — waiver applied';

  @override
  String get cmpFieldDisplayName => 'Display name';

  @override
  String get cmpFieldWhatsapp => 'WhatsApp number';

  @override
  String get cmpAgreeRules => 'I have read and agree to the rules';

  @override
  String get cmpCoinsTitle => 'Use SX Coins';

  @override
  String get cmpCoinsNone => 'Don\'t use coins';

  @override
  String cmpCoinsOption(int coins, String naira) {
    return '$coins coins (−₦$naira)';
  }

  @override
  String get cmpSubmitRegister => 'Continue';

  @override
  String get cmpSubmitWaitlist => 'Join waitlist';

  @override
  String get cmpSubmitting => 'Working…';

  @override
  String get cmpValDisplayName => 'Enter a name (1–60 characters).';

  @override
  String get cmpValWhatsapp => 'Enter a valid WhatsApp number.';

  @override
  String get cmpValRules => 'Please agree to the rules.';

  @override
  String get cmpPayConfirming => 'Confirming your payment…';

  @override
  String get cmpPaySuccess => 'You\'re in! Payment confirmed.';

  @override
  String get cmpPayNotConfirmed =>
      'We haven\'t seen your payment yet. If you were charged it will confirm shortly — check back in a minute.';

  @override
  String get cmpPayCancelled =>
      'Payment window closed. You can resume from the tournament page.';

  @override
  String get cmpConfirmedFree => 'You\'re registered!';

  @override
  String get cmpWaitlistJoined => 'You\'re on the waitlist.';

  @override
  String get cmpInvTitle => 'My invitations';

  @override
  String get cmpInvEmpty => 'No pending invitations.';

  @override
  String get cmpInvAccept => 'Accept';

  @override
  String get cmpInvDecline => 'Decline';

  @override
  String cmpInvExpires(String date) {
    return 'Expires $date';
  }

  @override
  String get cmpInvDeclined => 'Invitation declined.';

  @override
  String get cmpGamesTitle => 'Games';

  @override
  String get cmpGamesEmpty => 'No games yet.';

  @override
  String get cmpEditProfile => 'Edit profile';

  @override
  String get cmpFieldBio => 'Bio';

  @override
  String get cmpFieldCountry => 'Country';

  @override
  String get cmpFieldUsername => 'Username (can be changed once)';

  @override
  String get cmpSave => 'Save';

  @override
  String get cmpSaved => 'Profile saved.';

  @override
  String get cmpValBio => 'Bio must be 280 characters or fewer.';

  @override
  String get cmpValCountry => 'Country is too long (60 max).';

  @override
  String get cmpEcGeneric => 'Something went wrong. Please try again.';

  @override
  String get cmpEcNetwork =>
      'No connection. Check your internet and try again.';

  @override
  String get cmpEcSession => 'Your session expired. Please log in again.';

  @override
  String get cmpEcTournamentNotFound => 'Tournament not found.';

  @override
  String get cmpEcRulesRequired => 'Please confirm you agree to the rules.';

  @override
  String get cmpEcAlreadyRegistered =>
      'You\'re already registered for this tournament.';

  @override
  String get cmpEcTournamentFull => 'This tournament is full.';

  @override
  String get cmpEcInvitationOnly => 'This tournament is invitation-only.';

  @override
  String get cmpEcRegistrationClosed => 'Registration is closed.';

  @override
  String get cmpEcInsufficientCoins => 'Not enough SX Coins for this discount.';

  @override
  String get cmpEcPaymentInit =>
      'Payment couldn\'t be started. Please try again.';

  @override
  String get cmpEcWaitlistNotOpen =>
      'The waitlist opens once registration closes.';

  @override
  String get cmpEcAlreadyWaitlisted => 'You\'re already on the waitlist.';

  @override
  String get cmpEcInProgress =>
      'Still processing your request. Please wait a moment and try again.';

  @override
  String get cmpEcInvitationNotFound => 'Invitation not found.';

  @override
  String get cmpEcInvitationGone => 'This invitation is no longer available.';

  @override
  String get cmpEcInvitationExpired => 'This invitation has expired.';

  @override
  String get cmpEcUsernameTaken => 'That username is already taken.';

  @override
  String get cmpEcUsernameLocked =>
      'Your username has already been changed once.';

  @override
  String get cmpEcSaveFailed =>
      'Couldn\'t save your profile. Please try again.';

  @override
  String get cmpHomeGamesTile => 'Games';

  @override
  String get cmpHomeInvitationsTile => 'My invitations';

  @override
  String get cmpAccountEditProfile => 'Edit profile';

  @override
  String get cmpStatusRegistrationOpen => 'Registration open';

  @override
  String get cmpStatusRegistrationClosed => 'Registration closed';

  @override
  String get cmpStatusActive => 'Live';

  @override
  String get cmpStatusCompleted => 'Completed';

  @override
  String get cmpPayCheckAgain => 'Check payment status';

  @override
  String get cmpInvPayCancelled =>
      'Payment window closed. If you were charged, it will confirm shortly.';

  @override
  String get cmpValUsername =>
      'Usernames are 3–20 letters, numbers or underscores.';

  @override
  String get commonDeletedPlayer => 'Deleted player';

  @override
  String get rankingsTitle => 'Leaderboards';

  @override
  String get rankingsRankByScore => 'Ranked by SX Score';

  @override
  String get rankingsRankByWins => 'Ranked by wins';

  @override
  String get rankingsAllGames => 'All games';

  @override
  String get rankingsAllRegions => 'All regions';

  @override
  String get rankingsYourRank => 'Your rank';

  @override
  String get rankingsYou => '(you)';

  @override
  String get rankingsPrev => 'Previous';

  @override
  String get rankingsNext => 'Next';

  @override
  String get rankingsEmpty => 'No ranked players yet.';

  @override
  String get rankingsErrorRetry => 'Couldn\'t load. Tap to retry.';

  @override
  String get rankingsTrendNew => 'New';

  @override
  String get seasonsTitle => 'Seasons';

  @override
  String get seasonsEmpty => 'No seasons yet.';

  @override
  String get seasonsLeaderboardEmpty => 'No season points awarded yet.';

  @override
  String get seasonsProvisional => 'Provisional';

  @override
  String get seasonsProvisionalNote =>
      'Points can still change while tournaments are in progress.';

  @override
  String get seasonsTournaments => 'Tournaments';

  @override
  String get seasonsInviteOnly => 'Invite only';

  @override
  String get seasonsYou => 'You';

  @override
  String get hallOfFameTitle => 'Hall of Fame';

  @override
  String get hallOfFameMvp => 'All-Time MVP';

  @override
  String get hallOfFameGoldenBoot => 'Golden Boot';

  @override
  String get hallOfFameChampionsCup => 'Champions Cup';

  @override
  String get hallOfFameMasters => 'Masters';

  @override
  String get hallOfFameCommunityClub => 'Community Club';

  @override
  String get hallOfFameOpen => 'Open tournaments';

  @override
  String get hallOfFameBronze => 'Bronze finishes';

  @override
  String get hallOfFameEmpty => 'Nothing here yet.';

  @override
  String rankingsWinsCount(int wins) {
    return '$wins wins';
  }

  @override
  String rankingsMatchesCount(int matches) {
    return '$matches matches';
  }

  @override
  String rankingsStreakValue(int n) {
    return '$n-win streak';
  }

  @override
  String rankingsPageOf(int page, int total) {
    return 'Page $page of $total';
  }

  @override
  String rankingsPlayersRanked(int n) {
    return '$n players ranked';
  }

  @override
  String seasonsPoints(int n) {
    return '$n pts';
  }

  @override
  String hallOfFameRunnerUp(String name) {
    return 'Runner-up: $name';
  }

  @override
  String get commonLoadError => 'Couldn\'t load. Tap to retry.';

  @override
  String get playersTitle => 'Players';

  @override
  String get playersSearchHint => 'Search players';

  @override
  String get playersEmpty => 'No players found.';

  @override
  String get playersNotFound => 'Player not found.';

  @override
  String get profileFollow => 'Follow';

  @override
  String get profileFollowing => 'Following';

  @override
  String get profileFollowsYou => 'Follows you';

  @override
  String profileFollowersCount(int n) {
    return '$n followers';
  }

  @override
  String profileFollowingCount(int n) {
    return '$n following';
  }

  @override
  String get profileStatMatches => 'Matches';

  @override
  String get profileStatWins => 'Wins';

  @override
  String get profileStatLosses => 'Losses';

  @override
  String get profileStatGoalsFor => 'Goals for';

  @override
  String get profileStatGoalsAgainst => 'Goals against';

  @override
  String get profileStatTitles => 'Titles';

  @override
  String get profileStatTournaments => 'Tournaments';

  @override
  String get profileStatStreak => 'Win streak';

  @override
  String get profileStatRank => 'Global rank';

  @override
  String profileRankOf(int rank, int total) {
    return '#$rank of $total';
  }

  @override
  String get profileRankUnranked => 'Unranked';

  @override
  String profileSxScore(int n) {
    return 'SX Score $n';
  }

  @override
  String get profileCategoryStats => 'Goals by category';

  @override
  String get profileTitlesHeading => 'Titles';

  @override
  String get profileNoTitles => 'No titles yet.';

  @override
  String get profileRecentMatches => 'Recent matches';

  @override
  String get profileNoMatches => 'No matches yet.';

  @override
  String get profileOutcomeWin => 'Win';

  @override
  String get profileOutcomeLoss => 'Loss';

  @override
  String get profileOutcomeDraw => 'Draw';

  @override
  String get profileAchievements => 'Achievements';

  @override
  String profileAchievementsProgress(int unlocked, int total) {
    return '$unlocked/$total unlocked';
  }

  @override
  String get profileAchievementLocked => 'Locked';

  @override
  String get profilePosts => 'Recent posts';

  @override
  String get profileGallery => 'Gallery';

  @override
  String get followErrorSelf => 'You can\'t follow yourself.';

  @override
  String get followErrorBlocked => 'You can\'t follow this player.';

  @override
  String get followErrorNotFound => 'This player no longer exists.';

  @override
  String get followErrorGeneric => 'Couldn\'t update. Please try again.';

  @override
  String get followersTitle => 'Followers';

  @override
  String get followingTitle => 'Following';

  @override
  String get followersEmpty => 'No followers yet.';

  @override
  String get followingEmpty => 'Not following anyone yet.';

  @override
  String get accountMyProgress => 'My progress';

  @override
  String get progressTitle => 'My progress';

  @override
  String get progressSignIn => 'Log in to see your progress.';

  @override
  String get progressXpHeading => 'XP';

  @override
  String progressXpToNext(int into, int needed, String tier) {
    return '$into / $needed XP to $tier';
  }

  @override
  String get progressMaxTier => 'Max tier reached';

  @override
  String get progressSxScore => 'SX Score';

  @override
  String get progressCoins => 'Coins';

  @override
  String get progressSeasonHeading => 'Season standing';

  @override
  String progressSeasonRank(int rank) {
    return 'Rank #$rank';
  }

  @override
  String get progressSeasonUnranked => 'Unranked';

  @override
  String get progressSeasonMonthly => 'This month';

  @override
  String get progressSeasonNone => 'No active season.';

  @override
  String progressToRankSixteen(int n) {
    return 'Rank 16 has $n pts';
  }

  @override
  String get progressHistoryXp => 'XP history';

  @override
  String get progressHistoryScore => 'SX Score history';

  @override
  String get progressHistoryCoins => 'Coin history';

  @override
  String get historyEmpty => 'No activity yet.';

  @override
  String get historyLoadMoreError => 'Couldn\'t load more. Tap to retry.';

  @override
  String historyBalanceAfter(int n) {
    return 'Balance $n';
  }

  @override
  String get tierRecruit => 'Recruit';

  @override
  String get tierGuardian => 'Guardian';

  @override
  String get tierElite => 'Elite';

  @override
  String get tierSentinel => 'Sentinel';

  @override
  String get tierLegend => 'Legend';

  @override
  String get xpSourceMatchPlayed => 'Match played';

  @override
  String get xpSourceMatchWon => 'Match won';

  @override
  String get xpSourceTournamentEntered => 'Tournament entered';

  @override
  String get xpSourceTournamentCompleted => 'Tournament completed';

  @override
  String get xpSourceTournamentPlacement => 'Tournament placement';

  @override
  String get xpSourceAchievementUnlocked => 'Achievement unlocked';

  @override
  String get xpSourceDailyLogin => 'Daily login';

  @override
  String get xpSourceLoginStreak => 'Login streak';

  @override
  String get xpSourceCommunityActivity => 'Community activity';

  @override
  String get xpSourceAdminGrant => 'Admin grant';

  @override
  String get scoreEventMatchCompleted => 'Match completed';

  @override
  String get scoreEventNoShow => 'No-show';

  @override
  String get scoreEventRageQuit => 'Left a match early';

  @override
  String get scoreEventDisputeLost => 'Dispute lost';

  @override
  String get scoreEventRatingReceived => 'Rating received';

  @override
  String get scoreEventAdminFlagConduct => 'Conduct flag';

  @override
  String get scoreEventAdminFlagCheat => 'Cheat flag';

  @override
  String get coinSourceMatchPlayed => 'Match played';

  @override
  String get coinSourceMatchWon => 'Match won';

  @override
  String get coinSourceTournamentPlacement => 'Tournament placement';

  @override
  String get coinSourceDailyLogin => 'Daily login';

  @override
  String get coinSourceLoginStreak => 'Login streak';

  @override
  String get coinSourceAchievementUnlocked => 'Achievement unlocked';

  @override
  String get coinSourceStorePurchase => 'Store purchase';

  @override
  String get coinSourceCommunityActivity => 'Community activity';

  @override
  String get coinSourceAdminGrant => 'Admin grant';

  @override
  String get coinSourceAdminDeduct => 'Admin deduction';

  @override
  String get coinSourceWeeklyChallenge => 'Weekly challenge';

  @override
  String get coinSourceBestPlayWinner => 'Best Play winner';

  @override
  String get coinSourceBestPlayRunnerUp => 'Best Play runner-up';

  @override
  String get coinSourceEntryDiscount => 'Entry discount';

  @override
  String get coinSourceEntryDiscountRefund => 'Entry discount refund';

  @override
  String get coinSourceWagerStake => 'Wager stake';

  @override
  String get coinSourceWagerWon => 'Wager won';

  @override
  String get coinSourceWagerRefund => 'Wager refund';

  @override
  String get coinSourcePostBoost => 'Post boost';

  @override
  String get coinSourceReferralReward => 'Referral reward';

  @override
  String get coinSourceReferralMilestone => 'Referral milestone';

  @override
  String get coinSourceFriendlyStake => 'Friendly stake';

  @override
  String get coinSourceFriendlyStakePayout => 'Friendly payout';

  @override
  String get mtcBracketTitle => 'Bracket';

  @override
  String get mtcTabGroups => 'Groups';

  @override
  String get mtcTabFixtures => 'Fixtures';

  @override
  String get mtcTabKnockout => 'Knockout';

  @override
  String get mtcNoDrawYet => 'The draw hasn\'t been made yet.';

  @override
  String get mtcChampion => 'Champion';

  @override
  String get mtcThirdPlace => 'Third place';

  @override
  String get mtcNoWinner => 'This tournament closed without a winner.';

  @override
  String mtcGroupCol(String group) {
    return '$group';
  }

  @override
  String get mtcColPlayed => 'P';

  @override
  String get mtcColWins => 'W';

  @override
  String get mtcColDraws => 'D';

  @override
  String get mtcColLosses => 'L';

  @override
  String get mtcColGoalDiff => 'GD';

  @override
  String get mtcColPoints => 'Pts';

  @override
  String get mtcAdvancing => 'Advancing';

  @override
  String get mtcFixtLive => 'Live';

  @override
  String get mtcFixtUpcoming => 'Upcoming';

  @override
  String get mtcFixtCompleted => 'Completed';

  @override
  String get mtcFixtDisputed => 'Disputed or cancelled';

  @override
  String mtcProjectedMatches(int count) {
    return '$count matches to come';
  }

  @override
  String get mtcTbd => 'To be announced';

  @override
  String get mtcVs => 'vs';

  @override
  String get mtcStages => 'Stages';

  @override
  String get mtcStageStandingsTitle => 'Standings';

  @override
  String get mtcColRank => '#';

  @override
  String get mtcColKills => 'Kills';

  @override
  String get mtcTieUnresolved => 'Tied — awaiting tiebreak';

  @override
  String get mtcMatchTitle => 'Match';

  @override
  String get mtcStatusScheduled => 'Scheduled';

  @override
  String get mtcStatusLive => 'Live';

  @override
  String get mtcStatusCompleted => 'Completed';

  @override
  String get mtcStatusDisputed => 'Under review';

  @override
  String get mtcStatusCancelled => 'Cancelled';

  @override
  String get mtcStatusBye => 'Bye';

  @override
  String get mtcStatusForfeited => 'Forfeited';

  @override
  String get mtcWatchLive => 'Watch live';

  @override
  String get mtcWatchReplay => 'Watch replay';

  @override
  String get mtcCheckIn => 'I\'m here — check in';

  @override
  String get mtcCheckedIn => 'Checked in';

  @override
  String get mtcNotCheckedIn => 'Not checked in';

  @override
  String get mtcCheckInSuccess => 'You\'re checked in.';

  @override
  String get mtcSubmitResult => 'Submit result';

  @override
  String get mtcResultSubmitted => 'Result submitted — awaiting confirmation.';

  @override
  String get mtcRateOpponent => 'Rate your opponent';

  @override
  String get mtcRated => 'Thanks for rating!';

  @override
  String get mtcWagerTitle => 'Wager';

  @override
  String get mtcWagerLoginPrompt => 'Log in to place a wager.';

  @override
  String get mtcWagerClosed => 'Wagering is closed for this match.';

  @override
  String mtcWagerPool(int a, int b) {
    return 'Pool: $a vs $b coins';
  }

  @override
  String mtcWagerFee(String percent) {
    return 'House fee $percent%';
  }

  @override
  String mtcWagerYourPick(int coins, String name) {
    return 'Your wager: $coins coins on $name';
  }

  @override
  String get mtcWagerPlace => 'Place wager';

  @override
  String get mtcWagerChange => 'Change wager';

  @override
  String get mtcWagerStake => 'Stake (coins)';

  @override
  String mtcWagerStakeRange(int min, int max) {
    return 'Between $min and $max coins.';
  }

  @override
  String get mtcWagerPlaced => 'Wager placed.';

  @override
  String mtcWagerEstimate(String payout) {
    return 'A 100-coin wager on the first player would pay about $payout coins.';
  }

  @override
  String get mtcNoShowInfo =>
      'This match is eligible for no-show handling by the organizers.';

  @override
  String mtcScoreA(String name) {
    return '$name score';
  }

  @override
  String get mtcRecordingUrl => 'Recording link (optional)';

  @override
  String get mtcPickScreenshot => 'Choose screenshot';

  @override
  String get mtcChangeScreenshot => 'Change screenshot';

  @override
  String get mtcScreenshotRequired => 'A screenshot is required.';

  @override
  String get mtcUploading => 'Uploading screenshot…';

  @override
  String get mtcSubmitting => 'Submitting…';

  @override
  String get mtcValScore => 'Enter a whole number from 0 to 99.';

  @override
  String get mtcLobbyResultTitle => 'Lobby result';

  @override
  String get mtcPlacement => 'Placement';

  @override
  String get mtcKills => 'Kills';

  @override
  String get mtcValPlacement => 'Enter a whole number from 1 to 100.';

  @override
  String get mtcValKills => 'Enter a whole number from 0 to 100.';

  @override
  String get mtcFixturesTitle => 'Your fixtures';

  @override
  String get mtcNextMatch => 'Next match';

  @override
  String get mtcNextLobby => 'Next lobby';

  @override
  String get mtcSubmitPrompt => 'You have a match awaiting your result.';

  @override
  String get mtcLobbySubmitted => 'Result submitted';

  @override
  String get mtcRoomCodeReady => 'Room details are ready';

  @override
  String mtcBannerQualified(String title, String round) {
    return 'You qualified in $title ($round).';
  }

  @override
  String get mtcBannerAwaiting => 'Waiting for your opponent.';

  @override
  String mtcBannerEliminated(String title, String round) {
    return 'You were eliminated from $title ($round).';
  }

  @override
  String get mtcRegistrationsHeading => 'Your registrations';

  @override
  String get mtcPaymentPending => 'Payment pending';

  @override
  String get mtcPaymentPaid => 'Paid';

  @override
  String get mtcEcGeneric => 'Something went wrong. Please try again.';

  @override
  String get mtcEcNetwork =>
      'No connection. Check your internet and try again.';

  @override
  String get mtcEcSession => 'Your session expired. Please log in again.';

  @override
  String get mtcEcInProgress =>
      'Still processing your request. Please wait a moment and try again.';

  @override
  String get mtcEcUploadFailed => 'Screenshot upload failed. Please try again.';

  @override
  String get mtcEcMatchNotFound => 'Match not found.';

  @override
  String get mtcEcNotParticipant => 'You\'re not playing in this match.';

  @override
  String get mtcEcNotMatchDay => 'You can check in once it\'s match day.';

  @override
  String get mtcEcCheckInClosed => 'This match is no longer open for check-in.';

  @override
  String get mtcEcBye => 'This is a bye — there is no result to submit.';

  @override
  String get mtcEcCancelled => 'This match was cancelled.';

  @override
  String get mtcEcAlreadyConfirmed => 'This result is already confirmed.';

  @override
  String get mtcEcSubmissionLocked =>
      'Your submission is under review and can no longer be edited.';

  @override
  String get mtcEcValidation => 'Please check what you entered.';

  @override
  String get mtcEcResultNotConfirmed =>
      'You can rate your opponent once the result is confirmed.';

  @override
  String get mtcEcCannotRateSelf => 'You can\'t rate yourself.';

  @override
  String get mtcEcNotRatable => 'This match can\'t be rated.';

  @override
  String get mtcEcAlreadyRated => 'You\'ve already rated this match.';

  @override
  String get mtcEcPendingDeletion => 'Your account is pending deletion.';

  @override
  String get mtcEcOwnMatch => 'You can\'t wager on your own match.';

  @override
  String get mtcEcInvalidPick => 'Pick one of the two players in this match.';

  @override
  String get mtcEcWindowClosed => 'Wagering is closed for this match.';

  @override
  String get mtcEcInsufficientCoins => 'Not enough SX Coins for this stake.';

  @override
  String get mtcEcNotInLobby => 'You\'re not in this lobby.';

  @override
  String get mtcEcLobbyConfirmed =>
      'This lobby is confirmed and can no longer be edited.';

  @override
  String get mtcEcResultConfirmed =>
      'Your result is confirmed and can no longer be edited.';

  @override
  String get mtcHomeFixtures => 'Fixtures';

  @override
  String get mtcDone => 'Done';

  @override
  String get cmtTitle => 'Community';

  @override
  String get cmtFeedEmpty => 'No posts yet. Be the first to share something!';

  @override
  String get cmtFeedLoadError => 'Couldn\'t load the feed.';

  @override
  String get cmtRetry => 'Try again';

  @override
  String get cmtLoadMore => 'Load more';

  @override
  String get cmtPinnedLabel => 'Pinned';

  @override
  String get cmtBoostedLabel => 'Boosted';

  @override
  String get cmtComposeFab => 'New post';

  @override
  String get cmtSignInToPost => 'Log in to post';

  @override
  String get cmtSignInToReact => 'Log in to react';

  @override
  String get cmtSignInToComment => 'Log in to comment';

  @override
  String get cmtSignInToVote => 'Log in to vote';

  @override
  String get cmtSignInToReport => 'Log in to report';

  @override
  String cmtCommentCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count comments',
      one: '$count comment',
    );
    return '$_temp0';
  }

  @override
  String get cmtReactFire => 'Fire';

  @override
  String get cmtReactCrown => 'Crown';

  @override
  String get cmtReactStrong => 'Strong';

  @override
  String get cmtReactWow => 'Wow';

  @override
  String get cmtMatchResultLabel => 'Match result';

  @override
  String get cmtAchievementLabel => 'Achievement';

  @override
  String get cmtAnnouncementLabel => 'Announcement';

  @override
  String get cmtComposeTitle => 'New post';

  @override
  String get cmtComposeHint => 'What\'s happening in the SentinelX community?';

  @override
  String get cmtComposeAddImage => 'Add photo';

  @override
  String cmtComposeImagesCount(int count) {
    return '$count/5';
  }

  @override
  String get cmtComposePost => 'Post';

  @override
  String get cmtComposePosting => 'Posting…';

  @override
  String get cmtComposeCancel => 'Cancel';

  @override
  String get cmtComposeValidation => 'Write something or add a photo first.';

  @override
  String get cmtComposeRemoveImage => 'Remove image';

  @override
  String get cmtPostDetailTitle => 'Post';

  @override
  String get cmtCommentsTitle => 'Comments';

  @override
  String get cmtCommentsEmpty => 'No comments yet.';

  @override
  String get cmtCommentsCapNotice => 'Showing the first 50 comments.';

  @override
  String get cmtCommentHint => 'Add a comment…';

  @override
  String get cmtCommentSend => 'Send';

  @override
  String get cmtDeletePost => 'Delete post';

  @override
  String get cmtDeletePostConfirm => 'Delete this post? This can\'t be undone.';

  @override
  String get cmtDeleteComment => 'Delete comment';

  @override
  String get cmtDeleteCommentConfirm => 'Delete this comment?';

  @override
  String get cmtDeleteConfirmYes => 'Delete';

  @override
  String get cmtDeleteConfirmCancel => 'Cancel';

  @override
  String get cmtBoostAction => 'Boost (200 coins)';

  @override
  String get cmtBoostConfirmTitle => 'Boost this post?';

  @override
  String get cmtBoostConfirmBody =>
      'Your post will be pinned to the top of the feed for 24 hours for 200 SX Coins.';

  @override
  String get cmtBoostConfirm => 'Boost';

  @override
  String get cmtBoostSuccess => 'Post boosted!';

  @override
  String get cmtStatusesTitle => 'Stories';

  @override
  String get cmtStatusAddYours => 'Your story';

  @override
  String get cmtStatusPost => 'Post story';

  @override
  String get cmtStatusCaptionHint => 'Add a caption (optional)';

  @override
  String get cmtStatusEmpty => 'No stories yet.';

  @override
  String get cmtStatusViewersTitle => 'Viewers';

  @override
  String get cmtStatusViewersEmpty => 'No one has viewed this yet.';

  @override
  String get cmtStatusDelete => 'Delete story';

  @override
  String get cmtStatusDeleteConfirm => 'Delete this story?';

  @override
  String get cmtStatusValidation => 'Add a photo or a caption.';

  @override
  String get cmtChallengesTitle => 'Weekly challenges';

  @override
  String get cmtChallengesSignedOut => 'Log in to track weekly challenges.';

  @override
  String get cmtChallengeCompleted => 'Completed';

  @override
  String cmtChallengeProgress(int progress, int goal) {
    return '$progress/$goal';
  }

  @override
  String get cmtBestPlayTitle => 'Best Play of the Week';

  @override
  String get cmtBestPlayEmpty => 'No nominations this week.';

  @override
  String get cmtBestPlayVote => 'Vote';

  @override
  String get cmtBestPlayVoted => 'Voted';

  @override
  String get cmtBestPlayVoteSuccess => 'Vote recorded!';

  @override
  String get cmtTopMembersTitle => 'Top members';

  @override
  String get cmtUpcomingEventsTitle => 'Upcoming events';

  @override
  String get cmtGalleryTitle => 'Gallery';

  @override
  String cmtStatsMembers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count members',
      one: '$count member',
    );
    return '$_temp0';
  }

  @override
  String cmtStatsCountries(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count countries',
      one: '$count country',
    );
    return '$_temp0';
  }

  @override
  String cmtStatsTournaments(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tournaments',
      one: '$count tournament',
    );
    return '$_temp0';
  }

  @override
  String get cmtReportPost => 'Report post';

  @override
  String get cmtReportComment => 'Report comment';

  @override
  String get cmtReportTitle => 'Report content';

  @override
  String get cmtReportReasonSpam => 'Spam';

  @override
  String get cmtReportReasonHarassment => 'Harassment';

  @override
  String get cmtReportReasonHateSpeech => 'Hate speech';

  @override
  String get cmtReportReasonNudity => 'Nudity or sexual content';

  @override
  String get cmtReportReasonViolence => 'Violence';

  @override
  String get cmtReportReasonMisinformation => 'Misinformation';

  @override
  String get cmtReportReasonOther => 'Other';

  @override
  String get cmtReportNoteHint => 'Add details (optional)';

  @override
  String get cmtReportSubmit => 'Submit report';

  @override
  String get cmtReportSubmitted => 'Report submitted. Thank you.';

  @override
  String get cmtEcGeneric => 'Something went wrong. Please try again.';

  @override
  String get cmtEcNetwork =>
      'No connection. Check your internet and try again.';

  @override
  String get cmtEcSession => 'Your session expired. Please log in again.';

  @override
  String get cmtEcInProgress =>
      'Still processing your request. Please wait a moment and try again.';

  @override
  String get cmtEcValidation => 'Write something or add a photo first.';

  @override
  String get cmtEcNotFound => 'This content is no longer available.';

  @override
  String get cmtEcForbidden => 'You can only do this for your own content.';

  @override
  String get cmtEcAlreadyBoosted => 'This post is already boosted.';

  @override
  String get cmtEcActiveBoostExists =>
      'You already have an active boost on another post.';

  @override
  String get cmtEcInsufficientCoins => 'Not enough SX Coins to boost.';

  @override
  String get cmtEcVotingClosed => 'Voting is closed right now.';

  @override
  String get cmtEcAlreadyVoted => 'You\'ve already voted this week.';

  @override
  String get cmtEcAlreadyReported => 'You\'ve already reported this.';

  @override
  String get cmtEcUploadFailed => 'Image upload failed. Please try again.';

  @override
  String get authMetaProfile => 'Complete your profile · SentinelX Esports';

  @override
  String get authProfileStepTitle => 'Complete your profile';

  @override
  String get authProfileStepSubtitle =>
      'Tell us where you play and which games you\'re into — we\'ll only reach out about tournaments you actually care about.';

  @override
  String get profileCountryLabel => 'Country';

  @override
  String get profileCountryPlaceholder => 'Select your country';

  @override
  String get profileWhatsappLabel => 'WhatsApp number';

  @override
  String get profileWhatsappHint => '+2348012345678';

  @override
  String get profileGamesLabel => 'Which games are you interested in?';

  @override
  String get profileGamesLoading => 'Loading games…';

  @override
  String get profileGamesRetry => 'Couldn\'t load games. Try again';

  @override
  String get profileConsentLabel => 'Receive tournament updates on WhatsApp?';

  @override
  String get profileConsentYes => 'Yes';

  @override
  String get profileConsentNo => 'No';

  @override
  String get profileCountryRequired => 'Select your country.';

  @override
  String get profileWhatsappRequired => 'Enter your WhatsApp number.';

  @override
  String get profileWhatsappInvalid =>
      'Enter a valid WhatsApp number for the selected country.';

  @override
  String get profileGamesRequired => 'Choose at least one game.';

  @override
  String get profileConsentRequired => 'Choose yes or no.';

  @override
  String get profileCountryInvalid => 'Select a country from the list.';

  @override
  String get profileGameUnavailable =>
      'One of the games you picked is no longer available. Reload and try again.';

  @override
  String get profileContinue => 'Continue';

  @override
  String get profileSaving => 'Saving…';

  @override
  String get profileSaveFailed =>
      'Could not save your profile. Please try again.';

  @override
  String get profileSaved => 'Profile saved.';

  @override
  String get ntfTitle => 'Notifications';

  @override
  String get ntfMarkAllRead => 'Mark all read';

  @override
  String get ntfMuteThread => 'Mute this thread';

  @override
  String get ntfUnmuteThread => 'Unmute this thread';

  @override
  String get ntfMuteType => 'Mute this type';

  @override
  String get ntfUnmuteType => 'Unmute this type';

  @override
  String get ntfMuteFor1h => 'For 1 hour';

  @override
  String get ntfMuteFor1w => 'For 1 week';

  @override
  String get ntfMuteAlways => 'Always';

  @override
  String get ntfMuted => 'Muted';

  @override
  String get ntfUnmuted => 'Unmuted';

  @override
  String get ntfEmptyTitle => 'You\'re all caught up';

  @override
  String get ntfEmptyBody =>
      'Fixture assignments, results and prizes show up here.';

  @override
  String get ntfLoadError => 'Couldn\'t load your notifications.';

  @override
  String get ntfRetry => 'Try again';

  @override
  String get ntfSignedOut => 'Log in to see your notifications.';

  @override
  String get ntfLogIn => 'Log in';

  @override
  String get ntfActionFailed => 'That didn\'t work. Try again.';

  @override
  String ntfUnreadCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count unread notifications',
      one: '$count unread notification',
    );
    return '$_temp0';
  }

  @override
  String get ntfTimeNow => 'Just now';

  @override
  String ntfTimeMinutes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count minutes ago',
      one: '$count minute ago',
    );
    return '$_temp0';
  }

  @override
  String ntfTimeHours(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count hours ago',
      one: '$count hour ago',
    );
    return '$_temp0';
  }

  @override
  String ntfTimeDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days ago',
      one: '$count day ago',
    );
    return '$_temp0';
  }

  @override
  String get ntfPermTitle => 'Turn on notifications';

  @override
  String get ntfPermBody =>
      'Get fixture assignments and match reminders on this phone.';

  @override
  String get ntfPermEnable => 'Turn on';

  @override
  String get ntfPermOpenSettings => 'Open system settings';

  @override
  String get ntfPermOn => 'Notifications are on for this phone.';

  @override
  String get ntfPermBlocked =>
      'Notifications are turned off for this app in your phone settings.';

  @override
  String get ntfSettingsTitle => 'Notification settings';

  @override
  String get ntfSettingsEntry => 'Notifications';

  @override
  String get ntfSectionPush => 'Push notifications';

  @override
  String get ntfSectionWhatsapp => 'WhatsApp';

  @override
  String get ntfSectionSharing => 'Share achievements to the community';

  @override
  String get ntfSaveFailed => 'Couldn\'t save that change.';

  @override
  String get ntfTestAction => 'Send a test notification';

  @override
  String get ntfTestSent => 'Test sent — it should arrive in a moment.';

  @override
  String get ntfTestNoDevice =>
      'This phone isn\'t registered for notifications yet.';

  @override
  String get ntfTestFailed => 'The test notification couldn\'t be delivered.';

  @override
  String get ntfPushMatchReminder => 'Match reminders';

  @override
  String get ntfPushResultConfirmed => 'Result confirmed';

  @override
  String get ntfPushAchievementUnlocked => 'Achievement unlocked';

  @override
  String get ntfPushChallengeCompleted => 'Weekly challenge completed';

  @override
  String get ntfPushNewAnnouncement => 'Community announcements';

  @override
  String get ntfPushTournamentAnnounced => 'New tournaments';

  @override
  String get ntfPushWagerSettled => 'Wager settled';

  @override
  String get ntfPushReferralConverted => 'Referral converted';

  @override
  String get ntfPushPostComment => 'Comments on your posts';

  @override
  String get ntfPushPostReaction => 'Reactions on your posts';

  @override
  String get ntfPushBracketReleased => 'Bracket released';

  @override
  String get ntfPushMatchAssigned => 'New fixture assigned';

  @override
  String get ntfPushPrizeCredited => 'Prize credited';

  @override
  String get ntfPushStatusFromFriend => 'A friend posts a status';

  @override
  String get ntfPushStatusViewed => 'Someone views your status';

  @override
  String get ntfPushNewFollower => 'Someone follows you';

  @override
  String get ntfPushDirectMessage => 'Direct messages';

  @override
  String get ntfWaMatchReminder => 'Match reminders (1h before kickoff)';

  @override
  String get ntfWaResultConfirmed => 'Result confirmed';

  @override
  String get ntfWaPrizeCredited => 'Prize credited to wallet';

  @override
  String get ntfWaChallengeCompleted => 'Weekly challenge completed';

  @override
  String get ntfWaAchievementUnlocked => 'Achievement unlocked';

  @override
  String get ntfWaRegistrationConfirmed => 'Registration confirmed';

  @override
  String get ntfShareTournament => 'Tournament wins';

  @override
  String get ntfShareMilestone => 'Milestone achievements (100 matches, etc.)';

  @override
  String get ntfShareStreak => 'Streak achievements';

  @override
  String get ntfShareSocial => 'Social achievements (reactions, posts)';

  @override
  String get ntfShareOther => 'All other achievements';

  @override
  String get ntfChannelMatches => 'Matches';

  @override
  String get ntfChannelMatchesDesc => 'Fixtures, reminders and results';

  @override
  String get ntfChannelSocial => 'Community';

  @override
  String get ntfChannelSocialDesc =>
      'Comments, reactions, followers and achievements';

  @override
  String get ntfChannelMessages => 'Messages';

  @override
  String get ntfChannelMessagesDesc => 'Direct messages';

  @override
  String get ntfChannelMoney => 'Money';

  @override
  String get ntfChannelMoneyDesc => 'Prizes and referral rewards';

  @override
  String get ntfChannelAdmin => 'Admin alerts';

  @override
  String get ntfChannelAdminDesc => 'Staff-only alerts';

  @override
  String get ntfErrValidation => 'That value isn\'t valid.';

  @override
  String get ntfErrNotFound => 'That notification no longer exists.';

  @override
  String get ntfErrNetwork => 'Check your connection and try again.';

  @override
  String get ntfErrGeneric => 'Something went wrong.';

  @override
  String get ntfBannerOpen => 'Open';

  @override
  String get dmErrorGeneric => 'Something went wrong. Please try again.';

  @override
  String get dmErrorBlockedByMe =>
      'You blocked this player. Unblock them to send messages.';

  @override
  String get dmErrorBlocked => 'You can\'t message this player.';

  @override
  String get dmErrorRestricted =>
      'Messaging is restricted on your account right now.';

  @override
  String get dmErrorEditWindow =>
      'You can only edit or unsend a message within 10 minutes of sending it.';

  @override
  String get dmErrorNotForwardable => 'This message can\'t be forwarded.';

  @override
  String get dmErrorRequestLimit =>
      'You can send one message until they accept your request.';

  @override
  String get dmErrorRequestNoMedia =>
      'Photos, stickers and voice notes unlock once they accept your request.';

  @override
  String get dmErrorNotFound =>
      'That message or conversation no longer exists.';

  @override
  String get dmErrorSendFailed => 'Your message couldn\'t be sent.';

  @override
  String get dmErrorAction => 'That didn\'t work. Please try again.';

  @override
  String get dmErrorValidation => 'That message isn\'t valid.';

  @override
  String get dmErrorImageTooLarge => 'That photo is too large to send.';

  @override
  String get dmInboxTitle => 'Messages';

  @override
  String get dmMessagesTooltip => 'Messages';

  @override
  String get dmRequestsTitle => 'Message requests';

  @override
  String dmRequestsRow(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Message requests ($count)',
      one: 'Message requests ($count)',
    );
    return '$_temp0';
  }

  @override
  String dmRequestsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count requests',
      one: '$count request',
    );
    return '$_temp0';
  }

  @override
  String get dmEmptyInbox =>
      'No messages yet. Open a player\'s profile to start a conversation.';

  @override
  String get dmEmptyRequests => 'No message requests.';

  @override
  String get dmLoadError => 'Couldn\'t load your messages.';

  @override
  String get dmRetry => 'Try again';

  @override
  String get dmSignedOut => 'Log in to see your messages.';

  @override
  String get dmLogIn => 'Log in';

  @override
  String dmUnreadCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count unread messages',
      one: '$count unread message',
    );
    return '$_temp0';
  }

  @override
  String dmWaitingFor(String name) {
    return 'Waiting for $name to accept';
  }

  @override
  String get dmRequestChip => 'Request';

  @override
  String get dmPreviewPhoto => 'Photo';

  @override
  String get dmPreviewVoice => 'Voice message';

  @override
  String get dmPreviewRemoved => 'Message removed';

  @override
  String get dmPreviewOther => 'Message';

  @override
  String get dmTyping => 'typing…';

  @override
  String get dmOnline => 'Online';

  @override
  String dmVoiceSeconds(int seconds) {
    String _temp0 = intl.Intl.pluralLogic(
      seconds,
      locale: localeName,
      other: '$seconds seconds',
      one: '$seconds second',
    );
    return '$_temp0';
  }

  @override
  String get dmMessageRemoved => 'Message removed';

  @override
  String get dmUnsupported => 'Unsupported message';

  @override
  String get dmForwardedLabel => 'Forwarded';

  @override
  String get dmEditedLabel => 'edited';

  @override
  String get dmReplyRemoved => 'Original message removed';

  @override
  String dmReplyingTo(String name) {
    return 'Replying to $name';
  }

  @override
  String get dmReplyPhoto => 'Photo';

  @override
  String get dmReplySticker => 'Sticker';

  @override
  String get dmReplyVoice => 'Voice message';

  @override
  String get dmYou => 'You';

  @override
  String get dmToday => 'Today';

  @override
  String get dmYesterday => 'Yesterday';

  @override
  String get dmNewMessages => 'New messages';

  @override
  String get dmReceiptSent => 'Sent';

  @override
  String get dmReceiptDelivered => 'Delivered';

  @override
  String get dmReceiptRead => 'Read';

  @override
  String get dmSending => 'Sending';

  @override
  String get dmRetryAction => 'Retry';

  @override
  String get dmDiscard => 'Discard';

  @override
  String get dmActionReply => 'Reply';

  @override
  String get dmActionCopy => 'Copy';

  @override
  String get dmActionForward => 'Forward';

  @override
  String get dmActionEdit => 'Edit';

  @override
  String get dmActionUnsend => 'Unsend';

  @override
  String get dmActionReport => 'Report';

  @override
  String get dmCopied => 'Copied';

  @override
  String get dmComposerHint => 'Message';

  @override
  String get dmSend => 'Send';

  @override
  String get dmEditingBar => 'Editing message';

  @override
  String get dmSave => 'Save';

  @override
  String get dmCancel => 'Cancel';

  @override
  String get dmCloseReply => 'Cancel reply';

  @override
  String get dmConversationNotFound => 'This conversation doesn\'t exist.';

  @override
  String get dmMore => 'More options';

  @override
  String get dmStickers => 'Stickers';

  @override
  String get dmStickerUnknown => 'Unsupported sticker';

  @override
  String get dmForwardTitle => 'Forward to…';

  @override
  String get dmForwardEmpty => 'No conversations to forward to.';

  @override
  String get dmForwarded => 'Message forwarded';

  @override
  String get dmAttachPhoto => 'Send a photo';

  @override
  String get dmPhotoLibrary => 'Choose from library';

  @override
  String get dmPhotoCamera => 'Take a photo';

  @override
  String get dmImageUnavailable => 'Image unavailable';

  @override
  String get dmBlock => 'Block';

  @override
  String get dmUnblock => 'Unblock';

  @override
  String get dmReport => 'Report';

  @override
  String dmBlockConfirmTitle(String name) {
    return 'Block $name?';
  }

  @override
  String get dmBlockConfirmBody =>
      'They won\'t be able to message you. You can unblock them at any time.';

  @override
  String dmBlockedByMeBanner(String name) {
    return 'You blocked $name';
  }

  @override
  String get dmCannotMessage => 'You can\'t message this player.';

  @override
  String get dmReportTitle => 'Report this conversation';

  @override
  String get dmReportHint => 'What happened?';

  @override
  String get dmReportSubmit => 'Submit report';

  @override
  String get dmReported => 'Thanks. We\'ll review your report.';

  @override
  String dmIncomingTitle(String name) {
    return '$name wants to message you';
  }

  @override
  String get dmIncomingHint =>
      'Only you can see that you have read this. They get no read receipt until you accept.';

  @override
  String get dmAccept => 'Accept';

  @override
  String get dmDecline => 'Decline';

  @override
  String get dmBlockAndReport => 'Block and report';

  @override
  String get dmWaitingHint =>
      'You can send one text message until they accept.';

  @override
  String get dmMessageButton => 'Message';

  @override
  String get dmVoiceMessage => 'Voice message';

  @override
  String get dmMicTooltip => 'Record a voice message';

  @override
  String get dmVoiceRecording => 'Recording';

  @override
  String get dmVoicePaused => 'Paused';

  @override
  String get dmVoicePause => 'Pause';

  @override
  String get dmVoiceResume => 'Resume';

  @override
  String get dmVoiceStop => 'Stop';

  @override
  String get dmVoiceDelete => 'Delete';

  @override
  String get dmVoicePlay => 'Play';

  @override
  String get dmVoiceTooShort => 'That was too short. Hold on a little longer.';

  @override
  String get dmMicDenied =>
      'Microphone access is needed to record voice messages.';

  @override
  String get dmMicTryAgain => 'Try again';

  @override
  String get dmMicOpenSettings => 'Open settings';

  @override
  String get dmVoicePlaybackError => 'Couldn\'t play this voice message.';

  @override
  String get dmVoiceLimitReached => 'Maximum length reached';

  @override
  String get avatarChangePhoto => 'Change photo';

  @override
  String get avatarFromGallery => 'Choose from gallery';

  @override
  String get avatarFromCamera => 'Take a photo';

  @override
  String get avatarUploading => 'Uploading photo…';

  @override
  String get avatarUploadFailed => 'Couldn\'t upload your photo. Try again.';

  @override
  String get avatarTooLarge => 'That photo is too large. Pick a smaller one.';

  @override
  String get avatarNotImage => 'That file isn\'t a photo we can use.';
}
