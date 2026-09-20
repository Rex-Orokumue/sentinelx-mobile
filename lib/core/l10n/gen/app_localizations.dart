import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_fr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'gen/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('fr'),
  ];

  /// No description provided for @appName.
  ///
  /// In en, this message translates to:
  /// **'Sentinel X'**
  String get appName;

  /// No description provided for @maintenanceTitle.
  ///
  /// In en, this message translates to:
  /// **'We\'ll be right back'**
  String get maintenanceTitle;

  /// No description provided for @updateRequiredTitle.
  ///
  /// In en, this message translates to:
  /// **'Update required'**
  String get updateRequiredTitle;

  /// No description provided for @updateRequiredBody.
  ///
  /// In en, this message translates to:
  /// **'Please update Sentinel X to version {minVersion} or newer to continue.'**
  String updateRequiredBody(String minVersion);

  /// No description provided for @updateAction.
  ///
  /// In en, this message translates to:
  /// **'Update now'**
  String get updateAction;

  /// No description provided for @commonSiteName.
  ///
  /// In en, this message translates to:
  /// **'SentinelX'**
  String get commonSiteName;

  /// No description provided for @commonViewAll.
  ///
  /// In en, this message translates to:
  /// **'View all'**
  String get commonViewAll;

  /// No description provided for @commonMenu.
  ///
  /// In en, this message translates to:
  /// **'Menu'**
  String get commonMenu;

  /// No description provided for @commonCloseMenu.
  ///
  /// In en, this message translates to:
  /// **'Close menu'**
  String get commonCloseMenu;

  /// No description provided for @commonJoinWhatsapp.
  ///
  /// In en, this message translates to:
  /// **'Join WhatsApp Community'**
  String get commonJoinWhatsapp;

  /// No description provided for @commonAdmin.
  ///
  /// In en, this message translates to:
  /// **'Admin'**
  String get commonAdmin;

  /// No description provided for @commonModerator.
  ///
  /// In en, this message translates to:
  /// **'Moderator'**
  String get commonModerator;

  /// No description provided for @navHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get navHome;

  /// No description provided for @navTournaments.
  ///
  /// In en, this message translates to:
  /// **'Tournaments'**
  String get navTournaments;

  /// No description provided for @navGames.
  ///
  /// In en, this message translates to:
  /// **'Games'**
  String get navGames;

  /// No description provided for @navRankings.
  ///
  /// In en, this message translates to:
  /// **'Leaderboards'**
  String get navRankings;

  /// No description provided for @navSeasons.
  ///
  /// In en, this message translates to:
  /// **'Seasons'**
  String get navSeasons;

  /// No description provided for @navExchange.
  ///
  /// In en, this message translates to:
  /// **'Exchange'**
  String get navExchange;

  /// No description provided for @navStore.
  ///
  /// In en, this message translates to:
  /// **'Store'**
  String get navStore;

  /// No description provided for @navCommunity.
  ///
  /// In en, this message translates to:
  /// **'Community'**
  String get navCommunity;

  /// No description provided for @navAbout.
  ///
  /// In en, this message translates to:
  /// **'About Us'**
  String get navAbout;

  /// No description provided for @navTv.
  ///
  /// In en, this message translates to:
  /// **'TV'**
  String get navTv;

  /// No description provided for @navMore.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get navMore;

  /// No description provided for @homeUpcomingHeading.
  ///
  /// In en, this message translates to:
  /// **'Upcoming'**
  String get homeUpcomingHeading;

  /// No description provided for @homeTopPlayersHeading.
  ///
  /// In en, this message translates to:
  /// **'Top Players'**
  String get homeTopPlayersHeading;

  /// No description provided for @homeFullRankingsLink.
  ///
  /// In en, this message translates to:
  /// **'Full Rankings'**
  String get homeFullRankingsLink;

  /// No description provided for @authMetaLogin.
  ///
  /// In en, this message translates to:
  /// **'Log in · SentinelX Esports'**
  String get authMetaLogin;

  /// No description provided for @authMetaSignup.
  ///
  /// In en, this message translates to:
  /// **'Sign up · SentinelX Esports'**
  String get authMetaSignup;

  /// No description provided for @authMetaForgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot password · SentinelX Esports'**
  String get authMetaForgotPassword;

  /// No description provided for @authMetaResetPassword.
  ///
  /// In en, this message translates to:
  /// **'Set new password · SentinelX Esports'**
  String get authMetaResetPassword;

  /// No description provided for @authMetaUsername.
  ///
  /// In en, this message translates to:
  /// **'Choose your username · SentinelX Esports'**
  String get authMetaUsername;

  /// No description provided for @authMetaPhone.
  ///
  /// In en, this message translates to:
  /// **'Verify your phone · SentinelX Esports'**
  String get authMetaPhone;

  /// No description provided for @authCommonEmail.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get authCommonEmail;

  /// No description provided for @authCommonPassword.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get authCommonPassword;

  /// No description provided for @authCommonUsername.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get authCommonUsername;

  /// No description provided for @authCommonOr.
  ///
  /// In en, this message translates to:
  /// **'OR'**
  String get authCommonOr;

  /// No description provided for @authCommonBackToLogin.
  ///
  /// In en, this message translates to:
  /// **'Back to log in'**
  String get authCommonBackToLogin;

  /// No description provided for @authCommonShowPassword.
  ///
  /// In en, this message translates to:
  /// **'Show password'**
  String get authCommonShowPassword;

  /// No description provided for @authCommonHidePassword.
  ///
  /// In en, this message translates to:
  /// **'Hide password'**
  String get authCommonHidePassword;

  /// No description provided for @authCommonAtLeast8.
  ///
  /// In en, this message translates to:
  /// **'At least 8 characters.'**
  String get authCommonAtLeast8;

  /// No description provided for @authCommonContinueWithGoogle.
  ///
  /// In en, this message translates to:
  /// **'Continue with Google'**
  String get authCommonContinueWithGoogle;

  /// No description provided for @authCommonBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get authCommonBack;

  /// No description provided for @authLoginTitle.
  ///
  /// In en, this message translates to:
  /// **'Welcome back'**
  String get authLoginTitle;

  /// No description provided for @authLoginSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Log in to your SentinelX Esports account.'**
  String get authLoginSubtitle;

  /// No description provided for @authLoginSubmit.
  ///
  /// In en, this message translates to:
  /// **'Log in'**
  String get authLoginSubmit;

  /// No description provided for @authLoginSubmitting.
  ///
  /// In en, this message translates to:
  /// **'Signing in…'**
  String get authLoginSubmitting;

  /// No description provided for @authLoginResend.
  ///
  /// In en, this message translates to:
  /// **'Resend confirmation email'**
  String get authLoginResend;

  /// No description provided for @authLoginResending.
  ///
  /// In en, this message translates to:
  /// **'Sending…'**
  String get authLoginResending;

  /// No description provided for @authLoginResendHint.
  ///
  /// In en, this message translates to:
  /// **'Didn\'t get the first one? Check spam — or use Google sign-in below, which skips email confirmation.'**
  String get authLoginResendHint;

  /// No description provided for @authLoginForgot.
  ///
  /// In en, this message translates to:
  /// **'Forgot password?'**
  String get authLoginForgot;

  /// No description provided for @authLoginCreateAccount.
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get authLoginCreateAccount;

  /// No description provided for @authSignupStep1Title.
  ///
  /// In en, this message translates to:
  /// **'Join SentinelX Esports'**
  String get authSignupStep1Title;

  /// No description provided for @authSignupStep1Subtitle.
  ///
  /// In en, this message translates to:
  /// **'Fastest way in — no email confirmation needed:'**
  String get authSignupStep1Subtitle;

  /// No description provided for @authSignupContinueWithEmail.
  ///
  /// In en, this message translates to:
  /// **'Continue with email'**
  String get authSignupContinueWithEmail;

  /// No description provided for @authSignupHaveAccount.
  ///
  /// In en, this message translates to:
  /// **'Already have an account?'**
  String get authSignupHaveAccount;

  /// No description provided for @authSignupLogIn.
  ///
  /// In en, this message translates to:
  /// **'Log in'**
  String get authSignupLogIn;

  /// No description provided for @authSignupStep2Title.
  ///
  /// In en, this message translates to:
  /// **'Create your account'**
  String get authSignupStep2Title;

  /// No description provided for @authSignupSubmit.
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get authSignupSubmit;

  /// No description provided for @authSignupSubmitting.
  ///
  /// In en, this message translates to:
  /// **'Creating account…'**
  String get authSignupSubmitting;

  /// No description provided for @authSignupCheckEmailTitle.
  ///
  /// In en, this message translates to:
  /// **'Check your email'**
  String get authSignupCheckEmailTitle;

  /// No description provided for @authSignupCheckEmailBody.
  ///
  /// In en, this message translates to:
  /// **'We sent a confirmation link to {email}. Click it to activate your account, then log in and pick your handle.'**
  String authSignupCheckEmailBody(String email);

  /// No description provided for @authSignupNothingYet.
  ///
  /// In en, this message translates to:
  /// **'Nothing after a few minutes? Check your spam folder, then:'**
  String get authSignupNothingYet;

  /// No description provided for @authSignupResend.
  ///
  /// In en, this message translates to:
  /// **'Resend it'**
  String get authSignupResend;

  /// No description provided for @authSignupResending.
  ///
  /// In en, this message translates to:
  /// **'Sending…'**
  String get authSignupResending;

  /// No description provided for @authSignupGoogleTipBefore.
  ///
  /// In en, this message translates to:
  /// **'Email links sometimes get held up. Signing up with Google skips confirmation entirely — '**
  String get authSignupGoogleTipBefore;

  /// No description provided for @authSignupStartOver.
  ///
  /// In en, this message translates to:
  /// **'start over'**
  String get authSignupStartOver;

  /// No description provided for @authSignupGoogleTipAfter.
  ///
  /// In en, this message translates to:
  /// **' and use the Google button.'**
  String get authSignupGoogleTipAfter;

  /// No description provided for @authSignupOrSignUpWithEmail.
  ///
  /// In en, this message translates to:
  /// **'OR SIGN UP WITH EMAIL'**
  String get authSignupOrSignUpWithEmail;

  /// No description provided for @authSignupSigningUpAs.
  ///
  /// In en, this message translates to:
  /// **'Signing up as {username}.'**
  String authSignupSigningUpAs(String username);

  /// No description provided for @authForgotTitle.
  ///
  /// In en, this message translates to:
  /// **'Reset your password'**
  String get authForgotTitle;

  /// No description provided for @authForgotSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Enter your email and we\'ll send a reset link.'**
  String get authForgotSubtitle;

  /// No description provided for @authForgotSubmit.
  ///
  /// In en, this message translates to:
  /// **'Send reset link'**
  String get authForgotSubmit;

  /// No description provided for @authForgotSubmitting.
  ///
  /// In en, this message translates to:
  /// **'Sending…'**
  String get authForgotSubmitting;

  /// No description provided for @authResetTitle.
  ///
  /// In en, this message translates to:
  /// **'Set a new password'**
  String get authResetTitle;

  /// No description provided for @authResetSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Choose a new password for your account.'**
  String get authResetSubtitle;

  /// No description provided for @authResetNewPassword.
  ///
  /// In en, this message translates to:
  /// **'New password'**
  String get authResetNewPassword;

  /// No description provided for @authResetSubmit.
  ///
  /// In en, this message translates to:
  /// **'Set new password'**
  String get authResetSubmit;

  /// No description provided for @authResetSubmitting.
  ///
  /// In en, this message translates to:
  /// **'Updating…'**
  String get authResetSubmitting;

  /// No description provided for @authUsernameStepTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose your handle'**
  String get authUsernameStepTitle;

  /// No description provided for @authUsernameStepSubtitle.
  ///
  /// In en, this message translates to:
  /// **'This is your public username on SentinelX Esports.'**
  String get authUsernameStepSubtitle;

  /// No description provided for @authUsernameStepSubmit.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get authUsernameStepSubmit;

  /// No description provided for @authUsernameStepSubmitting.
  ///
  /// In en, this message translates to:
  /// **'Saving…'**
  String get authUsernameStepSubmitting;

  /// No description provided for @authPhoneStepTitle.
  ///
  /// In en, this message translates to:
  /// **'Verify your phone'**
  String get authPhoneStepTitle;

  /// No description provided for @authPhoneStepSubtitle.
  ///
  /// In en, this message translates to:
  /// **'We\'ll send a 6-digit code on WhatsApp so we can reach you about fixtures and results.'**
  String get authPhoneStepSubtitle;

  /// No description provided for @authAvailabilityTaken.
  ///
  /// In en, this message translates to:
  /// **'That username is taken.'**
  String get authAvailabilityTaken;

  /// No description provided for @authAvailabilityInvalid.
  ///
  /// In en, this message translates to:
  /// **'3–20 characters: letters, numbers, underscores.'**
  String get authAvailabilityInvalid;

  /// No description provided for @authAvailabilityUnknown.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t verify right now — you can still continue.'**
  String get authAvailabilityUnknown;

  /// No description provided for @authNoticesCheckEmail.
  ///
  /// In en, this message translates to:
  /// **'Check your email for a confirmation link.'**
  String get authNoticesCheckEmail;

  /// No description provided for @authNoticesResendSent.
  ///
  /// In en, this message translates to:
  /// **'If that address still needs confirming, a fresh link is on its way. Check your spam folder — and Google sign-in skips email entirely.'**
  String get authNoticesResendSent;

  /// No description provided for @authNoticesResetSent.
  ///
  /// In en, this message translates to:
  /// **'If an account exists for that email, we\'ve sent a reset link.'**
  String get authNoticesResetSent;

  /// No description provided for @authErrorsInvalidEmail.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email address.'**
  String get authErrorsInvalidEmail;

  /// No description provided for @authErrorsPasswordRequired.
  ///
  /// In en, this message translates to:
  /// **'Password is required.'**
  String get authErrorsPasswordRequired;

  /// No description provided for @authErrorsPasswordTooShort.
  ///
  /// In en, this message translates to:
  /// **'Password must be at least 8 characters.'**
  String get authErrorsPasswordTooShort;

  /// No description provided for @authErrorsUsernameTooShort.
  ///
  /// In en, this message translates to:
  /// **'Username must be at least 3 characters.'**
  String get authErrorsUsernameTooShort;

  /// No description provided for @authErrorsUsernameTooLong.
  ///
  /// In en, this message translates to:
  /// **'Username must be at most 20 characters.'**
  String get authErrorsUsernameTooLong;

  /// No description provided for @authErrorsUsernameCharset.
  ///
  /// In en, this message translates to:
  /// **'Only letters, numbers, and underscores.'**
  String get authErrorsUsernameCharset;

  /// No description provided for @authErrorsInvalidCredentials.
  ///
  /// In en, this message translates to:
  /// **'Invalid email or password.'**
  String get authErrorsInvalidCredentials;

  /// No description provided for @authErrorsEmailNotConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Your email isn\'t confirmed yet — check your inbox (and spam) for the link.'**
  String get authErrorsEmailNotConfirmed;

  /// No description provided for @authErrorsBlockedDetails.
  ///
  /// In en, this message translates to:
  /// **'We could not create an account with those details.'**
  String get authErrorsBlockedDetails;

  /// No description provided for @authErrorsUsernameTaken.
  ///
  /// In en, this message translates to:
  /// **'That username is taken — try another.'**
  String get authErrorsUsernameTaken;

  /// No description provided for @authErrorsUsernameTakenGoBack.
  ///
  /// In en, this message translates to:
  /// **'That username is taken — go back and pick another.'**
  String get authErrorsUsernameTakenGoBack;

  /// No description provided for @authErrorsSignupFailed.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong creating your account. Please try again.'**
  String get authErrorsSignupFailed;

  /// No description provided for @authErrorsUsernameSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save your username. Please try again.'**
  String get authErrorsUsernameSaveFailed;

  /// No description provided for @authErrorsLinkExpired.
  ///
  /// In en, this message translates to:
  /// **'Your reset link has expired. Please request a new one.'**
  String get authErrorsLinkExpired;

  /// No description provided for @authErrorsResetFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not update your password. Please try again.'**
  String get authErrorsResetFailed;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'fr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'fr':
      return AppLocalizationsFr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
