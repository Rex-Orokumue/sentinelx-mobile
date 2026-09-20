import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/core/config/remote_config.dart';

Map<String, dynamic> _json({String min = '0.0.0', Map<String, dynamic>? maintenance}) => {
      'minSupportedAppVersion': min,
      'latestAppVersion': '1.4.0',
      'maintenance': maintenance,
      'siteUrl': 'https://sentinelxesports.com.ng',
      'coins': {'coinsPerNaira': 2, 'nairaPerCoin': 0.5, 'coinsPerEntry': 1000, 'coinsHalfEntry': 500},
      'enforcePhoneVerification': false,
      'whatsappCommunityUrl': null,
      'features': {'wagering': false, 'store': true},
    };

void main() {
  group('RemoteConfig.fromJson', () {
    test('parses the /config payload', () {
      final c = RemoteConfig.fromJson(_json(min: '1.2.0', maintenance: {'message': 'Back at 3pm'}));
      expect(c.minSupportedAppVersion, '1.2.0');
      expect(c.maintenanceMessage, 'Back at 3pm');
      expect(c.coinsPerEntry, 1000);
      expect(c.nairaPerCoin, 0.5);
      expect(c.whatsappCommunityUrl, isNull);
    });
    test('feature() reads flags and treats unknown keys as enabled', () {
      final c = RemoteConfig.fromJson(_json());
      expect(c.feature('wagering'), isFalse);
      expect(c.feature('store'), isTrue);
      expect(c.feature('something_new'), isTrue);
    });
  });

  group('evaluateGate', () {
    test('opens when the config could not be fetched — never lock users out on a network blip', () {
      expect(evaluateGate(null, '1.0.0').kind, GateKind.open);
    });
    test('opens when the installed version meets the minimum', () {
      expect(evaluateGate(RemoteConfig.fromJson(_json(min: '1.0.0')), '1.0.0+7').kind, GateKind.open);
    });
    test('requires an update below the minimum and names it', () {
      final g = evaluateGate(RemoteConfig.fromJson(_json(min: '1.2.0')), '1.1.9');
      expect(g.kind, GateKind.updateRequired);
      expect(g.minVersion, '1.2.0');
    });
    test('maintenance wins over everything and carries the message', () {
      final g = evaluateGate(RemoteConfig.fromJson(_json(min: '9.0.0', maintenance: {'message': 'Down'})), '1.0.0');
      expect(g.kind, GateKind.maintenance);
      expect(g.message, 'Down');
    });
  });
}
