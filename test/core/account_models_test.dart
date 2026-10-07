import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/core/api/account_models.dart';
import 'package:sentinelx_mobile/core/api/models.dart';

void main() {
  test('MyAccount parses a full response', () {
    final a = MyAccount.fromJson({
      'deletion': {'requestedAt': '2026-10-05T00:00:00.000Z', 'dueAt': '2026-10-20T00:00:00.000Z', 'daysRemaining': 13},
      'signIn': {'email': 'a@b.com', 'pendingEmail': 'n@b.com', 'passwordIdentity': true, 'google': false},
      'phone': {'masked': '••••678', 'verifiedAt': '2026-10-01T00:00:00.000Z'},
      'locale': 'fr',
    });
    expect(a.deletion!.daysRemaining, 13);
    expect(a.deletion!.dueAt, DateTime.utc(2026, 10, 20));
    expect(a.signIn.pendingEmail, 'n@b.com');
    expect(a.signIn.passwordIdentity, isTrue);
    expect(a.signIn.google, isFalse);
    expect(a.phone!.masked, '••••678');
    expect(a.locale, 'fr');
  });

  test('MyAccount parses the empty case', () {
    final a = MyAccount.fromJson({
      'deletion': null,
      'signIn': {'email': null, 'pendingEmail': null, 'passwordIdentity': false, 'google': true},
      'phone': null,
      'locale': null,
    });
    expect(a.deletion, isNull);
    expect(a.phone, isNull);
    expect(a.signIn.email, isNull);
    expect(a.locale, isNull);
  });

  test('PhoneCodeTicket and DeletionTicket parse ISO times', () {
    expect(PhoneCodeTicket.fromJson({'expiresAt': '2026-10-07T10:10:00.000Z', 'resendAt': '2026-10-07T10:01:00.000Z'}).resendAt,
        DateTime.utc(2026, 10, 7, 10, 1));
    expect(DeletionTicket.fromJson({'requestedAt': '2026-10-07T00:00:00.000Z', 'dueAt': '2026-10-22T00:00:00.000Z'}).dueAt,
        DateTime.utc(2026, 10, 22));
  });

  test('DeletionBlocker keeps amount or count and ignores unknown codes gracefully', () {
    final list = DeletionBlocker.listFrom({
      'blockers': [
        {'code': 'wallet_balance', 'amount': 5000},
        {'code': 'pending_withdrawal', 'count': 2},
        {'code': 'something_new_from_the_server', 'count': 1},
      ],
    });
    expect(list.map((b) => b.code), ['wallet_balance', 'pending_withdrawal', 'something_new_from_the_server']);
    expect(list[0].amount, 5000);
    expect(list[1].count, 2);
  });

  test('DeletionBlocker.listFrom tolerates missing or malformed details', () {
    expect(DeletionBlocker.listFrom(const {}), isEmpty);
    expect(DeletionBlocker.listFrom({'blockers': 'nope'}), isEmpty);
    expect(DeletionBlocker.listFrom({'blockers': [1, null]}), isEmpty);
  });

  test('MeProfile parses phoneVerifiedAt and tolerates its absence (older server)', () {
    Map<String, dynamic> base() => {
          'username': 'ada', 'displayName': null, 'avatarUrl': null, 'whatsappNumber': null, 'country': null, 'locale': 'en',
          'membershipTier': null, 'kycVerified': false, 'deletionRequestedAt': null, 'profileCompletedAt': null,
          'consentWhatsappUpdates': false, 'gameInterests': <dynamic>[], 'bubbleSkinUrl': null,
        };
    expect(MeProfile.fromJson(base()).phoneVerifiedAt, isNull);
    expect(MeProfile.fromJson({...base(), 'phoneVerifiedAt': '2026-10-01T00:00:00.000Z'}).phoneVerifiedAt, '2026-10-01T00:00:00.000Z');
  });
}
