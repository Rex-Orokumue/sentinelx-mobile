import 'package:flutter_test/flutter_test.dart';
import 'package:sentinelx_mobile/core/api/api_client.dart';
import 'package:sentinelx_mobile/core/l10n/gen/app_localizations_en.dart';
import 'package:sentinelx_mobile/features/wallet/wallet_errors.dart';

ApiException _e(String code, {Map<String, String> fields = const {}}) =>
    ApiException(status: 400, code: code, message: 'RAW SERVER MESSAGE', fields: fields);

void main() {
  final l10n = AppLocalizationsEn();

  test('known codes map to localized copy', () {
    expect(walletErrorCopy(l10n, _e('account_pending_deletion')), l10n.walletErrPendingDeletion);
    expect(walletErrorCopy(l10n, _e('email_required')), l10n.walletErrEmailRequired);
    expect(walletErrorCopy(l10n, _e('payment_unavailable')), l10n.walletErrPaymentUnavailable);
    expect(walletErrorCopy(l10n, _e('deposit_failed')), l10n.walletErrPaymentUnavailable);
    expect(walletErrorCopy(l10n, _e('account_unresolvable')), l10n.walletErrAccountUnresolvable);
    expect(walletErrorCopy(l10n, _e('unknown_bank')), l10n.walletErrUnknownBank);
    expect(walletErrorCopy(l10n, _e('already_verified')), l10n.walletErrAlreadyVerified);
    expect(walletErrorCopy(l10n, _e('payout_unavailable')), l10n.walletErrPayoutUnavailable);
    expect(walletErrorCopy(l10n, _e('kyc_required')), l10n.walletErrKycRequired);
    expect(walletErrorCopy(l10n, _e('insufficient_balance')), l10n.walletErrInsufficient);
    expect(walletErrorCopy(l10n, _e('withdrawal_pending')), l10n.walletErrWithdrawalPending);
    expect(walletErrorCopy(l10n, _e('network')), l10n.walletErrNetwork);
    expect(walletErrorCopy(l10n, _e('unauthorized')), l10n.walletErrSession);
    expect(walletErrorCopy(l10n, _e('idempotency_in_progress')), l10n.walletErrInProgress);
  });

  test('rate_limited reads retryAfterSeconds from the error fields', () {
    expect(walletErrorCopy(l10n, _e('rate_limited', fields: {'retryAfterSeconds': '42'})), l10n.walletErrRateLimited('42'));
  });

  test('rate_limited without a usable retry value still shows the rate-limit copy', () {
    expect(walletErrorCopy(l10n, _e('rate_limited')), l10n.walletErrRateLimited('60'));
  });

  test('anything unknown, and non-API errors, show the generic copy and never the raw server message', () {
    expect(walletErrorCopy(l10n, _e('something_new')), l10n.walletErrGeneric);
    expect(walletErrorCopy(l10n, StateError('boom')), l10n.walletErrGeneric);
    expect(walletErrorCopy(l10n, _e('something_new')), isNot(contains('RAW SERVER MESSAGE')));
  });
}
