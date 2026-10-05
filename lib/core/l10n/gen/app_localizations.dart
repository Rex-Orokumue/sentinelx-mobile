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

  /// No description provided for @homeLoadError.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong loading this page.'**
  String get homeLoadError;

  /// No description provided for @accountTitle.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get accountTitle;

  /// No description provided for @accountLogIn.
  ///
  /// In en, this message translates to:
  /// **'Log in'**
  String get accountLogIn;

  /// No description provided for @accountCreateAccount.
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get accountCreateAccount;

  /// No description provided for @accountLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load your account.'**
  String get accountLoadFailed;

  /// No description provided for @accountRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get accountRetry;

  /// No description provided for @accountSignOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get accountSignOut;

  /// No description provided for @accountSigningOut.
  ///
  /// In en, this message translates to:
  /// **'Signing out…'**
  String get accountSigningOut;

  /// No description provided for @accountSignOutFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not sign out. Please try again.'**
  String get accountSignOutFailed;

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

  /// No description provided for @authErrorsForgotFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not send the reset link. Please try again.'**
  String get authErrorsForgotFailed;

  /// No description provided for @authErrorsResendFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not resend the confirmation link. Please try again.'**
  String get authErrorsResendFailed;

  /// No description provided for @authErrorsGoogleNotConfigured.
  ///
  /// In en, this message translates to:
  /// **'Google sign-in isn\'t set up yet.'**
  String get authErrorsGoogleNotConfigured;

  /// No description provided for @authErrorsGoogleFailed.
  ///
  /// In en, this message translates to:
  /// **'Google sign-in failed. Please try again.'**
  String get authErrorsGoogleFailed;

  /// No description provided for @termsEyebrow.
  ///
  /// In en, this message translates to:
  /// **'Legal'**
  String get termsEyebrow;

  /// No description provided for @termsTitle.
  ///
  /// In en, this message translates to:
  /// **'Terms of Service'**
  String get termsTitle;

  /// No description provided for @termsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'The terms that govern your use of the SentinelX platform.'**
  String get termsSubtitle;

  /// No description provided for @termsMetaUpdated.
  ///
  /// In en, this message translates to:
  /// **'Last updated September 2026'**
  String get termsMetaUpdated;

  /// No description provided for @termsSummary.
  ///
  /// In en, this message translates to:
  /// **'The short version: you must be 13 or older, one account per person, and you play fair — real results, backed by proof. Prize money pays to your bank through Paystack after an ID check. SX Coins are platform points with no cash value. Nigerian law applies. This summary is not the legal text — the sections below are.'**
  String get termsSummary;

  /// No description provided for @termsMetaTitle.
  ///
  /// In en, this message translates to:
  /// **'Terms of Service'**
  String get termsMetaTitle;

  /// No description provided for @termsMetaDescription.
  ///
  /// In en, this message translates to:
  /// **'The terms that govern using the SentinelX Esports platform.'**
  String get termsMetaDescription;

  /// No description provided for @termsS1Heading.
  ///
  /// In en, this message translates to:
  /// **'1. Who We Are'**
  String get termsS1Heading;

  /// No description provided for @termsS1P1.
  ///
  /// In en, this message translates to:
  /// **'SentinelX Esports is a mobile esports platform operated by Samuel Chinoyerem Akpoke (“we”, “us”, “our”). We are based in Nigeria and our platform is available at sentinelxesports.com.ng.'**
  String get termsS1P1;

  /// No description provided for @termsS1P2.
  ///
  /// In en, this message translates to:
  /// **'By creating an account or using any part of SentinelX, you agree to these Terms of Service. If you do not agree, please do not use the platform.'**
  String get termsS1P2;

  /// No description provided for @termsS2Heading.
  ///
  /// In en, this message translates to:
  /// **'2. Eligibility'**
  String get termsS2Heading;

  /// No description provided for @termsS2P1.
  ///
  /// In en, this message translates to:
  /// **'You must be at least 13 years old to create an account. If you are under 18, you confirm that you have permission from a parent or guardian to use the platform. Players under 18 may not withdraw prize money without verifiable parental or guardian consent.'**
  String get termsS2P1;

  /// No description provided for @termsS2P2.
  ///
  /// In en, this message translates to:
  /// **'You may only hold one account. Creating multiple accounts to gain an unfair advantage is prohibited and will result in a permanent ban.'**
  String get termsS2P2;

  /// No description provided for @termsS3Heading.
  ///
  /// In en, this message translates to:
  /// **'3. Your Account'**
  String get termsS3Heading;

  /// No description provided for @termsS3P1.
  ///
  /// In en, this message translates to:
  /// **'You are responsible for keeping your login details secure. Do not share your password with anyone. You are responsible for all activity that takes place under your account.'**
  String get termsS3P1;

  /// No description provided for @termsS3P2.
  ///
  /// In en, this message translates to:
  /// **'If you believe your account has been compromised, contact us immediately at <email>sentinelxesports@gmail.com</email>.'**
  String get termsS3P2;

  /// No description provided for @termsS4Heading.
  ///
  /// In en, this message translates to:
  /// **'4. Tournaments and Entry Fees'**
  String get termsS4Heading;

  /// No description provided for @termsS4P1.
  ///
  /// In en, this message translates to:
  /// **'Tournament entry fees are set per event and displayed clearly before registration. The current standard fee is ₦500. By registering and completing payment, you confirm your intent to participate.'**
  String get termsS4P1;

  /// No description provided for @termsS4P2.
  ///
  /// In en, this message translates to:
  /// **'Entry fees are processed securely by Paystack. We do not store your card details.'**
  String get termsS4P2;

  /// No description provided for @termsS4P3.
  ///
  /// In en, this message translates to:
  /// **'SX Coins may be used to reduce or eliminate entry fees where that option is offered. See the <link>Refund Policy</link> for how cancellations are handled.'**
  String get termsS4P3;

  /// No description provided for @termsS5Heading.
  ///
  /// In en, this message translates to:
  /// **'5. Match Rules and Fair Play'**
  String get termsS5Heading;

  /// No description provided for @termsS5Intro.
  ///
  /// In en, this message translates to:
  /// **'All players must compete honestly. The following are prohibited:'**
  String get termsS5Intro;

  /// No description provided for @termsS5List.
  ///
  /// In en, this message translates to:
  /// **'<li>Submitting false or manipulated match results</li><li>Using external tools, scripts, or exploits to gain an advantage</li><li>Colluding with an opponent to produce a predetermined result</li><li>Threatening, harassing, or abusing opponents</li>'**
  String get termsS5List;

  /// No description provided for @termsS5P2.
  ///
  /// In en, this message translates to:
  /// **'Match results must be submitted with supporting evidence (screenshot and screen recording). Admin decisions on disputed results are final. Full conduct and match rules are in the <link>Tournament Rules</link>.'**
  String get termsS5P2;

  /// No description provided for @termsS5P3.
  ///
  /// In en, this message translates to:
  /// **'A no-show — failing to appear for your scheduled match without notice — results in a forfeit and a penalty to your SX Score.'**
  String get termsS5P3;

  /// No description provided for @termsS6Heading.
  ///
  /// In en, this message translates to:
  /// **'6. Prizes and Withdrawals'**
  String get termsS6Heading;

  /// No description provided for @termsS6P1.
  ///
  /// In en, this message translates to:
  /// **'Prize money is paid to the bank account you link to your player dashboard via Paystack. You must complete identity verification before your first withdrawal.'**
  String get termsS6P1;

  /// No description provided for @termsS6P2.
  ///
  /// In en, this message translates to:
  /// **'We aim to process approved withdrawals within 1–5 business days. We are not responsible for delays caused by your bank.'**
  String get termsS6P2;

  /// No description provided for @termsS7Heading.
  ///
  /// In en, this message translates to:
  /// **'7. SX Coins'**
  String get termsS7Heading;

  /// No description provided for @termsS7P1.
  ///
  /// In en, this message translates to:
  /// **'SX Coins are a virtual in-platform currency. They are earned by competing and spending time on the platform. SX Coins have no monetary value and cannot be exchanged for cash. They may be used within the platform for entry fee discounts, community features, and the in-platform store. SX Coins may also be staked in community wagering (see section 8), and can be lost if your wager does not win.'**
  String get termsS7P1;

  /// No description provided for @termsS8Heading.
  ///
  /// In en, this message translates to:
  /// **'8. Community Wagering (SX Coins)'**
  String get termsS8Heading;

  /// No description provided for @termsS8P1.
  ///
  /// In en, this message translates to:
  /// **'You may stake SX Coins on the outcome of a match you are not playing in. Wagering is optional and uses SX Coins only.'**
  String get termsS8P1;

  /// No description provided for @termsS8List.
  ///
  /// In en, this message translates to:
  /// **'<li>Wagering opens once both players are confirmed for a scheduled match and closes 15 minutes before the scheduled start time. For matches scheduled across a full day, it closes 24 hours after that day begins.</li><li>A 5% platform fee is taken from the losing pool. Winnings are paid in SX Coins only.</li><li>Wagers settle automatically from the admin-confirmed match result, and that settlement is final.</li><li>If a match is voided or a result is overturned, every stake is returned in full.</li>'**
  String get termsS8List;

  /// No description provided for @termsS8P2.
  ///
  /// In en, this message translates to:
  /// **'Because SX Coins have no monetary value and cannot be exchanged for cash, community wagering is not betting for money.'**
  String get termsS8P2;

  /// No description provided for @termsS9Heading.
  ///
  /// In en, this message translates to:
  /// **'9. Gaming Exchange'**
  String get termsS9Heading;

  /// No description provided for @termsS9P1.
  ///
  /// In en, this message translates to:
  /// **'The Gaming Exchange (powered by Zolarux escrow) allows players to buy and sell gaming accounts and in-game items. SentinelX provides the platform and escrow infrastructure. We are not party to the transaction between buyer and seller and are not liable for disputes that arise from transactions conducted outside the platform\'s escrow system. See <link>how escrow works</link> for the step-by-step.'**
  String get termsS9P1;

  /// No description provided for @termsS10Heading.
  ///
  /// In en, this message translates to:
  /// **'10. Community Standards'**
  String get termsS10Heading;

  /// No description provided for @termsS10P1.
  ///
  /// In en, this message translates to:
  /// **'You agree to treat all other members of the SentinelX community with respect. Hate speech, discrimination, threats, and harassment are not tolerated and will result in suspension or permanent ban. See our <link>Community Rules</link> for the full standards.'**
  String get termsS10P1;

  /// No description provided for @termsS11Heading.
  ///
  /// In en, this message translates to:
  /// **'11. Intellectual Property'**
  String get termsS11Heading;

  /// No description provided for @termsS11P1.
  ///
  /// In en, this message translates to:
  /// **'All SentinelX branding, design, and original content is owned by SentinelX Esports. You may not reproduce, copy, or distribute our content without written permission. Content you post (match screenshots, community posts) remains yours, but you grant us a licence to display it on the platform.'**
  String get termsS11P1;

  /// No description provided for @termsS12Heading.
  ///
  /// In en, this message translates to:
  /// **'12. Limitation of Liability'**
  String get termsS12Heading;

  /// No description provided for @termsS12P1.
  ///
  /// In en, this message translates to:
  /// **'SentinelX Esports is not liable for indirect, incidental, or consequential losses arising from your use of the platform. Our total liability to you for any claim shall not exceed the total entry fees you have paid to us in the 3 months prior to the claim.'**
  String get termsS12P1;

  /// No description provided for @termsS12P2.
  ///
  /// In en, this message translates to:
  /// **'We do not guarantee uninterrupted access to the platform. We will make reasonable efforts to restore service promptly in the event of downtime.'**
  String get termsS12P2;

  /// No description provided for @termsS13Heading.
  ///
  /// In en, this message translates to:
  /// **'13. Changes to These Terms'**
  String get termsS13Heading;

  /// No description provided for @termsS13P1.
  ///
  /// In en, this message translates to:
  /// **'We may update these Terms from time to time. We will notify you via the platform or email when significant changes are made. Continuing to use SentinelX after changes are posted means you accept the updated terms.'**
  String get termsS13P1;

  /// No description provided for @termsS14Heading.
  ///
  /// In en, this message translates to:
  /// **'14. Governing Law'**
  String get termsS14Heading;

  /// No description provided for @termsS14P1.
  ///
  /// In en, this message translates to:
  /// **'These Terms are governed by the laws of the Federal Republic of Nigeria. Any disputes shall be subject to the jurisdiction of Nigerian courts.'**
  String get termsS14P1;

  /// No description provided for @termsS15Heading.
  ///
  /// In en, this message translates to:
  /// **'15. Contact'**
  String get termsS15Heading;

  /// No description provided for @termsS15P1.
  ///
  /// In en, this message translates to:
  /// **'Questions about these Terms? Email us at <email>sentinelxesports@gmail.com</email> or message us on WhatsApp: <whatsapp>+234 903 239 5685</whatsapp>.'**
  String get termsS15P1;

  /// No description provided for @cmpTabAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get cmpTabAll;

  /// No description provided for @cmpTabLive.
  ///
  /// In en, this message translates to:
  /// **'Live'**
  String get cmpTabLive;

  /// No description provided for @cmpTabUpcoming.
  ///
  /// In en, this message translates to:
  /// **'Upcoming'**
  String get cmpTabUpcoming;

  /// No description provided for @cmpTabCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get cmpTabCompleted;

  /// No description provided for @cmpAllGames.
  ///
  /// In en, this message translates to:
  /// **'All games'**
  String get cmpAllGames;

  /// No description provided for @cmpEmpty.
  ///
  /// In en, this message translates to:
  /// **'No tournaments here yet.'**
  String get cmpEmpty;

  /// No description provided for @cmpLoadError.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load this. Check your connection and try again.'**
  String get cmpLoadError;

  /// No description provided for @cmpRetry.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get cmpRetry;

  /// No description provided for @cmpLoadMore.
  ///
  /// In en, this message translates to:
  /// **'Load more'**
  String get cmpLoadMore;

  /// No description provided for @cmpEntryFee.
  ///
  /// In en, this message translates to:
  /// **'Entry fee'**
  String get cmpEntryFee;

  /// No description provided for @cmpFree.
  ///
  /// In en, this message translates to:
  /// **'Free'**
  String get cmpFree;

  /// No description provided for @cmpPrizePool.
  ///
  /// In en, this message translates to:
  /// **'Prize pool'**
  String get cmpPrizePool;

  /// No description provided for @cmpSecondPlace.
  ///
  /// In en, this message translates to:
  /// **'2nd place'**
  String get cmpSecondPlace;

  /// No description provided for @cmpThirdPlace.
  ///
  /// In en, this message translates to:
  /// **'3rd place'**
  String get cmpThirdPlace;

  /// No description provided for @cmpMaxPlayers.
  ///
  /// In en, this message translates to:
  /// **'{count} players max'**
  String cmpMaxPlayers(int count);

  /// No description provided for @cmpRules.
  ///
  /// In en, this message translates to:
  /// **'Rules'**
  String get cmpRules;

  /// No description provided for @cmpViewBracket.
  ///
  /// In en, this message translates to:
  /// **'View bracket'**
  String get cmpViewBracket;

  /// No description provided for @cmpShareWhatsapp.
  ///
  /// In en, this message translates to:
  /// **'Share on WhatsApp'**
  String get cmpShareWhatsapp;

  /// No description provided for @cmpShareText.
  ///
  /// In en, this message translates to:
  /// **'Join {title} on Sentinel X: {url}'**
  String cmpShareText(String title, String url);

  /// No description provided for @cmpCtaRegister.
  ///
  /// In en, this message translates to:
  /// **'Register'**
  String get cmpCtaRegister;

  /// No description provided for @cmpCtaResume.
  ///
  /// In en, this message translates to:
  /// **'Resume payment'**
  String get cmpCtaResume;

  /// No description provided for @cmpCtaLogin.
  ///
  /// In en, this message translates to:
  /// **'Log in to register'**
  String get cmpCtaLogin;

  /// No description provided for @cmpCtaJoinWaitlist.
  ///
  /// In en, this message translates to:
  /// **'Join waitlist'**
  String get cmpCtaJoinWaitlist;

  /// No description provided for @cmpViewInvitations.
  ///
  /// In en, this message translates to:
  /// **'View my invitations'**
  String get cmpViewInvitations;

  /// No description provided for @cmpStateRegistered.
  ///
  /// In en, this message translates to:
  /// **'You\'re registered.'**
  String get cmpStateRegistered;

  /// No description provided for @cmpStateWaitlisted.
  ///
  /// In en, this message translates to:
  /// **'You\'re on the waitlist.'**
  String get cmpStateWaitlisted;

  /// No description provided for @cmpStateFull.
  ///
  /// In en, this message translates to:
  /// **'This tournament is full.'**
  String get cmpStateFull;

  /// No description provided for @cmpStateEnded.
  ///
  /// In en, this message translates to:
  /// **'This tournament has ended.'**
  String get cmpStateEnded;

  /// No description provided for @cmpStateInvitationOnly.
  ///
  /// In en, this message translates to:
  /// **'This tournament is invitation-only.'**
  String get cmpStateInvitationOnly;

  /// No description provided for @cmpFeeWaived.
  ///
  /// In en, this message translates to:
  /// **'Free entry — waiver applied'**
  String get cmpFeeWaived;

  /// No description provided for @cmpFieldDisplayName.
  ///
  /// In en, this message translates to:
  /// **'Display name'**
  String get cmpFieldDisplayName;

  /// No description provided for @cmpFieldWhatsapp.
  ///
  /// In en, this message translates to:
  /// **'WhatsApp number'**
  String get cmpFieldWhatsapp;

  /// No description provided for @cmpAgreeRules.
  ///
  /// In en, this message translates to:
  /// **'I have read and agree to the rules'**
  String get cmpAgreeRules;

  /// No description provided for @cmpCoinsTitle.
  ///
  /// In en, this message translates to:
  /// **'Use SX Coins'**
  String get cmpCoinsTitle;

  /// No description provided for @cmpCoinsNone.
  ///
  /// In en, this message translates to:
  /// **'Don\'t use coins'**
  String get cmpCoinsNone;

  /// No description provided for @cmpCoinsOption.
  ///
  /// In en, this message translates to:
  /// **'{coins} coins (−₦{naira})'**
  String cmpCoinsOption(int coins, String naira);

  /// No description provided for @cmpSubmitRegister.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get cmpSubmitRegister;

  /// No description provided for @cmpSubmitWaitlist.
  ///
  /// In en, this message translates to:
  /// **'Join waitlist'**
  String get cmpSubmitWaitlist;

  /// No description provided for @cmpSubmitting.
  ///
  /// In en, this message translates to:
  /// **'Working…'**
  String get cmpSubmitting;

  /// No description provided for @cmpValDisplayName.
  ///
  /// In en, this message translates to:
  /// **'Enter a name (1–60 characters).'**
  String get cmpValDisplayName;

  /// No description provided for @cmpValWhatsapp.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid WhatsApp number.'**
  String get cmpValWhatsapp;

  /// No description provided for @cmpValRules.
  ///
  /// In en, this message translates to:
  /// **'Please agree to the rules.'**
  String get cmpValRules;

  /// No description provided for @cmpPayConfirming.
  ///
  /// In en, this message translates to:
  /// **'Confirming your payment…'**
  String get cmpPayConfirming;

  /// No description provided for @cmpPaySuccess.
  ///
  /// In en, this message translates to:
  /// **'You\'re in! Payment confirmed.'**
  String get cmpPaySuccess;

  /// No description provided for @cmpPayNotConfirmed.
  ///
  /// In en, this message translates to:
  /// **'We haven\'t seen your payment yet. If you were charged it will confirm shortly — check back in a minute.'**
  String get cmpPayNotConfirmed;

  /// No description provided for @cmpPayCancelled.
  ///
  /// In en, this message translates to:
  /// **'Payment window closed. You can resume from the tournament page.'**
  String get cmpPayCancelled;

  /// No description provided for @cmpConfirmedFree.
  ///
  /// In en, this message translates to:
  /// **'You\'re registered!'**
  String get cmpConfirmedFree;

  /// No description provided for @cmpWaitlistJoined.
  ///
  /// In en, this message translates to:
  /// **'You\'re on the waitlist.'**
  String get cmpWaitlistJoined;

  /// No description provided for @cmpInvTitle.
  ///
  /// In en, this message translates to:
  /// **'My invitations'**
  String get cmpInvTitle;

  /// No description provided for @cmpInvEmpty.
  ///
  /// In en, this message translates to:
  /// **'No pending invitations.'**
  String get cmpInvEmpty;

  /// No description provided for @cmpInvAccept.
  ///
  /// In en, this message translates to:
  /// **'Accept'**
  String get cmpInvAccept;

  /// No description provided for @cmpInvDecline.
  ///
  /// In en, this message translates to:
  /// **'Decline'**
  String get cmpInvDecline;

  /// No description provided for @cmpInvExpires.
  ///
  /// In en, this message translates to:
  /// **'Expires {date}'**
  String cmpInvExpires(String date);

  /// No description provided for @cmpInvDeclined.
  ///
  /// In en, this message translates to:
  /// **'Invitation declined.'**
  String get cmpInvDeclined;

  /// No description provided for @cmpGamesTitle.
  ///
  /// In en, this message translates to:
  /// **'Games'**
  String get cmpGamesTitle;

  /// No description provided for @cmpGamesEmpty.
  ///
  /// In en, this message translates to:
  /// **'No games yet.'**
  String get cmpGamesEmpty;

  /// No description provided for @cmpEditProfile.
  ///
  /// In en, this message translates to:
  /// **'Edit profile'**
  String get cmpEditProfile;

  /// No description provided for @cmpFieldBio.
  ///
  /// In en, this message translates to:
  /// **'Bio'**
  String get cmpFieldBio;

  /// No description provided for @cmpFieldCountry.
  ///
  /// In en, this message translates to:
  /// **'Country'**
  String get cmpFieldCountry;

  /// No description provided for @cmpFieldUsername.
  ///
  /// In en, this message translates to:
  /// **'Username (can be changed once)'**
  String get cmpFieldUsername;

  /// No description provided for @cmpSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get cmpSave;

  /// No description provided for @cmpSaved.
  ///
  /// In en, this message translates to:
  /// **'Profile saved.'**
  String get cmpSaved;

  /// No description provided for @cmpValBio.
  ///
  /// In en, this message translates to:
  /// **'Bio must be 280 characters or fewer.'**
  String get cmpValBio;

  /// No description provided for @cmpValCountry.
  ///
  /// In en, this message translates to:
  /// **'Country is too long (60 max).'**
  String get cmpValCountry;

  /// No description provided for @cmpEcGeneric.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get cmpEcGeneric;

  /// No description provided for @cmpEcNetwork.
  ///
  /// In en, this message translates to:
  /// **'No connection. Check your internet and try again.'**
  String get cmpEcNetwork;

  /// No description provided for @cmpEcSession.
  ///
  /// In en, this message translates to:
  /// **'Your session expired. Please log in again.'**
  String get cmpEcSession;

  /// No description provided for @cmpEcTournamentNotFound.
  ///
  /// In en, this message translates to:
  /// **'Tournament not found.'**
  String get cmpEcTournamentNotFound;

  /// No description provided for @cmpEcRulesRequired.
  ///
  /// In en, this message translates to:
  /// **'Please confirm you agree to the rules.'**
  String get cmpEcRulesRequired;

  /// No description provided for @cmpEcAlreadyRegistered.
  ///
  /// In en, this message translates to:
  /// **'You\'re already registered for this tournament.'**
  String get cmpEcAlreadyRegistered;

  /// No description provided for @cmpEcTournamentFull.
  ///
  /// In en, this message translates to:
  /// **'This tournament is full.'**
  String get cmpEcTournamentFull;

  /// No description provided for @cmpEcInvitationOnly.
  ///
  /// In en, this message translates to:
  /// **'This tournament is invitation-only.'**
  String get cmpEcInvitationOnly;

  /// No description provided for @cmpEcRegistrationClosed.
  ///
  /// In en, this message translates to:
  /// **'Registration is closed.'**
  String get cmpEcRegistrationClosed;

  /// No description provided for @cmpEcInsufficientCoins.
  ///
  /// In en, this message translates to:
  /// **'Not enough SX Coins for this discount.'**
  String get cmpEcInsufficientCoins;

  /// No description provided for @cmpEcPaymentInit.
  ///
  /// In en, this message translates to:
  /// **'Payment couldn\'t be started. Please try again.'**
  String get cmpEcPaymentInit;

  /// No description provided for @cmpEcWaitlistNotOpen.
  ///
  /// In en, this message translates to:
  /// **'The waitlist opens once registration closes.'**
  String get cmpEcWaitlistNotOpen;

  /// No description provided for @cmpEcAlreadyWaitlisted.
  ///
  /// In en, this message translates to:
  /// **'You\'re already on the waitlist.'**
  String get cmpEcAlreadyWaitlisted;

  /// No description provided for @cmpEcInProgress.
  ///
  /// In en, this message translates to:
  /// **'Still processing your request. Please wait a moment and try again.'**
  String get cmpEcInProgress;

  /// No description provided for @cmpEcInvitationNotFound.
  ///
  /// In en, this message translates to:
  /// **'Invitation not found.'**
  String get cmpEcInvitationNotFound;

  /// No description provided for @cmpEcInvitationGone.
  ///
  /// In en, this message translates to:
  /// **'This invitation is no longer available.'**
  String get cmpEcInvitationGone;

  /// No description provided for @cmpEcInvitationExpired.
  ///
  /// In en, this message translates to:
  /// **'This invitation has expired.'**
  String get cmpEcInvitationExpired;

  /// No description provided for @cmpEcUsernameTaken.
  ///
  /// In en, this message translates to:
  /// **'That username is already taken.'**
  String get cmpEcUsernameTaken;

  /// No description provided for @cmpEcUsernameLocked.
  ///
  /// In en, this message translates to:
  /// **'Your username has already been changed once.'**
  String get cmpEcUsernameLocked;

  /// No description provided for @cmpEcSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save your profile. Please try again.'**
  String get cmpEcSaveFailed;

  /// No description provided for @cmpHomeGamesTile.
  ///
  /// In en, this message translates to:
  /// **'Games'**
  String get cmpHomeGamesTile;

  /// No description provided for @cmpHomeInvitationsTile.
  ///
  /// In en, this message translates to:
  /// **'My invitations'**
  String get cmpHomeInvitationsTile;

  /// No description provided for @cmpAccountEditProfile.
  ///
  /// In en, this message translates to:
  /// **'Edit profile'**
  String get cmpAccountEditProfile;

  /// No description provided for @cmpStatusRegistrationOpen.
  ///
  /// In en, this message translates to:
  /// **'Registration open'**
  String get cmpStatusRegistrationOpen;

  /// No description provided for @cmpStatusRegistrationClosed.
  ///
  /// In en, this message translates to:
  /// **'Registration closed'**
  String get cmpStatusRegistrationClosed;

  /// No description provided for @cmpStatusActive.
  ///
  /// In en, this message translates to:
  /// **'Live'**
  String get cmpStatusActive;

  /// No description provided for @cmpStatusCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get cmpStatusCompleted;

  /// No description provided for @cmpPayCheckAgain.
  ///
  /// In en, this message translates to:
  /// **'Check payment status'**
  String get cmpPayCheckAgain;

  /// No description provided for @cmpInvPayCancelled.
  ///
  /// In en, this message translates to:
  /// **'Payment window closed. If you were charged, it will confirm shortly.'**
  String get cmpInvPayCancelled;

  /// No description provided for @cmpValUsername.
  ///
  /// In en, this message translates to:
  /// **'Usernames are 3–20 letters, numbers or underscores.'**
  String get cmpValUsername;

  /// No description provided for @commonDeletedPlayer.
  ///
  /// In en, this message translates to:
  /// **'Deleted player'**
  String get commonDeletedPlayer;

  /// No description provided for @rankingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Leaderboards'**
  String get rankingsTitle;

  /// No description provided for @rankingsRankByScore.
  ///
  /// In en, this message translates to:
  /// **'Ranked by SX Score'**
  String get rankingsRankByScore;

  /// No description provided for @rankingsRankByWins.
  ///
  /// In en, this message translates to:
  /// **'Ranked by wins'**
  String get rankingsRankByWins;

  /// No description provided for @rankingsAllGames.
  ///
  /// In en, this message translates to:
  /// **'All games'**
  String get rankingsAllGames;

  /// No description provided for @rankingsAllRegions.
  ///
  /// In en, this message translates to:
  /// **'All regions'**
  String get rankingsAllRegions;

  /// No description provided for @rankingsYourRank.
  ///
  /// In en, this message translates to:
  /// **'Your rank'**
  String get rankingsYourRank;

  /// No description provided for @rankingsYou.
  ///
  /// In en, this message translates to:
  /// **'(you)'**
  String get rankingsYou;

  /// No description provided for @rankingsPrev.
  ///
  /// In en, this message translates to:
  /// **'Previous'**
  String get rankingsPrev;

  /// No description provided for @rankingsNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get rankingsNext;

  /// No description provided for @rankingsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No ranked players yet.'**
  String get rankingsEmpty;

  /// No description provided for @rankingsErrorRetry.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load. Tap to retry.'**
  String get rankingsErrorRetry;

  /// No description provided for @rankingsTrendNew.
  ///
  /// In en, this message translates to:
  /// **'New'**
  String get rankingsTrendNew;

  /// No description provided for @seasonsTitle.
  ///
  /// In en, this message translates to:
  /// **'Seasons'**
  String get seasonsTitle;

  /// No description provided for @seasonsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No seasons yet.'**
  String get seasonsEmpty;

  /// No description provided for @seasonsLeaderboardEmpty.
  ///
  /// In en, this message translates to:
  /// **'No season points awarded yet.'**
  String get seasonsLeaderboardEmpty;

  /// No description provided for @seasonsProvisional.
  ///
  /// In en, this message translates to:
  /// **'Provisional'**
  String get seasonsProvisional;

  /// No description provided for @seasonsProvisionalNote.
  ///
  /// In en, this message translates to:
  /// **'Points can still change while tournaments are in progress.'**
  String get seasonsProvisionalNote;

  /// No description provided for @seasonsTournaments.
  ///
  /// In en, this message translates to:
  /// **'Tournaments'**
  String get seasonsTournaments;

  /// No description provided for @seasonsInviteOnly.
  ///
  /// In en, this message translates to:
  /// **'Invite only'**
  String get seasonsInviteOnly;

  /// No description provided for @seasonsYou.
  ///
  /// In en, this message translates to:
  /// **'You'**
  String get seasonsYou;

  /// No description provided for @hallOfFameTitle.
  ///
  /// In en, this message translates to:
  /// **'Hall of Fame'**
  String get hallOfFameTitle;

  /// No description provided for @hallOfFameMvp.
  ///
  /// In en, this message translates to:
  /// **'All-Time MVP'**
  String get hallOfFameMvp;

  /// No description provided for @hallOfFameGoldenBoot.
  ///
  /// In en, this message translates to:
  /// **'Golden Boot'**
  String get hallOfFameGoldenBoot;

  /// No description provided for @hallOfFameChampionsCup.
  ///
  /// In en, this message translates to:
  /// **'Champions Cup'**
  String get hallOfFameChampionsCup;

  /// No description provided for @hallOfFameMasters.
  ///
  /// In en, this message translates to:
  /// **'Masters'**
  String get hallOfFameMasters;

  /// No description provided for @hallOfFameCommunityClub.
  ///
  /// In en, this message translates to:
  /// **'Community Club'**
  String get hallOfFameCommunityClub;

  /// No description provided for @hallOfFameOpen.
  ///
  /// In en, this message translates to:
  /// **'Open tournaments'**
  String get hallOfFameOpen;

  /// No description provided for @hallOfFameBronze.
  ///
  /// In en, this message translates to:
  /// **'Bronze finishes'**
  String get hallOfFameBronze;

  /// No description provided for @hallOfFameEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nothing here yet.'**
  String get hallOfFameEmpty;

  /// No description provided for @rankingsWinsCount.
  ///
  /// In en, this message translates to:
  /// **'{wins} wins'**
  String rankingsWinsCount(int wins);

  /// No description provided for @rankingsMatchesCount.
  ///
  /// In en, this message translates to:
  /// **'{matches} matches'**
  String rankingsMatchesCount(int matches);

  /// No description provided for @rankingsStreakValue.
  ///
  /// In en, this message translates to:
  /// **'{n}-win streak'**
  String rankingsStreakValue(int n);

  /// No description provided for @rankingsPageOf.
  ///
  /// In en, this message translates to:
  /// **'Page {page} of {total}'**
  String rankingsPageOf(int page, int total);

  /// No description provided for @rankingsPlayersRanked.
  ///
  /// In en, this message translates to:
  /// **'{n} players ranked'**
  String rankingsPlayersRanked(int n);

  /// No description provided for @seasonsPoints.
  ///
  /// In en, this message translates to:
  /// **'{n} pts'**
  String seasonsPoints(int n);

  /// No description provided for @hallOfFameRunnerUp.
  ///
  /// In en, this message translates to:
  /// **'Runner-up: {name}'**
  String hallOfFameRunnerUp(String name);

  /// No description provided for @commonLoadError.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load. Tap to retry.'**
  String get commonLoadError;

  /// No description provided for @playersTitle.
  ///
  /// In en, this message translates to:
  /// **'Players'**
  String get playersTitle;

  /// No description provided for @playersSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search players'**
  String get playersSearchHint;

  /// No description provided for @playersEmpty.
  ///
  /// In en, this message translates to:
  /// **'No players found.'**
  String get playersEmpty;

  /// No description provided for @playersNotFound.
  ///
  /// In en, this message translates to:
  /// **'Player not found.'**
  String get playersNotFound;

  /// No description provided for @profileFollow.
  ///
  /// In en, this message translates to:
  /// **'Follow'**
  String get profileFollow;

  /// No description provided for @profileFollowing.
  ///
  /// In en, this message translates to:
  /// **'Following'**
  String get profileFollowing;

  /// No description provided for @profileFollowsYou.
  ///
  /// In en, this message translates to:
  /// **'Follows you'**
  String get profileFollowsYou;

  /// No description provided for @profileFollowersCount.
  ///
  /// In en, this message translates to:
  /// **'{n} followers'**
  String profileFollowersCount(int n);

  /// No description provided for @profileFollowingCount.
  ///
  /// In en, this message translates to:
  /// **'{n} following'**
  String profileFollowingCount(int n);

  /// No description provided for @profileStatMatches.
  ///
  /// In en, this message translates to:
  /// **'Matches'**
  String get profileStatMatches;

  /// No description provided for @profileStatWins.
  ///
  /// In en, this message translates to:
  /// **'Wins'**
  String get profileStatWins;

  /// No description provided for @profileStatLosses.
  ///
  /// In en, this message translates to:
  /// **'Losses'**
  String get profileStatLosses;

  /// No description provided for @profileStatGoalsFor.
  ///
  /// In en, this message translates to:
  /// **'Goals for'**
  String get profileStatGoalsFor;

  /// No description provided for @profileStatGoalsAgainst.
  ///
  /// In en, this message translates to:
  /// **'Goals against'**
  String get profileStatGoalsAgainst;

  /// No description provided for @profileStatTitles.
  ///
  /// In en, this message translates to:
  /// **'Titles'**
  String get profileStatTitles;

  /// No description provided for @profileStatTournaments.
  ///
  /// In en, this message translates to:
  /// **'Tournaments'**
  String get profileStatTournaments;

  /// No description provided for @profileStatStreak.
  ///
  /// In en, this message translates to:
  /// **'Win streak'**
  String get profileStatStreak;

  /// No description provided for @profileStatRank.
  ///
  /// In en, this message translates to:
  /// **'Global rank'**
  String get profileStatRank;

  /// No description provided for @profileRankOf.
  ///
  /// In en, this message translates to:
  /// **'#{rank} of {total}'**
  String profileRankOf(int rank, int total);

  /// No description provided for @profileRankUnranked.
  ///
  /// In en, this message translates to:
  /// **'Unranked'**
  String get profileRankUnranked;

  /// No description provided for @profileSxScore.
  ///
  /// In en, this message translates to:
  /// **'SX Score {n}'**
  String profileSxScore(int n);

  /// No description provided for @profileCategoryStats.
  ///
  /// In en, this message translates to:
  /// **'Goals by category'**
  String get profileCategoryStats;

  /// No description provided for @profileTitlesHeading.
  ///
  /// In en, this message translates to:
  /// **'Titles'**
  String get profileTitlesHeading;

  /// No description provided for @profileNoTitles.
  ///
  /// In en, this message translates to:
  /// **'No titles yet.'**
  String get profileNoTitles;

  /// No description provided for @profileRecentMatches.
  ///
  /// In en, this message translates to:
  /// **'Recent matches'**
  String get profileRecentMatches;

  /// No description provided for @profileNoMatches.
  ///
  /// In en, this message translates to:
  /// **'No matches yet.'**
  String get profileNoMatches;

  /// No description provided for @profileOutcomeWin.
  ///
  /// In en, this message translates to:
  /// **'Win'**
  String get profileOutcomeWin;

  /// No description provided for @profileOutcomeLoss.
  ///
  /// In en, this message translates to:
  /// **'Loss'**
  String get profileOutcomeLoss;

  /// No description provided for @profileOutcomeDraw.
  ///
  /// In en, this message translates to:
  /// **'Draw'**
  String get profileOutcomeDraw;

  /// No description provided for @profileAchievements.
  ///
  /// In en, this message translates to:
  /// **'Achievements'**
  String get profileAchievements;

  /// No description provided for @profileAchievementsProgress.
  ///
  /// In en, this message translates to:
  /// **'{unlocked}/{total} unlocked'**
  String profileAchievementsProgress(int unlocked, int total);

  /// No description provided for @profileAchievementLocked.
  ///
  /// In en, this message translates to:
  /// **'Locked'**
  String get profileAchievementLocked;

  /// No description provided for @profilePosts.
  ///
  /// In en, this message translates to:
  /// **'Recent posts'**
  String get profilePosts;

  /// No description provided for @profileGallery.
  ///
  /// In en, this message translates to:
  /// **'Gallery'**
  String get profileGallery;

  /// No description provided for @followErrorSelf.
  ///
  /// In en, this message translates to:
  /// **'You can\'t follow yourself.'**
  String get followErrorSelf;

  /// No description provided for @followErrorBlocked.
  ///
  /// In en, this message translates to:
  /// **'You can\'t follow this player.'**
  String get followErrorBlocked;

  /// No description provided for @followErrorNotFound.
  ///
  /// In en, this message translates to:
  /// **'This player no longer exists.'**
  String get followErrorNotFound;

  /// No description provided for @followErrorGeneric.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t update. Please try again.'**
  String get followErrorGeneric;

  /// No description provided for @followersTitle.
  ///
  /// In en, this message translates to:
  /// **'Followers'**
  String get followersTitle;

  /// No description provided for @followingTitle.
  ///
  /// In en, this message translates to:
  /// **'Following'**
  String get followingTitle;

  /// No description provided for @followersEmpty.
  ///
  /// In en, this message translates to:
  /// **'No followers yet.'**
  String get followersEmpty;

  /// No description provided for @followingEmpty.
  ///
  /// In en, this message translates to:
  /// **'Not following anyone yet.'**
  String get followingEmpty;

  /// No description provided for @accountMyProgress.
  ///
  /// In en, this message translates to:
  /// **'My progress'**
  String get accountMyProgress;

  /// No description provided for @progressTitle.
  ///
  /// In en, this message translates to:
  /// **'My progress'**
  String get progressTitle;

  /// No description provided for @progressSignIn.
  ///
  /// In en, this message translates to:
  /// **'Log in to see your progress.'**
  String get progressSignIn;

  /// No description provided for @progressXpHeading.
  ///
  /// In en, this message translates to:
  /// **'XP'**
  String get progressXpHeading;

  /// No description provided for @progressXpToNext.
  ///
  /// In en, this message translates to:
  /// **'{into} / {needed} XP to {tier}'**
  String progressXpToNext(int into, int needed, String tier);

  /// No description provided for @progressMaxTier.
  ///
  /// In en, this message translates to:
  /// **'Max tier reached'**
  String get progressMaxTier;

  /// No description provided for @progressSxScore.
  ///
  /// In en, this message translates to:
  /// **'SX Score'**
  String get progressSxScore;

  /// No description provided for @progressCoins.
  ///
  /// In en, this message translates to:
  /// **'Coins'**
  String get progressCoins;

  /// No description provided for @progressSeasonHeading.
  ///
  /// In en, this message translates to:
  /// **'Season standing'**
  String get progressSeasonHeading;

  /// No description provided for @progressSeasonRank.
  ///
  /// In en, this message translates to:
  /// **'Rank #{rank}'**
  String progressSeasonRank(int rank);

  /// No description provided for @progressSeasonUnranked.
  ///
  /// In en, this message translates to:
  /// **'Unranked'**
  String get progressSeasonUnranked;

  /// No description provided for @progressSeasonMonthly.
  ///
  /// In en, this message translates to:
  /// **'This month'**
  String get progressSeasonMonthly;

  /// No description provided for @progressSeasonNone.
  ///
  /// In en, this message translates to:
  /// **'No active season.'**
  String get progressSeasonNone;

  /// No description provided for @progressToRankSixteen.
  ///
  /// In en, this message translates to:
  /// **'Rank 16 has {n} pts'**
  String progressToRankSixteen(int n);

  /// No description provided for @progressHistoryXp.
  ///
  /// In en, this message translates to:
  /// **'XP history'**
  String get progressHistoryXp;

  /// No description provided for @progressHistoryScore.
  ///
  /// In en, this message translates to:
  /// **'SX Score history'**
  String get progressHistoryScore;

  /// No description provided for @progressHistoryCoins.
  ///
  /// In en, this message translates to:
  /// **'Coin history'**
  String get progressHistoryCoins;

  /// No description provided for @historyEmpty.
  ///
  /// In en, this message translates to:
  /// **'No activity yet.'**
  String get historyEmpty;

  /// No description provided for @historyLoadMoreError.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load more. Tap to retry.'**
  String get historyLoadMoreError;

  /// No description provided for @historyBalanceAfter.
  ///
  /// In en, this message translates to:
  /// **'Balance {n}'**
  String historyBalanceAfter(int n);

  /// No description provided for @tierRecruit.
  ///
  /// In en, this message translates to:
  /// **'Recruit'**
  String get tierRecruit;

  /// No description provided for @tierGuardian.
  ///
  /// In en, this message translates to:
  /// **'Guardian'**
  String get tierGuardian;

  /// No description provided for @tierElite.
  ///
  /// In en, this message translates to:
  /// **'Elite'**
  String get tierElite;

  /// No description provided for @tierSentinel.
  ///
  /// In en, this message translates to:
  /// **'Sentinel'**
  String get tierSentinel;

  /// No description provided for @tierLegend.
  ///
  /// In en, this message translates to:
  /// **'Legend'**
  String get tierLegend;

  /// No description provided for @xpSourceMatchPlayed.
  ///
  /// In en, this message translates to:
  /// **'Match played'**
  String get xpSourceMatchPlayed;

  /// No description provided for @xpSourceMatchWon.
  ///
  /// In en, this message translates to:
  /// **'Match won'**
  String get xpSourceMatchWon;

  /// No description provided for @xpSourceTournamentEntered.
  ///
  /// In en, this message translates to:
  /// **'Tournament entered'**
  String get xpSourceTournamentEntered;

  /// No description provided for @xpSourceTournamentCompleted.
  ///
  /// In en, this message translates to:
  /// **'Tournament completed'**
  String get xpSourceTournamentCompleted;

  /// No description provided for @xpSourceTournamentPlacement.
  ///
  /// In en, this message translates to:
  /// **'Tournament placement'**
  String get xpSourceTournamentPlacement;

  /// No description provided for @xpSourceAchievementUnlocked.
  ///
  /// In en, this message translates to:
  /// **'Achievement unlocked'**
  String get xpSourceAchievementUnlocked;

  /// No description provided for @xpSourceDailyLogin.
  ///
  /// In en, this message translates to:
  /// **'Daily login'**
  String get xpSourceDailyLogin;

  /// No description provided for @xpSourceLoginStreak.
  ///
  /// In en, this message translates to:
  /// **'Login streak'**
  String get xpSourceLoginStreak;

  /// No description provided for @xpSourceCommunityActivity.
  ///
  /// In en, this message translates to:
  /// **'Community activity'**
  String get xpSourceCommunityActivity;

  /// No description provided for @xpSourceAdminGrant.
  ///
  /// In en, this message translates to:
  /// **'Admin grant'**
  String get xpSourceAdminGrant;

  /// No description provided for @scoreEventMatchCompleted.
  ///
  /// In en, this message translates to:
  /// **'Match completed'**
  String get scoreEventMatchCompleted;

  /// No description provided for @scoreEventNoShow.
  ///
  /// In en, this message translates to:
  /// **'No-show'**
  String get scoreEventNoShow;

  /// No description provided for @scoreEventRageQuit.
  ///
  /// In en, this message translates to:
  /// **'Left a match early'**
  String get scoreEventRageQuit;

  /// No description provided for @scoreEventDisputeLost.
  ///
  /// In en, this message translates to:
  /// **'Dispute lost'**
  String get scoreEventDisputeLost;

  /// No description provided for @scoreEventRatingReceived.
  ///
  /// In en, this message translates to:
  /// **'Rating received'**
  String get scoreEventRatingReceived;

  /// No description provided for @scoreEventAdminFlagConduct.
  ///
  /// In en, this message translates to:
  /// **'Conduct flag'**
  String get scoreEventAdminFlagConduct;

  /// No description provided for @scoreEventAdminFlagCheat.
  ///
  /// In en, this message translates to:
  /// **'Cheat flag'**
  String get scoreEventAdminFlagCheat;

  /// No description provided for @coinSourceMatchPlayed.
  ///
  /// In en, this message translates to:
  /// **'Match played'**
  String get coinSourceMatchPlayed;

  /// No description provided for @coinSourceMatchWon.
  ///
  /// In en, this message translates to:
  /// **'Match won'**
  String get coinSourceMatchWon;

  /// No description provided for @coinSourceTournamentPlacement.
  ///
  /// In en, this message translates to:
  /// **'Tournament placement'**
  String get coinSourceTournamentPlacement;

  /// No description provided for @coinSourceDailyLogin.
  ///
  /// In en, this message translates to:
  /// **'Daily login'**
  String get coinSourceDailyLogin;

  /// No description provided for @coinSourceLoginStreak.
  ///
  /// In en, this message translates to:
  /// **'Login streak'**
  String get coinSourceLoginStreak;

  /// No description provided for @coinSourceAchievementUnlocked.
  ///
  /// In en, this message translates to:
  /// **'Achievement unlocked'**
  String get coinSourceAchievementUnlocked;

  /// No description provided for @coinSourceStorePurchase.
  ///
  /// In en, this message translates to:
  /// **'Store purchase'**
  String get coinSourceStorePurchase;

  /// No description provided for @coinSourceCommunityActivity.
  ///
  /// In en, this message translates to:
  /// **'Community activity'**
  String get coinSourceCommunityActivity;

  /// No description provided for @coinSourceAdminGrant.
  ///
  /// In en, this message translates to:
  /// **'Admin grant'**
  String get coinSourceAdminGrant;

  /// No description provided for @coinSourceAdminDeduct.
  ///
  /// In en, this message translates to:
  /// **'Admin deduction'**
  String get coinSourceAdminDeduct;

  /// No description provided for @coinSourceWeeklyChallenge.
  ///
  /// In en, this message translates to:
  /// **'Weekly challenge'**
  String get coinSourceWeeklyChallenge;

  /// No description provided for @coinSourceBestPlayWinner.
  ///
  /// In en, this message translates to:
  /// **'Best Play winner'**
  String get coinSourceBestPlayWinner;

  /// No description provided for @coinSourceBestPlayRunnerUp.
  ///
  /// In en, this message translates to:
  /// **'Best Play runner-up'**
  String get coinSourceBestPlayRunnerUp;

  /// No description provided for @coinSourceEntryDiscount.
  ///
  /// In en, this message translates to:
  /// **'Entry discount'**
  String get coinSourceEntryDiscount;

  /// No description provided for @coinSourceEntryDiscountRefund.
  ///
  /// In en, this message translates to:
  /// **'Entry discount refund'**
  String get coinSourceEntryDiscountRefund;

  /// No description provided for @coinSourceWagerStake.
  ///
  /// In en, this message translates to:
  /// **'Wager stake'**
  String get coinSourceWagerStake;

  /// No description provided for @coinSourceWagerWon.
  ///
  /// In en, this message translates to:
  /// **'Wager won'**
  String get coinSourceWagerWon;

  /// No description provided for @coinSourceWagerRefund.
  ///
  /// In en, this message translates to:
  /// **'Wager refund'**
  String get coinSourceWagerRefund;

  /// No description provided for @coinSourcePostBoost.
  ///
  /// In en, this message translates to:
  /// **'Post boost'**
  String get coinSourcePostBoost;

  /// No description provided for @coinSourceReferralReward.
  ///
  /// In en, this message translates to:
  /// **'Referral reward'**
  String get coinSourceReferralReward;

  /// No description provided for @coinSourceReferralMilestone.
  ///
  /// In en, this message translates to:
  /// **'Referral milestone'**
  String get coinSourceReferralMilestone;

  /// No description provided for @coinSourceFriendlyStake.
  ///
  /// In en, this message translates to:
  /// **'Friendly stake'**
  String get coinSourceFriendlyStake;

  /// No description provided for @coinSourceFriendlyStakePayout.
  ///
  /// In en, this message translates to:
  /// **'Friendly payout'**
  String get coinSourceFriendlyStakePayout;

  /// No description provided for @mtcBracketTitle.
  ///
  /// In en, this message translates to:
  /// **'Bracket'**
  String get mtcBracketTitle;

  /// No description provided for @mtcTabGroups.
  ///
  /// In en, this message translates to:
  /// **'Groups'**
  String get mtcTabGroups;

  /// No description provided for @mtcTabFixtures.
  ///
  /// In en, this message translates to:
  /// **'Fixtures'**
  String get mtcTabFixtures;

  /// No description provided for @mtcTabKnockout.
  ///
  /// In en, this message translates to:
  /// **'Knockout'**
  String get mtcTabKnockout;

  /// No description provided for @mtcNoDrawYet.
  ///
  /// In en, this message translates to:
  /// **'The draw hasn\'t been made yet.'**
  String get mtcNoDrawYet;

  /// No description provided for @mtcChampion.
  ///
  /// In en, this message translates to:
  /// **'Champion'**
  String get mtcChampion;

  /// No description provided for @mtcThirdPlace.
  ///
  /// In en, this message translates to:
  /// **'Third place'**
  String get mtcThirdPlace;

  /// No description provided for @mtcNoWinner.
  ///
  /// In en, this message translates to:
  /// **'This tournament closed without a winner.'**
  String get mtcNoWinner;

  /// No description provided for @mtcGroupCol.
  ///
  /// In en, this message translates to:
  /// **'{group}'**
  String mtcGroupCol(String group);

  /// No description provided for @mtcColPlayed.
  ///
  /// In en, this message translates to:
  /// **'P'**
  String get mtcColPlayed;

  /// No description provided for @mtcColWins.
  ///
  /// In en, this message translates to:
  /// **'W'**
  String get mtcColWins;

  /// No description provided for @mtcColDraws.
  ///
  /// In en, this message translates to:
  /// **'D'**
  String get mtcColDraws;

  /// No description provided for @mtcColLosses.
  ///
  /// In en, this message translates to:
  /// **'L'**
  String get mtcColLosses;

  /// No description provided for @mtcColGoalDiff.
  ///
  /// In en, this message translates to:
  /// **'GD'**
  String get mtcColGoalDiff;

  /// No description provided for @mtcColPoints.
  ///
  /// In en, this message translates to:
  /// **'Pts'**
  String get mtcColPoints;

  /// No description provided for @mtcAdvancing.
  ///
  /// In en, this message translates to:
  /// **'Advancing'**
  String get mtcAdvancing;

  /// No description provided for @mtcFixtLive.
  ///
  /// In en, this message translates to:
  /// **'Live'**
  String get mtcFixtLive;

  /// No description provided for @mtcFixtUpcoming.
  ///
  /// In en, this message translates to:
  /// **'Upcoming'**
  String get mtcFixtUpcoming;

  /// No description provided for @mtcFixtCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get mtcFixtCompleted;

  /// No description provided for @mtcFixtDisputed.
  ///
  /// In en, this message translates to:
  /// **'Disputed or cancelled'**
  String get mtcFixtDisputed;

  /// No description provided for @mtcProjectedMatches.
  ///
  /// In en, this message translates to:
  /// **'{count} matches to come'**
  String mtcProjectedMatches(int count);

  /// No description provided for @mtcTbd.
  ///
  /// In en, this message translates to:
  /// **'To be announced'**
  String get mtcTbd;

  /// No description provided for @mtcVs.
  ///
  /// In en, this message translates to:
  /// **'vs'**
  String get mtcVs;

  /// No description provided for @mtcStages.
  ///
  /// In en, this message translates to:
  /// **'Stages'**
  String get mtcStages;

  /// No description provided for @mtcStageStandingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Standings'**
  String get mtcStageStandingsTitle;

  /// No description provided for @mtcColRank.
  ///
  /// In en, this message translates to:
  /// **'#'**
  String get mtcColRank;

  /// No description provided for @mtcColKills.
  ///
  /// In en, this message translates to:
  /// **'Kills'**
  String get mtcColKills;

  /// No description provided for @mtcTieUnresolved.
  ///
  /// In en, this message translates to:
  /// **'Tied — awaiting tiebreak'**
  String get mtcTieUnresolved;

  /// No description provided for @mtcMatchTitle.
  ///
  /// In en, this message translates to:
  /// **'Match'**
  String get mtcMatchTitle;

  /// No description provided for @mtcStatusScheduled.
  ///
  /// In en, this message translates to:
  /// **'Scheduled'**
  String get mtcStatusScheduled;

  /// No description provided for @mtcStatusLive.
  ///
  /// In en, this message translates to:
  /// **'Live'**
  String get mtcStatusLive;

  /// No description provided for @mtcStatusCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get mtcStatusCompleted;

  /// No description provided for @mtcStatusDisputed.
  ///
  /// In en, this message translates to:
  /// **'Under review'**
  String get mtcStatusDisputed;

  /// No description provided for @mtcStatusCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get mtcStatusCancelled;

  /// No description provided for @mtcStatusBye.
  ///
  /// In en, this message translates to:
  /// **'Bye'**
  String get mtcStatusBye;

  /// No description provided for @mtcStatusForfeited.
  ///
  /// In en, this message translates to:
  /// **'Forfeited'**
  String get mtcStatusForfeited;

  /// No description provided for @mtcWatchLive.
  ///
  /// In en, this message translates to:
  /// **'Watch live'**
  String get mtcWatchLive;

  /// No description provided for @mtcWatchReplay.
  ///
  /// In en, this message translates to:
  /// **'Watch replay'**
  String get mtcWatchReplay;

  /// No description provided for @mtcCheckIn.
  ///
  /// In en, this message translates to:
  /// **'I\'m here — check in'**
  String get mtcCheckIn;

  /// No description provided for @mtcCheckedIn.
  ///
  /// In en, this message translates to:
  /// **'Checked in'**
  String get mtcCheckedIn;

  /// No description provided for @mtcNotCheckedIn.
  ///
  /// In en, this message translates to:
  /// **'Not checked in'**
  String get mtcNotCheckedIn;

  /// No description provided for @mtcCheckInSuccess.
  ///
  /// In en, this message translates to:
  /// **'You\'re checked in.'**
  String get mtcCheckInSuccess;

  /// No description provided for @mtcSubmitResult.
  ///
  /// In en, this message translates to:
  /// **'Submit result'**
  String get mtcSubmitResult;

  /// No description provided for @mtcResultSubmitted.
  ///
  /// In en, this message translates to:
  /// **'Result submitted — awaiting confirmation.'**
  String get mtcResultSubmitted;

  /// No description provided for @mtcRateOpponent.
  ///
  /// In en, this message translates to:
  /// **'Rate your opponent'**
  String get mtcRateOpponent;

  /// No description provided for @mtcRated.
  ///
  /// In en, this message translates to:
  /// **'Thanks for rating!'**
  String get mtcRated;

  /// No description provided for @mtcWagerTitle.
  ///
  /// In en, this message translates to:
  /// **'Wager'**
  String get mtcWagerTitle;

  /// No description provided for @mtcWagerLoginPrompt.
  ///
  /// In en, this message translates to:
  /// **'Log in to place a wager.'**
  String get mtcWagerLoginPrompt;

  /// No description provided for @mtcWagerClosed.
  ///
  /// In en, this message translates to:
  /// **'Wagering is closed for this match.'**
  String get mtcWagerClosed;

  /// No description provided for @mtcWagerPool.
  ///
  /// In en, this message translates to:
  /// **'Pool: {a} vs {b} coins'**
  String mtcWagerPool(int a, int b);

  /// No description provided for @mtcWagerFee.
  ///
  /// In en, this message translates to:
  /// **'House fee {percent}%'**
  String mtcWagerFee(String percent);

  /// No description provided for @mtcWagerYourPick.
  ///
  /// In en, this message translates to:
  /// **'Your wager: {coins} coins on {name}'**
  String mtcWagerYourPick(int coins, String name);

  /// No description provided for @mtcWagerPlace.
  ///
  /// In en, this message translates to:
  /// **'Place wager'**
  String get mtcWagerPlace;

  /// No description provided for @mtcWagerChange.
  ///
  /// In en, this message translates to:
  /// **'Change wager'**
  String get mtcWagerChange;

  /// No description provided for @mtcWagerStake.
  ///
  /// In en, this message translates to:
  /// **'Stake (coins)'**
  String get mtcWagerStake;

  /// No description provided for @mtcWagerStakeRange.
  ///
  /// In en, this message translates to:
  /// **'Between {min} and {max} coins.'**
  String mtcWagerStakeRange(int min, int max);

  /// No description provided for @mtcWagerPlaced.
  ///
  /// In en, this message translates to:
  /// **'Wager placed.'**
  String get mtcWagerPlaced;

  /// No description provided for @mtcWagerEstimate.
  ///
  /// In en, this message translates to:
  /// **'A 100-coin wager on the first player would pay about {payout} coins.'**
  String mtcWagerEstimate(String payout);

  /// No description provided for @mtcNoShowInfo.
  ///
  /// In en, this message translates to:
  /// **'This match is eligible for no-show handling by the organizers.'**
  String get mtcNoShowInfo;

  /// No description provided for @mtcScoreA.
  ///
  /// In en, this message translates to:
  /// **'{name} score'**
  String mtcScoreA(String name);

  /// No description provided for @mtcRecordingUrl.
  ///
  /// In en, this message translates to:
  /// **'Recording link (optional)'**
  String get mtcRecordingUrl;

  /// No description provided for @mtcPickScreenshot.
  ///
  /// In en, this message translates to:
  /// **'Choose screenshot'**
  String get mtcPickScreenshot;

  /// No description provided for @mtcChangeScreenshot.
  ///
  /// In en, this message translates to:
  /// **'Change screenshot'**
  String get mtcChangeScreenshot;

  /// No description provided for @mtcScreenshotRequired.
  ///
  /// In en, this message translates to:
  /// **'A screenshot is required.'**
  String get mtcScreenshotRequired;

  /// No description provided for @mtcUploading.
  ///
  /// In en, this message translates to:
  /// **'Uploading screenshot…'**
  String get mtcUploading;

  /// No description provided for @mtcSubmitting.
  ///
  /// In en, this message translates to:
  /// **'Submitting…'**
  String get mtcSubmitting;

  /// No description provided for @mtcValScore.
  ///
  /// In en, this message translates to:
  /// **'Enter a whole number from 0 to 99.'**
  String get mtcValScore;

  /// No description provided for @mtcLobbyResultTitle.
  ///
  /// In en, this message translates to:
  /// **'Lobby result'**
  String get mtcLobbyResultTitle;

  /// No description provided for @mtcPlacement.
  ///
  /// In en, this message translates to:
  /// **'Placement'**
  String get mtcPlacement;

  /// No description provided for @mtcKills.
  ///
  /// In en, this message translates to:
  /// **'Kills'**
  String get mtcKills;

  /// No description provided for @mtcValPlacement.
  ///
  /// In en, this message translates to:
  /// **'Enter a whole number from 1 to 100.'**
  String get mtcValPlacement;

  /// No description provided for @mtcValKills.
  ///
  /// In en, this message translates to:
  /// **'Enter a whole number from 0 to 100.'**
  String get mtcValKills;

  /// No description provided for @mtcFixturesTitle.
  ///
  /// In en, this message translates to:
  /// **'Your fixtures'**
  String get mtcFixturesTitle;

  /// No description provided for @mtcNextMatch.
  ///
  /// In en, this message translates to:
  /// **'Next match'**
  String get mtcNextMatch;

  /// No description provided for @mtcNextLobby.
  ///
  /// In en, this message translates to:
  /// **'Next lobby'**
  String get mtcNextLobby;

  /// No description provided for @mtcSubmitPrompt.
  ///
  /// In en, this message translates to:
  /// **'You have a match awaiting your result.'**
  String get mtcSubmitPrompt;

  /// No description provided for @mtcLobbySubmitted.
  ///
  /// In en, this message translates to:
  /// **'Result submitted'**
  String get mtcLobbySubmitted;

  /// No description provided for @mtcRoomCodeReady.
  ///
  /// In en, this message translates to:
  /// **'Room details are ready'**
  String get mtcRoomCodeReady;

  /// No description provided for @mtcBannerQualified.
  ///
  /// In en, this message translates to:
  /// **'You qualified in {title} ({round}).'**
  String mtcBannerQualified(String title, String round);

  /// No description provided for @mtcBannerAwaiting.
  ///
  /// In en, this message translates to:
  /// **'Waiting for your opponent.'**
  String get mtcBannerAwaiting;

  /// No description provided for @mtcBannerEliminated.
  ///
  /// In en, this message translates to:
  /// **'You were eliminated from {title} ({round}).'**
  String mtcBannerEliminated(String title, String round);

  /// No description provided for @mtcRegistrationsHeading.
  ///
  /// In en, this message translates to:
  /// **'Your registrations'**
  String get mtcRegistrationsHeading;

  /// No description provided for @mtcPaymentPending.
  ///
  /// In en, this message translates to:
  /// **'Payment pending'**
  String get mtcPaymentPending;

  /// No description provided for @mtcPaymentPaid.
  ///
  /// In en, this message translates to:
  /// **'Paid'**
  String get mtcPaymentPaid;

  /// No description provided for @mtcEcGeneric.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get mtcEcGeneric;

  /// No description provided for @mtcEcNetwork.
  ///
  /// In en, this message translates to:
  /// **'No connection. Check your internet and try again.'**
  String get mtcEcNetwork;

  /// No description provided for @mtcEcSession.
  ///
  /// In en, this message translates to:
  /// **'Your session expired. Please log in again.'**
  String get mtcEcSession;

  /// No description provided for @mtcEcInProgress.
  ///
  /// In en, this message translates to:
  /// **'Still processing your request. Please wait a moment and try again.'**
  String get mtcEcInProgress;

  /// No description provided for @mtcEcUploadFailed.
  ///
  /// In en, this message translates to:
  /// **'Screenshot upload failed. Please try again.'**
  String get mtcEcUploadFailed;

  /// No description provided for @mtcEcMatchNotFound.
  ///
  /// In en, this message translates to:
  /// **'Match not found.'**
  String get mtcEcMatchNotFound;

  /// No description provided for @mtcEcNotParticipant.
  ///
  /// In en, this message translates to:
  /// **'You\'re not playing in this match.'**
  String get mtcEcNotParticipant;

  /// No description provided for @mtcEcNotMatchDay.
  ///
  /// In en, this message translates to:
  /// **'You can check in once it\'s match day.'**
  String get mtcEcNotMatchDay;

  /// No description provided for @mtcEcCheckInClosed.
  ///
  /// In en, this message translates to:
  /// **'This match is no longer open for check-in.'**
  String get mtcEcCheckInClosed;

  /// No description provided for @mtcEcBye.
  ///
  /// In en, this message translates to:
  /// **'This is a bye — there is no result to submit.'**
  String get mtcEcBye;

  /// No description provided for @mtcEcCancelled.
  ///
  /// In en, this message translates to:
  /// **'This match was cancelled.'**
  String get mtcEcCancelled;

  /// No description provided for @mtcEcAlreadyConfirmed.
  ///
  /// In en, this message translates to:
  /// **'This result is already confirmed.'**
  String get mtcEcAlreadyConfirmed;

  /// No description provided for @mtcEcSubmissionLocked.
  ///
  /// In en, this message translates to:
  /// **'Your submission is under review and can no longer be edited.'**
  String get mtcEcSubmissionLocked;

  /// No description provided for @mtcEcValidation.
  ///
  /// In en, this message translates to:
  /// **'Please check what you entered.'**
  String get mtcEcValidation;

  /// No description provided for @mtcEcResultNotConfirmed.
  ///
  /// In en, this message translates to:
  /// **'You can rate your opponent once the result is confirmed.'**
  String get mtcEcResultNotConfirmed;

  /// No description provided for @mtcEcCannotRateSelf.
  ///
  /// In en, this message translates to:
  /// **'You can\'t rate yourself.'**
  String get mtcEcCannotRateSelf;

  /// No description provided for @mtcEcNotRatable.
  ///
  /// In en, this message translates to:
  /// **'This match can\'t be rated.'**
  String get mtcEcNotRatable;

  /// No description provided for @mtcEcAlreadyRated.
  ///
  /// In en, this message translates to:
  /// **'You\'ve already rated this match.'**
  String get mtcEcAlreadyRated;

  /// No description provided for @mtcEcPendingDeletion.
  ///
  /// In en, this message translates to:
  /// **'Your account is pending deletion.'**
  String get mtcEcPendingDeletion;

  /// No description provided for @mtcEcOwnMatch.
  ///
  /// In en, this message translates to:
  /// **'You can\'t wager on your own match.'**
  String get mtcEcOwnMatch;

  /// No description provided for @mtcEcInvalidPick.
  ///
  /// In en, this message translates to:
  /// **'Pick one of the two players in this match.'**
  String get mtcEcInvalidPick;

  /// No description provided for @mtcEcWindowClosed.
  ///
  /// In en, this message translates to:
  /// **'Wagering is closed for this match.'**
  String get mtcEcWindowClosed;

  /// No description provided for @mtcEcInsufficientCoins.
  ///
  /// In en, this message translates to:
  /// **'Not enough SX Coins for this stake.'**
  String get mtcEcInsufficientCoins;

  /// No description provided for @mtcEcNotInLobby.
  ///
  /// In en, this message translates to:
  /// **'You\'re not in this lobby.'**
  String get mtcEcNotInLobby;

  /// No description provided for @mtcEcLobbyConfirmed.
  ///
  /// In en, this message translates to:
  /// **'This lobby is confirmed and can no longer be edited.'**
  String get mtcEcLobbyConfirmed;

  /// No description provided for @mtcEcResultConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Your result is confirmed and can no longer be edited.'**
  String get mtcEcResultConfirmed;

  /// No description provided for @mtcHomeFixtures.
  ///
  /// In en, this message translates to:
  /// **'Fixtures'**
  String get mtcHomeFixtures;

  /// No description provided for @mtcDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get mtcDone;

  /// No description provided for @cmtTitle.
  ///
  /// In en, this message translates to:
  /// **'Community'**
  String get cmtTitle;

  /// No description provided for @cmtFeedEmpty.
  ///
  /// In en, this message translates to:
  /// **'No posts yet. Be the first to share something!'**
  String get cmtFeedEmpty;

  /// No description provided for @cmtFeedLoadError.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load the feed.'**
  String get cmtFeedLoadError;

  /// No description provided for @cmtRetry.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get cmtRetry;

  /// No description provided for @cmtLoadMore.
  ///
  /// In en, this message translates to:
  /// **'Load more'**
  String get cmtLoadMore;

  /// No description provided for @cmtPinnedLabel.
  ///
  /// In en, this message translates to:
  /// **'Pinned'**
  String get cmtPinnedLabel;

  /// No description provided for @cmtBoostedLabel.
  ///
  /// In en, this message translates to:
  /// **'Boosted'**
  String get cmtBoostedLabel;

  /// No description provided for @cmtComposeFab.
  ///
  /// In en, this message translates to:
  /// **'New post'**
  String get cmtComposeFab;

  /// No description provided for @cmtSignInToPost.
  ///
  /// In en, this message translates to:
  /// **'Log in to post'**
  String get cmtSignInToPost;

  /// No description provided for @cmtSignInToReact.
  ///
  /// In en, this message translates to:
  /// **'Log in to react'**
  String get cmtSignInToReact;

  /// No description provided for @cmtSignInToComment.
  ///
  /// In en, this message translates to:
  /// **'Log in to comment'**
  String get cmtSignInToComment;

  /// No description provided for @cmtSignInToVote.
  ///
  /// In en, this message translates to:
  /// **'Log in to vote'**
  String get cmtSignInToVote;

  /// No description provided for @cmtSignInToReport.
  ///
  /// In en, this message translates to:
  /// **'Log in to report'**
  String get cmtSignInToReport;

  /// No description provided for @cmtCommentCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} comment} other{{count} comments}}'**
  String cmtCommentCount(int count);

  /// No description provided for @cmtReactFire.
  ///
  /// In en, this message translates to:
  /// **'Fire'**
  String get cmtReactFire;

  /// No description provided for @cmtReactCrown.
  ///
  /// In en, this message translates to:
  /// **'Crown'**
  String get cmtReactCrown;

  /// No description provided for @cmtReactStrong.
  ///
  /// In en, this message translates to:
  /// **'Strong'**
  String get cmtReactStrong;

  /// No description provided for @cmtReactWow.
  ///
  /// In en, this message translates to:
  /// **'Wow'**
  String get cmtReactWow;

  /// No description provided for @cmtMatchResultLabel.
  ///
  /// In en, this message translates to:
  /// **'Match result'**
  String get cmtMatchResultLabel;

  /// No description provided for @cmtAchievementLabel.
  ///
  /// In en, this message translates to:
  /// **'Achievement'**
  String get cmtAchievementLabel;

  /// No description provided for @cmtAnnouncementLabel.
  ///
  /// In en, this message translates to:
  /// **'Announcement'**
  String get cmtAnnouncementLabel;

  /// No description provided for @cmtComposeTitle.
  ///
  /// In en, this message translates to:
  /// **'New post'**
  String get cmtComposeTitle;

  /// No description provided for @cmtComposeHint.
  ///
  /// In en, this message translates to:
  /// **'What\'s happening in the SentinelX community?'**
  String get cmtComposeHint;

  /// No description provided for @cmtComposeAddImage.
  ///
  /// In en, this message translates to:
  /// **'Add photo'**
  String get cmtComposeAddImage;

  /// No description provided for @cmtComposeImagesCount.
  ///
  /// In en, this message translates to:
  /// **'{count}/5'**
  String cmtComposeImagesCount(int count);

  /// No description provided for @cmtComposePost.
  ///
  /// In en, this message translates to:
  /// **'Post'**
  String get cmtComposePost;

  /// No description provided for @cmtComposePosting.
  ///
  /// In en, this message translates to:
  /// **'Posting…'**
  String get cmtComposePosting;

  /// No description provided for @cmtComposeCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cmtComposeCancel;

  /// No description provided for @cmtComposeValidation.
  ///
  /// In en, this message translates to:
  /// **'Write something or add a photo first.'**
  String get cmtComposeValidation;

  /// No description provided for @cmtComposeRemoveImage.
  ///
  /// In en, this message translates to:
  /// **'Remove image'**
  String get cmtComposeRemoveImage;

  /// No description provided for @cmtPostDetailTitle.
  ///
  /// In en, this message translates to:
  /// **'Post'**
  String get cmtPostDetailTitle;

  /// No description provided for @cmtCommentsTitle.
  ///
  /// In en, this message translates to:
  /// **'Comments'**
  String get cmtCommentsTitle;

  /// No description provided for @cmtCommentsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No comments yet.'**
  String get cmtCommentsEmpty;

  /// No description provided for @cmtCommentsCapNotice.
  ///
  /// In en, this message translates to:
  /// **'Showing the first 50 comments.'**
  String get cmtCommentsCapNotice;

  /// No description provided for @cmtCommentHint.
  ///
  /// In en, this message translates to:
  /// **'Add a comment…'**
  String get cmtCommentHint;

  /// No description provided for @cmtCommentSend.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get cmtCommentSend;

  /// No description provided for @cmtDeletePost.
  ///
  /// In en, this message translates to:
  /// **'Delete post'**
  String get cmtDeletePost;

  /// No description provided for @cmtDeletePostConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete this post? This can\'t be undone.'**
  String get cmtDeletePostConfirm;

  /// No description provided for @cmtDeleteComment.
  ///
  /// In en, this message translates to:
  /// **'Delete comment'**
  String get cmtDeleteComment;

  /// No description provided for @cmtDeleteCommentConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete this comment?'**
  String get cmtDeleteCommentConfirm;

  /// No description provided for @cmtDeleteConfirmYes.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get cmtDeleteConfirmYes;

  /// No description provided for @cmtDeleteConfirmCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cmtDeleteConfirmCancel;

  /// No description provided for @cmtBoostAction.
  ///
  /// In en, this message translates to:
  /// **'Boost (200 coins)'**
  String get cmtBoostAction;

  /// No description provided for @cmtBoostConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Boost this post?'**
  String get cmtBoostConfirmTitle;

  /// No description provided for @cmtBoostConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'Your post will be pinned to the top of the feed for 24 hours for 200 SX Coins.'**
  String get cmtBoostConfirmBody;

  /// No description provided for @cmtBoostConfirm.
  ///
  /// In en, this message translates to:
  /// **'Boost'**
  String get cmtBoostConfirm;

  /// No description provided for @cmtBoostSuccess.
  ///
  /// In en, this message translates to:
  /// **'Post boosted!'**
  String get cmtBoostSuccess;

  /// No description provided for @cmtStatusesTitle.
  ///
  /// In en, this message translates to:
  /// **'Stories'**
  String get cmtStatusesTitle;

  /// No description provided for @cmtStatusAddYours.
  ///
  /// In en, this message translates to:
  /// **'Your story'**
  String get cmtStatusAddYours;

  /// No description provided for @cmtStatusPost.
  ///
  /// In en, this message translates to:
  /// **'Post story'**
  String get cmtStatusPost;

  /// No description provided for @cmtStatusCaptionHint.
  ///
  /// In en, this message translates to:
  /// **'Add a caption (optional)'**
  String get cmtStatusCaptionHint;

  /// No description provided for @cmtStatusEmpty.
  ///
  /// In en, this message translates to:
  /// **'No stories yet.'**
  String get cmtStatusEmpty;

  /// No description provided for @cmtStatusViewersTitle.
  ///
  /// In en, this message translates to:
  /// **'Viewers'**
  String get cmtStatusViewersTitle;

  /// No description provided for @cmtStatusViewersEmpty.
  ///
  /// In en, this message translates to:
  /// **'No one has viewed this yet.'**
  String get cmtStatusViewersEmpty;

  /// No description provided for @cmtStatusDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete story'**
  String get cmtStatusDelete;

  /// No description provided for @cmtStatusDeleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete this story?'**
  String get cmtStatusDeleteConfirm;

  /// No description provided for @cmtStatusValidation.
  ///
  /// In en, this message translates to:
  /// **'Add a photo or a caption.'**
  String get cmtStatusValidation;

  /// No description provided for @cmtChallengesTitle.
  ///
  /// In en, this message translates to:
  /// **'Weekly challenges'**
  String get cmtChallengesTitle;

  /// No description provided for @cmtChallengesSignedOut.
  ///
  /// In en, this message translates to:
  /// **'Log in to track weekly challenges.'**
  String get cmtChallengesSignedOut;

  /// No description provided for @cmtChallengeCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get cmtChallengeCompleted;

  /// No description provided for @cmtChallengeProgress.
  ///
  /// In en, this message translates to:
  /// **'{progress}/{goal}'**
  String cmtChallengeProgress(int progress, int goal);

  /// No description provided for @cmtBestPlayTitle.
  ///
  /// In en, this message translates to:
  /// **'Best Play of the Week'**
  String get cmtBestPlayTitle;

  /// No description provided for @cmtBestPlayEmpty.
  ///
  /// In en, this message translates to:
  /// **'No nominations this week.'**
  String get cmtBestPlayEmpty;

  /// No description provided for @cmtBestPlayVote.
  ///
  /// In en, this message translates to:
  /// **'Vote'**
  String get cmtBestPlayVote;

  /// No description provided for @cmtBestPlayVoted.
  ///
  /// In en, this message translates to:
  /// **'Voted'**
  String get cmtBestPlayVoted;

  /// No description provided for @cmtBestPlayVoteSuccess.
  ///
  /// In en, this message translates to:
  /// **'Vote recorded!'**
  String get cmtBestPlayVoteSuccess;

  /// No description provided for @cmtTopMembersTitle.
  ///
  /// In en, this message translates to:
  /// **'Top members'**
  String get cmtTopMembersTitle;

  /// No description provided for @cmtUpcomingEventsTitle.
  ///
  /// In en, this message translates to:
  /// **'Upcoming events'**
  String get cmtUpcomingEventsTitle;

  /// No description provided for @cmtGalleryTitle.
  ///
  /// In en, this message translates to:
  /// **'Gallery'**
  String get cmtGalleryTitle;

  /// No description provided for @cmtStatsMembers.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} member} other{{count} members}}'**
  String cmtStatsMembers(int count);

  /// No description provided for @cmtStatsCountries.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} country} other{{count} countries}}'**
  String cmtStatsCountries(int count);

  /// No description provided for @cmtStatsTournaments.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} tournament} other{{count} tournaments}}'**
  String cmtStatsTournaments(int count);

  /// No description provided for @cmtReportPost.
  ///
  /// In en, this message translates to:
  /// **'Report post'**
  String get cmtReportPost;

  /// No description provided for @cmtReportComment.
  ///
  /// In en, this message translates to:
  /// **'Report comment'**
  String get cmtReportComment;

  /// No description provided for @cmtReportTitle.
  ///
  /// In en, this message translates to:
  /// **'Report content'**
  String get cmtReportTitle;

  /// No description provided for @cmtReportReasonSpam.
  ///
  /// In en, this message translates to:
  /// **'Spam'**
  String get cmtReportReasonSpam;

  /// No description provided for @cmtReportReasonHarassment.
  ///
  /// In en, this message translates to:
  /// **'Harassment'**
  String get cmtReportReasonHarassment;

  /// No description provided for @cmtReportReasonHateSpeech.
  ///
  /// In en, this message translates to:
  /// **'Hate speech'**
  String get cmtReportReasonHateSpeech;

  /// No description provided for @cmtReportReasonNudity.
  ///
  /// In en, this message translates to:
  /// **'Nudity or sexual content'**
  String get cmtReportReasonNudity;

  /// No description provided for @cmtReportReasonViolence.
  ///
  /// In en, this message translates to:
  /// **'Violence'**
  String get cmtReportReasonViolence;

  /// No description provided for @cmtReportReasonMisinformation.
  ///
  /// In en, this message translates to:
  /// **'Misinformation'**
  String get cmtReportReasonMisinformation;

  /// No description provided for @cmtReportReasonOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get cmtReportReasonOther;

  /// No description provided for @cmtReportNoteHint.
  ///
  /// In en, this message translates to:
  /// **'Add details (optional)'**
  String get cmtReportNoteHint;

  /// No description provided for @cmtReportSubmit.
  ///
  /// In en, this message translates to:
  /// **'Submit report'**
  String get cmtReportSubmit;

  /// No description provided for @cmtReportSubmitted.
  ///
  /// In en, this message translates to:
  /// **'Report submitted. Thank you.'**
  String get cmtReportSubmitted;

  /// No description provided for @cmtEcGeneric.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get cmtEcGeneric;

  /// No description provided for @cmtEcNetwork.
  ///
  /// In en, this message translates to:
  /// **'No connection. Check your internet and try again.'**
  String get cmtEcNetwork;

  /// No description provided for @cmtEcSession.
  ///
  /// In en, this message translates to:
  /// **'Your session expired. Please log in again.'**
  String get cmtEcSession;

  /// No description provided for @cmtEcInProgress.
  ///
  /// In en, this message translates to:
  /// **'Still processing your request. Please wait a moment and try again.'**
  String get cmtEcInProgress;

  /// No description provided for @cmtEcValidation.
  ///
  /// In en, this message translates to:
  /// **'Write something or add a photo first.'**
  String get cmtEcValidation;

  /// No description provided for @cmtEcNotFound.
  ///
  /// In en, this message translates to:
  /// **'This content is no longer available.'**
  String get cmtEcNotFound;

  /// No description provided for @cmtEcForbidden.
  ///
  /// In en, this message translates to:
  /// **'You can only do this for your own content.'**
  String get cmtEcForbidden;

  /// No description provided for @cmtEcAlreadyBoosted.
  ///
  /// In en, this message translates to:
  /// **'This post is already boosted.'**
  String get cmtEcAlreadyBoosted;

  /// No description provided for @cmtEcActiveBoostExists.
  ///
  /// In en, this message translates to:
  /// **'You already have an active boost on another post.'**
  String get cmtEcActiveBoostExists;

  /// No description provided for @cmtEcInsufficientCoins.
  ///
  /// In en, this message translates to:
  /// **'Not enough SX Coins to boost.'**
  String get cmtEcInsufficientCoins;

  /// No description provided for @cmtEcVotingClosed.
  ///
  /// In en, this message translates to:
  /// **'Voting is closed right now.'**
  String get cmtEcVotingClosed;

  /// No description provided for @cmtEcAlreadyVoted.
  ///
  /// In en, this message translates to:
  /// **'You\'ve already voted this week.'**
  String get cmtEcAlreadyVoted;

  /// No description provided for @cmtEcAlreadyReported.
  ///
  /// In en, this message translates to:
  /// **'You\'ve already reported this.'**
  String get cmtEcAlreadyReported;

  /// No description provided for @cmtEcUploadFailed.
  ///
  /// In en, this message translates to:
  /// **'Image upload failed. Please try again.'**
  String get cmtEcUploadFailed;

  /// No description provided for @authMetaProfile.
  ///
  /// In en, this message translates to:
  /// **'Complete your profile · SentinelX Esports'**
  String get authMetaProfile;

  /// No description provided for @authProfileStepTitle.
  ///
  /// In en, this message translates to:
  /// **'Complete your profile'**
  String get authProfileStepTitle;

  /// No description provided for @authProfileStepSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Tell us where you play and which games you\'re into — we\'ll only reach out about tournaments you actually care about.'**
  String get authProfileStepSubtitle;

  /// No description provided for @profileCountryLabel.
  ///
  /// In en, this message translates to:
  /// **'Country'**
  String get profileCountryLabel;

  /// No description provided for @profileCountryPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Select your country'**
  String get profileCountryPlaceholder;

  /// No description provided for @profileWhatsappLabel.
  ///
  /// In en, this message translates to:
  /// **'WhatsApp number'**
  String get profileWhatsappLabel;

  /// No description provided for @profileWhatsappHint.
  ///
  /// In en, this message translates to:
  /// **'+2348012345678'**
  String get profileWhatsappHint;

  /// No description provided for @profileGamesLabel.
  ///
  /// In en, this message translates to:
  /// **'Which games are you interested in?'**
  String get profileGamesLabel;

  /// No description provided for @profileGamesLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading games…'**
  String get profileGamesLoading;

  /// No description provided for @profileGamesRetry.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load games. Try again'**
  String get profileGamesRetry;

  /// No description provided for @profileConsentLabel.
  ///
  /// In en, this message translates to:
  /// **'Receive tournament updates on WhatsApp?'**
  String get profileConsentLabel;

  /// No description provided for @profileConsentYes.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get profileConsentYes;

  /// No description provided for @profileConsentNo.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get profileConsentNo;

  /// No description provided for @profileCountryRequired.
  ///
  /// In en, this message translates to:
  /// **'Select your country.'**
  String get profileCountryRequired;

  /// No description provided for @profileWhatsappRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter your WhatsApp number.'**
  String get profileWhatsappRequired;

  /// No description provided for @profileWhatsappInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid WhatsApp number for the selected country.'**
  String get profileWhatsappInvalid;

  /// No description provided for @profileGamesRequired.
  ///
  /// In en, this message translates to:
  /// **'Choose at least one game.'**
  String get profileGamesRequired;

  /// No description provided for @profileConsentRequired.
  ///
  /// In en, this message translates to:
  /// **'Choose yes or no.'**
  String get profileConsentRequired;

  /// No description provided for @profileCountryInvalid.
  ///
  /// In en, this message translates to:
  /// **'Select a country from the list.'**
  String get profileCountryInvalid;

  /// No description provided for @profileGameUnavailable.
  ///
  /// In en, this message translates to:
  /// **'One of the games you picked is no longer available. Reload and try again.'**
  String get profileGameUnavailable;

  /// No description provided for @profileContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get profileContinue;

  /// No description provided for @profileSaving.
  ///
  /// In en, this message translates to:
  /// **'Saving…'**
  String get profileSaving;

  /// No description provided for @profileSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save your profile. Please try again.'**
  String get profileSaveFailed;

  /// No description provided for @profileSaved.
  ///
  /// In en, this message translates to:
  /// **'Profile saved.'**
  String get profileSaved;

  /// No description provided for @ntfTitle.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get ntfTitle;

  /// No description provided for @ntfMarkAllRead.
  ///
  /// In en, this message translates to:
  /// **'Mark all read'**
  String get ntfMarkAllRead;

  /// No description provided for @ntfMuteThread.
  ///
  /// In en, this message translates to:
  /// **'Mute this thread'**
  String get ntfMuteThread;

  /// No description provided for @ntfUnmuteThread.
  ///
  /// In en, this message translates to:
  /// **'Unmute this thread'**
  String get ntfUnmuteThread;

  /// No description provided for @ntfMuteType.
  ///
  /// In en, this message translates to:
  /// **'Mute this type'**
  String get ntfMuteType;

  /// No description provided for @ntfUnmuteType.
  ///
  /// In en, this message translates to:
  /// **'Unmute this type'**
  String get ntfUnmuteType;

  /// No description provided for @ntfMuteFor1h.
  ///
  /// In en, this message translates to:
  /// **'For 1 hour'**
  String get ntfMuteFor1h;

  /// No description provided for @ntfMuteFor1w.
  ///
  /// In en, this message translates to:
  /// **'For 1 week'**
  String get ntfMuteFor1w;

  /// No description provided for @ntfMuteAlways.
  ///
  /// In en, this message translates to:
  /// **'Always'**
  String get ntfMuteAlways;

  /// No description provided for @ntfMuted.
  ///
  /// In en, this message translates to:
  /// **'Muted'**
  String get ntfMuted;

  /// No description provided for @ntfUnmuted.
  ///
  /// In en, this message translates to:
  /// **'Unmuted'**
  String get ntfUnmuted;

  /// No description provided for @ntfEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'You\'re all caught up'**
  String get ntfEmptyTitle;

  /// No description provided for @ntfEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Fixture assignments, results and prizes show up here.'**
  String get ntfEmptyBody;

  /// No description provided for @ntfLoadError.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load your notifications.'**
  String get ntfLoadError;

  /// No description provided for @ntfRetry.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get ntfRetry;

  /// No description provided for @ntfSignedOut.
  ///
  /// In en, this message translates to:
  /// **'Log in to see your notifications.'**
  String get ntfSignedOut;

  /// No description provided for @ntfLogIn.
  ///
  /// In en, this message translates to:
  /// **'Log in'**
  String get ntfLogIn;

  /// No description provided for @ntfActionFailed.
  ///
  /// In en, this message translates to:
  /// **'That didn\'t work. Try again.'**
  String get ntfActionFailed;

  /// No description provided for @ntfUnreadCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} unread notification} other{{count} unread notifications}}'**
  String ntfUnreadCount(int count);

  /// No description provided for @ntfTimeNow.
  ///
  /// In en, this message translates to:
  /// **'Just now'**
  String get ntfTimeNow;

  /// No description provided for @ntfTimeMinutes.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} minute ago} other{{count} minutes ago}}'**
  String ntfTimeMinutes(int count);

  /// No description provided for @ntfTimeHours.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} hour ago} other{{count} hours ago}}'**
  String ntfTimeHours(int count);

  /// No description provided for @ntfTimeDays.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} day ago} other{{count} days ago}}'**
  String ntfTimeDays(int count);

  /// No description provided for @ntfPermTitle.
  ///
  /// In en, this message translates to:
  /// **'Turn on notifications'**
  String get ntfPermTitle;

  /// No description provided for @ntfPermBody.
  ///
  /// In en, this message translates to:
  /// **'Get fixture assignments and match reminders on this phone.'**
  String get ntfPermBody;

  /// No description provided for @ntfPermEnable.
  ///
  /// In en, this message translates to:
  /// **'Turn on'**
  String get ntfPermEnable;

  /// No description provided for @ntfPermOpenSettings.
  ///
  /// In en, this message translates to:
  /// **'Open system settings'**
  String get ntfPermOpenSettings;

  /// No description provided for @ntfPermOn.
  ///
  /// In en, this message translates to:
  /// **'Notifications are on for this phone.'**
  String get ntfPermOn;

  /// No description provided for @ntfPermBlocked.
  ///
  /// In en, this message translates to:
  /// **'Notifications are turned off for this app in your phone settings.'**
  String get ntfPermBlocked;

  /// No description provided for @ntfSettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Notification settings'**
  String get ntfSettingsTitle;

  /// No description provided for @ntfSettingsEntry.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get ntfSettingsEntry;

  /// No description provided for @ntfSectionPush.
  ///
  /// In en, this message translates to:
  /// **'Push notifications'**
  String get ntfSectionPush;

  /// No description provided for @ntfSectionWhatsapp.
  ///
  /// In en, this message translates to:
  /// **'WhatsApp'**
  String get ntfSectionWhatsapp;

  /// No description provided for @ntfSectionSharing.
  ///
  /// In en, this message translates to:
  /// **'Share achievements to the community'**
  String get ntfSectionSharing;

  /// No description provided for @ntfSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save that change.'**
  String get ntfSaveFailed;

  /// No description provided for @ntfTestAction.
  ///
  /// In en, this message translates to:
  /// **'Send a test notification'**
  String get ntfTestAction;

  /// No description provided for @ntfTestSent.
  ///
  /// In en, this message translates to:
  /// **'Test sent — it should arrive in a moment.'**
  String get ntfTestSent;

  /// No description provided for @ntfTestNoDevice.
  ///
  /// In en, this message translates to:
  /// **'This phone isn\'t registered for notifications yet.'**
  String get ntfTestNoDevice;

  /// No description provided for @ntfTestFailed.
  ///
  /// In en, this message translates to:
  /// **'The test notification couldn\'t be delivered.'**
  String get ntfTestFailed;

  /// No description provided for @ntfPushMatchReminder.
  ///
  /// In en, this message translates to:
  /// **'Match reminders'**
  String get ntfPushMatchReminder;

  /// No description provided for @ntfPushResultConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Result confirmed'**
  String get ntfPushResultConfirmed;

  /// No description provided for @ntfPushAchievementUnlocked.
  ///
  /// In en, this message translates to:
  /// **'Achievement unlocked'**
  String get ntfPushAchievementUnlocked;

  /// No description provided for @ntfPushChallengeCompleted.
  ///
  /// In en, this message translates to:
  /// **'Weekly challenge completed'**
  String get ntfPushChallengeCompleted;

  /// No description provided for @ntfPushNewAnnouncement.
  ///
  /// In en, this message translates to:
  /// **'Community announcements'**
  String get ntfPushNewAnnouncement;

  /// No description provided for @ntfPushTournamentAnnounced.
  ///
  /// In en, this message translates to:
  /// **'New tournaments'**
  String get ntfPushTournamentAnnounced;

  /// No description provided for @ntfPushWagerSettled.
  ///
  /// In en, this message translates to:
  /// **'Wager settled'**
  String get ntfPushWagerSettled;

  /// No description provided for @ntfPushReferralConverted.
  ///
  /// In en, this message translates to:
  /// **'Referral converted'**
  String get ntfPushReferralConverted;

  /// No description provided for @ntfPushPostComment.
  ///
  /// In en, this message translates to:
  /// **'Comments on your posts'**
  String get ntfPushPostComment;

  /// No description provided for @ntfPushPostReaction.
  ///
  /// In en, this message translates to:
  /// **'Reactions on your posts'**
  String get ntfPushPostReaction;

  /// No description provided for @ntfPushBracketReleased.
  ///
  /// In en, this message translates to:
  /// **'Bracket released'**
  String get ntfPushBracketReleased;

  /// No description provided for @ntfPushMatchAssigned.
  ///
  /// In en, this message translates to:
  /// **'New fixture assigned'**
  String get ntfPushMatchAssigned;

  /// No description provided for @ntfPushPrizeCredited.
  ///
  /// In en, this message translates to:
  /// **'Prize credited'**
  String get ntfPushPrizeCredited;

  /// No description provided for @ntfPushStatusFromFriend.
  ///
  /// In en, this message translates to:
  /// **'A friend posts a status'**
  String get ntfPushStatusFromFriend;

  /// No description provided for @ntfPushStatusViewed.
  ///
  /// In en, this message translates to:
  /// **'Someone views your status'**
  String get ntfPushStatusViewed;

  /// No description provided for @ntfPushNewFollower.
  ///
  /// In en, this message translates to:
  /// **'Someone follows you'**
  String get ntfPushNewFollower;

  /// No description provided for @ntfPushDirectMessage.
  ///
  /// In en, this message translates to:
  /// **'Direct messages'**
  String get ntfPushDirectMessage;

  /// No description provided for @ntfWaMatchReminder.
  ///
  /// In en, this message translates to:
  /// **'Match reminders (1h before kickoff)'**
  String get ntfWaMatchReminder;

  /// No description provided for @ntfWaResultConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Result confirmed'**
  String get ntfWaResultConfirmed;

  /// No description provided for @ntfWaPrizeCredited.
  ///
  /// In en, this message translates to:
  /// **'Prize credited to wallet'**
  String get ntfWaPrizeCredited;

  /// No description provided for @ntfWaChallengeCompleted.
  ///
  /// In en, this message translates to:
  /// **'Weekly challenge completed'**
  String get ntfWaChallengeCompleted;

  /// No description provided for @ntfWaAchievementUnlocked.
  ///
  /// In en, this message translates to:
  /// **'Achievement unlocked'**
  String get ntfWaAchievementUnlocked;

  /// No description provided for @ntfWaRegistrationConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Registration confirmed'**
  String get ntfWaRegistrationConfirmed;

  /// No description provided for @ntfShareTournament.
  ///
  /// In en, this message translates to:
  /// **'Tournament wins'**
  String get ntfShareTournament;

  /// No description provided for @ntfShareMilestone.
  ///
  /// In en, this message translates to:
  /// **'Milestone achievements (100 matches, etc.)'**
  String get ntfShareMilestone;

  /// No description provided for @ntfShareStreak.
  ///
  /// In en, this message translates to:
  /// **'Streak achievements'**
  String get ntfShareStreak;

  /// No description provided for @ntfShareSocial.
  ///
  /// In en, this message translates to:
  /// **'Social achievements (reactions, posts)'**
  String get ntfShareSocial;

  /// No description provided for @ntfShareOther.
  ///
  /// In en, this message translates to:
  /// **'All other achievements'**
  String get ntfShareOther;

  /// No description provided for @ntfChannelMatches.
  ///
  /// In en, this message translates to:
  /// **'Matches'**
  String get ntfChannelMatches;

  /// No description provided for @ntfChannelMatchesDesc.
  ///
  /// In en, this message translates to:
  /// **'Fixtures, reminders and results'**
  String get ntfChannelMatchesDesc;

  /// No description provided for @ntfChannelSocial.
  ///
  /// In en, this message translates to:
  /// **'Community'**
  String get ntfChannelSocial;

  /// No description provided for @ntfChannelSocialDesc.
  ///
  /// In en, this message translates to:
  /// **'Comments, reactions, followers and achievements'**
  String get ntfChannelSocialDesc;

  /// No description provided for @ntfChannelMessages.
  ///
  /// In en, this message translates to:
  /// **'Messages'**
  String get ntfChannelMessages;

  /// No description provided for @ntfChannelMessagesDesc.
  ///
  /// In en, this message translates to:
  /// **'Direct messages'**
  String get ntfChannelMessagesDesc;

  /// No description provided for @ntfChannelMoney.
  ///
  /// In en, this message translates to:
  /// **'Money'**
  String get ntfChannelMoney;

  /// No description provided for @ntfChannelMoneyDesc.
  ///
  /// In en, this message translates to:
  /// **'Prizes and referral rewards'**
  String get ntfChannelMoneyDesc;

  /// No description provided for @ntfChannelAdmin.
  ///
  /// In en, this message translates to:
  /// **'Admin alerts'**
  String get ntfChannelAdmin;

  /// No description provided for @ntfChannelAdminDesc.
  ///
  /// In en, this message translates to:
  /// **'Staff-only alerts'**
  String get ntfChannelAdminDesc;

  /// No description provided for @ntfErrValidation.
  ///
  /// In en, this message translates to:
  /// **'That value isn\'t valid.'**
  String get ntfErrValidation;

  /// No description provided for @ntfErrNotFound.
  ///
  /// In en, this message translates to:
  /// **'That notification no longer exists.'**
  String get ntfErrNotFound;

  /// No description provided for @ntfErrNetwork.
  ///
  /// In en, this message translates to:
  /// **'Check your connection and try again.'**
  String get ntfErrNetwork;

  /// No description provided for @ntfErrGeneric.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong.'**
  String get ntfErrGeneric;

  /// No description provided for @ntfBannerOpen.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get ntfBannerOpen;

  /// No description provided for @dmErrorGeneric.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get dmErrorGeneric;

  /// No description provided for @dmErrorBlockedByMe.
  ///
  /// In en, this message translates to:
  /// **'You blocked this player. Unblock them to send messages.'**
  String get dmErrorBlockedByMe;

  /// No description provided for @dmErrorBlocked.
  ///
  /// In en, this message translates to:
  /// **'You can\'t message this player.'**
  String get dmErrorBlocked;

  /// No description provided for @dmErrorRestricted.
  ///
  /// In en, this message translates to:
  /// **'Messaging is restricted on your account right now.'**
  String get dmErrorRestricted;

  /// No description provided for @dmErrorEditWindow.
  ///
  /// In en, this message translates to:
  /// **'You can only edit or unsend a message within 10 minutes of sending it.'**
  String get dmErrorEditWindow;

  /// No description provided for @dmErrorNotForwardable.
  ///
  /// In en, this message translates to:
  /// **'This message can\'t be forwarded.'**
  String get dmErrorNotForwardable;

  /// No description provided for @dmErrorRequestLimit.
  ///
  /// In en, this message translates to:
  /// **'You can send one message until they accept your request.'**
  String get dmErrorRequestLimit;

  /// No description provided for @dmErrorRequestNoMedia.
  ///
  /// In en, this message translates to:
  /// **'Photos, stickers and voice notes unlock once they accept your request.'**
  String get dmErrorRequestNoMedia;

  /// No description provided for @dmErrorNotFound.
  ///
  /// In en, this message translates to:
  /// **'That message or conversation no longer exists.'**
  String get dmErrorNotFound;

  /// No description provided for @dmErrorSendFailed.
  ///
  /// In en, this message translates to:
  /// **'Your message couldn\'t be sent.'**
  String get dmErrorSendFailed;

  /// No description provided for @dmErrorAction.
  ///
  /// In en, this message translates to:
  /// **'That didn\'t work. Please try again.'**
  String get dmErrorAction;

  /// No description provided for @dmErrorValidation.
  ///
  /// In en, this message translates to:
  /// **'That message isn\'t valid.'**
  String get dmErrorValidation;

  /// No description provided for @dmErrorImageTooLarge.
  ///
  /// In en, this message translates to:
  /// **'That photo is too large to send.'**
  String get dmErrorImageTooLarge;

  /// No description provided for @dmInboxTitle.
  ///
  /// In en, this message translates to:
  /// **'Messages'**
  String get dmInboxTitle;

  /// No description provided for @dmMessagesTooltip.
  ///
  /// In en, this message translates to:
  /// **'Messages'**
  String get dmMessagesTooltip;

  /// No description provided for @dmRequestsTitle.
  ///
  /// In en, this message translates to:
  /// **'Message requests'**
  String get dmRequestsTitle;

  /// No description provided for @dmRequestsRow.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{Message requests ({count})} other{Message requests ({count})}}'**
  String dmRequestsRow(int count);

  /// No description provided for @dmRequestsCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} request} other{{count} requests}}'**
  String dmRequestsCount(int count);

  /// No description provided for @dmEmptyInbox.
  ///
  /// In en, this message translates to:
  /// **'No messages yet. Open a player\'s profile to start a conversation.'**
  String get dmEmptyInbox;

  /// No description provided for @dmEmptyRequests.
  ///
  /// In en, this message translates to:
  /// **'No message requests.'**
  String get dmEmptyRequests;

  /// No description provided for @dmLoadError.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load your messages.'**
  String get dmLoadError;

  /// No description provided for @dmRetry.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get dmRetry;

  /// No description provided for @dmSignedOut.
  ///
  /// In en, this message translates to:
  /// **'Log in to see your messages.'**
  String get dmSignedOut;

  /// No description provided for @dmLogIn.
  ///
  /// In en, this message translates to:
  /// **'Log in'**
  String get dmLogIn;

  /// No description provided for @dmUnreadCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} unread message} other{{count} unread messages}}'**
  String dmUnreadCount(int count);

  /// No description provided for @dmWaitingFor.
  ///
  /// In en, this message translates to:
  /// **'Waiting for {name} to accept'**
  String dmWaitingFor(String name);

  /// No description provided for @dmRequestChip.
  ///
  /// In en, this message translates to:
  /// **'Request'**
  String get dmRequestChip;

  /// No description provided for @dmPreviewPhoto.
  ///
  /// In en, this message translates to:
  /// **'Photo'**
  String get dmPreviewPhoto;

  /// No description provided for @dmPreviewVoice.
  ///
  /// In en, this message translates to:
  /// **'Voice message'**
  String get dmPreviewVoice;

  /// No description provided for @dmPreviewRemoved.
  ///
  /// In en, this message translates to:
  /// **'Message removed'**
  String get dmPreviewRemoved;

  /// No description provided for @dmPreviewOther.
  ///
  /// In en, this message translates to:
  /// **'Message'**
  String get dmPreviewOther;

  /// No description provided for @dmTyping.
  ///
  /// In en, this message translates to:
  /// **'typing…'**
  String get dmTyping;

  /// No description provided for @dmOnline.
  ///
  /// In en, this message translates to:
  /// **'Online'**
  String get dmOnline;

  /// No description provided for @dmVoiceSeconds.
  ///
  /// In en, this message translates to:
  /// **'{seconds, plural, one{{seconds} second} other{{seconds} seconds}}'**
  String dmVoiceSeconds(int seconds);

  /// No description provided for @dmMessageRemoved.
  ///
  /// In en, this message translates to:
  /// **'Message removed'**
  String get dmMessageRemoved;

  /// No description provided for @dmUnsupported.
  ///
  /// In en, this message translates to:
  /// **'Unsupported message'**
  String get dmUnsupported;

  /// No description provided for @dmForwardedLabel.
  ///
  /// In en, this message translates to:
  /// **'Forwarded'**
  String get dmForwardedLabel;

  /// No description provided for @dmEditedLabel.
  ///
  /// In en, this message translates to:
  /// **'edited'**
  String get dmEditedLabel;

  /// No description provided for @dmReplyRemoved.
  ///
  /// In en, this message translates to:
  /// **'Original message removed'**
  String get dmReplyRemoved;

  /// No description provided for @dmReplyingTo.
  ///
  /// In en, this message translates to:
  /// **'Replying to {name}'**
  String dmReplyingTo(String name);

  /// No description provided for @dmReplyPhoto.
  ///
  /// In en, this message translates to:
  /// **'Photo'**
  String get dmReplyPhoto;

  /// No description provided for @dmReplySticker.
  ///
  /// In en, this message translates to:
  /// **'Sticker'**
  String get dmReplySticker;

  /// No description provided for @dmReplyVoice.
  ///
  /// In en, this message translates to:
  /// **'Voice message'**
  String get dmReplyVoice;

  /// No description provided for @dmYou.
  ///
  /// In en, this message translates to:
  /// **'You'**
  String get dmYou;

  /// No description provided for @dmToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get dmToday;

  /// No description provided for @dmYesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get dmYesterday;

  /// No description provided for @dmNewMessages.
  ///
  /// In en, this message translates to:
  /// **'New messages'**
  String get dmNewMessages;

  /// No description provided for @dmReceiptSent.
  ///
  /// In en, this message translates to:
  /// **'Sent'**
  String get dmReceiptSent;

  /// No description provided for @dmReceiptDelivered.
  ///
  /// In en, this message translates to:
  /// **'Delivered'**
  String get dmReceiptDelivered;

  /// No description provided for @dmReceiptRead.
  ///
  /// In en, this message translates to:
  /// **'Read'**
  String get dmReceiptRead;

  /// No description provided for @dmSending.
  ///
  /// In en, this message translates to:
  /// **'Sending'**
  String get dmSending;

  /// No description provided for @dmRetryAction.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get dmRetryAction;

  /// No description provided for @dmDiscard.
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get dmDiscard;

  /// No description provided for @dmActionReply.
  ///
  /// In en, this message translates to:
  /// **'Reply'**
  String get dmActionReply;

  /// No description provided for @dmActionCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get dmActionCopy;

  /// No description provided for @dmActionForward.
  ///
  /// In en, this message translates to:
  /// **'Forward'**
  String get dmActionForward;

  /// No description provided for @dmActionEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get dmActionEdit;

  /// No description provided for @dmActionUnsend.
  ///
  /// In en, this message translates to:
  /// **'Unsend'**
  String get dmActionUnsend;

  /// No description provided for @dmActionReport.
  ///
  /// In en, this message translates to:
  /// **'Report'**
  String get dmActionReport;

  /// No description provided for @dmCopied.
  ///
  /// In en, this message translates to:
  /// **'Copied'**
  String get dmCopied;

  /// No description provided for @dmComposerHint.
  ///
  /// In en, this message translates to:
  /// **'Message'**
  String get dmComposerHint;

  /// No description provided for @dmSend.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get dmSend;

  /// No description provided for @dmEditingBar.
  ///
  /// In en, this message translates to:
  /// **'Editing message'**
  String get dmEditingBar;

  /// No description provided for @dmSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get dmSave;

  /// No description provided for @dmCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get dmCancel;

  /// No description provided for @dmCloseReply.
  ///
  /// In en, this message translates to:
  /// **'Cancel reply'**
  String get dmCloseReply;

  /// No description provided for @dmConversationNotFound.
  ///
  /// In en, this message translates to:
  /// **'This conversation doesn\'t exist.'**
  String get dmConversationNotFound;

  /// No description provided for @dmMore.
  ///
  /// In en, this message translates to:
  /// **'More options'**
  String get dmMore;

  /// No description provided for @dmStickers.
  ///
  /// In en, this message translates to:
  /// **'Stickers'**
  String get dmStickers;

  /// No description provided for @dmStickerUnknown.
  ///
  /// In en, this message translates to:
  /// **'Unsupported sticker'**
  String get dmStickerUnknown;

  /// No description provided for @dmForwardTitle.
  ///
  /// In en, this message translates to:
  /// **'Forward to…'**
  String get dmForwardTitle;

  /// No description provided for @dmForwardEmpty.
  ///
  /// In en, this message translates to:
  /// **'No conversations to forward to.'**
  String get dmForwardEmpty;

  /// No description provided for @dmForwarded.
  ///
  /// In en, this message translates to:
  /// **'Message forwarded'**
  String get dmForwarded;

  /// No description provided for @dmAttachPhoto.
  ///
  /// In en, this message translates to:
  /// **'Send a photo'**
  String get dmAttachPhoto;

  /// No description provided for @dmPhotoLibrary.
  ///
  /// In en, this message translates to:
  /// **'Choose from library'**
  String get dmPhotoLibrary;

  /// No description provided for @dmPhotoCamera.
  ///
  /// In en, this message translates to:
  /// **'Take a photo'**
  String get dmPhotoCamera;

  /// No description provided for @dmImageUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Image unavailable'**
  String get dmImageUnavailable;

  /// No description provided for @dmBlock.
  ///
  /// In en, this message translates to:
  /// **'Block'**
  String get dmBlock;

  /// No description provided for @dmUnblock.
  ///
  /// In en, this message translates to:
  /// **'Unblock'**
  String get dmUnblock;

  /// No description provided for @dmReport.
  ///
  /// In en, this message translates to:
  /// **'Report'**
  String get dmReport;

  /// No description provided for @dmBlockConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Block {name}?'**
  String dmBlockConfirmTitle(String name);

  /// No description provided for @dmBlockConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'They won\'t be able to message you. You can unblock them at any time.'**
  String get dmBlockConfirmBody;

  /// No description provided for @dmBlockedByMeBanner.
  ///
  /// In en, this message translates to:
  /// **'You blocked {name}'**
  String dmBlockedByMeBanner(String name);

  /// No description provided for @dmCannotMessage.
  ///
  /// In en, this message translates to:
  /// **'You can\'t message this player.'**
  String get dmCannotMessage;

  /// No description provided for @dmReportTitle.
  ///
  /// In en, this message translates to:
  /// **'Report this conversation'**
  String get dmReportTitle;

  /// No description provided for @dmReportHint.
  ///
  /// In en, this message translates to:
  /// **'What happened?'**
  String get dmReportHint;

  /// No description provided for @dmReportSubmit.
  ///
  /// In en, this message translates to:
  /// **'Submit report'**
  String get dmReportSubmit;

  /// No description provided for @dmReported.
  ///
  /// In en, this message translates to:
  /// **'Thanks. We\'ll review your report.'**
  String get dmReported;

  /// No description provided for @dmIncomingTitle.
  ///
  /// In en, this message translates to:
  /// **'{name} wants to message you'**
  String dmIncomingTitle(String name);

  /// No description provided for @dmIncomingHint.
  ///
  /// In en, this message translates to:
  /// **'Only you can see that you have read this. They get no read receipt until you accept.'**
  String get dmIncomingHint;

  /// No description provided for @dmAccept.
  ///
  /// In en, this message translates to:
  /// **'Accept'**
  String get dmAccept;

  /// No description provided for @dmDecline.
  ///
  /// In en, this message translates to:
  /// **'Decline'**
  String get dmDecline;

  /// No description provided for @dmBlockAndReport.
  ///
  /// In en, this message translates to:
  /// **'Block and report'**
  String get dmBlockAndReport;

  /// No description provided for @dmWaitingHint.
  ///
  /// In en, this message translates to:
  /// **'You can send one text message until they accept.'**
  String get dmWaitingHint;

  /// No description provided for @dmMessageButton.
  ///
  /// In en, this message translates to:
  /// **'Message'**
  String get dmMessageButton;

  /// No description provided for @dmVoiceMessage.
  ///
  /// In en, this message translates to:
  /// **'Voice message'**
  String get dmVoiceMessage;

  /// No description provided for @dmMicTooltip.
  ///
  /// In en, this message translates to:
  /// **'Record a voice message'**
  String get dmMicTooltip;

  /// No description provided for @dmVoiceRecording.
  ///
  /// In en, this message translates to:
  /// **'Recording'**
  String get dmVoiceRecording;

  /// No description provided for @dmVoicePaused.
  ///
  /// In en, this message translates to:
  /// **'Paused'**
  String get dmVoicePaused;

  /// No description provided for @dmVoicePause.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get dmVoicePause;

  /// No description provided for @dmVoiceResume.
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get dmVoiceResume;

  /// No description provided for @dmVoiceStop.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get dmVoiceStop;

  /// No description provided for @dmVoiceDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get dmVoiceDelete;

  /// No description provided for @dmVoicePlay.
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get dmVoicePlay;

  /// No description provided for @dmVoiceTooShort.
  ///
  /// In en, this message translates to:
  /// **'That was too short. Hold on a little longer.'**
  String get dmVoiceTooShort;

  /// No description provided for @dmMicDenied.
  ///
  /// In en, this message translates to:
  /// **'Microphone access is needed to record voice messages.'**
  String get dmMicDenied;

  /// No description provided for @dmMicTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get dmMicTryAgain;

  /// No description provided for @dmMicOpenSettings.
  ///
  /// In en, this message translates to:
  /// **'Open settings'**
  String get dmMicOpenSettings;

  /// No description provided for @dmVoicePlaybackError.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t play this voice message.'**
  String get dmVoicePlaybackError;

  /// No description provided for @dmVoiceLimitReached.
  ///
  /// In en, this message translates to:
  /// **'Maximum length reached'**
  String get dmVoiceLimitReached;
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
