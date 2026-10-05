import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/core/api/chat_models.dart';
import 'package:sentinelx_mobile/features/support_chat/chat_destinations.dart';

void main() {
test('only destinations that have a screen map to a route; the rest are hidden', () {
  expect(destinationRoute(ChatDestination.tournaments), '/tournaments');
  expect(destinationRoute(ChatDestination.matches), '/');
  expect(destinationRoute(ChatDestination.profile), '/account/profile');
  expect(destinationRoute(ChatDestination.notifications), '/notifications');
  expect(destinationRoute(ChatDestination.wallet), isNull);
  expect(destinationRoute(ChatDestination.rules), isNull);
});
}
