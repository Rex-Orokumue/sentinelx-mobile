// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get appName => 'Sentinel X';

  @override
  String get maintenanceTitle => 'Nous revenons tout de suite';

  @override
  String get updateRequiredTitle => 'Mise à jour requise';

  @override
  String updateRequiredBody(String minVersion) {
    return 'Veuillez mettre à jour Sentinel X vers la version $minVersion ou plus récente pour continuer.';
  }

  @override
  String get updateAction => 'Mettre à jour';

  @override
  String get commonSiteName => 'SentinelX';

  @override
  String get commonViewAll => 'Voir tout';

  @override
  String get commonMenu => 'Menu';

  @override
  String get commonCloseMenu => 'Fermer le menu';

  @override
  String get commonJoinWhatsapp => 'Rejoindre la communauté WhatsApp';

  @override
  String get commonAdmin => 'Administrateur';

  @override
  String get commonModerator => 'Modérateur';

  @override
  String get navHome => 'Accueil';

  @override
  String get navTournaments => 'Tournois';

  @override
  String get navGames => 'Jeux';

  @override
  String get navRankings => 'Classements';

  @override
  String get navSeasons => 'Saisons';

  @override
  String get navExchange => 'Échange';

  @override
  String get navStore => 'Boutique';

  @override
  String get navCommunity => 'Communauté';

  @override
  String get navAbout => 'À propos';

  @override
  String get navTv => 'TV';

  @override
  String get navMore => 'Plus';

  @override
  String get homeUpcomingHeading => 'À venir';

  @override
  String get homeTopPlayersHeading => 'Meilleurs joueurs';

  @override
  String get homeFullRankingsLink => 'Classement complet';

  @override
  String get authMetaLogin => 'Connexion · SentinelX Esports';

  @override
  String get authMetaSignup => 'Inscription · SentinelX Esports';

  @override
  String get authMetaForgotPassword =>
      'Mot de passe oublié · SentinelX Esports';

  @override
  String get authMetaResetPassword =>
      'Nouveau mot de passe · SentinelX Esports';

  @override
  String get authMetaUsername => 'Choisissez votre pseudo · SentinelX Esports';

  @override
  String get authMetaPhone => 'Vérifiez votre téléphone · SentinelX Esports';

  @override
  String get authCommonEmail => 'E-mail';

  @override
  String get authCommonPassword => 'Mot de passe';

  @override
  String get authCommonUsername => 'Pseudo';

  @override
  String get authCommonOr => 'OU';

  @override
  String get authCommonBackToLogin => 'Retour à la connexion';

  @override
  String get authCommonShowPassword => 'Afficher le mot de passe';

  @override
  String get authCommonHidePassword => 'Masquer le mot de passe';

  @override
  String get authCommonAtLeast8 => 'Au moins 8 caractères.';

  @override
  String get authCommonContinueWithGoogle => 'Continuer avec Google';

  @override
  String get authCommonBack => 'Retour';

  @override
  String get authLoginTitle => 'Bon retour';

  @override
  String get authLoginSubtitle =>
      'Connectez-vous à votre compte SentinelX Esports.';

  @override
  String get authLoginSubmit => 'Se connecter';

  @override
  String get authLoginSubmitting => 'Connexion…';

  @override
  String get authLoginResend => 'Renvoyer l\'e-mail de confirmation';

  @override
  String get authLoginResending => 'Envoi…';

  @override
  String get authLoginResendHint =>
      'Vous n\'avez rien reçu ? Vérifiez vos spams — ou utilisez la connexion Google ci-dessous, qui évite la confirmation par e-mail.';

  @override
  String get authLoginForgot => 'Mot de passe oublié ?';

  @override
  String get authLoginCreateAccount => 'Créer un compte';

  @override
  String get authSignupStep1Title => 'Rejoignez SentinelX Esports';

  @override
  String get authSignupStep1Subtitle =>
      'La voie la plus rapide — aucune confirmation par e-mail :';

  @override
  String get authSignupContinueWithEmail => 'Continuer avec un e-mail';

  @override
  String get authSignupHaveAccount => 'Vous avez déjà un compte ?';

  @override
  String get authSignupLogIn => 'Se connecter';

  @override
  String get authSignupStep2Title => 'Créez votre compte';

  @override
  String get authSignupSubmit => 'Créer un compte';

  @override
  String get authSignupSubmitting => 'Création du compte…';

  @override
  String get authSignupCheckEmailTitle => 'Consultez vos e-mails';

  @override
  String authSignupCheckEmailBody(String email) {
    return 'Nous avons envoyé un lien de confirmation à $email. Cliquez dessus pour activer votre compte, puis connectez-vous et choisissez votre pseudo.';
  }

  @override
  String get authSignupNothingYet =>
      'Toujours rien après quelques minutes ? Vérifiez vos spams, puis :';

  @override
  String get authSignupResend => 'Renvoyer';

  @override
  String get authSignupResending => 'Envoi…';

  @override
  String get authSignupGoogleTipBefore =>
      'Les e-mails sont parfois retardés. S\'inscrire avec Google évite complètement la confirmation — ';

  @override
  String get authSignupStartOver => 'recommencez';

  @override
  String get authSignupGoogleTipAfter => ' et utilisez le bouton Google.';

  @override
  String get authSignupOrSignUpWithEmail => 'OU S\'INSCRIRE PAR E-MAIL';

  @override
  String authSignupSigningUpAs(String username) {
    return 'Inscription en tant que $username.';
  }

  @override
  String get authForgotTitle => 'Réinitialisez votre mot de passe';

  @override
  String get authForgotSubtitle =>
      'Saisissez votre e-mail et nous vous enverrons un lien de réinitialisation.';

  @override
  String get authForgotSubmit => 'Envoyer le lien';

  @override
  String get authForgotSubmitting => 'Envoi…';

  @override
  String get authResetTitle => 'Définir un nouveau mot de passe';

  @override
  String get authResetSubtitle =>
      'Choisissez un nouveau mot de passe pour votre compte.';

  @override
  String get authResetNewPassword => 'Nouveau mot de passe';

  @override
  String get authResetSubmit => 'Définir le mot de passe';

  @override
  String get authResetSubmitting => 'Mise à jour…';

  @override
  String get authUsernameStepTitle => 'Choisissez votre pseudo';

  @override
  String get authUsernameStepSubtitle =>
      'C\'est votre nom public sur SentinelX Esports.';

  @override
  String get authUsernameStepSubmit => 'Continuer';

  @override
  String get authUsernameStepSubmitting => 'Enregistrement…';

  @override
  String get authPhoneStepTitle => 'Vérifiez votre téléphone';

  @override
  String get authPhoneStepSubtitle =>
      'Nous enverrons un code à 6 chiffres sur WhatsApp afin de pouvoir vous joindre au sujet des matchs et des résultats.';

  @override
  String get authAvailabilityTaken => 'Ce pseudo est déjà pris.';

  @override
  String get authAvailabilityInvalid =>
      '3 à 20 caractères : lettres, chiffres, tirets bas.';

  @override
  String get authAvailabilityUnknown =>
      'Vérification impossible pour l\'instant — vous pouvez continuer.';

  @override
  String get authNoticesCheckEmail =>
      'Consultez vos e-mails pour trouver le lien de confirmation.';

  @override
  String get authNoticesResendSent =>
      'Si cette adresse doit encore être confirmée, un nouveau lien est en route. Vérifiez vos spams — et la connexion Google évite entièrement l\'e-mail.';

  @override
  String get authNoticesResetSent =>
      'Si un compte existe pour cette adresse, nous avons envoyé un lien de réinitialisation.';

  @override
  String get authErrorsInvalidEmail => 'Saisissez une adresse e-mail valide.';

  @override
  String get authErrorsPasswordRequired => 'Le mot de passe est requis.';

  @override
  String get authErrorsPasswordTooShort =>
      'Le mot de passe doit contenir au moins 8 caractères.';

  @override
  String get authErrorsUsernameTooShort =>
      'Le pseudo doit contenir au moins 3 caractères.';

  @override
  String get authErrorsUsernameTooLong =>
      'Le pseudo ne doit pas dépasser 20 caractères.';

  @override
  String get authErrorsUsernameCharset =>
      'Uniquement des lettres, chiffres et tirets bas.';

  @override
  String get authErrorsInvalidCredentials =>
      'E-mail ou mot de passe incorrect.';

  @override
  String get authErrorsEmailNotConfirmed =>
      'Votre e-mail n\'est pas encore confirmé — cherchez le lien dans votre boîte de réception (et vos spams).';

  @override
  String get authErrorsBlockedDetails =>
      'Nous n\'avons pas pu créer de compte avec ces informations.';

  @override
  String get authErrorsUsernameTaken =>
      'Ce pseudo est déjà pris — essayez-en un autre.';

  @override
  String get authErrorsUsernameTakenGoBack =>
      'Ce pseudo est déjà pris — revenez en arrière et choisissez-en un autre.';

  @override
  String get authErrorsSignupFailed =>
      'Un problème est survenu lors de la création de votre compte. Veuillez réessayer.';

  @override
  String get authErrorsUsernameSaveFailed =>
      'Impossible d\'enregistrer votre pseudo. Veuillez réessayer.';

  @override
  String get authErrorsLinkExpired =>
      'Votre lien de réinitialisation a expiré. Veuillez en demander un nouveau.';

  @override
  String get authErrorsResetFailed =>
      'Impossible de mettre à jour votre mot de passe. Veuillez réessayer.';
}
