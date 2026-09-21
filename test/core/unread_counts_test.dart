import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/core/notifications/unread_counts.dart';

void main() {
  test('countQuery filters by player_id, read=false, and an optional type', () {
    expect(countQuery(playerId: 'u1', type: null), {'player_id': 'u1', 'read': false});
    expect(countQuery(playerId: 'u1', type: 'direct_message'), {'player_id': 'u1', 'read': false, 'type': 'direct_message'});
  });
}
