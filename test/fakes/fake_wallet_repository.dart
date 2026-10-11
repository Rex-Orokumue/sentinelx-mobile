import 'package:sentinelx_mobile/core/api/wallet_models.dart';
import 'package:sentinelx_mobile/features/wallet/wallet_repository.dart';

const testPayoutAccount = PayoutAccount(bankName: 'GTBank', accountName: 'ADA OBI', accountNumberMasked: '•••6789');

WalletOverview walletOverviewFixture({
  int balance = 5000,
  int pendingWithdrawal = 0,
  int? trendPct,
  List<WalletTxn> recent = const [],
  PayoutAccount? payout = testPayoutAccount,
  bool kycVerified = true,
  ActiveWithdrawal? active,
}) =>
    WalletOverview(
      balance: balance,
      pendingWithdrawal: pendingWithdrawal,
      earnings: WalletEarnings(tournamentPrize: 3000, referral: 250, bonus: 700, tournamentPrizeTrendPct: trendPct),
      recentTransactions: recent,
      payoutAccount: payout,
      kycVerified: kycVerified,
      activeWithdrawal: active,
    );

WalletTxn walletTxnFixture(String id, {int amount = 500, String type = 'prize', String? category = 'tournament_prize', String status = 'completed'}) =>
    WalletTxn(id: id, type: type, category: category, amount: amount, createdAt: DateTime.utc(2026, 10, 15, 9), status: status);

Withdrawal withdrawalFixture(String id, {String status = 'pending', int amount = 1500}) => Withdrawal(
      id: id,
      amount: amount,
      status: status,
      requestedAt: DateTime.utc(2026, 10, 15, 10),
      resolvedAt: status == 'pending' ? null : DateTime.utc(2026, 10, 16, 10),
      payoutAccount: testPayoutAccount,
    );

/// In-memory [WalletRepository]. Results are queued per call; an `Object` that is an Exception is thrown instead.
class FakeWalletRepository implements WalletRepository {
  final calls = <String>[];

  Object overview = walletOverviewFixture();
  final txnPages = <Object>[]; // WalletTxnPage or an Exception, consumed one per call
  final txnRequests = <({String filter, String? cursor})>[];
  List<WalletBank> banks = const [WalletBank(name: 'GTBank', code: '058'), WalletBank(name: 'Test Bank', code: '001')];
  Object resolveResult = 'ADA OBI'; // String or Exception
  Object setResult = testPayoutAccount; // PayoutAccount or Exception
  Object removeResult = true; // true or Exception
  Object depositStart = const DepositStart(reference: 'r1', authorizationUrl: 'https://pay.test/x', amount: 5000, fee: 175, total: 5175);
  final depositPolls = <Object>[]; // DepositPoll or Exception, consumed one per call
  Object withdrawalResult = withdrawalFixture('wr1'); // Withdrawal or Exception
  Object withdrawals = const WithdrawalPage(items: [], nextCursor: null);

  final idempotencyKeys = <String>[];
  final depositAmounts = <int>[];
  final withdrawalAmounts = <int>[];

  T _out<T>(Object o) {
    if (o is Exception) throw o;
    return o as T;
  }

  @override
  Future<WalletOverview> getMyWallet() async {
    calls.add('overview');
    return _out(overview);
  }

  @override
  Future<WalletTxnPage> listMyWalletTransactions({String filter = 'all', String? cursor}) async {
    calls.add('transactions');
    txnRequests.add((filter: filter, cursor: cursor));
    return _out(txnPages.isEmpty ? const WalletTxnPage(items: [], nextCursor: null) : txnPages.removeAt(0));
  }

  @override
  Future<List<WalletBank>> listWalletBanks() async {
    calls.add('banks');
    return banks;
  }

  @override
  Future<String> resolvePayoutAccount({required String bankCode, required String accountNumber}) async {
    calls.add('resolve:$bankCode:$accountNumber');
    return _out(resolveResult);
  }

  @override
  Future<PayoutAccount> setPayoutAccount({required String bankCode, required String accountNumber}) async {
    calls.add('set:$bankCode:$accountNumber');
    return _out(setResult);
  }

  @override
  Future<void> removePayoutAccount() async {
    calls.add('remove');
    _out<bool>(removeResult);
  }

  @override
  Future<DepositStart> startWalletDeposit(int amount, {required String idempotencyKey}) async {
    calls.add('startDeposit');
    depositAmounts.add(amount);
    idempotencyKeys.add(idempotencyKey);
    return _out(depositStart);
  }

  @override
  Future<DepositPoll> getWalletDeposit(String reference) async {
    calls.add('poll:$reference');
    return _out(depositPolls.isEmpty ? const DepositPoll(status: DepositStatus.notSuccessful, balance: null) : depositPolls.removeAt(0));
  }

  @override
  Future<Withdrawal> requestWithdrawal(int amount, {required String idempotencyKey}) async {
    calls.add('withdraw');
    withdrawalAmounts.add(amount);
    idempotencyKeys.add(idempotencyKey);
    return _out(withdrawalResult);
  }

  @override
  Future<WithdrawalPage> listMyWithdrawals({String? cursor}) async {
    calls.add('withdrawals');
    return _out(withdrawals);
  }
}
