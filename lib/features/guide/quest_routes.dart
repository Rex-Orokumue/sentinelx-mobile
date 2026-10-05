import '../../core/api/guide_models.dart';

/// Where "Take me there" goes. A null target (unknown to this app version) shows no link.
String? questStepRoute(QuestTarget? t) => switch (t) {
      QuestTarget.editProfile => '/account/profile',
      QuestTarget.tournaments => '/tournaments',
      QuestTarget.matches => '/',
      null => null,
    };
