import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/core/l10n/gen/app_localizations_en.dart';
import 'package:sentinelx_mobile/core/l10n/gen/app_localizations_fr.dart';
import 'package:sentinelx_mobile/core/notifications/push/push_gateway.dart';
import 'package:sentinelx_mobile/core/notifications/push/push_models.dart';

void main() {
  group('channels', () {
    test('ids are exactly the five versioned channels the web sender targets', () {
      // Literal copy of ANDROID_CHANNEL_IDS in the web repo's lib/notifications/channels.ts.
      expect(kPushChannelIds, ['matches_v1', 'social_v1', 'messages_v1', 'money_v1', 'admin_v1']);
    });

    test('buildPushChannels yields one localized spec per id, unique, social is default importance', () {
      for (final l in [AppLocalizationsEn(), AppLocalizationsFr()]) {
        final specs = buildPushChannels(l);
        expect(specs.map((s) => s.id).toList(), kPushChannelIds);
        expect(specs.map((s) => s.id).toSet(), hasLength(5));
        expect(specs.every((s) => s.name.isNotEmpty && s.description.isNotEmpty), isTrue);
        expect(specs.firstWhere((s) => s.id == 'social_v1').highImportance, isFalse);
        expect(specs.where((s) => s.id != 'social_v1').every((s) => s.highImportance), isTrue);
      }
    });
  });

  group('PushMessage.fromData', () {
    test('prefers url, falls back to link, blank becomes null', () {
      expect(PushMessage.fromData({'url': '/matches/1', 'link': '/x'}).url, '/matches/1');
      expect(PushMessage.fromData({'link': '/community/p'}).url, '/community/p');
      expect(PushMessage.fromData({'url': '   '}).url, isNull);
      expect(PushMessage.fromData({'url': ''}).url, isNull);
    });

    test('reads type and falls back title/body from data', () {
      final m = PushMessage.fromData({'type': 'match_assigned', 'title': 'T', 'body': 'B'});
      expect(m.type, 'match_assigned');
      expect(m.title, 'T');
      expect(m.body, 'B');
      final n = PushMessage.fromData({'title': 'data title'}, title: 'notif title', body: 'notif body');
      expect(n.title, 'notif title');
      expect(n.body, 'notif body');
    });

    test('an empty or odd payload never throws', () {
      final m = PushMessage.fromData({'url': 5, 'type': null});
      expect(m.url, isNull);
      expect(m.type, isNull);
      expect(m.title, isNull);
      expect(PushMessage.fromData(const {}).body, isNull);
    });
  });

  group('DisabledPushGateway', () {
    test('is inert and safe', () async {
      const g = DisabledPushGateway();
      expect(g.isAvailable, isFalse);
      expect(await g.getToken(), isNull);
      expect(await g.permission(), PushPermission.denied);
      expect(await g.requestPermission(), PushPermission.denied);
      expect(await g.getInitialMessage(), isNull);
      await g.createChannels(const []);
      await g.openSystemSettings();
      expect(await g.onTokenRefresh.isEmpty, isTrue);
      expect(await g.onForegroundMessage.isEmpty, isTrue);
      expect(await g.onMessageOpened.isEmpty, isTrue);
    });
  });
}
