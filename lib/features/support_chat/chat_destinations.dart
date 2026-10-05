import '../../core/api/chat_models.dart';

/// The ONLY way model output can influence navigation: a validated enum through this fixed table.
String? destinationRoute(ChatDestination d) => switch (d) {
      ChatDestination.tournaments => '/tournaments',
      ChatDestination.matches => '/',
      ChatDestination.profile => '/account/profile',
      ChatDestination.notifications => '/notifications',
      ChatDestination.wallet || ChatDestination.rules || ChatDestination.safety || ChatDestination.help => null,
    };
