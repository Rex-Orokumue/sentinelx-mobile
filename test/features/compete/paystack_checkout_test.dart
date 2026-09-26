import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/features/compete/paystack_checkout.dart';

void main() {
  test('recognizes the callback URL on any of our hosts, regardless of query and trailing slash', () {
    expect(isPaystackCallback(Uri.parse('https://sentinelxesports.com.ng/api/paystack/callback?reference=abc')), isTrue);
    expect(isPaystackCallback(Uri.parse('https://sentinelxesports.com.ng/api/paystack/callback/')), isTrue);
    expect(isPaystackCallback(Uri.parse('http://192.168.1.157:3000/api/paystack/callback?reference=abc&trxref=abc')), isTrue);
  });

  test('does not treat Paystack or lookalike URLs as the callback', () {
    expect(isPaystackCallback(Uri.parse('https://checkout.paystack.com/abc123')), isFalse);
    expect(isPaystackCallback(Uri.parse('https://checkout.paystack.com/api/paystack/callback')), isFalse);
    expect(isPaystackCallback(Uri.parse('https://paystack.com/api/paystack/callback')), isFalse);
    expect(isPaystackCallback(Uri.parse('https://sentinelxesports.com.ng/tournaments/x')), isFalse);
    expect(isPaystackCallback(Uri.parse('https://sentinelxesports.com.ng/api/paystack/callbackx')), isFalse);
  });
}
