import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/core/api/notifications_models.dart';
import 'package:sentinelx_mobile/core/l10n/gen/app_localizations_en.dart';
import 'package:sentinelx_mobile/core/l10n/gen/app_localizations_fr.dart';
import 'package:sentinelx_mobile/features/notifications/notification_error_copy.dart';
import 'package:sentinelx_mobile/features/notifications/pref_labels.dart';
import 'package:sentinelx_mobile/features/notifications/relative_time.dart';

void main() {
  final en = AppLocalizationsEn();
  final fr = AppLocalizationsFr();

  group('plurals (lesson 7: "1 notification", not "1 notifications")', () {
    test('en', () {
      expect(en.ntfUnreadCount(1), '1 unread notification');
      expect(en.ntfUnreadCount(3), '3 unread notifications');
      expect(en.ntfTimeMinutes(1), '1 minute ago');
      expect(en.ntfTimeMinutes(5), '5 minutes ago');
      expect(en.ntfTimeHours(1), '1 hour ago');
      expect(en.ntfTimeHours(5), '5 hours ago');
      expect(en.ntfTimeDays(1), '1 day ago');
      expect(en.ntfTimeDays(5), '5 days ago');
    });
    test('fr', () {
      expect(fr.ntfUnreadCount(1), '1 notification non lue');
      expect(fr.ntfUnreadCount(3), '3 notifications non lues');
      expect(fr.ntfTimeMinutes(1), 'il y a 1 minute');
      expect(fr.ntfTimeMinutes(5), 'il y a 5 minutes');
      expect(fr.ntfTimeHours(1), 'il y a 1 heure');
      expect(fr.ntfTimeDays(2), 'il y a 2 jours');
    });
  });

  group('notificationErrorCopy', () {
    test('maps known codes and falls back to generic', () {
      expect(notificationErrorCopy(en, 'validation_failed'), en.ntfErrValidation);
      expect(notificationErrorCopy(en, 'not_found'), en.ntfErrNotFound);
      expect(notificationErrorCopy(en, 'network'), en.ntfErrNetwork);
      expect(notificationErrorCopy(en, 'something_new'), en.ntfErrGeneric);
      expect(notificationErrorCopy(fr, 'network'), fr.ntfErrNetwork);
    });
  });

  group('relativeTime', () {
    final now = DateTime.utc(2026, 10, 3, 12);
    String at(Duration ago) => relativeTime(en, now.subtract(ago), now);

    test('under a minute is "just now"', () {
      expect(at(Duration.zero), en.ntfTimeNow);
      expect(at(const Duration(seconds: 59)), en.ntfTimeNow);
    });
    test('minutes, hours, days', () {
      expect(at(const Duration(seconds: 60)), '1 minute ago');
      expect(at(const Duration(minutes: 59)), '59 minutes ago');
      expect(at(const Duration(minutes: 60)), '1 hour ago');
      expect(at(const Duration(hours: 23)), '23 hours ago');
      expect(at(const Duration(hours: 24)), '1 day ago');
      expect(at(const Duration(days: 40)), '40 days ago');
    });
    test('a timestamp in the future (clock skew) reads as now, never negative', () {
      expect(relativeTime(en, now.add(const Duration(minutes: 5)), now), en.ntfTimeNow);
    });
    test('french uses the same buckets', () {
      expect(relativeTime(fr, now.subtract(const Duration(hours: 2)), now), 'il y a 2 heures');
    });
  });

  group('pref labels', () {
    test('every known key has a real label, in both languages', () {
      for (final l in [en, fr]) {
        for (final k in kPushPrefKeys) {
          expect(pushPrefLabel(l, k), isNot(k), reason: 'push $k');
        }
        for (final k in kWhatsappPrefKeys) {
          expect(whatsappPrefLabel(l, k), isNot(k), reason: 'whatsapp $k');
        }
        for (final k in kSharingPrefKeys) {
          expect(sharingPrefLabel(l, k), isNot(k), reason: 'sharing $k');
        }
      }
    });
    test('an unknown future key returns itself instead of throwing', () {
      expect(pushPrefLabel(en, 'brand_new'), 'brand_new');
      expect(whatsappPrefLabel(en, 'brand_new'), 'brand_new');
      expect(sharingPrefLabel(en, 'brand_new'), 'brand_new');
    });
    test('web labels carried over', () {
      expect(pushPrefLabel(en, 'match_assigned'), 'New fixture assigned');
      expect(whatsappPrefLabel(en, 'match_reminder'), 'Match reminders (1h before kickoff)');
      expect(sharingPrefLabel(en, 'tournament'), 'Tournament wins');
    });
  });
}
