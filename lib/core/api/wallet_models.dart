/// Response models for the `/wallet/**` operations. Money is integer naira; the server owns every figure.
/// The account number only ever arrives masked (`•••1234`).
class PayoutAccount {
  const PayoutAccount({required this.bankName, required this.accountName, required this.accountNumberMasked});

  factory PayoutAccount.fromJson(Map<String, dynamic> json) => PayoutAccount(
        bankName: json['bankName'] as String,
        accountName: json['accountName'] as String,
        accountNumberMasked: json['accountNumberMasked'] as String,
      );

  final String bankName;
  final String accountName;
  final String accountNumberMasked;
}

class WalletEarnings {
  const WalletEarnings({
    required this.tournamentPrize,
    required this.referral,
    required this.bonus,
    required this.tournamentPrizeTrendPct,
  });

  factory WalletEarnings.fromJson(Map<String, dynamic> json) => WalletEarnings(
        tournamentPrize: (json['tournamentPrize'] as num).toInt(),
        referral: (json['referral'] as num).toInt(),
        bonus: (json['bonus'] as num).toInt(),
        tournamentPrizeTrendPct: (json['tournamentPrizeTrendPct'] as num?)?.toInt(),
      );

  final int tournamentPrize;
  final int referral;
  final int bonus;

  /// Null when there is no earlier month to compare against; the UI hides the trend rather than show 0%.
  final int? tournamentPrizeTrendPct;
}

class WalletTxn {
  const WalletTxn({
    required this.id,
    required this.type,
    required this.category,
    required this.amount,
    required this.createdAt,
    required this.status,
  });

  factory WalletTxn.fromJson(Map<String, dynamic> json) => WalletTxn(
        id: json['id'] as String,
        type: json['type'] as String,
        category: json['category'] as String?,
        amount: (json['amount'] as num).toInt(),
        createdAt: DateTime.parse(json['createdAt'] as String).toUtc(),
        status: json['status'] as String,
      );

  final String id;
  final String type;
  final String? category;

  /// Signed: credits positive, debits negative.
  final int amount;
  final DateTime createdAt;

  /// `completed`, `pending` or `failed`.
  final String status;
}

class ActiveWithdrawal {
  const ActiveWithdrawal({required this.id, required this.amount, required this.requestedAt});

  factory ActiveWithdrawal.fromJson(Map<String, dynamic> json) => ActiveWithdrawal(
        id: json['id'] as String,
        amount: (json['amount'] as num).toInt(),
        requestedAt: DateTime.parse(json['requestedAt'] as String).toUtc(),
      );

  final String id;
  final int amount;
  final DateTime requestedAt;
}

class WalletOverview {
  const WalletOverview({
    required this.balance,
    required this.pendingWithdrawal,
    required this.earnings,
    required this.recentTransactions,
    required this.payoutAccount,
    required this.kycVerified,
    required this.activeWithdrawal,
  });

  factory WalletOverview.fromJson(Map<String, dynamic> json) => WalletOverview(
        balance: (json['balance'] as num).toInt(),
        pendingWithdrawal: (json['pendingWithdrawal'] as num).toInt(),
        earnings: WalletEarnings.fromJson(json['earnings'] as Map<String, dynamic>),
        recentTransactions: [
          for (final t in json['recentTransactions'] as List<dynamic>) WalletTxn.fromJson(t as Map<String, dynamic>),
        ],
        payoutAccount: json['payoutAccount'] == null
            ? null
            : PayoutAccount.fromJson(json['payoutAccount'] as Map<String, dynamic>),
        kycVerified: json['kycVerified'] as bool,
        activeWithdrawal: json['activeWithdrawal'] == null
            ? null
            : ActiveWithdrawal.fromJson(json['activeWithdrawal'] as Map<String, dynamic>),
      );

  final int balance;
  final int pendingWithdrawal;
  final WalletEarnings earnings;
  final List<WalletTxn> recentTransactions;
  final PayoutAccount? payoutAccount;
  final bool kycVerified;
  final ActiveWithdrawal? activeWithdrawal;
}

class WalletTxnPage {
  const WalletTxnPage({required this.items, required this.nextCursor});

  factory WalletTxnPage.fromJson(Map<String, dynamic> json) => WalletTxnPage(
        items: [for (final t in json['items'] as List<dynamic>) WalletTxn.fromJson(t as Map<String, dynamic>)],
        nextCursor: json['nextCursor'] as String?,
      );

  final List<WalletTxn> items;
  final String? nextCursor;
}

class WalletBank {
  const WalletBank({required this.name, required this.code});

  factory WalletBank.fromJson(Map<String, dynamic> json) =>
      WalletBank(name: json['name'] as String, code: json['code'] as String);

  final String name;
  final String code;
}

class DepositStart {
  const DepositStart({
    required this.reference,
    required this.authorizationUrl,
    required this.amount,
    required this.fee,
    required this.total,
  });

  factory DepositStart.fromJson(Map<String, dynamic> json) => DepositStart(
        reference: json['reference'] as String,
        authorizationUrl: json['authorizationUrl'] as String,
        amount: (json['amount'] as num).toInt(),
        fee: (json['fee'] as num).toInt(),
        total: (json['total'] as num).toInt(),
      );

  final String reference;
  final String authorizationUrl;
  final int amount;

  /// Computed by the server; the app never calculates the Paystack fee.
  final int fee;
  final int total;
}

enum DepositStatus { confirmed, alreadyPaid, notSuccessful, notFound }

class DepositPoll {
  const DepositPoll({required this.status, required this.balance});

  factory DepositPoll.fromJson(Map<String, dynamic> json) => DepositPoll(
        status: switch (json['status'] as String) {
          'confirmed' => DepositStatus.confirmed,
          'already_paid' => DepositStatus.alreadyPaid,
          'not_successful' => DepositStatus.notSuccessful,
          'not_found' => DepositStatus.notFound,
          final other => throw FormatException('Unknown deposit status: $other'),
        },
        balance: (json['balance'] as num?)?.toInt(),
      );

  final DepositStatus status;

  /// Present only once the deposit has been credited.
  final int? balance;

  bool get credited => status == DepositStatus.confirmed || status == DepositStatus.alreadyPaid;
}

class Withdrawal {
  const Withdrawal({
    required this.id,
    required this.amount,
    required this.status,
    required this.requestedAt,
    required this.resolvedAt,
    required this.payoutAccount,
  });

  factory Withdrawal.fromJson(Map<String, dynamic> json) => Withdrawal(
        id: json['id'] as String,
        amount: (json['amount'] as num).toInt(),
        status: json['status'] as String,
        requestedAt: DateTime.parse(json['requestedAt'] as String).toUtc(),
        resolvedAt: json['resolvedAt'] == null ? null : DateTime.parse(json['resolvedAt'] as String).toUtc(),
        payoutAccount: PayoutAccount.fromJson(json['payoutAccount'] as Map<String, dynamic>),
      );

  final String id;
  final int amount;

  /// `pending`, `paid` or `rejected`.
  final String status;
  final DateTime requestedAt;
  final DateTime? resolvedAt;
  final PayoutAccount payoutAccount;
}

class WithdrawalPage {
  const WithdrawalPage({required this.items, required this.nextCursor});

  factory WithdrawalPage.fromJson(Map<String, dynamic> json) => WithdrawalPage(
        items: [for (final w in json['items'] as List<dynamic>) Withdrawal.fromJson(w as Map<String, dynamic>)],
        nextCursor: json['nextCursor'] as String?,
      );

  final List<Withdrawal> items;
  final String? nextCursor;
}
