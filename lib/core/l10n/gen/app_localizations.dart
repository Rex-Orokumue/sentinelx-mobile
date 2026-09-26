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

  /// No description provided for @cmpFieldClub.
  ///
  /// In en, this message translates to:
  /// **'Club name'**
  String get cmpFieldClub;

  /// No description provided for @cmpFieldIgn.
  ///
  /// In en, this message translates to:
  /// **'In-game tag (optional)'**
  String get cmpFieldIgn;

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

  /// No description provided for @cmpValClub.
  ///
  /// In en, this message translates to:
  /// **'Enter your club (1–60 characters).'**
  String get cmpValClub;

  /// No description provided for @cmpValIgn.
  ///
  /// In en, this message translates to:
  /// **'Tag is too long (60 max).'**
  String get cmpValIgn;

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
