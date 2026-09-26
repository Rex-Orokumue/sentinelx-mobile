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
  String get homeLoadError =>
      'Une erreur s\'est produite lors du chargement de cette page.';

  @override
  String get accountTitle => 'Compte';

  @override
  String get accountLogIn => 'Se connecter';

  @override
  String get accountCreateAccount => 'Créer un compte';

  @override
  String get accountSignOut => 'Se déconnecter';

  @override
  String get accountSigningOut => 'Déconnexion…';

  @override
  String get accountSignOutFailed =>
      'Impossible de se déconnecter. Veuillez réessayer.';

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

  @override
  String get authErrorsForgotFailed =>
      'Impossible d\'envoyer le lien de réinitialisation. Veuillez réessayer.';

  @override
  String get authErrorsResendFailed =>
      'Impossible de renvoyer le lien de confirmation. Veuillez réessayer.';

  @override
  String get authErrorsGoogleNotConfigured =>
      'La connexion Google n\'est pas encore configurée.';

  @override
  String get authErrorsGoogleFailed =>
      'La connexion Google a échoué. Veuillez réessayer.';

  @override
  String get termsEyebrow => 'Mentions légales';

  @override
  String get termsTitle => 'Conditions d\'utilisation';

  @override
  String get termsSubtitle =>
      'Les conditions qui régissent votre utilisation de la plateforme SentinelX.';

  @override
  String get termsMetaUpdated => 'Dernière mise à jour : septembre 2026';

  @override
  String get termsSummary =>
      'En résumé : vous devez avoir au moins 13 ans, un seul compte par personne, et vous jouez loyalement — des résultats réels, appuyés par des preuves. Les gains sont versés sur votre compte bancaire via Paystack après une vérification d’identité. Les SX Coins sont des points de plateforme sans valeur monétaire. Le droit nigérian s’applique. Ce résumé n’est pas le texte juridique — les sections ci-dessous le sont.';

  @override
  String get termsMetaTitle => 'Conditions d\'utilisation';

  @override
  String get termsMetaDescription =>
      'Les conditions qui régissent l\'utilisation de la plateforme SentinelX Esports.';

  @override
  String get termsS1Heading => '1. Qui nous sommes';

  @override
  String get termsS1P1 =>
      'SentinelX Esports est une plateforme d\'esport mobile exploitée par Samuel Chinoyerem Akpoke (« nous », « notre »). Nous sommes basés au Nigeria et notre plateforme est disponible sur sentinelxesports.com.ng.';

  @override
  String get termsS1P2 =>
      'En créant un compte ou en utilisant une partie de SentinelX, vous acceptez les présentes Conditions d\'utilisation. Si vous n\'êtes pas d\'accord, veuillez ne pas utiliser la plateforme.';

  @override
  String get termsS2Heading => '2. Admissibilité';

  @override
  String get termsS2P1 =>
      'Vous devez avoir au moins 13 ans pour créer un compte. Si vous avez moins de 18 ans, vous confirmez avoir l\'autorisation d\'un parent ou tuteur pour utiliser la plateforme. Les joueurs de moins de 18 ans ne peuvent pas retirer leurs gains sans le consentement vérifiable d\'un parent ou tuteur.';

  @override
  String get termsS2P2 =>
      'Vous ne pouvez détenir qu\'un seul compte. La création de plusieurs comptes pour obtenir un avantage déloyal est interdite et entraîne un bannissement permanent.';

  @override
  String get termsS3Heading => '3. Votre compte';

  @override
  String get termsS3P1 =>
      'Vous êtes responsable de la sécurité de vos identifiants de connexion. Ne partagez votre mot de passe avec personne. Vous êtes responsable de toute activité effectuée sous votre compte.';

  @override
  String get termsS3P2 =>
      'Si vous pensez que votre compte a été compromis, contactez-nous immédiatement à <email>sentinelxesports@gmail.com</email>.';

  @override
  String get termsS4Heading => '4. Tournois et frais d\'inscription';

  @override
  String get termsS4P1 =>
      'Les frais d\'inscription aux tournois sont fixés par événement et affichés clairement avant l\'inscription. Le tarif standard actuel est de ₦500. En vous inscrivant et en effectuant le paiement, vous confirmez votre intention de participer.';

  @override
  String get termsS4P2 =>
      'Les frais d\'inscription sont traités en toute sécurité par Paystack. Nous ne conservons pas les données de votre carte.';

  @override
  String get termsS4P3 =>
      'Les SX Coins peuvent être utilisés pour réduire ou annuler les frais d\'inscription lorsque cette option est proposée. Consultez la <link>Politique de remboursement</link> pour savoir comment les annulations sont traitées.';

  @override
  String get termsS5Heading => '5. Règles de jeu et fair-play';

  @override
  String get termsS5Intro =>
      'Tous les joueurs doivent jouer honnêtement. Les actions suivantes sont interdites :';

  @override
  String get termsS5List =>
      '<li>Soumettre des résultats de match faux ou falsifiés</li><li>Utiliser des outils externes, scripts ou exploits pour obtenir un avantage</li><li>S\'entendre avec un adversaire pour produire un résultat prédéterminé</li><li>Menacer, harceler ou insulter ses adversaires</li>';

  @override
  String get termsS5P2 =>
      'Les résultats de match doivent être soumis avec des preuves à l\'appui (capture d\'écran et enregistrement d\'écran). Les décisions de l\'administrateur sur les résultats contestés sont définitives. Le règlement complet de conduite et de match figure dans le <link>Règlement des tournois</link>.';

  @override
  String get termsS5P3 =>
      'Une absence non signalée à votre match programmé entraîne un forfait et une pénalité sur votre SX Score.';

  @override
  String get termsS6Heading => '6. Gains et retraits';

  @override
  String get termsS6P1 =>
      'Les gains sont versés sur le compte bancaire que vous liez à votre tableau de bord joueur via Paystack. Vous devez terminer la vérification d\'identité avant votre premier retrait.';

  @override
  String get termsS6P2 =>
      'Nous visons à traiter les retraits approuvés sous 1 à 5 jours ouvrés. Nous ne sommes pas responsables des retards causés par votre banque.';

  @override
  String get termsS7Heading => '7. SX Coins';

  @override
  String get termsS7P1 =>
      'Les SX Coins sont une monnaie virtuelle interne à la plateforme. Ils sont gagnés en jouant et en passant du temps sur la plateforme. Les SX Coins n\'ont aucune valeur monétaire et ne peuvent pas être échangés contre de l\'argent. Ils peuvent être utilisés sur la plateforme pour des réductions sur les frais d\'inscription, des fonctionnalités communautaires et la boutique interne. Les SX Coins peuvent aussi être misés dans les paris communautaires (voir la section 8) et peuvent être perdus si votre pari n’est pas gagnant.';

  @override
  String get termsS8Heading => '8. Paris communautaires (SX Coins)';

  @override
  String get termsS8P1 =>
      'Vous pouvez miser des SX Coins sur l’issue d’un match auquel vous ne participez pas. Le pari est facultatif et utilise uniquement des SX Coins.';

  @override
  String get termsS8List =>
      '<li>Les paris ouvrent une fois les deux joueurs confirmés pour un match programmé et se ferment 15 minutes avant l’heure de début prévue. Pour les matchs programmés sur une journée entière, ils se ferment 24 heures après le début de cette journée.</li><li>Une commission de plateforme de 5 % est prélevée sur la cagnotte perdante. Les gains sont versés uniquement en SX Coins.</li><li>Les paris sont réglés automatiquement à partir du résultat du match confirmé par l’administrateur, et ce règlement est définitif.</li><li>Si un match est annulé ou qu’un résultat est infirmé, chaque mise est intégralement restituée.</li>';

  @override
  String get termsS8P2 =>
      'Comme les SX Coins n’ont aucune valeur monétaire et ne peuvent pas être échangés contre de l’argent, les paris communautaires ne constituent pas des paris d’argent.';

  @override
  String get termsS9Heading => '9. Gaming Exchange';

  @override
  String get termsS9P1 =>
      'Le Gaming Exchange (propulsé par l\'escrow Zolarux) permet aux joueurs d\'acheter et de vendre des comptes de jeu et des objets in-game. SentinelX fournit la plateforme et l\'infrastructure d\'escrow. Nous ne sommes pas partie à la transaction entre l\'acheteur et le vendeur et ne sommes pas responsables des litiges découlant de transactions effectuées en dehors du système d\'escrow de la plateforme. Consultez <link>le fonctionnement de l’escrow</link> pour le détail étape par étape.';

  @override
  String get termsS10Heading => '10. Standards communautaires';

  @override
  String get termsS10P1 =>
      'Vous acceptez de traiter tous les autres membres de la communauté SentinelX avec respect. Les discours de haine, la discrimination, les menaces et le harcèlement ne sont pas tolérés et entraîneront une suspension ou un bannissement permanent. Consultez nos <link>Règles communautaires</link> pour la liste complète des standards.';

  @override
  String get termsS11Heading => '11. Propriété intellectuelle';

  @override
  String get termsS11P1 =>
      'Toute l\'image de marque, le design et le contenu original de SentinelX appartiennent à SentinelX Esports. Vous ne pouvez pas reproduire, copier ou distribuer notre contenu sans autorisation écrite. Le contenu que vous publiez (captures d\'écran de match, publications communautaires) reste le vôtre, mais vous nous accordez une licence pour l\'afficher sur la plateforme.';

  @override
  String get termsS12Heading => '12. Limitation de responsabilité';

  @override
  String get termsS12P1 =>
      'SentinelX Esports n\'est pas responsable des pertes indirectes, accessoires ou consécutives résultant de votre utilisation de la plateforme. Notre responsabilité totale envers vous pour toute réclamation ne dépassera pas le total des frais d\'inscription que vous nous avez versés au cours des 3 mois précédant la réclamation.';

  @override
  String get termsS12P2 =>
      'Nous ne garantissons pas un accès ininterrompu à la plateforme. Nous ferons des efforts raisonnables pour rétablir le service rapidement en cas d\'interruption.';

  @override
  String get termsS13Heading => '13. Modifications des présentes conditions';

  @override
  String get termsS13P1 =>
      'Nous pouvons mettre à jour ces Conditions de temps à autre. Nous vous informerons via la plateforme ou par e-mail en cas de changements importants. Continuer à utiliser SentinelX après la publication des changements signifie que vous acceptez les conditions mises à jour.';

  @override
  String get termsS14Heading => '14. Droit applicable';

  @override
  String get termsS14P1 =>
      'Les présentes Conditions sont régies par les lois de la République fédérale du Nigeria. Tout litige relève de la compétence des tribunaux nigérians.';

  @override
  String get termsS15Heading => '15. Contact';

  @override
  String get termsS15P1 =>
      'Des questions sur ces Conditions ? Écrivez-nous à <email>sentinelxesports@gmail.com</email> ou contactez-nous sur WhatsApp : <whatsapp>+234 903 239 5685</whatsapp>.';

  @override
  String get cmpTabAll => 'Tous';

  @override
  String get cmpTabLive => 'En direct';

  @override
  String get cmpTabUpcoming => 'À venir';

  @override
  String get cmpTabCompleted => 'Terminés';

  @override
  String get cmpAllGames => 'Tous les jeux';

  @override
  String get cmpEmpty => 'Aucun tournoi pour le moment.';

  @override
  String get cmpLoadError =>
      'Chargement impossible. Vérifiez votre connexion et réessayez.';

  @override
  String get cmpRetry => 'Réessayer';

  @override
  String get cmpLoadMore => 'Charger plus';

  @override
  String get cmpEntryFee => 'Frais d\'inscription';

  @override
  String get cmpFree => 'Gratuit';

  @override
  String get cmpPrizePool => 'Cagnotte';

  @override
  String get cmpSecondPlace => '2e place';

  @override
  String get cmpThirdPlace => '3e place';

  @override
  String cmpMaxPlayers(int count) {
    return '$count joueurs maximum';
  }

  @override
  String get cmpRules => 'Règlement';

  @override
  String get cmpViewBracket => 'Voir le tableau';

  @override
  String get cmpShareWhatsapp => 'Partager sur WhatsApp';

  @override
  String cmpShareText(String title, String url) {
    return 'Rejoignez $title sur Sentinel X : $url';
  }

  @override
  String get cmpCtaRegister => 'S\'inscrire';

  @override
  String get cmpCtaResume => 'Reprendre le paiement';

  @override
  String get cmpCtaLogin => 'Connectez-vous pour vous inscrire';

  @override
  String get cmpCtaJoinWaitlist => 'Rejoindre la liste d\'attente';

  @override
  String get cmpViewInvitations => 'Voir mes invitations';

  @override
  String get cmpStateRegistered => 'Vous êtes inscrit.';

  @override
  String get cmpStateWaitlisted => 'Vous êtes sur la liste d\'attente.';

  @override
  String get cmpStateFull => 'Ce tournoi est complet.';

  @override
  String get cmpStateEnded => 'Ce tournoi est terminé.';

  @override
  String get cmpStateInvitationOnly =>
      'Ce tournoi est sur invitation uniquement.';

  @override
  String get cmpFeeWaived => 'Entrée gratuite — dispense appliquée';

  @override
  String get cmpFieldDisplayName => 'Nom affiché';

  @override
  String get cmpFieldWhatsapp => 'Numéro WhatsApp';

  @override
  String get cmpFieldClub => 'Nom du club';

  @override
  String get cmpFieldIgn => 'Pseudo en jeu (facultatif)';

  @override
  String get cmpAgreeRules => 'J\'ai lu et j\'accepte le règlement';

  @override
  String get cmpCoinsTitle => 'Utiliser des SX Coins';

  @override
  String get cmpCoinsNone => 'Ne pas utiliser de pièces';

  @override
  String cmpCoinsOption(int coins, String naira) {
    return '$coins pièces (−$naira ₦)';
  }

  @override
  String get cmpSubmitRegister => 'Continuer';

  @override
  String get cmpSubmitWaitlist => 'Rejoindre la liste d\'attente';

  @override
  String get cmpSubmitting => 'En cours…';

  @override
  String get cmpValDisplayName => 'Saisissez un nom (1 à 60 caractères).';

  @override
  String get cmpValWhatsapp => 'Saisissez un numéro WhatsApp valide.';

  @override
  String get cmpValClub => 'Saisissez votre club (1 à 60 caractères).';

  @override
  String get cmpValIgn => 'Pseudo trop long (60 max).';

  @override
  String get cmpValRules => 'Veuillez accepter le règlement.';

  @override
  String get cmpPayConfirming => 'Confirmation du paiement…';

  @override
  String get cmpPaySuccess => 'C\'est fait ! Paiement confirmé.';

  @override
  String get cmpPayNotConfirmed =>
      'Nous n\'avons pas encore reçu votre paiement. Si vous avez été débité, il sera confirmé sous peu — revenez dans une minute.';

  @override
  String get cmpPayCancelled =>
      'Fenêtre de paiement fermée. Vous pouvez reprendre depuis la page du tournoi.';

  @override
  String get cmpConfirmedFree => 'Vous êtes inscrit !';

  @override
  String get cmpWaitlistJoined => 'Vous êtes sur la liste d\'attente.';

  @override
  String get cmpInvTitle => 'Mes invitations';

  @override
  String get cmpInvEmpty => 'Aucune invitation en attente.';

  @override
  String get cmpInvAccept => 'Accepter';

  @override
  String get cmpInvDecline => 'Refuser';

  @override
  String cmpInvExpires(String date) {
    return 'Expire le $date';
  }

  @override
  String get cmpInvDeclined => 'Invitation refusée.';

  @override
  String get cmpGamesTitle => 'Jeux';

  @override
  String get cmpGamesEmpty => 'Aucun jeu pour le moment.';

  @override
  String get cmpEditProfile => 'Modifier le profil';

  @override
  String get cmpFieldBio => 'Bio';

  @override
  String get cmpFieldCountry => 'Pays';

  @override
  String get cmpFieldUsername => 'Nom d\'utilisateur (modifiable une fois)';

  @override
  String get cmpSave => 'Enregistrer';

  @override
  String get cmpSaved => 'Profil enregistré.';

  @override
  String get cmpValBio => 'La bio doit faire 280 caractères maximum.';

  @override
  String get cmpValCountry => 'Pays trop long (60 max).';

  @override
  String get cmpEcGeneric => 'Une erreur est survenue. Veuillez réessayer.';

  @override
  String get cmpEcNetwork =>
      'Pas de connexion. Vérifiez votre internet et réessayez.';

  @override
  String get cmpEcSession => 'Votre session a expiré. Reconnectez-vous.';

  @override
  String get cmpEcTournamentNotFound => 'Tournoi introuvable.';

  @override
  String get cmpEcRulesRequired =>
      'Veuillez confirmer que vous acceptez le règlement.';

  @override
  String get cmpEcAlreadyRegistered => 'Vous êtes déjà inscrit à ce tournoi.';

  @override
  String get cmpEcTournamentFull => 'Ce tournoi est complet.';

  @override
  String get cmpEcInvitationOnly => 'Ce tournoi est sur invitation uniquement.';

  @override
  String get cmpEcRegistrationClosed => 'Les inscriptions sont fermées.';

  @override
  String get cmpEcInsufficientCoins =>
      'Pas assez de SX Coins pour cette réduction.';

  @override
  String get cmpEcPaymentInit => 'Le paiement n\'a pas pu démarrer. Réessayez.';

  @override
  String get cmpEcWaitlistNotOpen =>
      'La liste d\'attente ouvre à la fin des inscriptions.';

  @override
  String get cmpEcAlreadyWaitlisted =>
      'Vous êtes déjà sur la liste d\'attente.';

  @override
  String get cmpEcInProgress =>
      'Traitement en cours. Patientez un instant puis réessayez.';

  @override
  String get cmpEcInvitationNotFound => 'Invitation introuvable.';

  @override
  String get cmpEcInvitationGone => 'Cette invitation n\'est plus disponible.';

  @override
  String get cmpEcInvitationExpired => 'Cette invitation a expiré.';

  @override
  String get cmpEcUsernameTaken => 'Ce nom d\'utilisateur est déjà pris.';

  @override
  String get cmpEcUsernameLocked =>
      'Votre nom d\'utilisateur a déjà été modifié une fois.';

  @override
  String get cmpEcSaveFailed =>
      'Impossible d\'enregistrer votre profil. Réessayez.';

  @override
  String get cmpHomeGamesTile => 'Jeux';

  @override
  String get cmpHomeInvitationsTile => 'Mes invitations';

  @override
  String get cmpAccountEditProfile => 'Modifier le profil';

  @override
  String get cmpStatusRegistrationOpen => 'Inscriptions ouvertes';

  @override
  String get cmpStatusRegistrationClosed => 'Inscriptions fermées';

  @override
  String get cmpStatusActive => 'En direct';

  @override
  String get cmpStatusCompleted => 'Terminé';
}
