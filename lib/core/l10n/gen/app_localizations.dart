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
