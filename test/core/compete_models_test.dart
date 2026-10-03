import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/core/api/compete_models.dart';

void main() {
  test('RegistrationState maps every documented view', () {
    const wire = {
      'guest': RegView.guest, 'can_register': RegView.canRegister, 'complete_payment': RegView.completePayment,
      'registered': RegView.registered, 'waitlisted': RegView.waitlisted, 'full': RegView.full,
      'closed': RegView.closed, 'ended': RegView.ended, 'invitation_only': RegView.invitationOnly,
    };
    wire.forEach((s, v) {
      final st = RegistrationState.fromJson({
        'view': s, 'feeNaira': 500, 'hasWaiver': false, 'coinDiscountEligible': true, 'agreementRequired': true,
      });
      expect(st.view, v);
      expect(st.feeNaira, 500);
      expect(st.coinDiscountEligible, isTrue);
    });
  });

  test('an unknown view from a newer server throws FormatException (surfaces as bad_response)', () {
    expect(
      () => RegistrationState.fromJson({'view': 'brand_new', 'feeNaira': 0, 'hasWaiver': false, 'coinDiscountEligible': false, 'agreementRequired': false}),
      throwsFormatException,
    );
  });

  test('parseRegisterOutcome handles confirmed and pending', () {
    expect(parseRegisterOutcome({'status': 'confirmed'}), isA<RegisterConfirmed>());
    final p = parseRegisterOutcome({'status': 'pending', 'authorizationUrl': 'https://pay.test/x', 'reference': 'ref1'});
    expect(p, isA<RegisterPending>());
    expect((p as RegisterPending).reference, 'ref1');
    expect(() => parseRegisterOutcome({'status': 'weird'}), throwsFormatException);
  });

  test('PaymentStatus parses snake_case and isPaid', () {
    expect(parsePaymentStatus('confirmed').isPaid, isTrue);
    expect(parsePaymentStatus('already_paid').isPaid, isTrue);
    expect(parsePaymentStatus('not_successful').isPaid, isFalse);
    expect(parsePaymentStatus('not_found').isPaid, isFalse);
    expect(() => parsePaymentStatus('??'), throwsFormatException);
  });

  test('RegistrationDetails emits the dynamic registrationDetails map', () {
    const d = RegistrationDetails(displayName: 'Ada', whatsapp: '+2348012345678', registrationDetails: {'club_name': 'FC'}, agreedToRules: true);
    expect(d.toJson(), {'displayName': 'Ada', 'whatsapp': '+2348012345678', 'registrationDetails': {'club_name': 'FC'}, 'agreedToRules': true});
  });

  test('ProfileEdit sends every field, empty string for blanks', () {
    const e = ProfileEdit(displayName: 'Ada', username: '', whatsapp: '', country: '', bio: '');
    expect(e.toJson(), {'displayName': 'Ada', 'username': '', 'whatsapp': '', 'country': '', 'bio': ''});
  });

  test('ProfileEdit omits new optional fields for old-client compatibility and preserves false when supplied', () {
    const old = ProfileEdit(displayName: 'Ada', username: '', whatsapp: '', country: '', bio: '');
    expect(old.toJson().containsKey('gameInterests'), isFalse);
    expect(old.toJson().containsKey('consentWhatsappUpdates'), isFalse);
    const current = ProfileEdit(
      displayName: 'Ada', username: '', whatsapp: '+2348012345678', country: 'Nigeria', bio: '',
      gameInterests: ['74db07fa-e711-4e78-a982-2863a45137f1'], consentWhatsappUpdates: false,
    );
    expect(current.toJson()['gameInterests'], ['74db07fa-e711-4e78-a982-2863a45137f1']);
    expect(current.toJson()['consentWhatsappUpdates'], isFalse);
  });
}
