import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/core/api/api_client.dart';
import 'package:sentinelx_mobile/core/api/wallet_models.dart';

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

ResponseBody _json(int status, Object body) =>
    ResponseBody.fromString(jsonEncode(body), status, headers: {Headers.contentTypeHeader: [Headers.jsonContentType]});

ApiClient _client(_FakeAdapter a) => ApiClient.create(
    baseUrl: 'https://api.test', appVersion: '1.0.0', platform: 'android', accessToken: () async => 'tok', adapter: a);

_FakeAdapter _ok(Object? data) => _FakeAdapter((_) => _json(200, {'data': data}));

void main() {
  test('startWalletDeposit posts the amount with the Idempotency-Key and parses the checkout details', () async {
    final a = _ok({'reference': 'r1', 'authorizationUrl': 'https://pay.test/x', 'amount': 5000, 'fee': 175, 'total': 5175});
    final d = await _client(a).startWalletDeposit(5000, idempotencyKey: 'key-1');
    expect(a.requests.single.method, 'POST');
    expect(a.requests.single.uri.toString(), 'https://api.test/api/mobile/v1/wallet/deposits');
    expect(a.requests.single.headers['Idempotency-Key'], 'key-1');
    expect(a.requests.single.data, {'amount': 5000});
    expect(d.total, 5175);
  });

  test('requestWithdrawal posts the amount with the Idempotency-Key and tolerates a response without resolvedAt', () async {
    final a = _ok({
      'id': 'wr1', 'amount': 1500, 'status': 'pending', 'requestedAt': '2026-10-15T10:00:00.000Z',
      'payoutAccount': {'bankName': 'GTBank', 'accountName': 'ADA OBI', 'accountNumberMasked': '•••6789'},
    });
    final w = await _client(a).requestWithdrawal(1500, idempotencyKey: 'key-2');
    expect(a.requests.single.headers['Idempotency-Key'], 'key-2');
    expect(a.requests.single.uri.toString(), 'https://api.test/api/mobile/v1/wallet/withdrawals');
    expect(w.status, 'pending');
    expect(w.resolvedAt, isNull);
  });

  test('listMyWalletTransactions sends the filter and an encoded cursor', () async {
    final a = _ok({'items': <Object>[], 'nextCursor': null});
    await _client(a).listMyWalletTransactions(filter: 'winnings', cursor: 'a+b/c==');
    final uri = a.requests.single.uri;
    expect(uri.path, '/api/mobile/v1/wallet/transactions');
    expect(uri.queryParameters, {'filter': 'winnings', 'cursor': 'a+b/c=='});
  });

  test('listMyWithdrawals omits the cursor on the first page', () async {
    final a = _ok({'items': <Object>[], 'nextCursor': null});
    await _client(a).listMyWithdrawals();
    expect(a.requests.single.uri.toString(), 'https://api.test/api/mobile/v1/wallet/withdrawals');
  });

  test('getWalletDeposit encodes the reference into the path', () async {
    final a = _ok({'status': 'confirmed', 'balance': 6000});
    final poll = await _client(a).getWalletDeposit('sxdep_a b');
    expect(a.requests.single.uri.toString(), 'https://api.test/api/mobile/v1/wallet/deposits/sxdep_a%20b');
    expect(poll.status, DepositStatus.confirmed);
    expect(poll.credited, isTrue);
  });

  test('payout calls send only the bank code and account number, and return the resolved name / masked account', () async {
    final resolveAdapter = _ok({'accountName': 'ADA OBI'});
    expect(await _client(resolveAdapter).resolvePayoutAccount(bankCode: '058', accountNumber: '0123456789'), 'ADA OBI');
    expect(resolveAdapter.requests.single.data, {'bankCode': '058', 'accountNumber': '0123456789'});

    final setAdapter = _ok({'payoutAccount': {'bankName': 'GTBank', 'accountName': 'ADA OBI', 'accountNumberMasked': '•••6789'}});
    final saved = await _client(setAdapter).setPayoutAccount(bankCode: '058', accountNumber: '0123456789');
    expect(setAdapter.requests.single.method, 'PUT');
    expect(saved.accountNumberMasked, '•••6789');

    final removeAdapter = _ok({'removed': true});
    await _client(removeAdapter).removePayoutAccount();
    expect(removeAdapter.requests.single.method, 'DELETE');
  });

  test('a rate_limited error surfaces its retryAfterSeconds field', () async {
    final a = _FakeAdapter((_) => _json(429, {
          'error': {'code': 'rate_limited', 'message': 'Too many attempts.', 'fields': {'retryAfterSeconds': '42'}},
        }));
    await expectLater(
      _client(a).resolvePayoutAccount(bankCode: '058', accountNumber: '0123456789'),
      throwsA(isA<ApiException>().having((e) => e.code, 'code', 'rate_limited').having((e) => e.fields['retryAfterSeconds'], 'retry', '42')),
    );
  });
}
