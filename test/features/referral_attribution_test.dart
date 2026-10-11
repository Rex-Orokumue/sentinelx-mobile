import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/features/account/referrals/referral_attribution.dart';

import '../fakes/fake_local_kv.dart';

void main() {
  test('reads and validates only the ref parameter', () {
    expect(parseInstallReferrer('utm_source=play&ref=friend_1'), 'friend_1');
    expect(parseInstallReferrer('ref=bad%2Bname'), isNull);
    expect(parseInstallReferrer('ref=ab'), isNull);
    expect(parseInstallReferrer('utm_source=play'), isNull);
  });

  test('an explicit link wins over the stored install referrer', () async {
    final kv = MemoryLocalKv();
    var reads = 0;
    final attribution = ReferralAttribution(kv, () async {
      reads++;
      return 'ref=install_friend';
    });
    expect(await attribution.refForSignup(null), 'install_friend');
    expect(await attribution.refForSignup('link_friend'), 'link_friend');
    expect(reads, 1);
  });

  test(
    'reads Play once per install and survives app restart until signup succeeds',
    () async {
      final kv = MemoryLocalKv();
      var reads = 0;
      final first = ReferralAttribution(kv, () async {
        reads++;
        return 'ref=install_friend';
      });
      expect(await first.refForSignup(null), 'install_friend');
      final restarted = ReferralAttribution(kv, () async {
        reads++;
        return null;
      });
      expect(await restarted.refForSignup(null), 'install_friend');
      expect(reads, 1);
      await restarted.clearAfterSignup();
      expect(await restarted.refForSignup(null), isNull);
      expect(reads, 1);
    },
  );

  test('malformed referrer is ignored and not retried', () async {
    final kv = MemoryLocalKv();
    var reads = 0;
    final attribution = ReferralAttribution(kv, () async {
      reads++;
      return 'ref=bad%2Bname';
    });
    expect(await attribution.refForSignup(null), isNull);
    expect(await attribution.refForSignup(null), isNull);
    expect(reads, 1);
  });

  test(
    'an interrupted cache write keeps the saved referral if Play later returns none',
    () async {
      final kv = MemoryLocalKv();
      await kv.write('referral.install.code', 'saved_friend');
      final attribution = ReferralAttribution(kv, () async => null);
      expect(await attribution.refForSignup(null), 'saved_friend');
    },
  );
}
