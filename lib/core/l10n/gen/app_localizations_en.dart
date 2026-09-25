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
}
