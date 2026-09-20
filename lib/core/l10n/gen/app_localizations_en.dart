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
}
