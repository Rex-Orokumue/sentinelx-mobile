import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/core/api/api_client.dart';
import 'package:sentinelx_mobile/core/api/compete_models.dart';
import 'package:sentinelx_mobile/core/api/registration_fields_models.dart';

class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.respond);
  final ResponseBody Function(RequestOptions options) respond;
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    requests.add(options);
    return respond(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _json(int status, Object body) => ResponseBody.fromString(jsonEncode(body), status,
    headers: {Headers.contentTypeHeader: [Headers.jsonContentType]});

ApiClient _client(_FakeAdapter a) => ApiClient.create(
    baseUrl: 'https://api.test', appVersion: '1.0.0', platform: 'android', accessToken: () async => 'tok', adapter: a);

const _details = RegistrationDetails(displayName: 'Ada', whatsapp: '+2348012345678', registrationDetails: {'club_name': 'FC Ada'}, agreedToRules: true);

void main() {
  test('getTournamentRegistrationFields is public and parses the ordered catalogue', () async {
    final a = _FakeAdapter((_) => _json(200, {'data': {'fields': [
      {'fieldKey': 'uid', 'label': 'UID', 'placeholder': '123', 'inputType': 'number', 'required': true,
       'validationPattern': r'^\d+$', 'validationMessage': 'Digits only'}
    ]}}));
    final fields = await _client(a).getTournamentRegistrationFields('t 1');
    expect(a.requests.single.path, '/api/mobile/v1/tournaments/t%201/registration-fields');
    expect(a.requests.single.headers.containsKey('Authorization'), isFalse);
    expect(fields.single.inputType, RegistrationFieldInputType.number);
  });

  test('getTournamentRegistrationState hits the right path and parses', () async {
    final a = _FakeAdapter((_) => _json(200, {
          'data': {'view': 'can_register', 'feeNaira': 500, 'hasWaiver': false, 'coinDiscountEligible': true, 'agreementRequired': true}
        }));
    final s = await _client(a).getTournamentRegistrationState('t1');
    expect(a.requests.single.method, 'GET');
    expect(a.requests.single.path, '/api/mobile/v1/tournaments/t1/registration-state');
    expect(s.view, RegView.canRegister);
  });

  test('postTournamentRegister sends the Idempotency-Key header and body, returns pending', () async {
    final a = _FakeAdapter((_) => _json(200, {
          'data': {'status': 'pending', 'authorizationUrl': 'https://pay.test/a', 'reference': 'r1'}
        }));
    final out = await _client(a).postTournamentRegister('t1', details: _details, coinsUsed: 500, idempotencyKey: 'key-1');
    final req = a.requests.single;
    expect(req.method, 'POST');
    expect(req.path, '/api/mobile/v1/tournaments/t1/register');
    expect(req.headers['Idempotency-Key'], 'key-1');
    expect((req.data as Map)['coinsUsed'], 500);
    expect((req.data as Map)['agreedToRules'], true);
    expect((req.data as Map)['registrationDetails'], {'club_name': 'FC Ada'});
    expect((req.data as Map).containsKey('clubName'), isFalse);
    expect(out, isA<RegisterPending>());
  });

  test('postTournamentRegister surfaces the error code and status', () async {
    final a = _FakeAdapter((_) => _json(409, {
          'error': {'code': 'tournament_full', 'message': 'This tournament is full.'}
        }));
    await expectLater(
      _client(a).postTournamentRegister('t1', details: _details, coinsUsed: 0, idempotencyKey: 'k'),
      throwsA(isA<ApiException>().having((e) => e.code, 'code', 'tournament_full').having((e) => e.status, 'status', 409)),
    );
  });

  test('postTournamentWaitlist sends no Idempotency-Key', () async {
    final a = _FakeAdapter((_) => _json(200, {'data': {'status': 'waitlisted'}}));
    await _client(a).postTournamentWaitlist('t1', details: _details);
    expect(a.requests.single.path, '/api/mobile/v1/tournaments/t1/waitlist');
    expect(a.requests.single.headers.containsKey('Idempotency-Key'), isFalse);
  });

  test('postInvitationAccept sends the key; decline does not', () async {
    final a = _FakeAdapter((o) => o.path.endsWith('/accept')
        ? _json(200, {'data': {'status': 'confirmed'}})
        : _json(200, {'data': {'status': 'declined'}}));
    final c = _client(a);
    expect(await c.postInvitationAccept('i1', idempotencyKey: 'k9'), isA<RegisterConfirmed>());
    expect(a.requests.last.headers['Idempotency-Key'], 'k9');
    await c.postInvitationDecline('i1');
    expect(a.requests.last.path, '/api/mobile/v1/invitations/i1/decline');
    expect(a.requests.last.headers.containsKey('Idempotency-Key'), isFalse);
  });

  test('getPaymentStatus parses the enum', () async {
    final a = _FakeAdapter((_) => _json(200, {'data': {'status': 'already_paid'}}));
    expect(await _client(a).getPaymentStatus('ref 1/x'), PaymentStatus.alreadyPaid);
    expect(a.requests.single.path, '/api/mobile/v1/payments/ref%201%2Fx');
  });

  test('patchMeProfile PATCHes /me/profile with every field', () async {
    final a = _FakeAdapter((_) => _json(200, {'data': {'ok': true}}));
    await _client(a).patchMeProfile(const ProfileEdit(
      displayName: 'Ada', username: '', whatsapp: '', country: 'Nigeria', bio: 'hi',
      gameInterests: ['74db07fa-e711-4e78-a982-2863a45137f1'], consentWhatsappUpdates: false,
    ));
    expect(a.requests.single.method, 'PATCH');
    expect(a.requests.single.path, '/api/mobile/v1/me/profile');
    expect((a.requests.single.data as Map)['country'], 'Nigeria');
    expect((a.requests.single.data as Map)['gameInterests'], ['74db07fa-e711-4e78-a982-2863a45137f1']);
    expect((a.requests.single.data as Map)['consentWhatsappUpdates'], isFalse);
  });
}
