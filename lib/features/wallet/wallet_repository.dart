import '../../core/api/api_client.dart';
import '../../core/api/wallet_models.dart';

/// The wallet's only data source: the `/api/mobile/v1/wallet/**` operations. Screens never touch Supabase tables
/// for balance or ledger, so the app and the website can never disagree on a figure.
abstract class WalletRepository {
  Future<WalletOverview> getMyWallet();
  Future<WalletTxnPage> listMyWalletTransactions({String filter = 'all', String? cursor});
  Future<List<WalletBank>> listWalletBanks();
  Future<String> resolvePayoutAccount({required String bankCode, required String accountNumber});
  Future<PayoutAccount> setPayoutAccount({required String bankCode, required String accountNumber});
  Future<void> removePayoutAccount();
  Future<DepositStart> startWalletDeposit(int amount, {required String idempotencyKey});
  Future<DepositPoll> getWalletDeposit(String reference);
  Future<Withdrawal> requestWithdrawal(int amount, {required String idempotencyKey});
  Future<WithdrawalPage> listMyWithdrawals({String? cursor});
}

class ApiWalletRepository implements WalletRepository {
  ApiWalletRepository(this._api);

  final ApiClient _api;

  @override
  Future<WalletOverview> getMyWallet() => _api.getMyWallet();

  @override
  Future<WalletTxnPage> listMyWalletTransactions({String filter = 'all', String? cursor}) =>
      _api.listMyWalletTransactions(filter: filter, cursor: cursor);

  @override
  Future<List<WalletBank>> listWalletBanks() => _api.listWalletBanks();

  @override
  Future<String> resolvePayoutAccount({required String bankCode, required String accountNumber}) =>
      _api.resolvePayoutAccount(bankCode: bankCode, accountNumber: accountNumber);

  @override
  Future<PayoutAccount> setPayoutAccount({required String bankCode, required String accountNumber}) =>
      _api.setPayoutAccount(bankCode: bankCode, accountNumber: accountNumber);

  @override
  Future<void> removePayoutAccount() => _api.removePayoutAccount();

  @override
  Future<DepositStart> startWalletDeposit(int amount, {required String idempotencyKey}) =>
      _api.startWalletDeposit(amount, idempotencyKey: idempotencyKey);

  @override
  Future<DepositPoll> getWalletDeposit(String reference) => _api.getWalletDeposit(reference);

  @override
  Future<Withdrawal> requestWithdrawal(int amount, {required String idempotencyKey}) =>
      _api.requestWithdrawal(amount, idempotencyKey: idempotencyKey);

  @override
  Future<WithdrawalPage> listMyWithdrawals({String? cursor}) => _api.listMyWithdrawals(cursor: cursor);
}
